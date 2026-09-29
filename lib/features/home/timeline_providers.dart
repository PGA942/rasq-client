import '../post/post_bookmark_button.dart' show keepKnownBookmarks;
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../backend/rasq_collections_api.dart';
import '../nodeprog/tl_components.dart' show compileTlConfig, rasqListKindPrefix, rasqPostsKind;
import '../nodeprog/tl_config_store.dart' show tlTemporaryConfigsProvider;
import 'account_affinity.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:sns_misskey/sns_misskey.dart';

import 'package:rasq_ml/rasq_ml.dart' show MlGateway;

import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../../text/inline_spans.dart';
import '../nodeprog/node_executor.dart';
import '../nodeprog/node_graph.dart';
import '../nodeprog/node_tabs.dart';
import '../trend/tendency_profile.dart';
import 'post_duplicates.dart';
import '../relational/relational_providers.dart' show mlGatewayProvider;
import '../settings/settings_dsl.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;

/// カスタム TL の宣言 (M5e / D-080): 現在のセッションが wasm 境界
/// ([WasmSnsSession])のとき、その TL レンダラー契約(`tl.timelines`)から
/// 読む。ホームのタブに `custom:<id>` として現れる。独立 TL プラグインの
/// 常設インストールはストア統合(M4)側で拡張する。
final customTimelinesProvider = FutureProvider<List<CustomTimelineSpec>>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  // スロットプラグイン (D-167): `tl` スロットの宣言は `slot:<pluginId>:<id>` で並ぶ。
  ref.watch(activeSlotPluginsProvider); // アカウントを変えたら、そのアカウントの版の TL (D-355)
  final slots = [for (final (p, t) in await ref.read(slotPluginsProvider.notifier).timelines()) CustomTimelineSpec(id: 'slot:${p.id}:${t.id}', label: t.label, base: t.base)];
  if (session is! WasmSnsSession) return slots;
  return [...await session.timelinePlugin.timelines(), ...slots];
});

@immutable
class TimelineState {
  const TimelineState({this.posts = const [], this.cursor, this.loadingMore = false, this.error, this.customTiles = const {}, this.badges = const {}});
  final List<Post> posts;
  final String? cursor;
  final bool loadingMore;
  final Object? error;

  /// 投稿カスタマイザ (D-082): postId → 置き換えタイル(RRL、V5 検証済み)。
  /// カスタム TL 以外は常に空。
  final Map<String, RrlNode> customTiles;

  /// 上付きバナー行 (D-085): postId → RT 行と同スタイルのバッジ。
  final Map<String, TimelineBadge> badges;
  bool get hasMore => cursor != null;

  TimelineState copyWith({List<Post>? posts, String? cursor, bool clearCursor = false, bool? loadingMore, Object? error, bool clearError = false, Map<String, RrlNode>? customTiles, Map<String, TimelineBadge>? badges}) => TimelineState(
        posts: posts ?? this.posts,
        cursor: clearCursor ? null : (cursor ?? this.cursor),
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        customTiles: customTiles ?? this.customTiles,
        badges: badges ?? this.badges,
      );
}

/// One timeline of the current account. Pages flow: plugin → posts + action
/// states → Store (状態はDSLの外) → rows receive props.
class TimelineNotifier extends AsyncNotifier<TimelineState> {
  TimelineNotifier(this.kind);
  final TimelineKind kind;

  SnsSession? get _session => ref.read(currentSnsSessionProvider);

  /// 総合TL (D-088) のアカウント別カーソル。build で作り直す。
  Map<String, String> _bundleCursors = {};

  /// グラフ取得ノードの枝ごとのカーソル (D-117)。キー = kind id(acct: 包み
  /// を含む)、値 null = その枝は末尾まで読了。続き読みは**グラフをもう一度
  /// 実行**し、各取得ノードが自分のカーソルから次ページを読む(マージ TL 用の
  /// 「使い捨てクロック」方式 — 1 回ぶんのトリガーとして焚き直すイメージ)。
  Map<String, String?> _nodeCursors = {};

  /// 総合TL がノードグラフで動いているか(loadMore/refresh の経路選択)。
  bool _bundleGraphActive = false;

  bool get _nodeHasMore => _nodeCursors.values.any((v) => v != null);

  /// 取得ノードの枝ごとページング (D-117)。[more] のときは前回のカーソルから
  /// 続きを読む(読了済みの枝は空)。自分の基礎 TL([selfKindId])は基礎側の
  /// カーソルで進むのでここでは扱わない。
  Future<List<Post>> _pagedNodeFetch(SnsSession session, String kid, {required bool more, String? selfKindId, List<Post> selfItems = const [], SnsSession? Function(String)? sessionFor}) async {
    if (kid == 'self' || (selfKindId != null && kid == selfKindId)) return selfItems; // 基礎TLのカーソルで進む (D-124)
    String? c;
    if (more && _nodeCursors.containsKey(kid)) {
      c = _nodeCursors[kid];
      if (c == null) return const []; // 読了
    }
    return resolveNodeFetch(session, kid, cursor: c, sessionFor: sessionFor, onCursor: (next) => _nodeCursors[kid] = next, rasqFeed: (until) => fetchRasqFeed(ref, until), rasqList: (id, until) => fetchRasqList(ref, id, until), rasqMine: () => fetchRasqMine(ref), listHidden: ref.read(childGateProvider).collectionHidden);
  }

  /// カスタム関数の中身グラフ (D-118)。
  Future<NodeGraph?> _loadFunctionBody(String fnId) => loadFunctionBody((a) => ref.read(settingsAreaProvider(a).future), fnId);

