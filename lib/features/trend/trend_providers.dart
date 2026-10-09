import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/timeline_providers.dart';
import '../nodeprog/node_executor.dart';
import '../nodeprog/node_graph.dart';
import '../nodeprog/node_tabs.dart';
import '../nodeprog/tl_components.dart';
import '../relational/relational_engine.dart';
import '../relational/relational_providers.dart';
import '../settings/settings_dsl.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'tendency_profile.dart';
import 'trend_analysis.dart';

/// トレンドワード. Phase-1 sample: `hashtags/trend` of the current SNS
/// (server-side trend provider lands later).
final trendingTagsProvider = FutureProvider.autoDispose<List<TrendTag>>((ref) async => (await ref.watch(sourcedTrendsProvider.future)).tags);

/// トレンドとその出どころ (D-388)。
typedef SourcedTrends = ({List<TrendTag> tags, Map<String, List<AccountId>> sources});

/// トレンドのワードの比べ方(`#` と大文字小文字を無視)。
String trendKey(String tag) => tag.replaceFirst(RegExp(r'^#'), '').toLowerCase();

/// **RASQ アカウントでまとめたトレンド** (D-388): いまの RASQ アカウントに入っている SNS アカウント**全部**
/// (Misskey / Mastodon / Bluesky / mixi2 …)のトレンドを集め、同じワードは 1 つにまとめる。並びは各アカウントの順位を
/// 交互に(1 位どうし → 2 位どうし …)。どのサーバーのトレンドか([SourcedTrends.sources])は、検索のトレンドの行に
/// 「サーバーのアイコン + サーバー名」で出す。読めなかったアカウントは飛ばす。
final sourcedTrendsProvider = FutureProvider.autoDispose<SourcedTrends>((ref) async {
  ref.watch(currentAccountProvider);
  final registry = ref.watch(pluginRegistryProvider);
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final current = ref.watch(currentAccountSessionProvider);
  final all = [?current, for (final x in sessions) if (x.account.key != current?.account.key) x];
  final lists = await Future.wait([
    for (final a in all)
      () async {
        try {
          return (account: a.account, tags: await registry.session(a).trendingTags());
        } catch (e) {
          debugPrint('trend(${a.account}): $e');
          return (account: a.account, tags: const <TrendTag>[]);
        }
      }(),
  ]);
  final tags = <TrendTag>[];
  final sources = <String, List<AccountId>>{};
  final longest = lists.fold(0, (m, l) => l.tags.length > m ? l.tags.length : m);
  for (var i = 0; i < longest; i++) {
    for (final l in lists) {
      if (i >= l.tags.length) continue;
      final t = l.tags[i];
      final k = trendKey(t.tag);
      final src = sources[k];
      if (src == null) {
        sources[k] = [l.account];
        tags.add(t);
      } else if (!src.contains(l.account)) {
        src.add(l.account);
      }
    }
  }
  return (tags: tags, sources: sources);
});

/// トレンドスコープのグラフを [posts] に適用する共通口 (D-113)。
/// デフォルト鎖の取得ノードが要求する kind([selfKindId])に、この欄の
/// 投稿を差し込む(= 欄の投稿を加工する)。鎖が無ければ null。
Future<List<Post>?> _applyTrendScopeGraph(Ref ref, SnsSession session, String scope, String selfKindId, List<Post> posts, {String? selfQuery}) async {
  try {
    final accKey = ref.read(currentAccountProvider)?.key;
    final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, scope);
    if (raw is! String) return null;
    final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    SnsSession? sessionForAccount(String label) {
      final s = ref.read(sessionsProvider).value?.sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
      return s == null ? null : ref.read(pluginRegistryProvider).session(s);
    }

    final storageArea = storageSafeAreaFor(accKey);
    return await runNodeGraph(
      graph,
      fetch: (kid) => resolveNodeFetch(session, kid, selfKindId: selfKindId, selfItems: posts, sessionFor: sessionForAccount, kindBlocked: childKindBlocked(ref.read(childGateProvider))),
      fetchTrends: () async => [for (final t in await session.trendingTags()) t.tag],
      storageRead: (slot) async {
        final own = (await ref.read(settingsAreaProvider(storageArea).future))[slot];
        if (own != null) return own;
        return (await ref.read(settingsAreaProvider('storage.safe').future))[slot];
      },
      storageWrite: (slot, value) => ref.read(settingsAreaProvider(storageArea).notifier).set(slot, value),
      loadFunction: (fnId) => loadFunctionBody((a) => ref.read(settingsAreaProvider(a).future), fnId), // カスタム関数の中身 (D-118)
      selfQuery: selfQuery, // 検索絞り込み (D-125): このページの検索ワード/タグ
    );
  } catch (e) {
    debugPrint('nodeprog($scope): $e');
    return null;
  }
}

