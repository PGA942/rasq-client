import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, FileSystemEntity, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../notify/local_notifier.dart';

/// **いま見ている画面を少しだけ読み取る** (D-415、Android の本物は D-416)。
///
/// 流れ(Android、[NativeScreenGlimpse]): 探す画面(好きな画像やコンテンツから探す)で「いつものブラウザで見て探す」→
/// 端末の「画面の読み取り」の同意 → RASQ の前面サービスが取り込みを持ち、ボタンつきの通知(「この画面を読み取る(3 秒)」)を出す →
/// 端末のブラウザで好きなページを見る → 通知のボタン → **RASQ を前に出さずに** 3 秒だけ読み取り(1 秒ごと、同じコマは飛ばす)、
/// すぐ取り込みを止める →「読み取りました — タップで結果を見る」→ タップで RASQ が開き(`/sns-discover/content?glimpse=done&id=…`)、
/// コマを `frames`(`source: screen`、`capturedAt`)で `POST /onboarding/discover/content` に送って結果を出す。送ったらコマは消す。
///
/// iOS(D-417、[NativeScreenGlimpse.broadcast]): 「いつものブラウザで見て探す」→ 端末の「画面の配信」のシート(RASQ の
/// Broadcast Upload Extension `ScreenGlimpseBroadcast`)→ ブラウザで好きなページを見る → 画面上部の赤い表示 / コントロールセンターから
/// 配信を止める → 止める直前の約 3 秒(最大 4 コマ)を拡張機能が残す → RASQ に戻ると、Android と同じく `done` / `open` で結果を開く。
/// iOS には「通知のボタンで読み取る」が無いので、**止めたことが合図**。
///
/// ほかの端末([DummyScreenGlimpse]): D-415 のまま、RASQ の通知のタップで開いて「3 秒読み取る」(ダミーの写し、画面にそう出す)。
abstract interface class ScreenGlimpse {
  /// 読み取りがダミーか(画面にそう出す)。
  bool get isDummy;

  /// 端末が自分で読み取るか(Android / iOS)。false なら RASQ の通知 + [capture](ダミー)。
  bool get native;

  /// 同意を得て、読み取りの準備をする(native だけ)。ブラウザは呼んだ側が開く。
  Future<GlimpseStartStatus> start();

  /// 準備をやめる(native だけ)。
  Future<void> cancel();

  /// 端末からの知らせ(native だけ)。
  Stream<GlimpseEvent> get events;

  /// 読み取ったコマ(native だけ)。無ければ null(消えた / もう送った)。
  Future<GlimpseFrames?> takeResult(String id);

  /// 読み取ったコマを消す(送ったあと / やめたとき)。「読み取りました」の通知も消す。
  Future<void> discard(String id);

  /// 「読み取りました」の通知から起動したときの id(1 度だけ)。
  Future<String?> takeLaunchOpen();

  /// 置いたままのコマ([maxAge] より古いもの)を消す(起動時)。消した数。
  Future<int> cleanupStale({Duration maxAge = glimpseStaleAfter});

  /// 画面を [duration] だけ読み取る(ダミーだけ)。[onProgress] は経過時間。
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress});
}

/// 置いたままのコマを消すまでの時間。
const glimpseStaleAfter = Duration(minutes: 10);

/// [ScreenGlimpse.start] の結果。
enum GlimpseStartStatus {
  /// 準備できた(通知を出した)。
  started,

  /// 画面の読み取りを許可されなかった。
  denied,

  /// 通知を許可されなかった(読み取りのボタンを出せない)。
  notificationsDenied,

  /// もう準備している / 読み取っている。
  busy,

  /// この端末では使えない。
  unavailable,
}

/// 端末からの知らせ。[type] は armed / capturing / done / stopped / open。
@immutable
class GlimpseEvent {
  const GlimpseEvent(this.type, {this.id, this.reason});
  final String type;

  /// 読み取りの id(capturing / done / open)。
  final String? id;

  /// 止まったわけ(stopped): cancel / system / timeout / killed / empty / error。
  final String? reason;

