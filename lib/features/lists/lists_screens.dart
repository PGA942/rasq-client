import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../clips/clip_providers.dart';
import '../clips/index_toc.dart';
import '../clips/virtual_index.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../settings/settings_dsl.dart';
import '../users/user_list.dart';

final listsProvider = FutureProvider.autoDispose<List<UserListInfo>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.lists();
});

/// 保存済みのカスタムフィード (D-195): Bluesky など持つ SNS だけ。無ければ空。
final savedFeedsProvider = FutureProvider.autoDispose<List<FeedInfo>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return await s.savedFeeds();
  } catch (_) {
    return const [];
  }
});

final listMembersProvider = FutureProvider.autoDispose.family<List<UserSummary>, String>((ref, id) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  final m = await s.listMembers(id);
  await ref.read(userListHelperProvider).primeRelationships(m.map((u) => u.id));
  return m;
});

/// リストを検索: 検索バー + 自分のリスト(リストタイル: アイコン・名前・#id・フォロー・›).
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});
  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  String _q = '';
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _q = _controller.text.trim().toLowerCase()));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    final manager = ref.watch(overlayManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    // 表示設定(非公開クリップ)は KV `lists.view.v1` に永続化。
    final viewSettings = ref.watch(settingsAreaProvider(listsViewArea)).value ?? const <String, Object?>{};
    final showPrivate = viewSettings['showPrivateClips'] == true;
    // カスタムフィード (D-196): Bluesky は上部メニュー(タブ)で「リスト / カスタムフィード」を切り替える。
    final bluesky = ref.watch(currentSnsSessionProvider)?.account.kind == SnsKind.bluesky;
    final feedsAsync = ref.watch(savedFeedsProvider);
    Widget feedsTab() {
      final feeds = (feedsAsync.value ?? const <FeedInfo>[]).where((f) => _q.isEmpty || f.name.toLowerCase().contains(_q)).toList();
      if (feedsAsync.isLoading) return const RasqLoading();
      if (feeds.isEmpty) return const RasqEmptyView(title: 'カスタムフィードはありません', hint: 'インポートから検索 / URL で追加できます');
      return ListView(children: [for (final f in feeds) ...[_feedRow(context, f), const Divider(height: 1)]]);
    }
    final body = Column(children: [
        // 検索ページと同じ一体型入力欄 (D-026 部品): 下方向に伸びて表示設定
        // チップが入る。非公開クリップは既定で出さない(ここで切替)。
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: RasqExpandableSearchBox(
            expanded: _filterOpen || _focus.hasFocus || showPrivate,
            controller: _controller,
            focusNode: _focus,
            hintText: 'リスト・クリップを検索',
            onDropdownTap: () => setState(() => _filterOpen = !_filterOpen),
            filterChips: [
              RasqFilterChipItem(
                label: '非公開クリップを表示',
                selected: showPrivate,
                onTap: () => ref.read(settingsAreaProvider(listsViewArea).notifier).set('showPrivateClips', !showPrivate),
              ),
            ],
          ),
        ),
        Expanded(
          child: bluesky
              ? TabBarView(children: [_listsBody(context, lists, showPrivate: showPrivate), feedsTab()])
              : _listsBody(context, lists, showPrivate: showPrivate),
        ),
      ]);
    final tabs = [const RasqTabItem('リスト'), const RasqTabItem('カスタムフィード')];
    final scaffold = Scaffold(
      appBar: RasqPageHeader(
        title: 'リスト',
        actions: [RasqIconButton(icon: Icons.download_outlined, onPressed: () => context.push('/lists/import'), tooltip: 'リストのインポート')],
        onMore: () {},
        bottom: bluesky ? RasqTabs(items: tabs) : null,
      ),
      body: body,
      floatingActionButton: bluesky
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final ctrl = TextEditingController();
                final ok = await manager.showBottomSheet<bool>(
                  id: 'lists.create',
                  title: 'リストを作成',
                  confirmText: '作成',
                  builder: (_) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqInput(controller: ctrl, hintText: 'リスト名', autofocus: true)),
                );
                if (ok == true && ctrl.text.trim().isNotEmpty) {
                  await ref.read(currentSnsSessionProvider)?.createList(ctrl.text.trim());
                  ref.invalidate(listsProvider);
                }
              },
              tooltip: 'リストを作成',
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
    );
    return bluesky ? DefaultTabController(length: 2, child: scaffold) : scaffold;
  }

  /// リスト + クリップの一覧(従来の本体)。
  Widget _listsBody(BuildContext context, AsyncValue<List<UserListInfo>> lists, {required bool showPrivate}) {
    final scheme = Theme.of(context).colorScheme;
    return lists.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(listsProvider), retryLabel: '再読み込み'),
            data: (all) {
              final list = all.where((l) => _q.isEmpty || l.name.toLowerCase().contains(_q)).toList();
              // クリップもリスト画面にまとめて出す(D-032: ユーザーページ以外の
              // 入口。詳細はクリップTL)。既定は公開ネイティブのみ — 非公開は
              // 入力欄のフィルタで表示切替、RASQ 横断はブックマーク欄へ。
              final clips = ref.watch(listsClipsProvider).where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q)).toList();
              if (list.isEmpty && clips.isEmpty) return const RasqEmptyView(title: 'リストはありません', hint: '＋でリストを作成できます');
              Widget listRow(UserListInfo l) => InkWell(
                    onTap: () => context.push('/lists/${Uri.encodeComponent(l.id)}', extra: l),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
                      child: Row(children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle), child: const Icon(Icons.list_alt_outlined)),
                        const SizedBox(width: RasqSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.name, style: RasqTypography.displayName),
                            Text('#${l.id}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant)),
                            Text('${l.memberIds.length} ユーザー', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                          ]),
                        ),
                        RasqIconButton(icon: Icons.more_horiz, size: 20, onPressed: () {}, tooltip: 'メニュー'),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  );
              Widget clipRow(ClipInfo c) => InkWell(
                    onTap: () => context.pushClip(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
                      child: Row(children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(c.isHost ? Icons.workspaces_outlined : Icons.collections_bookmark_outlined)),
                        const SizedBox(width: RasqSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: RasqTypography.displayName),
                            Text([if (c.notesCount != null) '${c.notesCount}件', if (c.isHost) 'RASQ(SNS 横断)' else if (!c.isPublic) '非公開クリップ' else 'クリップ'].join(' ・ '), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  );
              return ListView(children: [
                if (clips.isNotEmpty) ...[
                  const RasqSectionHeader(title: 'クリップ', topMargin: 0),
                  for (final c in clips) ...[clipRow(c), const Divider(height: 1)],
                ],
                if (list.isNotEmpty) ...[
                  if (clips.isNotEmpty) const RasqSectionHeader(title: 'リスト', topMargin: RasqSpacing.md),
                  for (final l in list) ...[listRow(l), const Divider(height: 1)],
                ],
              ]);
            },
          );
  }
}

