import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'list_member_picker.dart';
import 'topic_toc.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_collections_api.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart' show fowColumnOf;
import '../child_safe/child_safe_collections.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView;
import '../clips/clip_providers.dart';
import '../clips/index_toc.dart';
import '../clips/virtual_index.dart';
import '../collections/rasq_collection_tile.dart';
import '../collections/rasq_collections.dart';
import '../collections/rasq_list_picker.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../home/action_bundle_fow.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../home/timeline_search.dart';
import '../nodeprog/tl_components.dart';
import '../nodeprog/timeline_temp_fow.dart';
import '../nodeprog/tl_config_store.dart';
import '../settings/settings_dsl.dart';
import '../users/user_list.dart';

/// メンバーの id を返さないプラグイン(Mastodon / Bluesky の wasm は `memberIds: []`)のリストは、一覧の人数が
/// 「0 ユーザー」になっていた(REC-06、2026-09-28 録画: 一覧 0 人・詳細 3 人)。空のものだけメンバーを取りに行って埋める。
Future<List<UserListInfo>> withMemberIds(SnsSession s, List<UserListInfo> lists) async => [
      for (final l in await Future.wait([
        for (final l in lists)
          l.memberIds.isNotEmpty
              ? Future.value(l)
              : s.listMembers(l.id).then(
                    (m) => UserListInfo(id: l.id, name: l.name, memberIds: [for (final u in m) u.id], owner: l.owner, description: l.description, isPublic: l.isPublic),
                    onError: (Object _) => l,
                  ),
      ]))
        l,
    ];

final listsProvider = FutureProvider.autoDispose<List<UserListInfo>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  final lists = await withMemberIds(s, await s.lists());
  // チャイルドセーフ (D-314): 保護者の止める例に近い中身のリストは出さない(中身を確かめ終わってから出す)。
  final gate = ref.watch(childGateProvider);
  if (!gate.hasDenyExamples) return lists;
  final hidden = await ref.watch(childSafeHiddenCollectionsProvider.future);
  return [for (final l in lists) if (!childSafeCollectionHidden(gate, hidden, kind: 'list', id: l.id, name: l.name, description: l.description)) l];
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

/// アカウントごとのリスト (D-349)。null = 現在のアカウント。チャイルドセーフ (D-314) の絞り込みは [listsProvider] と同じ。
final listsForAccountProvider = FutureProvider.autoDispose.family<List<UserListInfo>, String?>((ref, key) async {
  final s = ref.watch(sessionForAccountProvider(key));
  if (s == null) return const [];
  final List<UserListInfo> lists;
  try {
    lists = await withMemberIds(s, await s.lists());
  } on UnsupportedError {
    return const [];
  }
  final gate = ref.watch(childGateProvider);
  if (!gate.hasDenyExamples) return lists;
  final hidden = await ref.watch(childSafeHiddenCollectionsProvider.future);
  return [for (final l in lists) if (!childSafeCollectionHidden(gate, hidden, kind: 'list', id: l.id, name: l.name, description: l.description)) l];
});

/// アカウントごとのネイティブクリップ (D-349)。持たない SNS は空。
final clipsForAccountProvider = FutureProvider.autoDispose.family<List<ClipInfo>, String?>((ref, key) async {
  final s = ref.watch(sessionForAccountProvider(key));
  if (s == null) return const [];
  final List<ClipInfo> clips;
  try {
    clips = await s.clips();
  } catch (_) {
    return const [];
  }
  // チャイルドセーフ (D-314): 止める例に近い中身のクリップは出さない(リストと同じ)。
  final gate = ref.watch(childGateProvider);
  if (!gate.hasDenyExamples) return clips;
  final hidden = await ref.watch(childSafeHiddenCollectionsProvider.future);
  return [for (final c in clips) if (!childSafeCollectionHidden(gate, hidden, kind: 'clip', id: c.id, name: c.name, description: c.description)) c];
});

/// アカウントごとの保存済みカスタムフィード (D-349)。持たない SNS は空。
final savedFeedsForAccountProvider = FutureProvider.autoDispose.family<List<FeedInfo>, String?>((ref, key) async {
  final s = ref.watch(sessionForAccountProvider(key));
  if (s == null) return const [];
  try {
    return await s.savedFeeds();
  } catch (_) {
    return const [];
  }
});

