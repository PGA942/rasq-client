import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart';
import 'swing_client.dart';
import 'swing_models.dart';
import '../../l10n/l10n.dart';

/// Swing (D-377 / Central S-056) の状態。
///
/// - RASQ アカウントがあって Central に繋がっているときだけ。**見守られている端末では出さない**(見守りの設定に Swing の
///   項目がまだ無いので、止めておく)。
/// - フィードは起動時と [SwingFeed.interval] ごとに読み直す。
/// - D-379: 見終えたものも期限までは残す(ヘッダーのリングが青 → 白になる。もう一度見られる)。

final swingApiProvider = Provider<SwingApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  if (client == null || ref.watch(orgateAccountProvider).value == null) return null;
  if (ref.watch(childGateProvider).supervised) return null;
  return SwingApi(client);
});

class SwingFeed extends AsyncNotifier<List<Swing>> {
  /// 読み直す間隔(テストで短く / 止める)。null = 読み直さない。
  static Duration? interval = const Duration(seconds: 60);

  Timer? _timer;
  final _seen = <String>{};

  @override
  Future<List<Swing>> build() async {
    final api = ref.watch(swingApiProvider);
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (api == null) return const [];
    final every = interval;
    if (every != null) _timer = Timer.periodic(every, (_) => unawaited(refresh()));
    return _load(api);
  }

  Future<List<Swing>> _load(SwingApi api) async => [
        for (final s in await api.feed(all: true)) _seen.contains(s.id) ? s.copyWith(seen: true) : s,
      ];

  Future<void> refresh() async {
    final api = ref.read(swingApiProvider);
    if (api == null) return;
    try {
      final next = await _load(api);
      state = AsyncData(next);
    } catch (_) {
      // 読めないときは前のまま(次の間隔でまた読む)。
    }
  }

  /// 手元の並びから外す(消した、D-446)。
  void removeLocal(String id) {
    final cur = state.value;
    if (cur != null && cur.any((s) => s.id == id)) state = AsyncData([for (final s in cur) if (s.id != id) s]);
  }

  /// 届いた Swing を足す(ライブの知らせ、D-449)。もうあれば何もしない。
  void upsertLocal(Swing s) {
    final cur = state.value ?? const <Swing>[];
    if (cur.any((x) => x.id == s.id)) return;
    state = AsyncData([s, ...cur]);
  }

  /// 見終えた: 手元で見終えた印を付けて Central へ。
  Future<void> markSeen(String id) async {
    if (!_seen.add(id)) return;
    final cur = state.value;
    if (cur != null) state = AsyncData([for (final s in cur) s.id == id ? s.copyWith(seen: true) : s]);
    try {
      await ref.read(swingApiProvider)?.seen(id);
    } catch (_) {
      // 送れなくても手元では消したまま(期限が来れば Central でも消える)。
    }
  }
}

/// 未審査のプラグインの入れ物を取る (D-379)。URL は Central の署名つき(テストで差し替える)。
final swingPackageFetcherProvider = Provider<Future<Uint8List> Function(Uri url)>((ref) => (url) async {
      final r = await http.get(url).timeout(const Duration(seconds: 60));
      if (r.statusCode != 200) throw StateError(appL10n.swingPackageFetchFailed(r.statusCode));
      return r.bodyBytes;
    });

final swingFeedProvider = AsyncNotifierProvider<SwingFeed, List<Swing>>(SwingFeed.new);

/// Swing を消す (D-446): Central で消し(`DELETE /swings/{id}`)、手元のフィードと自分の Swing からもすぐ外す
/// (前はビューワーの … の「削除」が根の投稿だけを消し、Swing は残り続けていた)。消せなければ例外のまま。
Future<void> deleteSwing(WidgetRef ref, String id) async {
  final api = ref.read(swingApiProvider);
  if (api == null) throw StateError(appL10n.swingNotLoggedIn);
  await api.delete(id);
  ref.read(swingFeedProvider.notifier).removeLocal(id);
  ref.read(mySwingsProvider.notifier).removeLocal(id);
}