  @override
  String toString() => 'GlimpseEvent($type, id: $id, reason: $reason)';
}

/// 読み取った写し(コマ)と、読めた文字 / URL(あれば)。
@immutable
class GlimpseFrames {
  const GlimpseFrames({this.frames = const [], this.text, this.url, this.capturedAt});
  final List<Uint8List> frames;
  final String? text;
  final Uri? url;

  /// 読み取りを始めた時刻。
  final DateTime? capturedAt;
  bool get isEmpty => frames.isEmpty && (text?.trim().isEmpty ?? true) && url == null;

  /// 最後のコマ(読み取りを止める直前に見ていたもの)。
  Uint8List? get representative => frames.isEmpty ? null : frames.last;
}

/// 読み取りの id の形(ネイティブの `GlimpseFrameMath.isValidId` と同じ。フォルダー名に使う)。
final _glimpseIdPattern = RegExp(r'^[a-z0-9-]{8,64}$');
bool isValidGlimpseId(String? id) => id != null && _glimpseIdPattern.hasMatch(id);
final _glimpseFramePattern = RegExp(r'^frame_\d{1,2}\.jpg$');

/// ダミーの読み取り: 1 秒ごとに 1 コマ、灰色の小さな PNG を返す(画面は読まない)。
class DummyScreenGlimpse implements ScreenGlimpse {
  const DummyScreenGlimpse({this.interval = const Duration(seconds: 1)});
  final Duration interval;

  /// 1×1 の灰色の PNG。
  static final Uint8List placeholderFrame = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg==');

  @override
  bool get isDummy => true;

  @override
  bool get native => false;

  @override
  Future<GlimpseStartStatus> start() async => GlimpseStartStatus.unavailable;

  @override
  Future<void> cancel() async {}

  @override
  Stream<GlimpseEvent> get events => const Stream.empty();

  @override
  Future<GlimpseFrames?> takeResult(String id) async => null;

  @override
  Future<void> discard(String id) async {}

  @override
  Future<String?> takeLaunchOpen() async => null;

  @override
  Future<int> cleanupStale({Duration maxAge = glimpseStaleAfter}) async => 0;

  @override
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress}) async {
    final startedAt = DateTime.now();
    final frames = <Uint8List>[];
    var elapsed = Duration.zero;
    while (elapsed < duration) {
      final step = duration - elapsed < interval ? duration - elapsed : interval;
      await Future<void>.delayed(step);
      elapsed += step;
      frames.add(placeholderFrame);
      onProgress?.call(elapsed);
    }
    return GlimpseFrames(frames: frames, capturedAt: startedAt);
  }
}

const screenGlimpseChannelName = 'rasq/screen_glimpse';