  /// クロックノード (D-095): グラフのクロックがアイコンに繋がっていると
  /// その間隔で TL を自動更新する。
  Timer? _clockTimer;
  Duration? _clockInterval;

  void _armClock(Duration? interval) {
    if (interval == null) {
      _clockTimer?.cancel();
      _clockTimer = null;
      _clockInterval = null;
      return;
    }
    if (_clockTimer != null && _clockInterval == interval) return; // 周期そのまま — 位相を保つ
    _clockTimer?.cancel();
    _clockInterval = interval;
    // 自動更新は上に足すだけ (D-379): 置き換えると、下のほうを読んでいる人が上へ戻される。
    _clockTimer = Timer.periodic(interval, (_) => prependNewer());
  }

  /// 投稿の所属アカウントのセッション (D-088): 総合TLでは投稿ごとに取得元
  /// アカウントが違うので、アクションは所属セッションへルーティングする。
  SnsSession? _sessionFor(Post p) {
    final s = ref.read(sessionsProvider).value?.sessions.where((x) => x.account == p.account).firstOrNull;
    return s == null ? null : ref.read(pluginRegistryProvider).session(s);
  }

  /// 見守りの時間 (D-307): 全アカウントのグローバル TL を 1 本に合流し、許された話題だけを流す。
  Future<List<Post>> _fetchChildWindow() async {
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final registry = ref.read(pluginRegistryProvider);
    final out = <Post>[];
    final seen = <String>{};
    for (final s in sessions) {
      try {
        final session = registry.session(s);
        final kinds = session.timelines;
        final kind = kinds.contains(TimelineKind.global) ? TimelineKind.global : (kinds.contains(TimelineKind.local) ? TimelineKind.local : TimelineKind.home);
        final page = await session.timeline(kind);
        _applyStates(page.items, await session.actionStates(page.items));
        for (final p in page.items) {
          if (seen.add('${p.author.key}/${p.id}')) out.add(p);
        }
      } catch (e) {
        debugPrint('child-safe window TL ${s.account.key}: $e');
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ref.read(childGateProvider).filterPosts(out);
  }

  @override
  Future<TimelineState> build() async {
    ref.watch(currentAccountProvider); // rebuild per account
    // チャイルドセーフ (D-307): 判定の強さ / 止める話題 / 見守りの時間が変われば取り直す。
    ref.watch(childGateProvider.select((g) => g.timelineSignature));
    if (kind == childSafeWindowKind) return TimelineState(posts: await _fetchChildWindow());
    // 一時変更 (D-338): タブの ↓ の FOW で変えた構成が入れ替わったら取り直す。
    ref.watch(tlTemporaryConfigsProvider.select((m) => m[_graphScope]));
    ref.onDispose(() {
      _clockTimer?.cancel();
      _clockTimer = null;
      _clockInterval = null;
    });
    if (kind == TimelineKind.bundle) {
      // 総合TL (D-088): アカウントの増減で作り直す。
      ref.watch(sessionsProvider.select((s) => s.value?.sessions.length ?? 0));
      _bundleCursors = {};
      _nodeCursors = {};
      // ノードグラフ経由 (D-114): 自動構成(アカウント追加でマージ段を更新)
      // を済ませてから実行。鎖が無ければ従来の合流へフォールバック。
      try {
        final result = await _runBundleGraph();
        if (result != null) {
          _bundleGraphActive = true;
          return TimelineState(posts: result, cursor: _nodeHasMore ? 'node' : null);
        }
      } catch (e) {
        debugPrint('bundle graph: $e');
      }
      _bundleGraphActive = false;
      final (page, _, _) = await _fetchBundle(first: true);
      return TimelineState(posts: page.items, cursor: page.nextCursor);
    }
    final session = _session;
    if (session == null) return const TimelineState();
    // タイムライン設定 (D-044) を取得前に反映。watch なので変更 → 再取得。
    try {
      final tl = await ref.watch(snsSettingValuesProvider('timeline').future);
      if (tl.isNotEmpty) await session.applySettings('timeline', tl);
    } catch (e) {
      debugPrint('timeline settings: $e');
    }
    final (page, states, deco) = await _fetch(session, null);
    return TimelineState(posts: page.items, cursor: page.nextCursor, customTiles: deco.tiles, badges: deco.badges);
  }

  /// この TL のノードグラフのスコープ。トレンド / タグ TL (D-102) と Today(featured, D-113)は共通の `trend`。
  String get _graphScope => kind.id.startsWith('tag:') || kind.id == 'featured' ? 'trend' : 'tl.${kind.id}';

  /// 一時変更 (D-338) の構成をコンパイルしたグラフ(raw JSON)。無ければ null。
  String? get _temporaryGraphRaw {
    final cfg = ref.read(tlTemporaryConfigsProvider)[_graphScope];
    return cfg == null ? null : jsonEncode(compileTlConfig(cfg, scope: _graphScope).toJson());
  }

  /// 総合スコープの自動構成 + 実行 (D-114)。グラフが無ければ全アカウント分を
  /// 自動生成(取得×N → マージ段 → タイムライン)。ユーザーが編集済み
  /// (auto フラグなし)なら、新アカウントはマージの空き口への差し込みだけ試す。
  /// [more] (D-117) は続き読み: 自動構成は済んでいる前提でグラフだけ読み、
  /// 各取得ノードが自分のカーソルから次ページを読む。
  Future<List<Post>?> _runBundleGraph({bool more = false}) async {
    final session = _session;
    if (session == null) return null;
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    if (sessions.isEmpty) return null;
    final accounts = [for (final s in sessions) '${s.account}'];
    final sig = accounts.join('|');
    final store = ref.read(settingsAreaProvider('nodeprog.tl.bundle').notifier);
    final area = await ref.read(settingsAreaProvider('nodeprog.tl.bundle').future);
    final raw = area['graph'];
    NodeGraph graph;
    final temporary = _temporaryGraphRaw;
    if (temporary != null) {
      // 一時変更 (D-338): 保存した構成と自動構成には触れない。
      graph = NodeGraph.fromJson((jsonDecode(temporary) as Map).cast<String, Object?>());
    } else if (more) {
      if (raw is! String) return null;
      graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } else if (raw is! String) {
      graph = buildBundleGraph(accounts);
      await store.set('graph', jsonEncode(graph.toJson()));
      await store.set('auto', true);
      await store.set('accounts', sig);
    } else {
      graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      if (area['accounts'] != sig) {
        if (area['auto'] == true) {
          graph = buildBundleGraph(accounts);
          await store.set('graph', jsonEncode(graph.toJson()));
        } else {
          final known = area['accounts'] is String ? (area['accounts'] as String).split('|').toSet() : const <String>{};
          for (final a in accounts) {
            if (known.contains(a)) continue;
            final inserted = insertAccountIntoBundleGraph(graph, a);
            if (inserted != null) graph = inserted; // 差し込めない形は手動に任せる
          }
          await store.set('graph', jsonEncode(graph.toJson()));
        }
        await store.set('accounts', sig);
      }
    }

    SnsSession? sessionForAccount(String label) {
      final s = sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
      return s == null ? null : ref.read(pluginRegistryProvider).session(s);
    }

    // マージが中身比較で畳んだコピー (D-115) は ↓ の選択肢へ回す。
    final merged = <String, List<Post>>{};
    final result = await runNodeGraph(
      graph,
      fetch: (kid) => _pagedNodeFetch(session, kid, more: more, sessionFor: sessionForAccount),
      fetchTrends: () async => [for (final t in await session.trendingTags()) t.tag],
      pluginSort: (id, posts, params) => id.startsWith('slot:') ? ref.read(slotPluginsProvider.notifier).sortById(id, posts, params: params) : (session is WasmSnsSession ? session.timelinePlugin.compose(id, posts) : Future.value(posts)),
      storageRead: (slot) async => (await ref.read(settingsAreaProvider('storage.safe').future))[slot],
      storageWrite: (slot, value) => ref.read(settingsAreaProvider('storage.safe').notifier).set(slot, value),
      onDuplicate: (kept, dropped) => merged.putIfAbsent(kept.key, () => []).add(dropped),
      loadFunction: _loadFunctionBody,
    );
    if (result == null) return null;
    if (merged.isNotEmpty) {
      Future.microtask(() => ref.read(postAlternatesProvider.notifier).recordAll(merged));
    }

    // アクション状態は所属アカウントのセッションから取り直す。隠したコピーの
    // 分も取る(↓ でアカウントを切り替えたとき用)。
    final byAccount = <String, List<Post>>{};
    for (final p in [...result, for (final l in merged.values) ...l]) {
      byAccount.putIfAbsent(p.account.key, () => []).add(p);
    }
    for (final e in byAccount.entries) {
      final s = sessions.where((x) => x.account.key == e.key).firstOrNull;
      if (s == null) continue;
      try {
        _applyStates(e.value, await ref.read(pluginRegistryProvider).session(s).actionStates(e.value));
      } catch (_) {}
    }
    _armClock(nodeGraphClockInterval(graph));
    final folded = ref.read(childGateProvider).filterPosts(_foldDuplicates(result));
    ref.read(emojiCacheProvider.notifier).request({for (final p in folded) ...InlineSpans.emojiShortcodes(p.body), for (final p in folded) ...InlineSpans.emojiShortcodes(p.author.displayName)});
    return folded;
  }

  /// 中身比較の畳み込み (D-110): 一致コピーは隠して ↓ の選択肢へ回す。
  List<Post> _foldDuplicates(List<Post> posts) {
    final byDup = <String, Post>{};
    final dropped = <String, List<Post>>{};
    final out = <Post>[];
    for (final p in posts) {
      final kept = byDup[postDupKey(p)];
      if (kept != null) {
        dropped.putIfAbsent(kept.key, () => []).add(p);
        continue;
      }
      byDup[postDupKey(p)] = p;
      out.add(p);
    }
    if (dropped.isNotEmpty) {
      Future.microtask(() => ref.read(postAlternatesProvider.notifier).recordAll(dropped));
    }
    return out;
  }

  /// 総合TL の続き読み (D-117): グラフをもう一度実行し、各取得ノードが自分の
  /// カーソルから次ページを読む(loadMore が id 重複を除いて末尾へ足す)。
  Future<(Page<Post>, Map<String, Map<String, ActionResult>>, TimelineDecorations)> _bundleGraphMore() async {
    List<Post> result = const [];
    try {
      result = await _runBundleGraph(more: true) ?? const [];
    } catch (e) {
      debugPrint('bundle graph more: $e');
    }
    return (Page(items: result, nextCursor: _nodeHasMore ? 'node' : null), <String, Map<String, ActionResult>>{}, const TimelineDecorations());
  }

  /// 総合TL (D-088): 全ログインアカウントのホームTLを合流する。重複は
  /// `著者キー/投稿id` で除外(同一インスタンスの複数アカウントで同じ投稿を
  /// 見る場合は最初のアカウント側に寄せる)。取得に失敗したアカウントは無視。
  Future<(Page<Post>, Map<String, Map<String, ActionResult>>, TimelineDecorations)> _fetchBundle({required bool first}) async {
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final registry = ref.read(pluginRegistryProvider);
    final out = <Post>[];
    final states = <String, Map<String, ActionResult>>{};
    final seen = <String>{};
    final byDup = <String, Post>{}; // 中身の同定キー (D-110) → 残したコピー
    final dropped = <String, List<Post>>{};
    final next = <String, String>{};
    for (final s in sessions) {
      final cursor = first ? null : _bundleCursors[s.account.key];
      if (!first && cursor == null) continue; // このアカウントは末尾まで読了
      try {
        final session = registry.session(s);
        final page = await session.timeline(TimelineKind.home, cursor: cursor);
        final st = await session.actionStates(page.items);
        // 隠すコピーの分も含めて状態は残す(↓ でアカウントを切り替えたとき用)。
        _applyStates(page.items, st);
        for (final p in page.items) {
          if (!seen.add('${p.author.key}/${p.id}')) continue;
          // 中身比較の同定 (D-110): 別インスタンス経由の同じ投稿は隠して
          // ↓(アカウント選択)の選択肢へ回す。
          final kept = byDup[postDupKey(p)];
          if (kept != null) {
            dropped.putIfAbsent(kept.key, () => []).add(p);
            continue;
          }
          byDup[postDupKey(p)] = p;
          out.add(p);
          final ps = st[p.id];
          if (ps != null) states[p.id] = ps;
        }
        if (page.nextCursor != null) next[s.account.key] = page.nextCursor!;
      } catch (e) {
        debugPrint('bundle TL ${s.account.key}: $e');
      }
    }
    if (dropped.isNotEmpty) {
      Future.microtask(() => ref.read(postAlternatesProvider.notifier).recordAll(dropped));
    }
    _bundleCursors = next;
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // チャイルドセーフ (D-307): 見せない投稿を落とす。
    final visible = ref.read(childGateProvider).filterPosts(out);
    if (visible.length != out.length) {
      out
        ..clear()
        ..addAll(visible);
    }
    _applyStates(out, states);
    ref.read(emojiCacheProvider.notifier).request({for (final p in out) ...InlineSpans.emojiShortcodes(p.body), for (final p in out) ...InlineSpans.emojiShortcodes(p.author.displayName)});
    // カーソルはアカウント別に持つので、状態側にはダミーの続きトークンだけ渡す。
    return (Page(items: out, nextCursor: next.isEmpty ? null : 'bundle'), states, const TimelineDecorations());
  }

  Future<(Page<Post>, Map<String, Map<String, ActionResult>>, TimelineDecorations)> _fetch(SnsSession session, String? cursor) async {
    // カスタム TL (M5e / D-080): データ取得はホスト(基礎 TL)、TL プラグインは
    // ソートアルゴリズム(`tl.sort` — 表示順の id 列、未掲載は除外)。
    if (kind.id.startsWith('custom:') && session is WasmSnsSession) {
      final specs = await ref.read(customTimelinesProvider.future);
      final spec = specs.where((x) => 'custom:${x.id}' == kind.id).firstOrNull;
      if (spec != null) {
        final base = await session.timeline(TimelineKind(spec.base, spec.base), cursor: cursor);
        final states = await session.actionStates(base.items);
        // 投稿加工 (D-083) → ソート → カスタマイザ (D-082/D-085) の順で通す。
        final transformed = await session.timelinePlugin.transform(base.items);
        final composed = await session.timelinePlugin.compose(spec.id, transformed);
        final deco = await session.timelinePlugin.customize(spec.id, composed);
        _applyStates(composed, states);
        ref.read(emojiCacheProvider.notifier).request({for (final p in composed) ...InlineSpans.emojiShortcodes(p.body)});
        return (Page(items: ref.read(childGateProvider).filterPosts(composed), nextCursor: base.nextCursor), states, deco);
      }
    }
    Page<Post> page;
    Map<String, Map<String, ActionResult>> states;
    if (kind.id.startsWith('node:')) {
      // ノードTLタブ (D-101): 基礎 TL なし — 中身はグラフの取得ノードが全て。
      page = Page(items: const []);
      states = {};
    } else if (session is MisskeySession) {
      (page, states) = await session.timelineWithStates(kind, cursor: cursor);
    } else {
      page = await session.timeline(kind, cursor: cursor);
      states = await session.actionStates(page.items);
    }
    // 投稿加工プラグイン (D-083): 通常 TL でも表示前に本文加工を通す
    // (v1 は wasm セッション自身のモジュール。独立プラグインはストア統合後)。
    if (session is WasmSnsSession && !kind.id.startsWith('node:')) {
      page = Page(items: await session.timelinePlugin.transform(page.items), nextCursor: page.nextCursor);
    }
    // 投稿加工のスロットプラグイン (D-167): 全 TL 共通。
    if (!kind.id.startsWith('node:') && ref.read(slotPluginsForProvider(SlotIds.postTransform)).isNotEmpty) {
      page = Page(items: await ref.read(slotPluginsProvider.notifier).transform(page.items), nextCursor: page.nextCursor);
    }
    // ノードグラフ実行 (D-094): この TL のスコープ(tl.<id>)に
    // 「タイムライン取得 → 加工 → タイムライン」の完成した鎖があれば通す。
    // トレンド/タグ TL (D-102) と Today(featured, D-113)は共通の `trend`
    // スコープ。
    if (!kind.id.startsWith('custom:')) {
      final scope = _graphScope;
      Duration? clock;
      try {
        // アカウント分離 (D-108): グラフ/storage.safe は持ち主アカウントの
        // 領域。ノード TL タブは作ったアカウントのグラフ + セッションで動く
        // (バンドルの集合表示でも中身が持ち主のまま)。
        var graphAccKey = ref.read(currentAccountProvider)?.key;
        var graphSession = session;
        if (kind.id.startsWith('node:')) {
          final owner = ref.read(allNodeTabsProvider).where((t) => t.$2.id == kind.id).firstOrNull;
          if (owner != null) {
            graphAccKey = owner.$1;
            final s = ref.read(sessionsProvider).value?.sessions.where((x) => x.account.key == owner.$1).firstOrNull;
            if (s != null) graphSession = ref.read(pluginRegistryProvider).session(s);
          }
        }
        // 一時変更 (D-338) があれば、保存した構成の代わりに使う。
        var raw = _temporaryGraphRaw ?? await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), graphAccKey, scope);
        // DM 共通設定 (D-127): ページ個別の設定が無ければ、メインページの
        // 設定(tl.dm)をカスタム未設定の全 DM ページに適用する。
        if (raw == null && (kind.id.startsWith('dm:') || kind.id.startsWith('chat:'))) {
          raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), graphAccKey, 'tl.dm');
        }
        if (raw is String) {
          final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
          // SigLIP ゲートウェイ (D-097): あれば類似度ノードが実埋め込みを使う
          // (無ければ executor が n-gram 類似度へ縮退)。
          MlGateway? gateway;
          try {
            gateway = await ref.read(mlGatewayProvider.future);
          } catch (_) {}
          final storageArea = storageSafeAreaFor(graphAccKey);
          // アカウント指定 (D-109) の解決: 表記(@handle@instance)かキーで探す。
          SnsSession? sessionForAccount(String label) {
            final s = ref.read(sessionsProvider).value?.sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
            return s == null ? null : ref.read(pluginRegistryProvider).session(s);
          }

          // マージが中身比較で畳んだコピー (D-115) は ↓ の選択肢へ回す。
          final merged = <String, List<Post>>{};
          // 枝ごとのカーソル (D-117): 初回/リフレッシュで仕切り直し、続き読みは
          // 各取得ノードが自分のカーソルから次ページを読む。
          if (cursor == null) _nodeCursors = {};
          final result = await runNodeGraph(
            graph,
            fetch: (kid) => _pagedNodeFetch(graphSession, kid, more: cursor != null, selfKindId: kind.id, selfItems: page.items, sessionFor: sessionForAccount),
            onDuplicate: (kept, dropped) => merged.putIfAbsent(kept.key, () => []).add(dropped),
            loadFunction: _loadFunctionBody,
            // 検索絞り込み (D-125): タグ TL ではタグが既定の検索ワード。
            selfQuery: kind.id.startsWith('tag:') ? kind.id.substring(4) : null,
            fetchTrends: () async => [for (final t in await graphSession.trendingTags()) t.tag],
            embedTexts: gateway == null ? null : (texts) async => [for (final e in await gateway!.embedTexts(texts)) e.toList()],
            // TL プラグインのソートノード (D-102): tl.sort/compose の実体。
            // プラグインの並べ替えは、このグラフの持ち主のアカウントで使う版で (D-355)。
            pluginSort: (id, posts, params) => id.startsWith('slot:') ? ref.read(slotPluginsProvider.notifier).sortById(id, posts, params: params, accountKey: graphAccKey) : (graphSession is WasmSnsSession ? graphSession.timelinePlugin.compose(id, posts) : Future.value(posts)),
            // storage.safe (D-104/D-108): アカウント別領域(旧共有領域は読み取りフォールバック)。
            storageRead: (slot) async {
              final own = (await ref.read(settingsAreaProvider(storageArea).future))[slot];
              if (own != null) return own;
              return (await ref.read(settingsAreaProvider('storage.safe').future))[slot];
            },
            storageWrite: (slot, value) => ref.read(settingsAreaProvider(storageArea).notifier).set(slot, value),
          );
          if (result != null) {
            // node: タブは基礎 TL のカーソルが無いので、枝に続きがある限り
            // 続き読みできる (D-117)。基礎 TL 有りのタブは基礎側のカーソル。
            final nodeMore = kind.id.startsWith('node:') && _nodeHasMore;
            page = Page(items: result, nextCursor: page.nextCursor ?? (nodeMore ? 'node' : null));
            states = await graphSession.actionStates(result); // 別 TL 由来の投稿の分を取り直す
            if (merged.isNotEmpty) {
              Future.microtask(() => ref.read(postAlternatesProvider.notifier).recordAll(merged));
            }
            // クロック → ノードのアイコン (D-095): 繋がっていれば自動更新。
            clock = nodeGraphClockInterval(graph);
          }
        }
      } catch (e) {
        debugPrint('nodeprog($scope): $e');
      }
      _armClock(clock);
    }
    // 指向性/刺激性の既定適用 (D-153): おすすめ(social)とトレンド(tag:)に、
    // カスタム鎖の後でプロファイルを掛ける(プロファイルが効かなければ素通し)。
    if (kind == TimelineKind.social || kind.id.startsWith('tag:')) {
      try {
        final profile = await ref.read(tendencyProfileProvider.future);
        if (profile.active) page = Page(items: applyTendencyProfile(page.items, profile), nextCursor: page.nextCursor);
      } catch (e) {
        debugPrint('tendency: $e');
      }
    }
    // チャイルドセーフ (D-307): 判定の強さ / 止める話題で見せない投稿を落とす(全 TL 共通、最後に掛ける)。
    final gate = ref.read(childGateProvider);
    if (gate.supervised) page = Page(items: gate.filterPosts(page.items), nextCursor: page.nextCursor);
    _applyStates(page.items, states);
    ref.read(emojiCacheProvider.notifier).request({for (final p in page.items) ...InlineSpans.emojiShortcodes(p.body), for (final p in page.items) ...InlineSpans.emojiShortcodes(p.author.displayName)});
    return (page, states, const TimelineDecorations());
  }

  void _applyStates(List<Post> posts, Map<String, Map<String, ActionResult>> states) {
    final store = ref.read(actionStateProvider.notifier);
    final batch = <ActionKey, ActionState>{};
    final descriptors = {for (final a in _session?.actions ?? const <ActionDescriptor>[]) a.id: a};
    for (final p in posts) {
      final s = states[p.id];
      if (s == null) continue;
      for (final e in s.entries) {
        // Validation gate: per-post icons only for actions that declared iconPerPost.
        final allowIcon = descriptors[e.key]?.iconPerPost ?? false;
        batch[(postKey: p.key, actionId: e.key)] = ActionState(done: e.value.done, count: e.value.count, iconUrl: allowIcon ? e.value.icon?.url : null, iconText: allowIcon ? e.value.icon?.text : null);
      }
    }
    final session = _session;
    store.applyAll(session == null ? batch : keepKnownBookmarks(store, session, batch));
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) return;
    try {
      state = AsyncData(await _latest(session));
    } catch (e, st) {
      if (state.value == null || state.value!.posts.isEmpty) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(state.value!.copyWith(error: e));
      }
    }
  }

  /// 最新の 1 ページ(state には書かない)。総合 TL はカーソルを作り直す。
  Future<TimelineState> _latest(SnsSession session) async {
    if (kind == childSafeWindowKind) return TimelineState(posts: await _fetchChildWindow());
    if (kind == TimelineKind.bundle) {
      _bundleCursors = {};
      _nodeCursors = {};
      // リフレッシュ(プル更新/クロック)もグラフ経由 (D-117): 以前はここが
      // 旧合流へ直行していて、更新のたびに総合グラフの加工が消えていた。
      try {
        final result = await _runBundleGraph();
        if (result != null) {
          _bundleGraphActive = true;
          return TimelineState(posts: result, cursor: _nodeHasMore ? 'node' : null);
        }
      } catch (e) {
        debugPrint('bundle graph: $e');
      }
      _bundleGraphActive = false;
      final (page, _, _) = await _fetchBundle(first: true);
      return TimelineState(posts: page.items, cursor: page.nextCursor);
    }
    final (page, _, deco) = await _fetch(session, null);
    return TimelineState(posts: page.items, cursor: page.nextCursor, customTiles: deco.tiles, badges: deco.badges);
  }

  /// 上の更新タイル (D-298) からの更新: **読み込んである投稿は残したまま、新しいぶんを上に足す**(引っ張って更新 = [refresh] は、最新の 1 ページに置き換える)。
  /// 新しいページが手元の投稿とつながらない(間が空いた)ときと、総合 TL(カーソルを作り直す)は、[refresh] と同じ置き換えになる。
  Future<void> refreshNewer() async {
    final before = state.value;
    await refresh();
    final after = state.value;
    if (before == null || after == null || after.error != null || kind == TimelineKind.bundle) return;
    final fresh = {for (final p in after.posts) p.id};
    if (!before.posts.any((p) => fresh.contains(p.id))) return;
    final tail = [for (final p in before.posts) if (!fresh.contains(p.id)) p];
    if (tail.isEmpty) return;
    state = AsyncData(after.copyWith(posts: [...after.posts, ...tail], cursor: before.cursor, clearCursor: before.cursor == null, customTiles: {...before.customTiles, ...after.customTiles}, badges: {...before.badges, ...after.badges}));
  }

  /// 自動更新 (D-379): **手元の投稿はそのまま、新しいものだけを上に足す**(間が空いていても足す)。続きのカーソルも変えない。
  /// 見ている位置は動かない(TL は中心より上に足す)。全体を取り直すのは「新しい投稿を読み込む」/ 引っ張って更新 = [refresh]。
  Future<void> prependNewer() async {
    final before = state.value;
    final session = _session;
    if (session == null) return;
    if (before == null || before.posts.isEmpty) return refresh();
    final bundleCursors = {..._bundleCursors};
    final nodeCursors = {..._nodeCursors};
    final graphActive = _bundleGraphActive;
    TimelineState latest;
    try {
      latest = await _latest(session);
    } catch (e) {
      final cur = state.value;
      if (cur != null) state = AsyncData(cur.copyWith(error: e));
      return;
    } finally {
      // 総合 TL はカーソルを作り直すので、続きを読む位置を戻す。
      _bundleCursors = bundleCursors;
      _nodeCursors = nodeCursors;
      _bundleGraphActive = graphActive;
    }
    // 待っている間に続きを読んだ / 更新したかもしれないので、いまの state に足す。
    final cur = state.value ?? before;
    final have = {for (final p in cur.posts) p.key};
    final fresh = [for (final p in latest.posts) if (!have.contains(p.key)) p];
    if (fresh.isEmpty) return;
    state = AsyncData(cur.copyWith(
      posts: [...fresh, ...cur.posts],
      clearError: true,
      customTiles: {...cur.customTiles, ...latest.customTiles},
      badges: {...cur.badges, ...latest.badges},
    ));
  }

  Future<void> loadMore() async {
    final cur = state.value;
    final session = _session;
    if (cur == null || session == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, clearError: true));
    try {
      final (page, _, deco) = kind == TimelineKind.bundle
          ? (_bundleGraphActive ? await _bundleGraphMore() : await _fetchBundle(first: false))
          : await _fetch(session, cur.cursor);
      final seen = {for (final p in cur.posts) p.id};
      final merged = [...cur.posts, ...page.items.where((p) => !seen.contains(p.id))];
      state = AsyncData(cur.copyWith(posts: merged, cursor: page.nextCursor, clearCursor: page.nextCursor == null, loadingMore: false, customTiles: {...cur.customTiles, ...deco.tiles}, badges: {...cur.badges, ...deco.badges}));
    } catch (e) {
      state = AsyncData(cur.copyWith(loadingMore: false, error: e));
    }
  }

  /// Performs [actionId] with optimistic update, reconciles with the plugin result.
  Future<void> perform(Post post, ActionDescriptor action, {Map<String, Object?> args = const {}}) async {
    // 総合TLでは投稿の所属アカウントのセッションで実行する (D-088)。
    final session = _sessionFor(post) ?? _session;
    if (session == null) return;
    final store = ref.read(actionStateProvider.notifier);
    final before = store.of(post.key, action.id);
    // `forceUndo` (D-274): 状態の入り切りではなく、向きを指定する(リノートのボタンは何度でも「リノート」、取り消しは帯の … から)。
    final forced = args['forceUndo'];
    args = {...args}..remove('forceUndo');
    final undo = forced is bool ? forced : (args.containsKey('reaction') ? false : before.done);
    store.applyOptimistic(post.key, action.id, done: !undo);
    try {
      final r = await session.performAction(action.id, post.id, args: {...args, 'undo': undo});
      // どのアカウントでこの相手と関わったか (D-280: 共有 / リノートに使うアカウントの予測の材料)。
      if (!undo) ref.read(accountAffinityProvider.notifier).record(post).ignore();
      store.apply(post.key, action.id, ActionState(done: r.done, count: r.count ?? before.count, iconUrl: action.iconPerPost ? (r.icon?.url ?? before.iconUrl) : null, iconText: action.iconPerPost ? (r.icon?.text ?? (r.icon?.url != null ? null : before.iconText)) : null));
    } catch (e) {
      store.apply(post.key, action.id, before);
      debugPrint('action ${action.id} failed: $e');
      rethrow;
    }
  }
}

