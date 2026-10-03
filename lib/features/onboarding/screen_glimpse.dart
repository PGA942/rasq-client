import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../notify/local_notifier.dart';

/// **いま見ている画面を少しだけ読み取る** (D-415、D-414 の LiveKit の画面共有の案を置き換えた)。
///
/// 流れ: 探す画面(好きな画像やコンテンツから探す)で「いつものブラウザで見て探す」→ RASQ が端末の通知を出す
/// (「タップすると、いま見ている画面を 3 秒だけ読み取ります」)→ 端末のブラウザで好きなページを見る → 通知をタップ →
/// RASQ が [discoverGlimpseDuration] だけ画面を読み取り、写し(と読めた文字)を `POST /onboarding/discover/content` に送って、結果を出す。
///
/// 読み取りの口は [ScreenGlimpse]。**いまは既定もテストも [DummyScreenGlimpse]**(実際の画面は読まず、ダミーの写しを返す)。
// TODO(D-415): 端末の画面を読む実装を [screenGlimpseProvider] に差す。
// - Android: MediaProjection(flutter_webrtc の getDisplayMedia + flutter_background の前面サービス `mediaProjection` は
//   AsTell の配信 D-317 で入っている)。ただし通知をタップすると RASQ が前に出るので、そのまま写すと RASQ の画面になる。
//   通知のボタンをアプリを開かずに受け(バックグラウンドの応答)、同意済みの MediaProjection を前面サービスで持っておく形が要る
//   (Android 14 からは同意は 1 回の取り込みごと)。ネイティブの部分が要るので未実装。
// - iOS: ほかのアプリの画面は Broadcast Upload Extension(ReplayKit)が無いと読めない。拡張はまだ無い。
abstract interface class ScreenGlimpse {
  /// 読み取りがダミーか(画面にそう出す)。
  bool get isDummy;

  /// 画面を [duration] だけ読み取る。[onProgress] は経過時間。
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress});
}

/// 読み取った写し(コマ)と、読めた文字 / URL(あれば)。
@immutable
class GlimpseFrames {
  const GlimpseFrames({this.frames = const [], this.text, this.url});
  final List<Uint8List> frames;
  final String? text;
  final Uri? url;
  bool get isEmpty => frames.isEmpty && (text?.trim().isEmpty ?? true) && url == null;

  /// Central に送る 1 枚(CONTRACT §2 の `image` は 1 枚)。いまは最後のコマ(読み取りを止める直前に見ていたもの)。
  Uint8List? get representative => frames.isEmpty ? null : frames.last;
}

/// ダミーの読み取り: 1 秒ごとに 1 コマ、灰色の小さな PNG を返す(画面は読まない)。
class DummyScreenGlimpse implements ScreenGlimpse {
  const DummyScreenGlimpse({this.interval = const Duration(seconds: 1)});
  final Duration interval;

  /// 1×1 の灰色の PNG。
  static final Uint8List placeholderFrame = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg==');

  @override
  bool get isDummy => true;

  @override
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress}) async {
    final frames = <Uint8List>[];
    var elapsed = Duration.zero;
    while (elapsed < duration) {
      final step = duration - elapsed < interval ? duration - elapsed : interval;
      await Future<void>.delayed(step);
      elapsed += step;
      frames.add(placeholderFrame);
      onProgress?.call(elapsed);
    }
    return GlimpseFrames(frames: frames);
  }
}

/// 画面の読み取りの口(テストで差し替える)。
final screenGlimpseProvider = Provider<ScreenGlimpse>((ref) => const DummyScreenGlimpse());

/// 読み取る長さ。
const discoverGlimpseDuration = Duration(seconds: 3);

/// 通知の id と payload。payload は `rasq://` の形(通知のタップで探す画面へ戻る)。
const discoverGlimpseNotificationId = 415000;
const discoverGlimpsePayload = 'rasq://sns-discover/content?glimpse=1';
const discoverGlimpseNotificationTitle = 'RASQ で探す';
const discoverGlimpseNotificationBody = 'タップすると、いま見ている画面を 3 秒だけ読み取ります';

/// 通知を出す。出せたら true。
Future<bool> showDiscoverGlimpseNotification(LocalNotifier notifier) =>
    notifier.show(id: discoverGlimpseNotificationId, title: discoverGlimpseNotificationTitle, body: discoverGlimpseNotificationBody, payload: discoverGlimpsePayload);

/// 通知のタップを、開いている探す画面に渡す口。開いていなければ、タップで探す画面を開き直す。
class DiscoverGlimpseRequests extends ChangeNotifier {
  bool get listening => hasListeners;
  void request() => notifyListeners();
}

final discoverGlimpseRequestsProvider = Provider<DiscoverGlimpseRequests>((ref) {
  final r = DiscoverGlimpseRequests();
  ref.onDispose(r.dispose);
  return r;
});

/// 通知のタップを受けて画面へ (D-415)。アプリの起動時に 1 回 watch する。いまは画面の読み取りの通知だけを扱う
/// (AsTell の開始の通知 `rasq://astell/...` は、これまでどおりアプリを開くだけ)。
final notificationTapRouterProvider = Provider<void>((ref) {
  final notifier = ref.watch(localNotifierProvider);
  final sub = notifier.taps.listen((payload) {
    if (payload != discoverGlimpsePayload) return;
    final requests = ref.read(discoverGlimpseRequestsProvider);
    if (requests.listening) {
      requests.request();
    } else {
      unawaited(ref.read(routerProvider).push('${Routes.snsDiscoverContent}?glimpse=1'));
    }
  });
  ref.onDispose(sub.cancel);
  unawaited(notifier.listenForTaps());
});