/// 本物 (Android は D-416、iOS は D-417): ネイティブ(Android は `ScreenGlimpseBridge` / `ScreenGlimpseService`、
/// iOS は `ScreenGlimpseBridge.swift` + 拡張機能 `ScreenGlimpseBroadcast`)と `rasq/screen_glimpse` で話す。
/// コマは端末のキャッシュ(`dir`)に置かれ、ここで読んで、送ったら消す。ファイルは小さく(JPEG 数枚)、数も少ないので
/// 同期の読み書きにしている(テストの偽の時計の中でも動く)。
class NativeScreenGlimpse implements ScreenGlimpse {
  NativeScreenGlimpse({MethodChannel? channel, DateTime Function()? clock, this.broadcast = false})
      : _channel = channel ?? const MethodChannel(screenGlimpseChannelName),
        _clock = clock ?? DateTime.now {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final DateTime Function() _clock;

  /// iOS の流れ(画面の配信を止めたら読み取る)。false なら Android の流れ(通知のボタンで読み取る)。
  final bool broadcast;
  final _events = StreamController<GlimpseEvent>.broadcast();
  Future<String?>? _root;

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_events.close());
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'event') return null;
    final m = call.arguments;
    if (m is! Map) return null;
    final type = m['type'];
    if (type is! String) return null;
    final id = m['id'];
    if (id != null && (id is! String || !isValidGlimpseId(id))) return null;
    final reason = m['reason'];
    _events.add(GlimpseEvent(type, id: id as String?, reason: reason is String ? reason : null));
    return null;
  }

  @override
  bool get isDummy => false;

  @override
  bool get native => true;

  @override
  Stream<GlimpseEvent> get events => _events.stream;

  @override
  Future<GlimpseStartStatus> start() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('start');
      return switch (r?['status']) {
        'started' => GlimpseStartStatus.started,
        'denied' => GlimpseStartStatus.denied,
        'notifications_denied' => GlimpseStartStatus.notificationsDenied,
        'busy' => GlimpseStartStatus.busy,
        _ => GlimpseStartStatus.unavailable,
      };
    } on MissingPluginException {
      return GlimpseStartStatus.unavailable;
    } on PlatformException catch (e) {
      debugPrint('screen glimpse start: $e');
      return GlimpseStartStatus.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Exception catch (e) {
      debugPrint('screen glimpse cancel: $e');
    }
  }

  Future<String?> _rootDir() => _root ??= () async {
        try {
          return await _channel.invokeMethod<String>('dir');
        } on Exception catch (e) {
          debugPrint('screen glimpse dir: $e');
          return null;
        }
      }();

  Future<Directory?> _dirOf(String id) async {
    if (!isValidGlimpseId(id)) return null;
    final root = await _rootDir();
    return root == null ? null : Directory('$root/$id');
  }

  @override
  Future<GlimpseFrames?> takeResult(String id) async {
    final dir = await _dirOf(id);
    if (dir == null) return null;
    final meta = File('${dir.path}/meta.json');
    try {
      if (!meta.existsSync()) return null;
      final j = jsonDecode(meta.readAsStringSync());
      if (j is! Map || j['id'] != id) return null;
      final frames = <Uint8List>[];
      for (final name in (j['frames'] as List? ?? const [])) {
        if (name is! String || !_glimpseFramePattern.hasMatch(name)) continue;
        final f = File('${dir.path}/$name');
        if (f.existsSync()) frames.add(f.readAsBytesSync());
      }
      return GlimpseFrames(frames: frames, capturedAt: DateTime.tryParse('${j['capturedAt']}'));
    } catch (e) {
      debugPrint('screen glimpse result: $e');
      return null;
    }
  }

  @override
  Future<void> discard(String id) async {
    final dir = await _dirOf(id);
    try {
      if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('screen glimpse discard: $e');
    }
    try {
      await _channel.invokeMethod<void>('dismissDone');
    } on Exception catch (_) {}
  }

  @override
  Future<String?> takeLaunchOpen() async {
    try {
      final id = await _channel.invokeMethod<String>('takeLaunchOpen');
      return isValidGlimpseId(id) ? id : null;
    } on Exception catch (e) {
      debugPrint('screen glimpse launch: $e');
      return null;
    }
  }

  @override
  Future<int> cleanupStale({Duration maxAge = glimpseStaleAfter}) async {
    final root = await _rootDir();
    if (root == null) return 0;
    final dir = Directory(root);
    var n = 0;
    try {
      if (!dir.existsSync()) return 0;
      final now = _clock();
      for (final FileSystemEntity e in dir.listSync(followLinks: false)) {
        if (now.difference(e.statSync().modified) < maxAge) continue;
        e.deleteSync(recursive: true);
        n++;
      }
    } catch (e) {
      debugPrint('screen glimpse cleanup: $e');
    }
    return n;
  }

  @override
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress}) =>
      throw UnsupportedError('端末の読み取りは start から(Android は通知のボタン、iOS は配信を止めたとき)');
}

/// 画面の読み取りの口(テストで差し替える)。Android / iOS は本物、ほか(デスクトップ / Web / テスト)はダミー。
final screenGlimpseProvider = Provider<ScreenGlimpse>((ref) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final g = NativeScreenGlimpse(broadcast: Platform.isIOS);
    ref.onDispose(g.dispose);
    return g;
  }
  return const DummyScreenGlimpse();
});

