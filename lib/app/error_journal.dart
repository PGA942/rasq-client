import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 端末に残す例外の記録 = バグレポートの中身 (D-554)。
///
/// 全画面表示のグレーアウト → フリーズ (D-552) は端末のログが無いと原因の部品が分からなかった。次に起きたときに**最初の例外**が
/// 端末に残るように、`FlutterError.onError`(組み立て / 配置 / 描画の例外)と `PlatformDispatcher.onError`(拾われなかった非同期の
/// 例外)をつなぎ、**起動ごとに最初の 1 件と直近の数件**をファイルに書く。前の受け手(既定の表示 / テストの受け手)はそのまま呼ぶので、
/// アプリの動きは変えない(グレーの箱もそのまま)。
///
/// **個人の情報は記録する前に伏せる**([redactReportText]): 投稿の本文などの引用された文、トークンらしい長い文字列、ハンドル /
/// メールアドレス、URL のホスト・クエリ・フラグメント、端末の上のパス(利用者の名前が入る)。端末の名前も読まない。
/// 設定 → RASQ について → バグレポート([BugReportScreen])で見て、全文のコピー / ファイルへの保存。

/// 1 件の例外。
@immutable
class ErrorRecord {
  const ErrorRecord({required this.at, required this.source, required this.type, required this.summary, this.context, this.library, this.widgetPath = const [], this.stack = const [], this.screen});

  final DateTime at;

  /// `flutter`(組み立て / 配置 / 描画 / ジェスチャー)/ `platform`(拾われなかった非同期の例外)。
  final String source;

  /// 例外の型(`FlutterError` / `RangeError` など)。
  final String type;

  /// 例外の文(伏せたあと、長ければ切る)。
  final String summary;

  /// どこで(`building Foo` / `during performLayout()` など)。
  final String? context;

  /// 例外を受けた所(`widgets library` など)。
  final String? library;

  /// 失敗した部品の経路の先頭数行(`The relevant error-causing widget was` / `creator: A ← B ← …`)。
  final List<String> widgetPath;

  /// スタックの先頭数行(パスは伏せる)。
  final List<String> stack;

  /// そのときの画面の大きさ(論理ピクセル × 倍率)。
  final String? screen;

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'source': source,
        'type': type,
        'summary': summary,
        'context': ?context,
        'library': ?library,
        if (widgetPath.isNotEmpty) 'widgetPath': widgetPath,
        if (stack.isNotEmpty) 'stack': stack,
        'screen': ?screen,
      };

  static ErrorRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    List<String> lines(Object? v) => v is List ? [for (final x in v) '$x'] : const [];
    return ErrorRecord(
      at: at,
      source: '${j['source'] ?? 'flutter'}',
      type: '${j['type'] ?? '?'}',
      summary: '${j['summary'] ?? ''}',
      context: j['context'] as String?,
      library: j['library'] as String?,
      widgetPath: lines(j['widgetPath']),
      stack: lines(j['stack']),
      screen: j['screen'] as String?,
    );
  }
}

/// 1 回の起動で記録したもの: 最初の 1 件 + 直近の [ErrorJournal.recentLimit] 件 + 数。
@immutable
class LaunchErrors {
  const LaunchErrors({required this.startedAt, required this.first, this.recent = const [], this.count = 1});
  final DateTime startedAt;
  final ErrorRecord first;

  /// 直近(新しい順)。最初の 1 件は含めない。
  final List<ErrorRecord> recent;
  final int count;

  Map<String, Object?> toJson() => {'startedAt': startedAt.toUtc().toIso8601String(), 'first': first.toJson(), 'recent': [for (final r in recent) r.toJson()], 'count': count};

  static LaunchErrors? fromJson(Object? j) {
    if (j is! Map) return null;
    final started = DateTime.tryParse('${j['startedAt']}');
    final first = ErrorRecord.fromJson(j['first']);
    if (started == null || first == null) return null;
    return LaunchErrors(
      startedAt: started,
      first: first,
      recent: [for (final r in (j['recent'] is List ? j['recent'] as List : const [])) ?ErrorRecord.fromJson(r)],
      count: j['count'] is int ? j['count'] as int : 1,
    );
  }
}

