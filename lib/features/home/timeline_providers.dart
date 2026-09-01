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
import '../../text/inline_spans.dart';
import '../nodeprog/node_executor.dart';
import '../nodeprog/node_graph.dart';
import '../nodeprog/node_tabs.dart';
import 'post_duplicates.dart';
import '../relational/relational_providers.dart' show mlGatewayProvider;
import '../settings/settings_dsl.dart';

/// カスタム TL の宣言 (M5e / D-080): 現在のセッションが wasm 境界
/// ([WasmSnsSession])のとき、その TL レンダラー契約(`tl.timelines`)から
/// 読む。ホームのタブに `custom:<id>` として現れる。独立 TL プラグインの
/// 常設インストールはストア統合(M4)側で拡張する。
final customTimelinesProvider = FutureProvider<List<CustomTimelineSpec>>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  if (session is! WasmSnsSession) return const [];
  return session.timelinePlugin.timelines();
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
    _clockTimer = Timer.periodic(interval, (_) => refresh());
  }

  /// 投稿の所属アカウントのセッション (D-088): 総合TLでは投稿ごとに取得元
  /// アカウントが違うので、アクションは所属セッションへルーティングする。
  SnsSession? _sessionFor(Post p) {
    final s = ref.read(sessionsProvider).value?.sessions.where((x) => x.account == p.account).firstOrNull;
    return s == null ? null : ref.read(pluginRegistryProvider).session(s);
  }

  @override
  Future<TimelineState> build() async {
    ref.watch(currentAccountProvider); // rebuild per account
    ref.onDispose(() {
      _clockTimer?.cancel();
      _clockTimer = null;
      _clockInterval = null;
    });
    if (kind == TimelineKind.bundle) {
      // 総合TL (D-088): アカウントの増減で作り直す。
      ref.watch(sessionsProvider.select((s) => s.value?.sessions.length ?? 0));
      _bundleCursors = {};
      // ノードグラフ経由 (D-114): 自動構成(アカウント追加でマージ段を更新)
      // を済ませてから実行。鎖が無ければ従来の合流へフォールバック。
      try {
        final result = await _runBundleGraph();
        if (result != null) return TimelineState(posts: result);
      } catch (e) {
        debugPrint('bundle graph: $e');
      }
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

  /// 総合スコープの自動構成 + 実行 (D-114)。グラフが無ければ全アカウント分を
  /// 自動生成(取得×N → マージ段 → タイムライン)。ユーザーが編集済み
  /// (auto フラグなし)なら、新アカウントはマージの空き口への差し込みだけ試す。
  Future<List<Post>?> _runBundleGraph() async {
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
    if (raw is! String) {
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
      fetch: (kid) => resolveNodeFetch(session, kid, sessionFor: sessionForAccount),
      fetchTrends: () async => [for (final t in await session.trendingTags()) t.tag],
      pluginSort: session is! WasmSnsSession ? null : (id, posts) => session.timelinePlugin.compose(id, posts),
      storageRead: (slot) async => (await ref.read(settingsAreaProvider('storage.safe').future))[slot],
      storageWrite: (slot, value) => ref.read(settingsAreaProvider('storage.safe').notifier).set(slot, value),
      onDuplicate: (kept, dropped) => merged.putIfAbsent(kept.key, () => []).add(dropped),
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
    final folded = _foldDuplicates(result);
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
        return (Page(items: composed, nextCursor: base.nextCursor), states, deco);
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
    // ノードグラフ実行 (D-094): この TL のスコープ(tl.<id>)に
    // 「タイムライン取得 → 加工 → タイムライン」の完成した鎖があれば通す。
    // トレンド/タグ TL (D-102) と Today(featured, D-113)は共通の `trend`
    // スコープ。
    if (!kind.id.startsWith('custom:')) {
      final scope = kind.id.startsWith('tag:') || kind.id == 'featured' ? 'trend' : 'tl.${kind.id}';
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
        final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), graphAccKey, scope);
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
          final result = await runNodeGraph(
            graph,
            fetch: (kid) => resolveNodeFetch(graphSession, kid, selfKindId: kind.id, selfItems: page.items, cursor: cursor, sessionFor: sessionForAccount),
            onDuplicate: (kept, dropped) => merged.putIfAbsent(kept.key, () => []).add(dropped),
            fetchTrends: () async => [for (final t in await graphSession.trendingTags()) t.tag],
            embedTexts: gateway == null ? null : (texts) async => [for (final e in await gateway!.embedTexts(texts)) e.toList()],
            // TL プラグインのソートノード (D-102): tl.sort/compose の実体。
            pluginSort: graphSession is! WasmSnsSession ? null : (id, posts) => (graphSession as WasmSnsSession).timelinePlugin.compose(id, posts),
            // storage.safe (D-104/D-108): アカウント別領域(旧共有領域は読み取りフォールバック)。
            storageRead: (slot) async {
              final own = (await ref.read(settingsAreaProvider(storageArea).future))[slot];
              if (own != null) return own;
              return (await ref.read(settingsAreaProvider('storage.safe').future))[slot];
            },
            storageWrite: (slot, value) => ref.read(settingsAreaProvider(storageArea).notifier).set(slot, value),
          );
          if (result != null) {
            page = Page(items: result, nextCursor: page.nextCursor);
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
    store.applyAll(batch);
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) return;
    try {
      if (kind == TimelineKind.bundle) {
        _bundleCursors = {};
        final (page, _, _) = await _fetchBundle(first: true);
        state = AsyncData(TimelineState(posts: page.items, cursor: page.nextCursor));
        return;
      }
      final (page, _, deco) = await _fetch(session, null);
      state = AsyncData(TimelineState(posts: page.items, cursor: page.nextCursor, customTiles: deco.tiles, badges: deco.badges));
    } catch (e, st) {
      if (state.value == null || state.value!.posts.isEmpty) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(state.value!.copyWith(error: e));
      }
    }
  }

  Future<void> loadMore() async {
    final cur = state.value;
    final session = _session;
    if (cur == null || session == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, clearError: true));
    try {
      final (page, _, deco) = kind == TimelineKind.bundle ? await _fetchBundle(first: false) : await _fetch(session, cur.cursor);
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
    final undo = args.containsKey('reaction') ? false : before.done;
    store.applyOptimistic(post.key, action.id, done: !undo);
    try {
      final r = await session.performAction(action.id, post.id, args: {...args, 'undo': undo});
      store.apply(post.key, action.id, ActionState(done: r.done, count: r.count ?? before.count, iconUrl: action.iconPerPost ? (r.icon?.url ?? before.iconUrl) : null, iconText: action.iconPerPost ? (r.icon?.text ?? (r.icon?.url != null ? null : before.iconText)) : null));
    } catch (e) {
      store.apply(post.key, action.id, before);
      debugPrint('action ${action.id} failed: $e');
      rethrow;
    }
  }
}