/// カスタムフィードの行 (D-195/196): 名前・作者・♥・説明。タップでフィード TL。
Widget _feedRow(BuildContext context, FeedInfo f) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    key: ValueKey('lists.feed.${f.uri}'),
    onTap: () => context.push(Routes.feed(f.uri), extra: f),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle), child: const Icon(Icons.rss_feed)),
        const SizedBox(width: RasqSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.name, style: RasqTypography.displayName),
            Text([if (f.creator != null) '@${f.creator}', if (f.likeCount != null) '♥ ${f.likeCount}'].join(' ・ '), style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant)),
            if (f.description != null && f.description!.isNotEmpty) Text(f.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        const Icon(Icons.chevron_right),
      ]),
    ),
  );
}

/// リストの中身: ヘッダータイル + tabs ∨ユーザー / 投稿.
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId, this.info});
  final String listId;
  final UserListInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(listMembersProvider(listId));
    final kind = TimelineKind.list(listId, info?.name ?? 'リスト');
    final tl = ref.watch(timelineProvider(kind));
    final notifier = ref.read(timelineProvider(kind).notifier);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final scheme = Theme.of(context).colorScheme;
    final tabs = [const RasqTabItem('ユーザー'), const RasqTabItem('投稿')];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: info?.name ?? 'リスト',
          onMore: () {},
          // リスト TL のカスタマイズ (D-124): TL 系は全部同 UI。デフォルトは
          // このリストの取得ノード(tl.list)から始まる。
          actions: [RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'リストTL設定', onPressed: () => context.push(Routes.tlConfig('tl.list:$listId')))],
          bottom: RasqTabs(items: tabs),
        ),
        body: TabBarView(children: [
          members.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
            data: (m) => m.isEmpty
                ? const RasqEmptyView(title: 'ユーザーはいません')
                : ListView.separated(
                    itemCount: m.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => RasqUserRow(
                      user: m[i],
                      onTap: () => context.pushUser(m[i]),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref.read(currentSnsSessionProvider)?.removeFromList(listId, m[i].id);
                          ref.invalidate(listMembersProvider(listId));
                        },
                        child: Text('外す', style: TextStyle(color: scheme.error)),
                      ),
                      onMore: () {},
                    ),
                  ),
          ),
          tl.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
            data: (s) => s.posts.isEmpty
                ? const RasqEmptyView(title: '投稿はありません')
                : _ListTimelinePosts(posts: s.posts, actions: actions, notifier: notifier),
          ),
        ]),
      ),
    );
  }
}

/// カスタムフィードの TL (D-195): `feed:<uri>` の投稿列。歯車で TL カスタマイズ(スコープ `tl.feed:<uri>`)。
class FeedTimelineScreen extends ConsumerWidget {
  const FeedTimelineScreen({super.key, required this.uri, this.info});
  final String uri;
  final FeedInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = TimelineKind('feed:$uri', info?.name ?? 'フィード');
    final tl = ref.watch(timelineProvider(kind));
    final notifier = ref.read(timelineProvider(kind).notifier);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    return Scaffold(
      appBar: RasqPageHeader(
        title: info?.name ?? 'フィード',
        onMore: () {},
        actions: [RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'フィードTL設定', onPressed: () => context.push(Routes.tlConfig('tl.feed:$uri')))],
      ),
      body: tl.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
        data: (s) => s.posts.isEmpty ? const RasqEmptyView(title: '投稿はありません') : _ListTimelinePosts(posts: s.posts, actions: actions, notifier: notifier),
      ),
    );
  }
}