/// 端末に残す記録ぜんぶ(新しい起動が先頭)。
@immutable
class ErrorJournal {
  const ErrorJournal({this.launches = const []});
  final List<LaunchErrors> launches;

  /// 残す起動の数(例外のあった起動だけ数える)。
  static const launchLimit = 3;

  /// 起動ごとに残す直近の数。
  static const recentLimit = 5;

  bool get isEmpty => launches.isEmpty;

  /// いちばん新しい、例外のあった起動。
  LaunchErrors? get latest => launches.firstOrNull;

  /// [startedAt] の起動に [r] を足す(無ければ起動を作る。最初の 1 件は上書きしない)。
  ErrorJournal add(DateTime startedAt, ErrorRecord r) {
    final i = launches.indexWhere((l) => l.startedAt == startedAt);
    if (i < 0) return ErrorJournal(launches: [LaunchErrors(startedAt: startedAt, first: r), ...launches].take(launchLimit).toList());
    final l = launches[i];
    final next = LaunchErrors(startedAt: l.startedAt, first: l.first, recent: [r, ...l.recent].take(recentLimit).toList(), count: l.count + 1);
    return ErrorJournal(launches: [...launches]..[i] = next);
  }

  String encode() => jsonEncode({'v': 1, 'launches': [for (final l in launches) l.toJson()]});

  static ErrorJournal decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ErrorJournal();
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['launches'] is! List) return const ErrorJournal();
      return ErrorJournal(launches: [for (final l in j['launches'] as List) ?LaunchErrors.fromJson(l)].take(launchLimit).toList());
    } catch (_) {
      return const ErrorJournal(); // 壊れた記録は捨てる
    }
  }
}

// ── 伏せる ──

final _url = RegExp(r'''\b([a-zA-Z][a-zA-Z0-9+.-]*)://[^\s"'<>()\[\]]+''');
final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _handle = RegExp(r'(?<![\w/])@[\w.-]+(@[\w.-]+)?');
final _bearer = RegExp(r'\b(bearer|token|authorization|password|secret|api[_-]?key|i)\s*[:=]\s*(bearer\s+|basic\s+)?\S+', caseSensitive: false);
final _bearerBare = RegExp(r'\b(bearer|basic)\s+[\w.~+/=-]{6,}', caseSensitive: false);
final _jwt = RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+');
final _longToken = RegExp(r'\b[A-Za-z0-9_\-+/]{24,}={0,2}');
final _homePath = RegExp(r'/(Users|home)/[^/\s]+');
/// iOS / iPadOS のアプリの入れ物(端末ごとの UUID が入る)。
final _containerPath = RegExp(r'/(private/)?var/(mobile/Containers/Data|containers/Bundle)/Application/[^/\s]+', caseSensitive: false);
final _quoted = RegExp(r'''"([^"\n]*)"|'([^'\n]*)'|「([^」\n]*)」''');

/// 引用の中身がプログラムの名前らしい(残してよい)か: 空白の無い ASCII の短い識別子 / パス / 式。
bool _codeLike(String s) => s.isEmpty || (s.length <= 80 && RegExp(r'''^[A-Za-z0-9_.:/!<>=&|()\[\]\-+*#$,]+$''').hasMatch(s));

