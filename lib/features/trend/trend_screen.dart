import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../home/create_fow.dart' show RadialCreateFab;
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/third_column.dart' show paneBack;
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../relational/relational_engine.dart';
import '../relational/relational_timeline_view.dart';
import '../search/search_filter.dart';
import '../search/search_filter_bar_view.dart';
import '../users/user_list.dart';
import '../vc/astell_actions.dart';
import '../vc/astell_tile.dart' show AstellTileStrip;
import 'tendency_fows.dart';
import '../../shell/floating_account_tile.dart';
import 'trend_analysis.dart';
import 'trend_providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView;

/// トレンドTL(検索結果): ∨ノート / フォロー中 / ユーザー.
/// ノート = 「フォロー中の反応」 + 「トレンド」(タグTL)。
///
/// 並び替え/絞り込みは検索フィルタ行(D-021): 検索バーの ∨ でトグル、設定後は
/// 常時表示。関連順は SearchRanker(ルールベース実働 + GLiNER/SigLIP は
/// ml.infer 配線後に有効, D-022)。選択中タブの再タップでも並び替えメニュー。
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key, required this.tag, this.account});
  final String tag;

  /// このアカウント(`AccountId.key`)で開く (D-397): トレンドを出したアカウント / 「別のアカウントで開く」で選んだもの。
  /// null = 現在のアカウント(アカウントを切り替えるとついてくる)。画面の上に浮かべたアカウントのタイル (D-411) で選び直せる。
  final String? account;
  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  final _scroll = ScrollController();
  late final _searchController = TextEditingController(text: widget.tag);

  /// この画面で読んでいるアカウント (D-397 の `account:`)。浮かべたアカウントのタイル (D-411) で選び直すと、タグの TL・分析・
  /// フォロー中・ユーザーをそのアカウントのセッションで読み直す(どれもアカウントごとのプロバイダなので、キーが変わるだけ)。
  late String? _account = widget.account;
  TimelineKind get _kind => DynamicTimelines.tag(widget.tag);
  TrendQuery get _q => (tag: widget.tag, account: _account);
  AsyncNotifierProvider<TimelineNotifier, TimelineState> get _tl => timelineFor(_kind, account: _account);

  @override
  void didUpdateWidget(TrendScreen old) {
    super.didUpdateWidget(old);
    if (old.account != widget.account || old.tag != widget.tag) _account = widget.account;
  }

  /// タイルでアカウントを選んだ。いまのアカウントを選んだら指定を外す(アカウントの切り替えについてくる、D-397 と同じ)。
  void _switchAccount(AccountId account) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _account = account == ref.read(currentAccountProvider) ? null : account.key);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(_tl.notifier).loadMore();
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
    final session = ref.watch(sessionForAccountProvider(_account));
    final actions = session?.actions ?? const [];
    final tl = ref.watch(_tl);
    // ノードグラフ実配線 (D-113): trend.following / trend.users スコープ。
    final following = ref.watch(trendFollowingPostsProvider(_q));
    final activity = ref.watch(trendFollowingActivityProvider(widget.tag)).value;
    final rankedUsers = ref.watch(trendUsersProvider(_q));
    final notifier = ref.read(_tl.notifier);
    final manager = ref.watch(overlayManagerProvider);
    final filter = ref.watch(searchFilterProvider);
    final trends = ref.watch(trendingTagsProvider);
    final genreCandidates = [
      for (final t in trends.value ?? const <TrendTag>[])
        if (t.tag != widget.tag) t.tag,
    ].take(maxGenreChips).toList();
    final opened = _account == null ? null : ref.watch(sessionsProvider).value?.allSessions.where((x) => x.account.key == _account).firstOrNull?.account;
    // 選ぶ一覧の印: このトレンドを出したアカウント (D-388)。
    final sources = ref.watch(sourcedTrendsProvider).value?.sources[trendKey(widget.tag)] ?? const <AccountId>[];
    final tabs = [const RasqTabItem('ノート'), const RasqTabItem('フォロー中'), const RasqTabItem('ユーザー')];

    // チャイルドセーフ (D-307): 検索結果も TL と同じ絞り込み。
    final gate = ref.watch(childGateProvider);
    List<Post> apply(List<Post> posts) => gate.filterPosts(applySearchFilter(posts, filter, query: widget.tag));

    Widget rows(List<Post> posts) => Column(children: [
          for (final p in posts) ...[PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)), const Divider()],
        ]);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // ＋ (D-381): ホームと同じ動き。投稿はこのワードのハッシュタグを入れて開く。
        floatingActionButton: RadialCreateFab(scope: 'trend', heroTag: 'fab.trend', postText: '#${widget.tag.replaceFirst(RegExp(r'^#'), '')} '),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
          // ← でトレンドホームへ戻る。入力欄は編集可能で、そのまま次の検索を
          // 続けられる(submit で結果画面を置き換え)。フィルタは一体型タイル内。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 第3カラムに開いているとき (D-320) は、ほかのページの < と同じくカラムの中で戻る(前が無ければ閉じる)。
              RasqIconButton(
                icon: Icons.arrow_back_ios_new,
                size: 18,
                tooltip: 'トレンドホームへ戻る',
                onPressed: () {
                  if (!paneBack(context)) Navigator.of(context).maybePop();
                },
              ),
              Expanded(
                child: SearchFilterBox(
                  controller: _searchController,
                  genreCandidates: genreCandidates,
                  onSubmitted: (q) {
                    final tag = q.trim().replaceFirst(RegExp(r'^#'), '');
                    if (tag.isNotEmpty && tag != widget.tag) context.replaceTrend(tag, account: _account);
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
            // トレンドもタイムラインと同じ (D-090/D-103): RAi は TL のタブ行
            // では隠し、ノード設定だけ置く。
            // TL 系は全部同 UI (D-124): 簡略版カスタマイズ画面へ。
            RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'トレンド設定', onPressed: () => showTrendProfileSheet(context, ref)),
          ]),
          Expanded(
            child: Stack(children: [
            Positioned.fill(child: TabBarView(children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trendAnalysisProvider(_q));
                  ref.invalidate(trendFollowingPostsProvider(_q));
                  ref.invalidate(trendFollowingActivityProvider(widget.tag));
                  ref.invalidate(trendUsersProvider(_q));
                  await notifier.refresh();
                },
                child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), children: [
                  const RasqSectionHeader(title: 'フォロー中の反応', topMargin: 0),
                  // AsTell / リレーショナル TL にすでにあるこのワードの話題 (D-364) → フォロイーのタグ投稿。
                  ...[
                    // タイルは高さの決まった帯に並べる (D-376): 縦のリストに直に置くと高さが決まらず、スクロールで戻ったときに
                    // レイアウトが壊れて戻るボタンが効かなくなっていた。
                    if (activity?.rooms.isNotEmpty ?? false) AstellTileStrip(key: const ValueKey('trend.following.rooms'), rooms: activity!.rooms, tileBuilder: (r) => AstellRoomTile(room: r)),
                    for (final e in activity?.events ?? const <ConversationEvent>[]) RelationalEventCard(key: ValueKey('trend.following.event.${e.id}'), event: e),
                  ],
                  following.when(
                    loading: () => const RasqLoading(),
                    error: (_, _) => const SizedBox(height: 48),
                    data: (fp) {
                      final posts = apply(fp).take(3).toList();
                      if (posts.isNotEmpty) return rows(posts);
                      final none = (activity?.rooms.isEmpty ?? true) && (activity?.events.isEmpty ?? true);
                      return none ? const RasqCaption('フォロー中の人の反応はまだありません', key: ValueKey('trend.following.empty')) : const SizedBox.shrink();
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
              following.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (fp) {
                  final posts = apply(fp);
                  return posts.isEmpty
                      ? const RasqEmptyView(title: 'フォロー中の投稿はありません', hint: 'このワードについてフォロイーはまだ投稿していません')
                      : ListView(children: [rows(posts)]);
                },
              ),
              if (!gate.searchAllowed('users'))
                const ChildSafeBlockedView(message: '保護者がユーザーの検索を止めています')
              else
              rankedUsers.when(
                loading: () => const RasqLoading(),
                error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
                data: (users) {
                  // ユーザーはリアクション合計順(古い順のみ昇順に反転)。
                  final ranked = [...users]..sort((x, y) => filter.sort == SearchSort.oldest ? x.$2.compareTo(y.$2) : y.$2.compareTo(x.$2));
                  return ranked.isEmpty
                      ? const RasqEmptyView(title: 'ユーザーはいません')
                      : UserList(users: [for (final e in ranked) e.$1.summary], subtitles: {for (final e in ranked) e.$1.summary.id: 'リアクション ${e.$2}'});
                },
              ),
            ])),
            // どのアカウントで読んでいるか (D-411、D-397 のサーバーの印をまとめた): 既定で出す。タップで別のアカウントに切り替える。
            // 左下(右下の ＋ と反対側)。上に置くと投稿の右上の「…」に重なる。
            Positioned(
              left: RasqSpacing.sm,
              bottom: RasqSpacing.md,
              child: FloatingAccountTile(key: const ValueKey('trend.accountTile'), id: 'trend.accountTile', account: opened, marked: sources, markLabel: 'トレンドに出したアカウント', onPick: _switchAccount),
            ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}