/// iOS の流れ(配信を止めたら読み取る)か。
bool isBroadcastGlimpse(ScreenGlimpse g) => g is NativeScreenGlimpse && g.broadcast;

/// 準備できたときに出す案内。
String glimpseArmedHint(ScreenGlimpse g) => isBroadcastGlimpse(g)
    ? '画面の配信を始めました。ブラウザで探したい画面を開いたら、画面上部の赤い表示(またはコントロールセンター)から配信を止めてください。止める直前の 3 秒だけを読み取り、RASQ に戻ると結果が出ます。'
    : '通知を出しました。ブラウザで探したい画面を開いてから、通知をタップしてください。タップすると、その画面を 3 秒だけ読み取ります。';

/// 読み取る長さ。
const discoverGlimpseDuration = Duration(seconds: 3);

/// 通知の id と payload。payload は `rasq://` の形(通知のタップで探す画面へ戻る)。ダミーの流れだけ(Android は端末が通知を出す)。
const discoverGlimpseNotificationId = 415000;
const discoverGlimpsePayload = 'rasq://sns-discover/content?glimpse=1';
const discoverGlimpseNotificationTitle = 'RASQ で探す';
const discoverGlimpseNotificationBody = 'タップすると、いま見ている画面を 3 秒だけ読み取ります';

/// 通知を出す。出せたら true。
Future<bool> showDiscoverGlimpseNotification(LocalNotifier notifier) =>
    notifier.show(id: discoverGlimpseNotificationId, title: discoverGlimpseNotificationTitle, body: discoverGlimpseNotificationBody, payload: discoverGlimpsePayload);

/// 読み取りの結果を開く場所 (D-416)。
String discoverGlimpseResultLocation(String id) => '${Routes.snsDiscoverContent}?glimpse=done&id=${Uri.encodeQueryComponent(id)}';

/// 通知のタップを、開いている探す画面に渡す口。開いていなければ、タップで探す画面を開き直す。
/// id つきなら、Android で読み取り終えた結果を開く(D-416)。
class DiscoverGlimpseRequests extends ChangeNotifier {
  bool get listening => hasListeners;
  String? _id;

  /// [request] で渡された結果の id(1 度だけ)。null ならダミーの「3 秒読み取る」。
  String? takeId() {
    final id = _id;
    _id = null;
    return id;
  }

  void request({String? id}) {
    _id = id;
    notifyListeners();
  }
}

final discoverGlimpseRequestsProvider = Provider<DiscoverGlimpseRequests>((ref) {
  final r = DiscoverGlimpseRequests();
  ref.onDispose(r.dispose);
  return r;
});

/// 通知のタップを受けて画面へ (D-415 / D-416)。アプリの起動時に 1 回 watch する。いまは画面の読み取りの通知だけを扱う
/// (AsTell の開始の通知 `rasq://astell/...` は、これまでどおりアプリを開くだけ)。Android では起動時に置いたままのコマも消す。
final notificationTapRouterProvider = Provider<void>((ref) {
  final notifier = ref.watch(localNotifierProvider);
  final glimpse = ref.watch(screenGlimpseProvider);
  void open({String? id}) {
    final requests = ref.read(discoverGlimpseRequestsProvider);
    if (requests.listening) {
      requests.request(id: id);
    } else {
      unawaited(ref.read(routerProvider).push(id == null ? '${Routes.snsDiscoverContent}?glimpse=1' : discoverGlimpseResultLocation(id)));
    }
  }

  final sub = notifier.taps.listen((payload) {
    if (payload == discoverGlimpsePayload) open();
  });
  ref.onDispose(sub.cancel);
  unawaited(notifier.listenForTaps());
  if (glimpse.native) {
    final gsub = glimpse.events.listen((e) {
      if (e.type == 'open' && e.id != null) open(id: e.id);
    });
    ref.onDispose(gsub.cancel);
    unawaited(() async {
      await glimpse.cleanupStale();
      final id = await glimpse.takeLaunchOpen();
      if (id != null) open(id: id);
    }());
  }
});