final timelineProvider = AsyncNotifierProvider.family<TimelineNotifier, TimelineState, TimelineKind>(TimelineNotifier.new);

/// 見守りの時間の 1 本の TL (D-307)。ホームのタブはこれだけになる(フォロー中 / AsTell もここへ畳む)。
const childSafeWindowKind = TimelineKind('childsafe.window', '見守りの時間', extensible: false);

/// 取得ノード (D-097) の kind 解決(TL/関連/トレンドで共用): リストは
/// 名前 → id、DM は相手ハンドル → ルームの peer id をアプリ側で引く。
/// [selfKindId] と一致する取得は [selfItems] を返す(自分の TL の再取得回避)。
/// [onCursor] (D-117) には取得ページの続きトークンを報告する(枝ごとの
/// ページング用。null = 末尾まで読了)。
Future<List<Post>> resolveNodeFetch(SnsSession session, String kid,
    {String? selfKindId, List<Post> selfItems = const [], String? cursor, SnsSession? Function(String account)? sessionFor, void Function(String? next)? onCursor, Future<(List<Post>, String?)> Function(String? until)? rasqFeed, Future<(List<Post>, String?)> Function(String id, String? until)? rasqList, Future<List<Post>> Function()? rasqMine, bool Function(String meta, List<String> bodies)? listHidden}) async {
  // RASQ の投稿 (D-283): SNS のセッションではなく、Central のフィード(自分とフォロー中の RASQ アカウント)。
  // `acct:` で包まれていても拾う(包んだまま流すと、現在の SNS のセッションで取りに行ってしまう)。
  if ((kid.startsWith('acct:') ? kid.substring(kid.indexOf('|') + 1) : kid) == rasqPostsKind) {
    if (rasqFeed == null) return const [];
    final (posts, next) = await rasqFeed(cursor);
    onCursor?.call(next);
    return posts;
  }
  // RASQ リスト (D-346): Central のリストのタイムライン(S-044)。アカウント指定は見ない。
  final bare = kid.startsWith('acct:') ? kid.substring(kid.indexOf('|') + 1) : kid;
  if (bare.startsWith(rasqListKindPrefix)) {
    final id = bare.substring(rasqListKindPrefix.length).trim();
    if (rasqList == null || id.isEmpty) return const [];
    final (posts, next) = await rasqList(id, cursor);
    onCursor?.call(next);
    return posts;
  }
  // アカウント指定 (D-109): `acct:<@handle@instance>|<kind>` — そのアカウントの
  // セッションで残りを解決する(見つからなければ渡されたセッションのまま)。
  if (kid.startsWith('acct:')) {
    final sep = kid.indexOf('|');
    if (sep > 5) {
      // RASQ アカウント(`@handle@rasq`)の「自分の投稿」(D-286): 投稿先のカスタマイズの RASQ のタブで、自分の投稿と比べる基準。
      // SNS のセッションは無いので、RASQ としての投稿を返す(以前は、表示中の SNS アカウントの投稿と比べていた)。
      if (kid.substring(5, sep).endsWith('@$rasqPostInstance')) {
        final kind = kid.substring(sep + 1);
        if (rasqMine == null || !const {'myposts', 'myreplies', 'home', 'self'}.contains(kind)) return const [];
        onCursor?.call(null);
        return rasqMine();
      }
      final other = sessionFor?.call(kid.substring(5, sep));
      return resolveNodeFetch(other ?? session, kid.substring(sep + 1), cursor: cursor, sessionFor: sessionFor, onCursor: onCursor, rasqFeed: rasqFeed, rasqList: rasqList, rasqMine: rasqMine, listHidden: listHidden);
    }
  }
  // `self` (D-124): この画面の基礎タイムライン(検索結果/リスト/欄の投稿)を
  // そのまま返す — kind id が動的なスコープ(トレンド等)の自己参照。
  if (kid == 'self' || (selfKindId != null && kid == selfKindId)) return selfItems;
  // 投稿加工プラグイン (D-083/D-118): ノード定義を持たないプラグインの加工は
  // **取得ノードに渡す直前**に済ませる(wasm セッションの post.transform)。
  Future<List<Post>> finish(Page<Post> page) async {
    onCursor?.call(page.nextCursor);
    if (session is WasmSnsSession) {
      try {
        return await session.timelinePlugin.transform(page.items);
      } catch (_) {} // 加工不達は素通し
    }
    return page.items;
  }

  if (kid == 'myreactions') return finish(await session.reactedPosts(cursor: cursor)); // リアクション済み取得 (D-103)
  // サジェストの基準 (D-121): 投稿内容 = 自分の投稿、会話内容 = 自分の返信。
  if (kid == 'myposts' || kid == 'myreplies') {
    final me = await session.me();
    return finish(await session.userPosts(me.id, cursor: cursor, filter: kid == 'myposts' ? UserPostsFilter.posts : UserPostsFilter.replies));
  }
  if (kid.startsWith('search:')) {
    final q = kid.substring(7).trim();
    if (q.isEmpty) return const [];
    return finish(await session.searchPosts(q, cursor: cursor));
  }
  if (kid.startsWith('list:')) {
    final name = kid.substring(5).trim();
    if (name.isEmpty) return const [];
    final lists = await session.lists();
    final l = lists.where((x) => x.name == name || x.id == name).firstOrNull;
    if (l == null) return const [];
    final page = await session.timeline(TimelineKind.list(l.id, l.name), cursor: cursor);
    // チャイルドセーフ (D-314): 止める例に近い中身のリストは、タイムラインにも流さない。
    if (listHidden != null && listHidden('${l.name} ${l.description ?? ''}'.trim(), [for (final p in page.items) '${p.body} ${p.quote?.body ?? ''}'])) return const [];
    return finish(page);
  }
  if (kid.startsWith('dm:')) {
    final who = kid.substring(3).trim().replaceFirst('@', '');
    if (who.isEmpty) return const [];
    final rooms = await session.dmRooms();
    final r = rooms.where((x) => x.peer.handle == who || x.peer.id == who).firstOrNull;
    if (r == null) return const [];
    return finish(await session.timeline(TimelineKind('dm:${r.peer.id}', 'DM'), cursor: cursor));
  }
  return finish(await session.timeline(TimelineKind(kid, kid), cursor: cursor));
}

