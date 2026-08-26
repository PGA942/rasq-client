import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../clips/clip_providers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../users/user_list.dart';

final listsProvider = FutureProvider.autoDispose<List<UserListInfo>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.lists();
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

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    final manager = ref.watch(overlayManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: RasqPageHeader(title: 'リスト', actions: [RasqIconButton(icon: Icons.download_outlined, onPressed: () => context.push('/lists/import'), tooltip: 'リストのインポート')], onMore: () {}),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm), child: RasqSearchBar(hintText: 'ActivityPub 荒らし', onChanged: (v) => setState(() => _q = v.trim().toLowerCase()))),
        Expanded(
          child: lists.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(listsProvider), retryLabel: '再読み込み'),
            data: (all) {
              final list = all.where((l) => _q.isEmpty || l.name.toLowerCase().contains(_q)).toList();
              // クリップ(ネイティブ + RASQ 横断)もリスト画面にまとめて出す
              // (D-032: ユーザーページ以外の入口。詳細はクリップTL)。
              final clips = ref.watch(myClipsProvider).where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q)).toList();
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
                            Text([if (c.notesCount != null) '${c.notesCount}件', if (c.isHost) 'RASQ(SNS 横断)' else 'クリップ'].join(' ・ '), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
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
  }
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
        appBar: RasqPageHeader(title: info?.name ?? 'リスト', onMore: () {}, bottom: RasqTabs(items: tabs)),
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
                : RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView.separated(
                      itemCount: s.posts.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (_, i) => PostRow(post: s.posts[i], actions: actions, onAction: (a, {args = const {}}) => notifier.perform(s.posts[i], a, args: args), onTap: () => context.pushPost(s.posts[i])),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// リストのインポート: 検索 + 「ローカルからインポート」 + 履歴.
class ListImportScreen extends ConsumerWidget {
  const ListImportScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(overlayManagerProvider);
    final tokens = RasqTokens.of(context);
    return Scaffold(
      appBar: RasqPageHeader(title: 'リストのインポート', onMore: () {}),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 4), child: RasqSearchBar(hintText: '検索')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('リストを検索して一括操作を行うことができます。', style: RasqTypography.bodySmall),
            TextButton(onPressed: () => manager.showAlert(id: 'lists.import', title: 'ローカルからインポート', message: 'CSV/JSON からのインポートはリスト機能(サーバー側: 第二期)と合わせて実装します。', confirmText: 'OK'), child: Text('ローカルからインポート', style: TextStyle(color: tokens.link))),
          ]),
        ),
        const RasqSectionHeader(title: '履歴', topMargin: 0),
        const RasqEmptyView(title: '履歴はありません'),
      ]),
    );
  }
}