/// リストの画面のタブ (D-349): すべて / アカウントごと / RASQ。
const listsTabAll = 'all';
const listsTabRasq = 'rasq';

/// リストの画面: 上にタイムラインのタブ行と同じタブ(**すべて / アカウントごと / RASQ**、D-349)、その下に検索欄、
/// 中身 = そのタブのリスト / クリップ / カスタムフィード(Bluesky)/ RASQ リスト。
/// **別のアカウントのリストを開くときは、そのアカウントに切り替えてから**開く(リストの画面は現在のアカウントのセッションで動く)。
/// 右下の + = 作成先を選ぶ FOW(アクションバンドルと同じ見た目: SNS のアカウントごと / RASQ リスト、D-349)。
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
  final _fabKey = GlobalKey();

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

  /// タブの名前: `@handle`。同じ handle が 2 つあれば `@handle@instance`。
  static String _tabLabel(AccountSession s, List<AccountSession> all) {
    final dup = all.where((x) => x.account.handle == s.account.handle).length > 1;
    return dup ? '${s.account}' : '@${s.account.handle}';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final current = ref.watch(currentAccountProvider)?.key;
    final hasRasq = ref.watch(hasRasqAccountProvider);
    // 表示設定(非公開クリップ)は KV `lists.view.v1` に永続化。
    final viewSettings = ref.watch(settingsAreaProvider(listsViewArea)).value ?? const <String, Object?>{};
    final showPrivate = viewSettings['showPrivateClips'] == true;
    final tabIds = [listsTabAll, for (final s in sessions) s.account.key, if (hasRasq) listsTabRasq];
    final tabs = [
      const RasqTabItem('すべて', id: listsTabAll, chevron: false),
      for (final s in sessions) RasqTabItem(_tabLabel(s, sessions), id: s.account.key, chevron: false),
      if (hasRasq) const RasqTabItem('RASQ', id: listsTabRasq, chevron: false),
    ];
    final initial = current == null ? 0 : tabIds.indexOf(current).clamp(0, tabIds.length - 1);
    final search = Padding(
      // 検索ページと同じ一体型入力欄 (D-026 部品): 下方向に伸びて表示設定チップが入る。非公開クリップは既定で出さない(ここで切替)。
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
    );
    return DefaultTabController(
      // アカウントが増減したら作り直す(タブの数が変わる)。
      key: ValueKey('lists.tabs.${tabIds.join('|')}'),
      length: tabIds.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: 'リスト',
          actions: [RasqIconButton(icon: Icons.download_outlined, onPressed: () => context.push('/lists/import'), tooltip: 'リストのインポート')],
          onMore: () {},
          bottom: RasqTabs(key: const ValueKey('lists.tabs'), items: tabs, showChevron: false),
        ),
        body: Column(children: [
          search,
          Expanded(
            child: TabBarView(children: [
              for (final id in tabIds)
                _ListsTabBody(
                  key: ValueKey('lists.tab.$id'),
                  tab: id,
                  sessions: sessions,
                  query: _q,
                  showPrivate: showPrivate,
                  labelOf: (s) => '${s.account}',
                ),
            ]),
          ),
        ]),
        floatingActionButton: FloatingActionButton(
        // 画面ごとに違う Hero のタグ (D-374): 既定のタグは、タブの画面が同じルームに並ぶと重なる。
        heroTag: 'fab.lists',
          key: _fabKey,
          onPressed: () => _create(sessions, hasRasq),
          tooltip: 'リストを作成',
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// 作成先を選ぶ FOW (D-349): アクションバンドルと同じ見た目(ボタンから出現)。SNS のアカウントごと + RASQ リスト。
  Future<void> _create(List<AccountSession> sessions, bool hasRasq) async {
    final manager = ref.read(overlayManagerProvider);
    final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
    final picked = await showBundleMenuFow<String>(
      manager,
      id: 'lists.create.target',
      title: 'リストを作成',
      anchor: anchor,
      column: fowColumnOf(context),
      keyOf: (v) => v,
      items: [
        for (final s in sessions) BundleMenuItem(value: s.account.key, label: '${s.account} のリスト', icon: Icons.list_alt_outlined),
        if (hasRasq) const BundleMenuItem(value: listsTabRasq, label: 'RASQ リスト(SNS 横断)', icon: Icons.people_alt_outlined),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == listsTabRasq) {
      final c = await showCreateRasqListSheet(ref);
      if (c != null && mounted) context.push(Routes.rasqCollection(c.code ?? c.id));
      return;
    }
    final account = sessions.where((s) => s.account.key == picked).firstOrNull;
    if (account == null) return;
    final ctrl = TextEditingController();
    final ok = await manager.showBottomSheet<bool>(
      id: 'lists.create',
      title: '${account.account} のリスト',
      confirmText: '作成',
      builder: (_) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqInput(controller: ctrl, hintText: 'リスト名', autofocus: true)),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    try {
      await ref.read(sessionForAccountProvider(account.account.key))?.createList(ctrl.text.trim());
      ref.invalidate(listsForAccountProvider(account.account.key));
      ref.invalidate(listsProvider);
      messenger?.showSnackBar(SnackBar(content: Text('「${ctrl.text.trim()}」を作りました')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e is UnsupportedError ? '${account.account.kind.name} ではリストを作れません' : 'リストを作れませんでした: $e')));
    }
  }
}

/// 1 つのタブの中身 (D-349)。`all` = RASQ + アカウントごとの欄、アカウントのキー = そのアカウントのもの、`rasq` = RASQ リスト。
class _ListsTabBody extends ConsumerWidget {
  const _ListsTabBody({super.key, required this.tab, required this.sessions, required this.query, required this.showPrivate, required this.labelOf});
  final String tab;
  final List<AccountSession> sessions;
  final String query;
  final bool showPrivate;
  final String Function(AccountSession) labelOf;

  bool _hit(String name) => query.isEmpty || name.toLowerCase().contains(query);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];
    if (tab == listsTabAll || tab == listsTabRasq) rows.addAll(_rasqRows(context, ref));
    for (final s in sessions) {
      if (tab != listsTabAll && tab != s.account.key) continue;
      rows.addAll(_accountRows(context, ref, s, header: tab == listsTabAll));
    }
    final loading = [
      for (final s in sessions)
        if (tab == listsTabAll || tab == s.account.key) ref.watch(listsForAccountProvider(s.account.key)).isLoading,
    ].any((x) => x);
    if (rows.isEmpty) {
      if (loading) return const RasqLoading();
      return RasqEmptyView(title: query.isEmpty ? 'リストはありません' : '見つかりません', hint: query.isEmpty ? '＋でリストを作成できます' : null);
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listsForAccountProvider);
        ref.invalidate(clipsForAccountProvider);
        ref.invalidate(savedFeedsForAccountProvider);
        invalidateRasqCollections(ref);
      },
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 88), children: rows),
    );
  }

  /// RASQ リスト (D-343): 自分のもの + フォロー中 + 作成。
  List<Widget> _rasqRows(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasRasqAccountProvider)) return const [];
    final mine = (ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list)).value ?? const <RasqCollection>[]).where((c) => _hit(c.name)).toList();
    final following = (ref.watch(followingRasqCollectionsProvider).value ?? const <RasqCollection>[]).where((c) => _hit(c.name)).toList();
    if (query.isNotEmpty && mine.isEmpty && following.isEmpty) return const [];
    return [
      const RasqSectionHeader(title: 'RASQ リスト(SNS 横断)', topMargin: 0),
      for (final c in mine) ...[RasqCollectionRow(collection: c), const Divider(height: 1)],
      for (final c in following) ...[RasqCollectionRow(collection: c, showOwner: true), const Divider(height: 1)],
      RasqListTile(
        key: const ValueKey('lists.rasq.create'),
        title: '新しい RASQ リスト',
        subtitle: 'Misskey / Mastodon / Bluesky の人を 1 つのリストに',
        leading: const Icon(Icons.add),
        onTap: () async {
          final c = await showCreateRasqListSheet(ref);
          if (c != null && context.mounted) context.push(Routes.rasqCollection(c.code ?? c.id));
        },
      ),
    ];
  }

  /// SNS のアカウントのリスト / クリップ(公開ネイティブ。非公開は設定で)/ カスタムフィード(保存済み)。
  List<Widget> _accountRows(BuildContext context, WidgetRef ref, AccountSession s, {required bool header}) {
    final key = s.account.key;
    final lists = (ref.watch(listsForAccountProvider(key)).value ?? const <UserListInfo>[]).where((l) => _hit(l.name)).toList();
    final clips = (ref.watch(clipsForAccountProvider(key)).value ?? const <ClipInfo>[]).where((c) => (c.isPublic || showPrivate) && _hit(c.name)).toList();
    final feeds = s.account.kind == SnsKind.bluesky ? (ref.watch(savedFeedsForAccountProvider(key)).value ?? const <FeedInfo>[]).where((f) => _hit(f.name)).toList() : const <FeedInfo>[];
    if (lists.isEmpty && clips.isEmpty && feeds.isEmpty) return const [];
    // 別のアカウントのものは、そのアカウントに切り替えてから開く。
    Future<void> open(VoidCallback go) async {
      if (ref.read(currentAccountProvider)?.key != key) {
        await ref.read(sessionsProvider.notifier).setCurrent(s.account);
        ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text('${s.account} に切り替えました')));
      }
      if (context.mounted) go();
    }

    return [
      if (header) RasqSectionHeader(title: labelOf(s), topMargin: RasqSpacing.md),
      if (clips.isNotEmpty) ...[
        if (!header) const RasqSectionHeader(title: 'クリップ', topMargin: 0),
        for (final c in clips) ...[_ClipRow(clip: c, onTap: () => open(() => context.pushClip(c))), const Divider(height: 1)],
      ],
      if (lists.isNotEmpty) ...[
        if (!header) RasqSectionHeader(title: 'リスト', topMargin: clips.isEmpty ? 0 : RasqSpacing.md),
        for (final l in lists) ...[_ListRow(list: l, onTap: () => open(() => context.push('/lists/${Uri.encodeComponent(l.id)}', extra: l))), const Divider(height: 1)],
      ],
      if (feeds.isNotEmpty) ...[
        if (!header) RasqSectionHeader(title: 'カスタムフィード', topMargin: clips.isEmpty && lists.isEmpty ? 0 : RasqSpacing.md),
        for (final f in feeds) ...[_feedRow(context, f), const Divider(height: 1)],
      ],
    ];
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.list, required this.onTap});
  final UserListInfo list;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = list;
    return InkWell(
      key: ValueKey('lists.list.${l.id}'),
      onTap: onTap,
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
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.clip, required this.onTap});
  final ClipInfo clip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = clip;
    return InkWell(
      key: ValueKey('lists.clip.${c.id}'),
      onTap: onTap,
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
  }
}