/// RASQ の投稿のフィード (D-283)。TL のタイルは RASQ の投稿の形 ([RasqAccountPost]) で描くので、原本を [rasqFeedPostsProvider] に置く。
/// ログインしていなければ空。
Future<(List<Post>, String?)> fetchRasqFeed(Ref ref, String? until) async {
  final api = ref.read(rasqAccountPageApiProvider);
  if (api == null || ref.read(orgateAccountProvider).value == null) return (const <Post>[], null);
  try {
    final page = await api.feed(until: until);
    ref.read(rasqFeedPostsProvider.notifier).put(page.posts);
    final central = ref.read(centralBaseUrlProvider);
    return ([for (final p in page.posts) p.toPost(central: central)], page.nextUntil);
  } catch (e) {
    debugPrint('rasq feed: $e');
    return (const <Post>[], null);
  }
}

final _rasqListRef = RegExp(r'^([0-9a-fA-F-]{36}|[1-9A-HJ-NP-Za-km-z]{16,22})$');

/// RASQ リストのタイムライン (D-346、Central S-044)。取れない(ログインしていない / リスト内の人の情報を取れない = 403)なら空。
/// 投稿は、見ている人が同じ種類・同じサーバーのアカウントを持っていれば、そのアカウントの投稿として(リアクションなどができる)。
Future<(List<Post>, String?)> fetchRasqList(Ref ref, String id, String? until) async {
  final api = ref.read(rasqCollectionsApiProvider);
  if (api == null || ref.read(orgateAccountProvider).value == null) return (const <Post>[], null);
  try {
    // ノードの「リスト」は名前でも入る(ノードエディターの選択肢)。id / 共有コードでなければ、自分のリスト + フォロー中から名前で引く。
    if (!_rasqListRef.hasMatch(id)) {
      final mine = await api.mine(RasqCollectionKind.list);
      final following = await api.following();
      final hit = [...mine, ...following].where((c) => c.kind == RasqCollectionKind.list && c.name == id).firstOrNull;
      if (hit != null) id = hit.id; // 名前で見つからなければ、そのまま id として引く

    }
    final page = await api.timeline(id, until: until);
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final posts = <Post>[];
    for (final p in page.posts) {
      final member = page.memberOf(p.memberKey);
      final kind = member?.kind ?? p.memberKey.split(':').first;
      final instance = member?.instance ?? (p.memberKey.split(':').length > 1 ? p.memberKey.split(':')[1] : '');
      final mine = sessions.where((s) => s.account.kind.name == kind && s.account.instance == instance).firstOrNull;
      posts.add(p.toPost(member, viewer: mine?.account));
    }
    return (posts, page.next);
  } catch (e) {
    debugPrint('rasq list $id: $e');
    return (const <Post>[], null);
  }
}

/// RASQ アカウントとしての自分の投稿 (D-286)。ログインしていなければ空。
Future<List<Post>> fetchRasqMine(Ref ref) async {
  final api = ref.read(rasqAccountPageApiProvider);
  final me = ref.read(orgateAccountProvider).value;
  if (api == null || me == null) return const [];
  try {
    final central = ref.read(centralBaseUrlProvider);
    return [for (final p in (await api.posts(me.handle)).posts) if (p.rebroadedBy == null) p.toPost(central: central)];
  } catch (e) {
    debugPrint('rasq mine: $e');
    return const [];
  }
}