/// バグレポートに入れる前に、個人の情報になりうるものを伏せる (D-554)。
/// - 引用された文(`"…"` / `'…'` / `「…」`)は、プログラムの名前らしいもの以外は中身を `…` に(投稿の本文・表示名・入力の文)。
/// - URL はスキームだけ残す(`https://…`。ホスト = 利用者のサーバー、パス = 投稿 / ユーザーの id、クエリ = トークン)。
/// - メールアドレス / ハンドル(`@name` / `@name@host`)/ `token=…` などの値 / JWT / 24 文字以上のトークンらしい文字列。
/// - 端末の上のパス(`/Users/<名前>` → `~`、アプリの入れ物 → `<app>`)。`package:` のパスはそのまま。
String redactReportText(String s) {
  var out = s;
  out = out.replaceAllMapped(_quoted, (m) {
    final inner = m.group(1) ?? m.group(2) ?? m.group(3) ?? '';
    if (_codeLike(inner)) return m.group(0)!;
    final open = m.group(0)!.substring(0, 1);
    final close = open == '「' ? '」' : open;
    return '$open…$close';
  });
  out = out.replaceAllMapped(_url, (m) {
    final scheme = m.group(1)!.toLowerCase();
    // ソースの場所(package: / dart: は URL の形をとらない。file:// はパスの伏せ方に回す)。
    if (scheme == 'file') return m.group(0)!.replaceAll(_homePath, '~');
    return '$scheme://…';
  });
  out = out.replaceAll(_jwt, '<token>');
  out = out.replaceAllMapped(_bearer, (m) => '${m.group(1)}=<redacted>');
  out = out.replaceAllMapped(_bearerBare, (m) => '${m.group(1)} <redacted>');
  // ハンドル(`@name@host`)を先に: メールの形にも合うので、後にするとハンドルが `@<email>` になる。
  out = out.replaceAll(_handle, '@…');
  out = out.replaceAll(_email, '<email>');
  out = out.replaceAll(_homePath, '~');
  out = out.replaceAll(_containerPath, '<app>');
  out = out.replaceAllMapped(_longToken, (m) {
    final t = m.group(0)!;
    // `package:foo/bar/baz.dart` のようなパスの一部・長い識別子(英字だけ / キャメル)は残す。数字や記号の混じったものだけ伏せる。
    if (t.contains('/') && !RegExp(r'[0-9]').hasMatch(t)) return t;
    if (RegExp(r'^[A-Za-z_]+$').hasMatch(t)) return t;
    return '<redacted>';
  });
  return out;
}

String _clip(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

/// [details] から経路の先頭数行を抜く: 「The relevant error-causing widget was」の続き、`creator:` / `←` の連なり(先頭 6 つ)。
List<String> widgetPathOf(String detailsText) {
  final lines = detailsText.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length && out.length < 6; i++) {
    final l = lines[i].trim();
    if (l.startsWith('The relevant error-causing widget was')) {
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final w = lines[j].trim();
        if (w.isEmpty) break;
        out.add(_clip(w, 160));
      }
    } else if (l.contains(' ← ')) {
      final parts = l.replaceFirst(RegExp(r'^creator:\s*'), '').split(' ← ').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
      out.add(_clip(parts.take(6).join(' ← ') + (parts.length > 6 ? ' ← …' : ''), 220));
    }
  }
  // 重複(同じ連なりが何度も出る)は 1 つに。
  return [for (final (i, l) in out.indexed) if (!out.take(i).contains(l)) redactReportText(l)];
}

/// スタックの先頭 [max] 行(空行・非同期の区切りは飛ばす)。
List<String> stackHeadOf(StackTrace? stack, {int max = 10}) {
  if (stack == null) return const [];
  return [
    for (final l in stack.toString().split('\n').map((x) => x.trimRight()).where((x) => x.trim().isNotEmpty && x.trim() != '<asynchronous suspension>').take(max)) _clip(redactReportText(l), 200),
  ];
}

/// [FlutterErrorDetails] → 1 件。
ErrorRecord errorRecordFromDetails(FlutterErrorDetails details, {DateTime? at, String? screen}) {
  String text;
  try {
    text = details.toString();
  } catch (_) {
    text = '';
  }
  String? context;
  try {
    context = details.context?.toDescription();
  } catch (_) {}
  return ErrorRecord(
    at: at ?? DateTime.now(),
    source: 'flutter',
    type: details.exception.runtimeType.toString(),
    summary: _clip(redactReportText(details.exceptionAsString().trim()), 600),
    context: context == null ? null : _clip(redactReportText(context), 200),
    library: details.library,
    widgetPath: widgetPathOf(text),
    stack: stackHeadOf(details.stack),
    screen: screen,
  );
}

/// 拾われなかった非同期の例外 → 1 件。
ErrorRecord errorRecordFromError(Object error, StackTrace stack, {DateTime? at, String? screen}) => ErrorRecord(
      at: at ?? DateTime.now(),
      source: 'platform',
      type: error.runtimeType.toString(),
      summary: _clip(redactReportText('$error'.trim()), 600),
      stack: stackHeadOf(stack),
      screen: screen,
    );

