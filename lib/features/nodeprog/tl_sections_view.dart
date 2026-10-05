import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../relational/relational_engine.dart';
import '../relational/relational_providers.dart' show relationalSettingsProvider;
import '../relational/relational_timeline_view.dart' show RelationalEventCard;
import '../search/search_screen.dart' show TrendTile;
import '../swing/swing_banner.dart';
import '../swing/swing_models.dart';
import '../swing/swing_providers.dart';
import '../trend/trend_providers.dart' show sourcedTrendsProvider, trendFollowingPostsProvider, trendKey;
import '../users/user_list.dart';
import '../vc/astell_actions.dart' show AstellRoomTile;
import '../vc/astell_providers.dart' show astellHomeProvider;
import '../vc/astell_tile.dart' show AstellTileStrip;
import '../vc/vc_screen.dart' show searchAstellRooms;
import 'node_tabs.dart';
import 'tl_components.dart';
import 'tl_config_store.dart';

/// 画面の並び (D-442): TL のカスタマイズの「SNSタイムライン」の並びの順に、
/// - **セクション**(見出し + 中のノードを入れた順に続けて。枠は無し、D-444)、
/// - **ブロック**(AsTell のタイル / Swing / トレンドのタイル。並びにそのまま置いたもの)、
/// - **本体の TL**(セクションの外の TL ノードを 1 本にまとめたもの。最初の TL ノードの位置。続きを読む / 新しい投稿も読む)
/// を出す。TL ノードが 1 つも無ければ本体は出さない。構成が無ければ本体だけ(これまでどおり)。
///
/// セクションの中の TL ノードは**新しい投稿を読み込まない**(開いたときの投稿を写して件数まで。引き下げ / 枠の ↻ で読み直す)。
/// AsTell / Swing / トレンドは「いま」のもの。トレンド TL では、AsTell / Swing / フォロー中の反応はページのワード / タグに当たるものだけ。

/// 本体の TL の前 / 後ろに出すもの。
typedef TlPageLayout = ({List<TlSourceComponent> before, bool main, List<TlSourceComponent> after});

TlPageLayout tlPageLayout(TlConfig? cfg) {
  if (cfg == null) return (before: const [], main: true, after: const []);
  final before = <TlSourceComponent>[];
  final after = <TlSourceComponent>[];
  var seenMain = false;
  for (final s in cfg.sources) {
    if (!s.enabled) continue;
    if (!s.isBlock) {
      seenMain = true;
    } else {
      (seenMain ? after : before).add(s);
    }
  }
  return (before: before, main: seenMain, after: after);
}

/// セクションを読み直す合図(引き下げで進める)。
class TlSectionsRefresh extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final tlSectionsRefreshProvider = NotifierProvider<TlSectionsRefresh, int>(TlSectionsRefresh.new);

/// ノードの名前(セクションの見出しが無いとき / 編集画面)。
String tlNodeLabel(WidgetRef ref, TlSourceComponent s) {
  if (s.isSection) return s.label.isEmpty ? 'セクション' : s.label;
  if (s.isAstell) return 'AsTell のタイル';
  if (s.isSwing) return 'Swing';
  if (s.isTrendTags) return 'トレンド';
  if (s.isTrendFollowing) return 'フォロー中の反応';
  if (s.tl.startsWith('node:')) return ref.watch(nodeTabsProvider).where((t) => t.id == s.tl).firstOrNull?.label ?? 'ノード TL';
  final kinds = ref.watch(currentSnsSessionProvider)?.timelines ?? const <TimelineKind>[];
  return kinds.where((k) => k.id == s.tl).firstOrNull?.label ?? switch (s.tl) {
        'home' => TimelineKind.home.label,
        'local' => TimelineKind.local.label,
        'social' => TimelineKind.social.label,
        'global' => TimelineKind.global.label,
        'featured' => 'Today',
        _ => s.tl,
      };
}

/// 並びのセクション / ブロックを順に。
class TlBlocks extends StatelessWidget {
  const TlBlocks({super.key, required this.nodes, this.query, this.trends, this.headerTrailing});
  final List<TlSourceComponent> nodes;

  /// このページの検索ワード / タグ(トレンド TL)。
  final String? query;

  /// トレンドのタイルに出すワード(トレンドページ、D-443: 通報 / 運営の制限 / 構成のアルゴリズム / 傾向を掛けたもの)。
  /// null なら SNS のトレンドのまま。
  final AsyncValue<List<TrendTag>>? trends;

  /// 見出しの右に足す部品(並びの番号ごと。トレンドページの先頭に設定のボタン)。
  final Widget? Function(int index)? headerTrailing;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < nodes.length; i++)
        TlNodeBlock(key: ValueKey('tl.block.$i.${nodes[i].tl}'), node: nodes[i], query: query, trends: trends, trailing: headerTrailing?.call(i)),
    ]);
  }
}