/// リストTL の投稿列 + 目次「いま話されていること」(D-036: リストは同じ
/// メンバーが複数話題を並行するので、会話イベントをそのまま章にする)。
/// 章タップで絞り込みトグル。単発投稿は 1 つのバケツにまとまる。
class _ListTimelinePosts extends ConsumerStatefulWidget {
  const _ListTimelinePosts({required this.posts, required this.actions, required this.notifier});
  final List<Post> posts;
  final List<ActionDescriptor> actions;
  final TimelineNotifier notifier;

  @override
  ConsumerState<_ListTimelinePosts> createState() => _ListTimelinePostsState();
}

class _ListTimelinePostsState extends ConsumerState<_ListTimelinePosts> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final entries = indexForListTimeline(widget.posts);
    final selected = findIndexEntry(entries, _selected);
    final visible = selected == null ? widget.posts : [for (final p in widget.posts) if (selected.postKeys.contains(p.key)) p];
    return RefreshIndicator(
      onRefresh: widget.notifier.refresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        VirtualIndexToc(entries: entries, selectedId: _selected, onSelect: (id) => setState(() => _selected = id), title: 'いま話されていること', showState: true),
        for (final p in visible) ...[
          PostRow(post: p, actions: widget.actions, onAction: (a, {args = const {}}) => widget.notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
          const Divider(),
        ],
      ]),
    );
  }
}

/// リストのインポート: 検索 + 「ローカルからインポート」 + 履歴.
/// フィードの検索 (D-196: インポートページ)。クエリか URL(at:// / bsky.app)。
final feedSearchProvider = FutureProvider.autoDispose.family<List<FeedInfo>, String>((ref, query) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null || query.trim().isEmpty) return const [];
  try {
    return await s.searchFeeds(query.trim());
  } catch (_) {
    return const [];
  }
});

/// リストのインポート (D-196): Bluesky は **カスタムフィードを検索 / URL を入力** してリストタイルで表示、
/// タップでそのフィードの TL へ。他の SNS は従来(ローカルからのインポートは第二期)。
class ListImportScreen extends ConsumerStatefulWidget {
  const ListImportScreen({super.key});
  @override
  ConsumerState<ListImportScreen> createState() => _ListImportScreenState();
}

class _ListImportScreenState extends ConsumerState<ListImportScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(overlayManagerProvider);
    final tokens = RasqTokens.of(context);
    final bluesky = ref.watch(currentSnsSessionProvider)?.account.kind == SnsKind.bluesky;
    final results = bluesky ? ref.watch(feedSearchProvider(_query)) : const AsyncValue<List<FeedInfo>>.data([]);
    return Scaffold(
      appBar: RasqPageHeader(title: 'リストのインポート', onMore: () {}),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 4),
          child: bluesky
              ? TextField(
                  key: const ValueKey('lists.import.search'),
                  controller: _ctrl,
                  style: RasqTypography.bodySmall,
                  decoration: const InputDecoration(hintText: 'カスタムフィードを検索、または URL(at:// / bsky.app)を入力', isDense: true, prefixIcon: Icon(Icons.search, size: 18)),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => setState(() => _query = v),
                  onChanged: (v) => setState(() => _query = v),
                )
              : const RasqSearchBar(hintText: '検索'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bluesky ? 'フィードを検索するか URL を貼ると、リストタイルで表示します。タップでそのフィードのタイムラインへ。' : 'リストを検索して一括操作を行うことができます。', style: RasqTypography.bodySmall),
            if (!bluesky) TextButton(onPressed: () => manager.showAlert(id: 'lists.import', title: 'ローカルからインポート', message: 'CSV/JSON からのインポートはリスト機能(サーバー側: 第二期)と合わせて実装します。', confirmText: 'OK'), child: Text('ローカルからインポート', style: TextStyle(color: tokens.link))),
          ]),
        ),
        if (bluesky) ...[
          RasqSectionHeader(title: _query.trim().isEmpty ? '人気のフィード' : '検索結果', topMargin: RasqSpacing.sm),
          results.when(
            loading: () => const RasqLoading(),
            error: (_, _) => const RasqEmptyView(title: '見つかりません'),
            data: (items) => items.isEmpty
                ? RasqEmptyView(title: _query.trim().isEmpty ? '検索語か URL を入れてください' : '見つかりません')
                : Column(children: [for (final f in items) ...[_feedRow(context, f), const Divider(height: 1)]]),
          ),
        ] else ...[
          const RasqSectionHeader(title: '履歴', topMargin: 0),
          const RasqEmptyView(title: '履歴はありません'),
        ],
      ]),
    );
  }
}