final timelineProvider = AsyncNotifierProvider.family<TimelineNotifier, TimelineState, TimelineKind>(TimelineNotifier.new);

/// 取得ノード (D-097) の kind 解決(TL/関連/トレンドで共用): リストは
/// 名前 → id、DM は相手ハンドル → ルームの peer id をアプリ側で引く。
/// [selfKindId] と一致する取得は [selfItems] を返す(自分の TL の再取得回避)。
Future<List<Post>> resolveNodeFetch(SnsSession session, String kid, {String? selfKindId, List<Post> selfItems = const [], String? cursor, SnsSession? Function(String account)? sessionFor}) async {
  // アカウント指定 (D-109): `acct:<@handle@instance>|<kind>` — そのアカウントの
  // セッションで残りを解決する(見つからなければ渡されたセッションのまま)。
  if (kid.startsWith('acct:')) {
    final sep = kid.indexOf('|');
    if (sep > 5) {
      final other = sessionFor?.call(kid.substring(5, sep));
      return resolveNodeFetch(other ?? session, kid.substring(sep + 1), cursor: cursor, sessionFor: sessionFor);
    }
  }
  if (selfKindId != null && kid == selfKindId) return selfItems;
  if (kid == 'myreactions') return (await session.reactedPosts(cursor: cursor)).items; // リアクション済み取得 (D-103)
  if (kid.startsWith('search:')) {
    final q = kid.substring(7).trim();
    if (q.isEmpty) return const [];
    return (await session.searchPosts(q, cursor: cursor)).items;
  }
  if (kid.startsWith('list:')) {
    final name = kid.substring(5).trim();
    if (name.isEmpty) return const [];
    final lists = await session.lists();
    final l = lists.where((x) => x.name == name || x.id == name).firstOrNull;
    if (l == null) return const [];
    return (await session.timeline(TimelineKind.list(l.id, l.name), cursor: cursor)).items;
  }
  if (kid.startsWith('dm:')) {
    final who = kid.substring(3).trim().replaceFirst('@', '');
    if (who.isEmpty) return const [];
    final rooms = await session.dmRooms();
    final r = rooms.where((x) => x.peer.handle == who || x.peer.id == who).firstOrNull;
    if (r == null) return const [];
    return (await session.timeline(TimelineKind('dm:${r.peer.id}', 'DM'))).items;
  }
  return (await session.timeline(TimelineKind(kid, kid), cursor: cursor)).items;
}