/// いまの画面の大きさ(論理ピクセル × 倍率)。取れなければ null。
String? currentScreenSize() {
  try {
    final v = PlatformDispatcher.instance.implicitView;
    if (v == null) return null;
    final dpr = v.devicePixelRatio;
    final s = v.physicalSize / dpr;
    return '${s.width.round()}×${s.height.round()} @${dpr.toStringAsFixed(dpr == dpr.roundToDouble() ? 0 : 2)}x';
  } catch (_) {
    return null;
  }
}

// ── 保存先 ──

/// 記録の保存先(テストでは [MemoryErrorJournalStore])。
abstract class ErrorJournalStore {
  Future<String?> load();
  Future<void> save(String data);
  Future<void> clear();
}

class MemoryErrorJournalStore implements ErrorJournalStore {
  MemoryErrorJournalStore([this.data]);
  String? data;
  int saves = 0;
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String d) async {
    saves++;
    data = d;
  }

  @override
  Future<void> clear() async => data = null;
}

/// アプリの支援フォルダの `bug_report/errors.json`(アプリの中だけ。「ファイル」App からは見えない)。
/// 秘密の保存領域(キーチェーン)は書き込みが遅く、例外が続いたときに詰まるので使わない(中身は伏せたあとのもの)。
class FileErrorJournalStore implements ErrorJournalStore {
  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/bug_report/errors.json');

  @override
  Future<String?> load() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> save(String data) async {
    final f = await _file();
    await Directory(f.parent.path).create(recursive: true);
    // 書きかけで落ちても前の記録が壊れないように、別の名前に書いてから置き換える。
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}

// ── 記録係 ──

/// 例外を受けて記録する。[install] で `FlutterError.onError` / `PlatformDispatcher.onError` につなぐ(前の受け手も呼ぶ)。
class ErrorJournalRecorder extends ChangeNotifier {
  ErrorJournalRecorder(this.store, {DateTime? launchedAt, this.screenSize = currentScreenSize}) : launchedAt = launchedAt ?? DateTime.now();

  final ErrorJournalStore store;

  /// この起動の時刻(起動ごとに分ける鍵)。
  final DateTime launchedAt;
  final String? Function() screenSize;

  ErrorJournal _journal = const ErrorJournal();
  ErrorJournal get journal => _journal;
  bool _loaded = false;
  Future<void>? _loading;

  /// 保存してある記録を読む(何度呼んでも 1 回)。読む前に来た例外は、読んだあとの記録に足す。
  Future<void> load() => _loading ??= () async {
        final pending = _journal;
        try {
          _journal = ErrorJournal.decode(await store.load());
        } catch (_) {}
        for (final l in pending.launches.reversed) {
          for (final r in [l.first, ...l.recent.reversed]) {
            _journal = _journal.add(l.startedAt, r);
          }
        }
        _loaded = true;
        if (_disposed) return;
        if (pending.launches.isNotEmpty) _scheduleSave(immediate: true);
        notifyListeners();
      }();

  bool _recording = false;

  /// 1 件記録する。記録の中で例外が出ても外へ出さない(記録のための例外で記録を呼び直さない)。
  void record(ErrorRecord r) {
    if (_recording) return;
    _recording = true;
    try {
      final firstOfLaunch = !_journal.launches.any((l) => l.startedAt == launchedAt);
      _journal = _journal.add(launchedAt, r);
      // 最初の 1 件はすぐ書く(このあと固まって終了されても残るように)。続く分はまとめて書く(毎フレームの例外で詰まらない)。
      if (_loaded) _scheduleSave(immediate: firstOfLaunch);
      _notifySoon();
    } catch (_) {
    } finally {
      _recording = false;
    }
  }

  /// 1 回の起動で記録する上限。毎フレーム同じ例外が出続けるとき(マウスのヒットテストの例外など)に、例外の文を組み立て続けて
  /// 重くならないように、これを超えたら記録しない(画面の件数は「100 件」で止まる)。最初の 1 件と直近は残っている。
  static const perLaunchLimit = 100;
  int _seen = 0;

  void recordFlutterError(FlutterErrorDetails details) {
    if (++_seen > perLaunchLimit) return;
    record(errorRecordFromDetails(details, screen: _safeScreen()));
  }

  void recordError(Object error, StackTrace stack) {
    if (++_seen > perLaunchLimit) return;
    record(errorRecordFromError(error, stack, screen: _safeScreen()));
  }

  String? _safeScreen() {
    try {
      return screenSize();
    } catch (_) {
      return null;
    }
  }