/// フォロー中タブ (D-113): `trend.following` スコープのグラフを通した
/// フォロイー投稿(鎖が無ければそのまま)。
final trendFollowingPostsProvider = FutureProvider.autoDispose.family<List<Post>, TrendQuery>((ref, q) async {
  final tag = q.tag;
  final a = await ref.watch(trendAnalysisProvider(q).future);
  final s = ref.watch(sessionForAccountProvider(q.account));
  if (s == null) return a.followingPosts;
  final posts = await _applyTrendScopeGraph(ref, s, 'trend.following', 'home', a.followingPosts, selfQuery: tag) ?? a.followingPosts;
  // 指向性/刺激性の既定適用 (D-153)。
  final profile = await ref.watch(tendencyProfileProvider.future);
  return applyTendencyProfile(posts, profile);
});

/// ユーザータブ (D-113): `trend.users` スコープのグラフでタグ投稿を絞って
/// からユーザーランキングを作り直す(鎖が無ければ従来のランキング)。
final trendUsersProvider = FutureProvider.autoDispose.family<List<(UserProfile, int)>, TrendQuery>((ref, q) async {
  final tag = q.tag;
  final a = await ref.watch(trendAnalysisProvider(q).future);
  final s = ref.watch(sessionForAccountProvider(q.account));
  if (s == null) return a.users;
  final filtered = await _applyTrendScopeGraph(ref, s, 'trend.users', 'search:', a.posts, selfQuery: tag);
  if (filtered == null) return a.users;
  final score = <String, int>{};
  for (final p in filtered) {
    score.update(p.author.id, (v) => v + p.reactionTotal, ifAbsent: () => p.reactionTotal);
  }
  final ranked = [for (final u in a.users) if (score.containsKey(u.$1.summary.id)) (u.$1, score[u.$1.summary.id]!)];
  ranked.sort((x, y) => y.$2.compareTo(x.$2));
  return ranked;
});

/// トレンドタイルの並び (D-113 → D-431)。上から:
/// 1. トレンドタイルの構成([trendTilesScope]、カスタマイズの画面で保存したもの)があれば、それをタグの並びに掛ける
///    (軽いアルゴリズムだけ、[applyTrendTilesConfig])。無ければ、前の置き場(トレンド TL と同じ `trend` のグラフ)に
///    「→ トレンド枠」の鎖があればその出力(ノードエディタで組んだもの)。どちらも無ければ SNS のトレンドのまま。
/// 2. 傾向 FOW のプロファイル(指向性 / 刺激性)を**一番最後**に([applyTendencyToTags])。
final trendFrameTagsProvider = FutureProvider.autoDispose<List<TrendTag>>((ref) async {
  final sourced = await ref.watch(sourcedTrendsProvider.future);
  final tags = sourced.tags;
  final accKey = ref.watch(currentAccountProvider)?.key;
  var out = tags;
  try {
    final area = await ref.watch(settingsAreaProvider(nodeprogAreaFor(accKey, trendTilesScope)).future);
    final raw = area['tlcfg'];
    if (raw is String) {
      final cfg = TlConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      // 取得元 (D-440): SNS アカウントごとのトレンド(`trend.tags`)があれば、有効なアカウントのトレンドに出ているワードだけ。
      // 無ければ(前の構成の self)全部。アカウントの表記が空なら、いまのアカウント。
      final from = filterTrendsBySources(sourced, cfg, current: ref.watch(currentAccountProvider));
      out = applyTrendTilesConfig(from, cfg, (t) => t.tag);
    } else {
      out = await _legacyTrendFrame(ref, accKey, tags) ?? tags;
    }
  } catch (e) {
    debugPrint('trend tiles: $e');
  }
  try {
    final profile = await ref.watch(tendencyProfileProvider.future);
    out = applyTendencyToTags(out, (t) => t.tag, profile);
  } catch (e) {
    debugPrint('trend tiles tendency: $e');
  }
  return out;
});