/// 自分が出している Swing (D-410): ヘッダーの Swing の並びの先頭に自分の顔で出す(`GET /me/swings`、届け先と見た人の数つき)。
/// フィードと同じ間隔で読み直し、期限の過ぎたものは手元でも外す。作ったら読み直す(`ref.invalidate`)。
class MySwings extends AsyncNotifier<List<Swing>> {
  /// 期限を比べる時計(テストで差し替える)。
  static DateTime Function() now = DateTime.now;

  Timer? _timer;

  @override
  Future<List<Swing>> build() async {
    final api = ref.watch(swingApiProvider);
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (api == null) return const [];
    final every = SwingFeed.interval;
    if (every != null) _timer = Timer.periodic(every, (_) => unawaited(refresh()));
    return _live(await api.mine());
  }

  List<Swing> _live(List<Swing> all) => [for (final s in all) if (s.expiresAt.isAfter(now())) s];

  /// 手元の並びから外す(消した、D-446)。
  void removeLocal(String id) {
    final cur = state.value;
    if (cur != null && cur.any((s) => s.id == id)) state = AsyncData([for (final s in cur) if (s.id != id) s]);
  }

  Future<void> refresh() async {
    final api = ref.read(swingApiProvider);
    if (api == null) return;
    try {
      state = AsyncData(_live(await api.mine()));
    } catch (_) {
      // 読めないときは前のまま。
    }
  }
}

final mySwingsProvider = AsyncNotifierProvider<MySwings, List<Swing>>(MySwings.new);

/// Swing を出している人(見ていないものがある人が先、その中は新しい順)と、見ていない数。
typedef SwingAuthorEntry = ({Swing first, int unseen, int total});

final swingAuthorsProvider = Provider<List<SwingAuthorEntry>>((ref) => swingAuthorsOf(ref.watch(swingFeedProvider).value ?? const <Swing>[]));

/// 作った人ごとにまとめる(見ていないものがある人が先、その中は新しい順)。
List<SwingAuthorEntry> swingAuthorsOf(List<Swing> feed) {
  final byAuthor = <String, List<Swing>>{};
  for (final s in feed) {
    byAuthor.putIfAbsent(s.authorAccountId, () => []).add(s);
  }
  final out = [
    for (final g in byAuthor.values)
      (first: (g..sort((a, b) => b.createdAt.compareTo(a.createdAt))).first, unseen: g.where((s) => !s.seen).length, total: g.length),
  ]..sort((a, b) {
      final u = (b.unseen > 0 ? 1 : 0) - (a.unseen > 0 ? 1 : 0);
      return u != 0 ? u : b.first.createdAt.compareTo(a.first.createdAt);
    });
  return out;
}

/// Swing の検索 (D-386): 作った人の名前 / @ハンドル / 文字 / 種類(画像 / 動画 / プラグイン)で探す。語は空白で区切り、
/// **全部を含むもの**(語を重ねて絞る)。当たった Swing を作った人ごとにまとめる。
List<SwingAuthorEntry> searchSwingAuthors(List<Swing> feed, String query) {
  final terms = query.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  String hay(Swing s) => [s.author.displayName, s.author.account.handle, '@${s.author.account.handle}', s.text, s.kind.label, 'swing'].join(' ').toLowerCase();
  return swingAuthorsOf([for (final s in feed) if (terms.every(hay(s).contains)) s]);
}

/// ビューワーの並び (D-379): [startAuthor] の Swing(見ていないものがあればそれ、無ければ全部)→ ほかの人の見ていないもの。
/// 誰も指定しなければ、見ていないもの全部(無ければ全部)。
List<Swing> swingViewerQueue(List<Swing> feed, {String? startAuthor}) {
  final unseen = [for (final s in feed) if (!s.seen) s];
  if (startAuthor == null) return orderForViewer(unseen.isEmpty ? feed : unseen);
  final mine = [for (final s in feed) if (s.authorAccountId == startAuthor) s];
  final first = mine.any((s) => !s.seen) ? [for (final s in mine) if (!s.seen) s] : mine;
  final rest = [for (final s in unseen) if (s.authorAccountId != startAuthor) s];
  return [...orderForViewer(first), ...orderForViewer(rest)];
}