/// カスタムフィードの行 (D-195/196): 名前・作者・♥・説明。タップでフィード TL。右に「フィードを保存」(D-227)。
Widget _feedRow(BuildContext context, FeedInfo f) => _FeedRow(key: ValueKey('lists.feed.${f.uri}'), feed: f);

class _FeedRow extends ConsumerWidget {
  const _FeedRow({super.key, required this.feed});
  final FeedInfo feed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final f = feed;
    return InkWell(
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
          FeedSaveButton(uri: f.uri),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

/// 「フィードを保存」/「保存を外す」(D-227): 保存済みフィード([savedFeedsProvider])にあるかで印を変え、
/// [SnsSession.saveFeed] で切り替える。持たない SNS では何もしない(非対応の知らせ)。
class FeedSaveButton extends ConsumerWidget {
  const FeedSaveButton({super.key, required this.uri, this.size = 22});
  final String uri;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedFeedsProvider).value?.any((f) => f.uri == uri) ?? false;
    return RasqIconButton(
      key: ValueKey('lists.feed.save.$uri'),
      icon: saved ? Icons.bookmark : Icons.bookmark_border,
      size: size,
      tooltip: saved ? '保存を外す' : 'フィードを保存',
      color: saved ? RasqColors.link : null,
      onPressed: () async {
        final s = ref.read(currentSnsSessionProvider);
        if (s == null) return;
        try {
          await s.saveFeed(uri, on: !saved);
          ref.invalidate(savedFeedsProvider);
        } catch (e) {
          ref.read(overlayManagerProvider).showAlert(id: 'lists.feed.save', title: saved ? '保存を外せませんでした' : '保存できませんでした', message: e is UnsupportedError ? 'この SNS はフィードの保存に対応していません' : '$e', confirmText: 'OK');
        }
      },
    );
  }
}