/// [scope] の構成の、本体の TL の前([after] なら後ろ)のセクション / ブロック。
class TlScopeBlocks extends ConsumerWidget {
  const TlScopeBlocks({super.key, required this.scope, this.after = false, this.query, this.fallback});
  final String scope;
  final bool after;
  final String? query;

  /// 構成が無いときに使う既定(トレンド TL は既定にセクションがある)。
  final TlConfig? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = tlPageLayout(ref.watch(tlViewConfigProvider(scope)) ?? fallback);
    return TlBlocks(key: ValueKey('tl.blocks.$scope.${after ? 'after' : 'before'}'), nodes: after ? layout.after : layout.before, query: query);
  }
}

/// 並びの 1 つ: セクションなら見出し + 中のノード(入れた順に続けて)、ほかは見出し + 中身。
class TlNodeBlock extends ConsumerWidget {
  const TlNodeBlock({super.key, required this.node, this.query, this.trends, this.trailing});
  final TlSourceComponent node;
  final String? query;
  final AsyncValue<List<TrendTag>>? trends;

  /// 見出しの右に足す部品。
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!node.isSection) {
      final content = TlNodeContent(node: node, query: query, trends: trends);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RasqSectionHeader(title: tlNodeLabel(ref, node), topMargin: 0, trailing: trailing),
        content,
        const Divider(height: 1),
      ]);
    }
    final children = [for (final c in node.children) if (c.enabled) c];
    return Column(key: ValueKey('tl.section.${node.label}'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(
        title: tlNodeLabel(ref, node),
        topMargin: 0,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ?trailing,
          RasqIconButton(icon: Icons.refresh, size: 18, tooltip: '読み直す', onPressed: () => ref.read(tlSectionsRefreshProvider.notifier).bump()),
        ]),
      ),
      // 中のノードは入れた順に、枠なしで続けて出す (D-444。D-442 では 1 つずつ角丸の枠に入れていた)。
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        KeyedSubtree(key: ValueKey('tl.section.${node.label}.$i'), child: TlNodeContent(node: children[i], query: query, trends: trends)),
      ],
      const Divider(height: 1),
    ]);
  }
}

/// ノードの中身(種類ごと)。
class TlNodeContent extends ConsumerWidget {
  const TlNodeContent({super.key, required this.node, this.query, this.trends});
  final TlSourceComponent node;
  final String? query;

  /// トレンドのタイルに出すワード([TlBlocks.trends])。null なら SNS のトレンドのまま。
  final AsyncValue<List<TrendTag>>? trends;

  String get _q => (query ?? '').replaceFirst(RegExp(r'^#'), '');

  static Widget _loading() => const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = node;
    final q = _q;
    if (s.isAstell) {
      // チャイルドセーフ: AsTell に入れないアカウントには出さない。
      if (!ref.watch(childGateProvider).featureAllowed('astell.join')) return const SizedBox.shrink();
      final home = ref.watch(astellHomeProvider);
      if (home.value == null) return home.hasError ? const RasqCaption('読み込めませんでした') : _loading();
      final rooms = searchAstellRooms(home.value!, q).take(s.limit).toList();
      if (rooms.isEmpty) return RasqCaption(q.isEmpty ? 'いま開いている AsTell はありません' : '「$q」の AsTell はありません');
      return AstellTileStrip(key: const ValueKey('tl.node.astell'), rooms: rooms, tileBuilder: (r) => AstellRoomTile(room: r));
    }
    if (s.isSwing) {
      final feed = ref.watch(swingFeedProvider).value ?? const <Swing>[];
      final entries = (q.isEmpty ? swingAuthorsOf(feed) : searchSwingAuthors(feed, q)).take(s.limit).toList();
      if (entries.isEmpty) return RasqCaption(q.isEmpty ? 'いま Swing はありません' : '「$q」の Swing はありません');
      return Column(key: const ValueKey('tl.node.swing'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final e in entries) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, 0), child: SwingBanner(entry: e)),
      ]);
    }
    if (s.isTrendTags) {
      final sourced = ref.watch(sourcedTrendsProvider);
      final v = sourced.value;
      if (v == null) return sourced.hasError ? const RasqCaption('読み込めませんでした') : _loading();
      final given = trends;
      if (given != null && !given.hasValue) return given.hasError ? const RasqCaption('読み込めませんでした') : _loading();
      // アカウントの表記が空 = 全部のアカウントのトレンド。
      final who = s.account.isEmpty ? null : s.account;
      final tags = [
        for (final t in given?.value ?? v.tags)
          if (who == null || (v.sources[trendKey(t.tag)] ?? const <AccountId>[]).any((a) => '$a' == who || a.key == who)) t,
      ].take(s.limit).toList();
      if (tags.isEmpty) return const RasqCaption('トレンドはまだありません');
      return Column(key: const ValueKey('tl.node.trend'), mainAxisSize: MainAxisSize.min, children: [for (final t in tags) TrendTile(trend: t)]);
    }
    if (s.isTrendFollowing) {
      if (q.isEmpty) return const RasqCaption('トレンド TL で出ます');
      final posts = ref.watch(trendFollowingPostsProvider((tag: query!, account: null)));
      final v = posts.value;
      if (v == null) return posts.hasError ? const RasqCaption('読み込めませんでした') : _loading();
      if (v.isEmpty) return const RasqCaption('フォロー中の人の反応はまだありません', key: ValueKey('trend.following.empty'));
      return TlPostsDisplay(posts: v, mode: s.display, limit: s.limit, scrollable: false, kind: TimelineKind.home);
    }
    return _TlSnapshot(key: ValueKey('tl.node.tl.${s.tl}'), node: s);
  }
}