/// トレンドタイルの取得元 (D-440) で絞る: 構成に `trend.tags` があれば(トレンドページのセクションの中も、D-443)、有効なアカウントの
/// トレンドに出ているワードだけ。アカウントの表記が空のものがあれば全部のアカウント(D-443。前は「いまのアカウント」)。
List<TrendTag> filterTrendsBySources(SourcedTrends sourced, TlConfig cfg, {AccountId? current}) {
  final nodes = trendTagsNodesOf(cfg).toList();
  if (nodes.isEmpty) return sourced.tags;
  final enabled = [for (final x in nodes) if (x.enabled) x];
  if (enabled.any((x) => x.account.isEmpty)) return sourced.tags;
  final picked = {for (final x in enabled) x.account};
  bool from(AccountId a) => picked.contains('$a') || picked.contains(a.key);
  return [for (final t in sourced.tags) if ((sourced.sources[trendKey(t.tag)] ?? const <AccountId>[]).any(from)) t];
}

/// 前の置き場(`trend` のグラフの「→ トレンド枠」の鎖)の出力。鎖が無ければ null。
Future<List<TrendTag>?> _legacyTrendFrame(Ref ref, String? accKey, List<TrendTag> tags) async {
  final s = ref.read(currentSnsSessionProvider);
  if (s == null) return null;
  try {
    final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'trend');
    if (raw is! String) return null;
    final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    final custom = await runNodeGraphTexts(
      graph,
      terminal: 'trend.frame',
      fetch: (kid) => resolveNodeFetch(s, kid, kindBlocked: childKindBlocked(ref.read(childGateProvider))),
      fetchTrends: () async => [for (final t in tags) t.tag],
      storageRead: (slot) async {
        final own = (await ref.read(settingsAreaProvider(storageSafeAreaFor(accKey)).future))[slot];
        if (own != null) return own;
        return (await ref.read(settingsAreaProvider('storage.safe').future))[slot];
      },
    );
    if (custom == null) return null;
    final byTag = {for (final t in tags) t.tag: t};
    return [for (final t in custom) byTag[t] ?? TrendTag(tag: t)];
  } catch (e) {
    debugPrint('nodeprog(trend.frame): $e');
    return null;
  }
}

/// 「フォロー中の反応」(D-364): AsTell とリレーショナルタイムラインに**すでにある**もののうち、このワードの話題。
/// - AsTell: フォロー中の人のルーム(タイトル / 要約 / ジャンルにワード)。
/// - リレーショナル TL: ホームの会話イベント(タグ / 特徴語 / 本文にワード)を新しい順に 3 件。
/// どちらも取れなければ空(フォロイーのタグ投稿は [trendFollowingPostsProvider] がそのまま出す)。
typedef TrendFollowingActivity = ({List<AstellRoom> rooms, List<ConversationEvent> events});

String _normTag(String tag) => tag.trim().replaceFirst(RegExp(r'^[#＃]'), '').toLowerCase();

bool astellRoomMatchesTag(AstellRoom r, String tag) {
  final t = _normTag(tag);
  if (t.isEmpty) return false;
  return r.title.toLowerCase().contains(t) || r.description.toLowerCase().contains(t) || r.genres.any((g) => _normTag(g) == t || g.toLowerCase().contains(t));
}

bool conversationMatchesTag(ConversationEvent e, String tag) {
  final t = _normTag(tag);
  if (t.isEmpty) return false;
  return e.anchors.contains('#$t') || e.entities.contains(t) || e.posts.any((p) => p.body.toLowerCase().contains(t));
}

final trendFollowingActivityProvider = FutureProvider.autoDispose.family<TrendFollowingActivity, String>((ref, tag) async {
  final events = [for (final e in ref.watch(conversationEventsProvider).value ?? const <ConversationEvent>[]) if (conversationMatchesTag(e, tag)) e]
    ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  var rooms = const <AstellRoom>[];
  try {
    final home = await ref.watch(astellHomeProvider.future);
    final following = await ref.watch(astellFollowingProvider.future).catchError((_) => <String>{});
    final seen = <String>{};
    rooms = [
      for (final r in [...home.following, ...home.trending, ...home.recommended])
        if ((home.following.contains(r) || following.contains(r.ownerId)) && r.closedAt == null && astellRoomMatchesTag(r, tag) && seen.add(r.id)) r,
    ];
  } catch (_) {
    // AsTell に繋がらない(未設定 / 未ログイン)なら出さない。
  }
  return (rooms: rooms.take(3).toList(), events: events.take(3).toList());
});