/// 「タイムラインに取り込む」(D-227): 開いているフィードをホームの TL カスタマイズの取り込み元に足す。
/// 保存の作法は TL カスタマイズ画面と同じ([addTlSource])。足したらホームの TL を読み直す。
Future<String> importFeedToHome(ProviderContainer c, {required String uri, required String name}) async {
  final acc = c.read(currentAccountProvider);
  if (acc == null) return 'ログインしていません';
  final added = await addTlSource(c, acc.key, 'tl.home', TlSourceComponent(tl: 'feed:$uri', account: '$acc', label: name));
  if (!added) return '「$name」はもうホームのタイムラインに入っています';
  c.invalidate(timelineProvider(TimelineKind.home));
  return '「$name」をホームのタイムラインに取り込みました(タブ行の歯車で確認できます)';
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
    // 投稿タブの `↓` (D-338): もう一度押すと、このリスト TL の一時変更 FOW(探す + 一時的な構成)。
    final query = ref.watch(timelineSearchProvider.select((m) => m[kind.id]));
    final tabs = [
      const RasqTabItem('ユーザー', chevron: false),
      RasqTabItem('投稿', dot: query != null || ref.watch(tlTemporaryConfigsProvider.select((m) => m.containsKey('tl.${kind.id}')))),
      // 話題の目次 (D-368): AsTell の目次と同じ形。
      const RasqTabItem('話題の目次', chevron: false),
    ];
    final topicScope = 'list:$listId';
    final loaded = tl.value?.posts ?? const <Post>[];
    final topics = indexForListTimeline(loaded);
    // チャイルドセーフ (D-314): 止める例に近い中身のリストは開かない(一覧からも外している。リンクで来たとき)。
    final gate = ref.watch(childGateProvider);
    if (gate.hasDenyExamples) {
      final hidden = ref.watch(childSafeHiddenCollectionsProvider).value;
      if (hidden == null) return Scaffold(appBar: RasqPageHeader(title: info?.name ?? 'リスト'), body: const RasqLoading());
      final loaded = tl.value?.posts ?? const <Post>[];
      if (childSafeCollectionHidden(gate, hidden, kind: 'list', id: listId, name: info?.name ?? '', description: info?.description) ||
          gate.collectionHidden(childSafeCollectionMeta(info?.name ?? '', info?.description), [for (final p in loaded) '${p.body} ${p.quote?.body ?? ''}'])) {
        return Scaffold(appBar: RasqPageHeader(title: info?.name ?? 'リスト'), body: const ChildSafeBlockedView(message: '保護者がこのリストを止めています'));
      }
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: info?.name ?? 'リスト',
          onMore: () {},
          // リスト TL のカスタマイズ (D-124): TL 系は全部同 UI。デフォルトは
          // このリストの取得ノード(tl.list)から始まる。
          actions: [RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'リストTL設定', onPressed: () => context.push(Routes.tlConfig('tl.list:$listId')))],
          bottom: RasqTabs(items: tabs, onSelectedTabTap: (i, _) => i == 1 ? showTimelineTempFow(ref, tabs: [('tl.${kind.id}', info?.name ?? 'リスト')], scope: 'tl.${kind.id}') : null),
        ),
        body: TabBarView(children: [
          members.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
            data: (m) {
              // メンバーを追加 (D-366): SNS / RASQ のフォロー中と検索から選ぶ。
              final add = Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
                child: OutlinedButton.icon(
                  key: const ValueKey('lists.members.add'),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('メンバーを追加'),
                  onPressed: () async {
                    final session = ref.read(currentSnsSessionProvider);
                    if (session == null) return;
                    final n = await showListMemberPicker(ref, session: session, target: SnsListMemberTarget(session, listId, {for (final u in m) u.id}));
                    if (n == null) return;
                    ref.invalidate(listMembersProvider(listId));
                    ref.invalidate(listsProvider);
                    ref.read(rootMessengerKeyProvider).currentState?..clearSnackBars()..showSnackBar(SnackBar(content: Text('$n 人を追加しました')));
                  },
                ),
              );
              if (m.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [add, const Expanded(child: RasqEmptyView(title: 'ユーザーはいません'))]);
              return ListView.separated(
                    itemCount: m.length + 1,
                    separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(),
                    itemBuilder: (context, j) {
                      if (j == 0) return add;
                      final i = j - 1;
                      return RasqUserRow(
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
                    );
                    },
                  );
            },
          ),
          tl.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
            data: (s) => s.posts.isEmpty
                ? const RasqEmptyView(title: '投稿はありません')
                : _ListTimelinePosts(posts: s.posts, actions: actions, notifier: notifier, timelineId: kind.id, scope: topicScope, entries: topics),
          ),
          ListTopicsTab(scope: topicScope, entries: topics, posts: {for (final p in loaded) p.key: p}, postsTabIndex: 1),
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
    // 話題の目次 (D-368)。
    final topicScope = 'feed:$uri';
    final loaded = tl.value?.posts ?? const <Post>[];
    final topics = indexForListTimeline(loaded);
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: RasqPageHeader(
        title: info?.name ?? 'フィード',
        bottom: RasqTabs(items: const [RasqTabItem('投稿', chevron: false), RasqTabItem('話題の目次', chevron: false)]),
        onMore: () {},
        actions: [
          FeedSaveButton(uri: uri, size: 20),
          RasqIconButton(
            key: const ValueKey('feed.import'),
            icon: Icons.playlist_add,
            size: 20,
            tooltip: 'タイムラインに取り込む',
            onPressed: () async {
              final msg = await importFeedToHome(ProviderScope.containerOf(context), uri: uri, name: info?.name ?? uri);
              ref.read(overlayManagerProvider).showAlert(id: 'feed.import', title: 'タイムラインに取り込む', message: msg, confirmText: 'OK');
            },
          ),
          RasqIconButton(icon: Icons.settings, size: 20, tooltip: 'フィードTL設定', onPressed: () => context.push(Routes.tlConfig('tl.feed:$uri'))),
        ],
      ),
      body: TabBarView(children: [
        tl.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
          data: (s) => s.posts.isEmpty ? const RasqEmptyView(title: '投稿はありません') : _ListTimelinePosts(posts: s.posts, actions: actions, notifier: notifier, scope: topicScope, entries: topics),
        ),
        ListTopicsTab(scope: topicScope, entries: topics, posts: {for (final p in loaded) p.key: p}, postsTabIndex: 0),
      ]),
    ));
  }
}

