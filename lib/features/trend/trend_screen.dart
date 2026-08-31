import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../search/search_filter.dart';
import '../search/search_filter_bar_view.dart';
import '../users/user_list.dart';
import 'trend_analysis.dart';
import 'trend_providers.dart';

/// トレンドTL(検索結果): ∨ノート / フォロー中 / ユーザー.
/// ノート = 「フォロー中の反応」 + 「トレンド」(タグTL)。
///
/// 並び替え/絞り込みは検索フィルタ行(D-021): 検索バーの ∨ でトグル、設定後は
/// 常時表示。関連順は SearchRanker(ルールベース実働 + GLiNER/SigLIP は
/// ml.infer 配線後に有効, D-022)。選択中タブの再タップでも並び替えメニュー。
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key, required this.tag});
  final String tag;
  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  final _scroll = ScrollController();
  late final _searchController = TextEditingController(text: widget.tag);
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const [];
    final tl = ref.watch(timelineProvider(_kind));
    final analysis = ref.watch(trendAnalysisProvider(widget.tag));
    final notifier = ref.read(timelineProvider(_kind).notifier);
    final manager = ref.watch(overlayManagerProvider);
    final filter = ref.watch(searchFilterProvider);
    final trends = ref.watch(trendingTagsProvider);
    final genreCandidates = [
      for (final t in trends.value ?? const <TrendTag>[])
        if (t.tag != widget.tag) t.tag,
    ].take(maxGenreChips).toList();
    final tabs = [const RasqTabItem('ノート'), const RasqTabItem('フォロー中'), const RasqTabItem('ユーザー')];

    List<Post> apply(List<Post> posts) => applySearchFilter(posts, filter, query: widget.tag);

    Widget rows(List<Post> posts) => Column(children: [
          for (final p in posts) ...[PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)), const Divider()],
        ]);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
          // ← でトレンドホームへ戻る。入力欄は編集可能で、そのまま次の検索を
          // 続けられる(submit で結果画面を置き換え)。フィルタは一体型タイル内。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, tooltip: 'トレンドホームへ戻る', onPressed: () => Navigator.of(context).maybePop()),
              Expanded(
                child: SearchFilterBox(
                  controller: _searchController,
                  genreCandidates: genreCandidates,
                  onSubmitted: (q) {
                    final tag = q.trim().replaceFirst(RegExp(r'^#'), '');
                    if (tag.isNotEmpty && tag != widget.tag) context.replaceTrend(tag);
                  },
                ),
              ),
            ]),
          ),
          Row(children: [
            Expanded(
              child: RasqTabs(
                items: tabs,
                onSelectedTabTap: (i, rect) async {
                  final s = await showSearchSortMenu(manager, rect, filter.sort);
                  if (s != null) ref.read(searchFilterProvider.notifier).set(filter.copyWith(sort: s));
                },
              ),
            ),
            // トレンドもタイムラインと同じ (D-090): RAi + ノード設定。
            RasqIconButton(icon: Icons.smart_toy_outlined, size: 20, onPressed: () {}, tooltip: 'RAi(準備中)'),
            RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'トレンド設定', onPressed: () => context.push(Routes.nodes('trend'))),
          ]),
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
                    data: (a) {
                      final posts = apply(a.followingPosts).take(3).toList();
                      return posts.isEmpty ? const SizedBox(height: 48) : rows(posts);
                    },
                  ),
                  const RasqSectionHeader(title: 'トレンド', topMargin: 0),
                  tl.when(
                    loading: () => const RasqLoading(),
                    error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
                    data: (s) {
                      final posts = apply(s.posts);
                      return posts.isEmpty
                          ? const RasqEmptyView(title: 'なんにもないようです', hint: 'ワードやフィルタを変えると見つかるかもしれません')
                          : Column(children: [rows(posts), if (s.loadingMore) const RasqLoading()]);
                    },
                  ),
                ]),
              ),
              analysis.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (a) {
                  final posts = apply(a.followingPosts);
                  return posts.isEmpty
                      ? const RasqEmptyView(title: 'フォロー中の投稿はありません', hint: 'このワードについてフォロイーはまだ投稿していません')
                      : ListView(children: [rows(posts)]);
                },
              ),
              analysis.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (a) {
                  // ユーザーはリアクション合計順(古い順のみ昇順に反転)。
                  final ranked = [...a.users]..sort((x, y) => filter.sort == SearchSort.oldest ? x.$2.compareTo(y.$2) : y.$2.compareTo(x.$2));
                  return ranked.isEmpty
                      ? const RasqEmptyView(title: 'ユーザーはいません')
                      : UserList(users: [for (final e in ranked) e.$1.summary], subtitles: {for (final e in ranked) e.$1.summary.id: 'リアクション ${e.$2}'});
                },
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}
