import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/sort_menu.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../users/user_list.dart';
import 'trend_analysis.dart';

/// トレンドTL(検索結果): ∨ノート / フォロー中 / ユーザー.
/// ノート = 「フォロー中の反応」(フォロイーの投稿をリアクション順) + 「トレンド」(タグTL).
/// フォロー中 = フォロイーの投稿一覧。ユーザー = リアクション数順のユーザータイル.
/// 選択中タブをもう一度タップ → ソートメニュー(リアクション数 昇順/降順/デフォルト).
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key, required this.tag});
  final String tag;
  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  final _scroll = ScrollController();
  RasqSortOrder _order = RasqSortOrder.defaultOrder;
  TimelineKind get _kind => DynamicTimelines.tag(widget.tag);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(timelineProvider(_kind).notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const [];
    final tl = ref.watch(timelineProvider(_kind));
    final analysis = ref.watch(trendAnalysisProvider(widget.tag));
    final notifier = ref.read(timelineProvider(_kind).notifier);
    final manager = ref.watch(overlayManagerProvider);
    final tabs = [const RasqTabItem('ノート'), const RasqTabItem('フォロー中'), const RasqTabItem('ユーザー')];

    Widget rows(List<Post> posts) => Column(children: [
          for (final p in posts) ...[PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)), const Divider()],
        ]);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqSearchHeader(
          me: me,
          onAvatarTap: () => RasqShell.openSidebar(context, ref),
          controller: TextEditingController(text: widget.tag),
          readOnly: true,
          onSearchTap: () => Navigator.of(context).maybePop(),
        ),
        body: Column(children: [
          RasqTabs(
            items: tabs,
            onSelectedTabTap: (i, rect) async {
              final o = await showSortMenu(manager, rect, _order, id: 'trend');
              if (o != null) setState(() => _order = o);
            },
          ),
          Expanded(
            child: TabBarView(children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trendAnalysisProvider(widget.tag));
                  await notifier.refresh();
                },
                child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), children: [
                  const RasqSectionHeader(title: 'フォロー中の反応', topMargin: 0),
                  analysis.when(
                    loading: () => const RasqLoading(),
                    error: (_, _) => const SizedBox(height: 48),
                    data: (a) => a.followingPosts.isEmpty ? const SizedBox(height: 48) : rows(sortByReactions(a.followingPosts.take(3).toList(), _order, (p) => p.reactionTotal)),
                  ),
                  const RasqSectionHeader(title: 'トレンド', topMargin: 0),
                  tl.when(
                    loading: () => const RasqLoading(),
                    error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
                    data: (s) => s.posts.isEmpty
                        ? const RasqEmptyView(title: 'なんにもないようです', hint: 'ワードを変えると見つかるかもしれません')
                        : Column(children: [rows(sortByReactions(s.posts, _order, (p) => p.reactionTotal)), if (s.loadingMore) const RasqLoading()]),
                  ),
                ]),
              ),
              analysis.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (a) => a.followingPosts.isEmpty
                    ? const RasqEmptyView(title: 'フォロー中の投稿はありません', hint: 'このワードについてフォロイーはまだ投稿していません')
                    : ListView(children: [rows(sortByReactions(a.followingPosts, _order, (p) => p.reactionTotal))]),
              ),
              analysis.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (a) {
                  final ranked = sortByReactions(a.users, _order == RasqSortOrder.defaultOrder ? RasqSortOrder.reactionsDesc : _order, (e) => e.$2);
                  return ranked.isEmpty
                      ? const RasqEmptyView(title: 'ユーザーはいません')
                      : UserList(users: [for (final e in ranked) e.$1.summary], subtitles: {for (final e in ranked) e.$1.summary.id: 'リアクション ${e.$2}'});
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