/// リストTL の投稿列 (D-036 → D-368): 目次(会話イベントを章にしたもの)は「話題の目次」タブへ移し、
/// ここは選んだ話題での絞り込みだけ([ListTopicFilterBar] で解除)。
class _ListTimelinePosts extends ConsumerStatefulWidget {
  const _ListTimelinePosts({required this.posts, required this.actions, required this.notifier, this.timelineId, required this.scope, required this.entries});
  final List<Post> posts;

  /// 話題の目次 (D-368): 選んだ話題の置き場の scope と、目次。
  final String scope;
  final List<IndexEntry> entries;

  /// 一時変更 FOW の ↑↓ を受ける TL の id (D-341)。null = 受けない(フィード)。
  final String? timelineId;
  final List<ActionDescriptor> actions;
  final TimelineNotifier notifier;

  @override
  ConsumerState<_ListTimelinePosts> createState() => _ListTimelinePostsState();
}

class _ListTimelinePostsState extends ConsumerState<_ListTimelinePosts> {
  final _scroll = ScrollController();
  final _jumper = TimelineJumpController();

  @override
  void dispose() {
    _scroll.dispose();
    _jumper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = findIndexEntry(widget.entries, ref.watch(listTopicSelectionProvider(widget.scope)));
    final visible = selected == null ? widget.posts : [for (final p in widget.posts) if (selected.postKeys.contains(p.key)) p];
    // 探す語の ↑↓ (D-341): 目次で章を選んでいて、飛ぶ先が隠れていれば章の選択を外してから飛ぶ。
    ref.listen(timelineSearchNavProvider, (prev, next) {
      if (next == null || next.timelineId != widget.timelineId || next.seq == prev?.seq) return;
      handleTimelineSearchNav(ref, next, jumper: _jumper, scroll: _scroll, posts: widget.posts, beforeJump: (key) async {
        if (visible.any((p) => p.key == key)) return;
        ref.read(listTopicSelectionProvider(widget.scope).notifier).select(null);
        await WidgetsBinding.instance.endOfFrame;
      });
    });
    return RefreshIndicator(
      onRefresh: widget.notifier.refresh,
      child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), children: [
        // 話題の目次で選んだ話題だけにしているとき (D-368)。目次そのものは「話題の目次」タブ。
        ListTopicFilterBar(scope: widget.scope, entry: selected),
        for (final p in visible)
          TimelineSearchRow(
            key: ValueKey('list.row.${p.key}'),
            controller: _jumper,
            postKey: p.key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PostRow(post: p, actions: widget.actions, onAction: (a, {args = const {}}) => widget.notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
              const Divider(),
            ]),
          ),
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
    final hasRasq = ref.watch(hasRasqAccountProvider);
    final results = bluesky ? ref.watch(feedSearchProvider(_query)) : const AsyncValue<List<FeedInfo>>.data([]);
    final hint = [if (bluesky) 'カスタムフィード', if (hasRasq) 'RASQ リスト'].join(' / ');
    return Scaffold(
      appBar: RasqPageHeader(title: 'リストのインポート', onMore: () {}),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 4),
          child: bluesky || hasRasq
              ? TextField(
                  key: const ValueKey('lists.import.search'),
                  controller: _ctrl,
                  style: RasqTypography.bodySmall,
                  decoration: InputDecoration(hintText: '$hintを検索、または共有リンク / URL を入力', isDense: true, prefixIcon: const Icon(Icons.search, size: 18)),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => setState(() => _query = v),
                  onChanged: (v) => setState(() => _query = v),
                )
              : const RasqSearchBar(hintText: '検索'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [
                if (bluesky) 'フィードを検索するか URL を貼ると、リストタイルで表示します。タップでそのフィードのタイムラインへ。',
                if (hasRasq) 'RASQ リストは「取り込む」でホームのタイムラインへ(リストをフォローします)。取り込めるのは、リスト内の人の情報を取れるリストだけです。',
                if (!bluesky && !hasRasq) 'リストを検索して一括操作を行うことができます。',
              ].join('\n'),
              style: RasqTypography.bodySmall,
            ),
            if (!bluesky) TextButton(onPressed: () => manager.showAlert(id: 'lists.import', title: 'ローカルからインポート', message: rasqDetail(context, 'ファイルからのインポートは準備中です。', 'CSV/JSON からのインポートはリスト機能(サーバー側: 第二期)と合わせて実装します。'), confirmText: 'OK'), child: Text('ローカルからインポート', style: TextStyle(color: tokens.link))),
          ]),
        ),
        if (bluesky) ...[
          RasqSectionHeader(title: _query.trim().isEmpty ? '人気のフィード' : 'フィードの検索結果', topMargin: RasqSpacing.sm),
          results.when(
            loading: () => const RasqLoading(),
            error: (_, _) => const RasqEmptyView(title: '見つかりません'),
            data: (items) => items.isEmpty
                ? RasqEmptyView(title: _query.trim().isEmpty ? '検索語か URL を入れてください' : '見つかりません')
                : Column(children: [for (final f in items) ...[_feedRow(context, f), const Divider(height: 1)]]),
          ),
        ],
        // RASQ リスト (D-347): 語が空 = 自分のリスト + フォロー中、語があれば公開リストの検索。行のタップでリストのページ、右の「取り込む」でホームの TL へ。
        if (hasRasq) ...[
          RasqSectionHeader(title: _query.trim().isEmpty ? 'RASQ リスト(自分 / フォロー中)' : 'RASQ リストの検索結果', topMargin: RasqSpacing.sm),
          RasqListCandidates(
            query: _query,
            onPick: null,
            trailing: (c) => TextButton(
              key: ValueKey('lists.import.rasq.${c.id}'),
              onPressed: c.canFetch == false && c.canFetchChecked
                  ? null
                  : () async {
                      final msg = await importRasqListToHome(ref, c);
                      if (!mounted) return;
                      ref.read(rootMessengerKeyProvider).currentState
                        ?..clearSnackBars()
                        ..showSnackBar(SnackBar(content: Text(msg)));
                    },
              child: const Text('取り込む'),
            ),
            onOpen: (c) => context.push(Routes.rasqCollection(c.code ?? c.id)),
          ),
        ],
        if (!bluesky && !hasRasq) ...[
          const RasqSectionHeader(title: '履歴', topMargin: 0),
          const RasqEmptyView(title: '履歴はありません'),
        ],
      ]),
    );
  }
}