  // 例外の受け手は組み立ての途中から呼ばれる: 画面への知らせは次のマイクロタスクで(組み立て中に描き直しを頼まない)。
  bool _notifyQueued = false;
  void _notifySoon() {
    if (_notifyQueued) return;
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  Timer? _saveTimer;
  bool _saving = false;
  bool _dirty = false;

  /// 書くまでの間(続けて来た例外をまとめる)。
  static const saveDelay = Duration(milliseconds: 500);

  void _scheduleSave({bool immediate = false}) {
    _dirty = true;
    if (immediate) {
      _saveTimer?.cancel();
      _saveTimer = null;
      unawaited(_flush());
      return;
    }
    _saveTimer ??= Timer(saveDelay, () {
      _saveTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (_saving) return; // 書いている間に来た分は、書き終えたらもう一度
    _saving = true;
    try {
      while (_dirty) {
        _dirty = false;
        await store.save(_journal.encode());
      }
    } catch (e) {
      debugPrint('error journal: save failed: $e');
    } finally {
      _saving = false;
    }
  }

  /// 書き終えるのを待つ(テスト / 消す前)。
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_dirty) await _flush();
    while (_saving) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// 記録を消す(画面の「消去」)。
  Future<void> clear() async {
    await flush();
    _journal = const ErrorJournal();
    await store.clear();
    notifyListeners();
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  /// `FlutterError.onError` と `PlatformDispatcher.onError` につなぐ。前の受け手(既定の表示など)はそのまま呼ぶ。
  /// `PlatformDispatcher.onError` は前の受け手の答え(無ければ false = 既定の扱い)を返す = 例外の扱いは変えない。
  void install() {
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      recordFlutterError(details);
      (prevFlutter ?? FlutterError.presentError)(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final prevPlatform = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      recordError(error, stack);
      return prevPlatform?.call(error, stack) ?? false;
    };
    unawaited(load());
  }

  /// アプリの記録係(`main` が [install] する)。
  static ErrorJournalRecorder? instance;

  /// `main` から(`WidgetsFlutterBinding.ensureInitialized()` のあと): ファイルに残す記録係を作ってつなぐ。Web は端末のファイルが無いので記録だけ(起動の間だけ)。
  static ErrorJournalRecorder installDefault() {
    final r = ErrorJournalRecorder(kIsWeb ? MemoryErrorJournalStore() : FileErrorJournalStore());
    r.install();
    return instance = r;
  }
}

/// 画面が読む記録係。`main` でつないだもの、無ければ(テストなど)この起動の間だけのもの。
final errorJournalProvider = Provider<ErrorJournalRecorder>((ref) {
  final installed = ErrorJournalRecorder.instance;
  if (installed != null) return installed;
  final r = ErrorJournalRecorder(MemoryErrorJournalStore());
  unawaited(r.load());
  ref.onDispose(r.dispose);
  return r;
});

// ── 端末の情報 ──

/// アプリの版 (pubspec の `version`)。組み立てのときに `--dart-define=RASQ_APP_VERSION=…` で上書きできる。
/// pubspec と食い違わないことはテスト(`bug_report_test`)が見る。
const rasqAppVersion = String.fromEnvironment('RASQ_APP_VERSION', defaultValue: '0.1.0+1');

/// 組み立てたときのコミット(`--dart-define=RASQ_GIT_SHA=…` を渡したときだけ)。
const rasqGitSha = String.fromEnvironment('RASQ_GIT_SHA');

/// 組み立ての種類。
String get rasqBuildMode => kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');

/// OS の名前と版。Linux / Windows の版の文字列にはホスト名が混じることがあるので伏せてから。
String currentOsDescription() {
  if (kIsWeb) return 'web';
  try {
    return '${Platform.operatingSystem} ${redactReportText(Platform.operatingSystemVersion)}';
  } catch (_) {
    return defaultTargetPlatform.name;
  }
}

/// 例外の文に出がちなプレフィックスを短く(画面用)。
String shortErrorType(String type) => type.startsWith('_') ? type.substring(1) : type;

/// ProviderContainer の外から(テストで)入れ替える用。
@visibleForTesting
void resetErrorJournalInstance() => ErrorJournalRecorder.instance = null;