/// セクションの中の TL ノード: 開いたときの投稿を写し、新しい投稿は読み込まない(引き下げ / 枠の ↻ で読み直す)。
class _TlSnapshot extends ConsumerStatefulWidget {
  const _TlSnapshot({super.key, required this.node});
  final TlSourceComponent node;

  @override
  ConsumerState<_TlSnapshot> createState() => _TlSnapshotState();
}

class _TlSnapshotState extends ConsumerState<_TlSnapshot> {
  List<Post>? _snapshot;
  int _tick = 0;

  TimelineKind get _kind => TimelineKind(widget.node.tl, widget.node.tl);

  @override
  void didUpdateWidget(_TlSnapshot old) {
    super.didUpdateWidget(old);
    if (old.node.tl != widget.node.tl) _snapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(tlSectionsRefreshProvider);
    if (tick != _tick) {
      _tick = tick;
      _snapshot = null;
      Future.microtask(() {
        if (mounted) ref.read(timelineProvider(_kind).notifier).refresh();
      });
    }
    final tl = ref.watch(timelineProvider(_kind));
    if (_snapshot == null && tl.hasValue && !tl.isLoading) _snapshot = tl.requireValue.posts;
    final posts = _snapshot;
    if (posts == null) return tl.hasError ? const RasqCaption('読み込めませんでした') : TlNodeContent._loading();
    if (posts.isEmpty) return const RasqCaption('まだありません');
    return TlPostsDisplay(posts: posts, mode: widget.node.display, limit: widget.node.limit, scrollable: false, kind: _kind);
  }
}

/// 投稿の並びを表示モードで描く。[limit] = 出す数(投稿 / 会話 / 人)。[scrollable] = false なら外のリストに埋め込む。
class TlPostsDisplay extends ConsumerWidget {
  const TlPostsDisplay({super.key, required this.posts, required this.mode, this.limit, this.scrollable = true, required this.kind});
  final List<Post> posts;
  final TlDisplayMode mode;
  final int? limit;
  final bool scrollable;

  /// 投稿へのアクション(リアクションなど)を送る TL。
  final TimelineKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(childGateProvider).filterPosts(posts);
    final children = switch (mode) {
      TlDisplayMode.timeline => _posts(context, ref, shown),
      TlDisplayMode.relational => _events(ref, shown),
      TlDisplayMode.users => _users(shown),
    };
    if (scrollable) return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 80), children: children);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  List<Widget> _posts(BuildContext context, WidgetRef ref, List<Post> shown) {
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(kind).notifier);
    return [
      for (final p in limit == null ? shown : shown.take(limit!)) ...[
        PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
        const Divider(),
      ],
    ];
  }

  /// 関連 TL の形: 並びの投稿から会話のまとまりを組む(関連 TL と同じエンジン、ゲストなし)。
  List<Widget> _events(WidgetRef ref, List<Post> shown) {
    final events = ConversationEngine(settings: ref.watch(relationalSettingsProvider)).build(followeePosts: shown, guestPosts: const []);
    if (events.isEmpty) return const [RasqCaption('会話のまとまりはまだありません')];
    return [
      for (final e in limit == null ? events : events.take(limit!)) ...[RelationalEventCard(key: ValueKey('tl.display.event.${e.id}'), event: e), const Divider()],
    ];
  }

  /// 投稿した人の並び(投稿の多い順、同じなら新しい順)。
  List<Widget> _users(List<Post> shown) {
    final count = <String, int>{};
    final users = <String, UserSummary>{};
    for (final p in shown) {
      count[p.author.key] = (count[p.author.key] ?? 0) + 1;
      users.putIfAbsent(p.author.key, () => p.author);
    }
    final order = users.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    final picked = [for (final k in limit == null ? order : order.take(limit!)) users[k]!];
    if (picked.isEmpty) return const [RasqCaption('まだいません')];
    return [UserList(key: const ValueKey('tl.display.users.list'), users: picked, shrinkWrap: true, subtitles: {for (final u in picked) u.id: '${count[u.key]} 件の投稿'})];
  }
}

