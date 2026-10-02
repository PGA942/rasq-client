import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../clips/index_toc.dart' show findIndexEntry;
import '../clips/virtual_index.dart';
import '../lists/list_member_picker.dart';
import '../lists/topic_toc.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart' show Routes;
import '../../backend/orgate_client.dart' show OrgateException;
import '../../backend/rasq_collections_api.dart';
import '../../shell/headers.dart';
import '../child_safe/child_gate.dart';
import '../child_safe/child_safe_collections.dart' show childSafeCollectionMeta;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView;
import '../clips/host_clips.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../servers/server_info_tile.dart';
import 'rasq_collections.dart';
import 'rasq_list_picker.dart';

/// RASQ リスト / 公開した RASQ クリップのページ (D-343/D-344)。`/rasq-collections/:ref`(id か共有コード)。
/// 開いたとき、見ている人に資格があれば(作った人 / 条件に合うフォロワー)Central がその人の AsTell のトークンで取り直してから返す。
/// タブ: リスト = 投稿 / メンバー / サーバー、クリップ = 投稿 / サーバー。サーバーのタブは、入っているインスタンスのサーバー情報タイル (D-345)。
class RasqCollectionScreen extends ConsumerWidget {
  const RasqCollectionScreen({super.key, required this.idOrCode});
  final String idOrCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(rasqCollectionProvider(idOrCode));
    final title = detail.value?.collection.name ?? '';
    return Scaffold(
      appBar: RasqPageHeader(
        title: title,
        actions: [
          // タイムラインに取り込む (D-347): リスト内の人の情報を取れるリストだけ。
          if (detail.value case final d? when d.collection.kind == RasqCollectionKind.list && d.canFetch)
            RasqIconButton(
              key: const ValueKey('rasqCollection.import'),
              icon: Icons.playlist_add,
              size: 20,
              tooltip: 'タイムラインに取り込む',
              onPressed: () async {
                final manager = ref.read(overlayManagerProvider);
                final msg = await importRasqListToHome(ref, d.summary);
                ref.invalidate(rasqCollectionProvider(idOrCode));
                manager.showAlert(id: 'rasqCollection.import', title: 'タイムラインに取り込む', message: msg, confirmText: 'OK');
              },
            ),
        ],
        onMore: detail.value == null ? null : () => _menu(context, ref, detail.value!),
      ),
      body: detail.when(
        loading: () => const RasqLoading(),
        error: (e, _) {
          if (e is OrgateException && e.code.code == '404') return const RasqEmptyView(title: '見つかりません', hint: '消されたか、非公開になっています');
          return RasqErrorView(code: ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(rasqCollectionProvider(idOrCode)), retryLabel: '再読み込み');
        },
        data: (d) {
          // チャイルドセーフ (D-407、指摘 #26): 端末のクリップ / リストと同じく、止める例に近い中身(名前 + 説明 / 投稿)なら
          // 開かない(見出し / 話題の目次も出さない)。開くときも、見せない投稿は外す。
          final guarded = childSafeRasqCollection(ref.watch(childGateProvider), d);
          if (guarded == null) {
            return ChildSafeBlockedView(message: d.collection.kind == RasqCollectionKind.list ? '保護者がこのリストを止めています' : '保護者がこのクリップを止めています');
          }
          return _Body(detail: guarded, idOrCode: idOrCode);
        },
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, RasqCollectionDetail d) async {
    final manager = ref.read(overlayManagerProvider);
    final api = ref.read(rasqCollectionsApiProvider);
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    final c = d.collection;
    final isList = c.kind == RasqCollectionKind.list;
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 80, 1, 1) : Rect.fromLTWH(box.size.width - 48, 56, 40, 40);
    final pick = await manager.showDropdown<String>(id: 'rasqCollection.menu', anchor: anchor, items: [
      if (c.url != null) const RasqDropdownItem('リンクをコピー', 'copy'),
      if (d.eligible) const RasqDropdownItem('いま取り直す', 'refresh'),
      if (d.isOwner && isList) RasqDropdownItem(c.isPublic ? '非公開にする' : '公開する', 'visibility'),
      if (d.isOwner && isList) const RasqDropdownItem('名前と説明を変更', 'rename'),
      if (d.isOwner && isList) const RasqDropdownItem('削除', 'delete', destructive: true),
      if (d.isOwner && !isList) const RasqDropdownItem('公開をやめる', 'unpublish', destructive: true),
    ]);
    if (pick == null || api == null) return;
    try {
      switch (pick) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: c.url!));
          messenger?.showSnackBar(const SnackBar(content: Text('リンクをコピーしました')));
        case 'refresh':
          final r = await api.refresh(c.id);
          ref.invalidate(rasqCollectionProvider(idOrCode));
          messenger?.showSnackBar(SnackBar(content: Text(r.refresh == 'failed' ? '取り直せませんでした' : '取り直しました')));
        case 'visibility':
          await api.update(c.id, isPublic: !c.isPublic);
          ref.invalidate(rasqCollectionProvider(idOrCode));
          invalidateRasqCollections(ref);
        case 'rename':
          final name = TextEditingController(text: c.name);
          final desc = TextEditingController(text: c.description ?? '');
          final ok = await manager.showBottomSheet<bool>(
            id: 'rasqCollection.rename',
            title: '名前と説明',
            confirmText: '保存',
            builder: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, maxLength: 60, decoration: const InputDecoration(hintText: '名前')),
                TextField(controller: desc, maxLength: 500, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: '説明(任意)')),
              ]),
            ),
          );
          if (ok == true && name.text.trim().isNotEmpty) {
            await api.update(c.id, name: name.text.trim(), description: desc.text.trim());
            ref.invalidate(rasqCollectionProvider(idOrCode));
            invalidateRasqCollections(ref);
          }
        case 'delete':
          final ok = await manager.showAlert(id: 'rasqCollection.delete', title: '「${c.name}」を削除しますか？', message: 'フォローしている人の一覧からも消えます。', confirmText: '削除', cancelText: 'キャンセル', destructive: true);
          if (!ok) return;
          await api.delete(c.id);
          invalidateRasqCollections(ref);
          if (context.mounted) context.pop();
        case 'unpublish':
          // 端末の RASQ クリップが元なら、その印も外す(クリップは端末に残る)。
          final host = (ref.read(hostClipsProvider).value ?? const <HostClip>[]).where((h) => h.remoteId == c.id).firstOrNull;
          if (host != null) {
            await ref.read(hostClipsProvider.notifier).unpublish(host.id);
          } else {
            await api.delete(c.id);
          }
          invalidateRasqCollections(ref);
          if (context.mounted) context.pop();
      }
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('できませんでした: $e')));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.idOrCode});
  final RasqCollectionDetail detail;
  final String idOrCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = detail.collection;
    final isList = c.kind == RasqCollectionKind.list;
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final hosts = [for (final h in c.instances) if (h != 'bsky.social' && h != 'bsky.app') h];
    final tabs = [const Tab(text: '投稿'), if (isList) const Tab(text: '話題の目次'), if (isList) const Tab(text: 'メンバー'), if (hosts.isNotEmpty) const Tab(text: 'サーバー')];
    // 話題の目次 (D-368): 投稿を話題ごとに区切る。投稿は RASQ 側の key で引く(見るアカウントで key が変わるため)。
    final topicScope = 'rasq:${c.id}';
    final byKey = <String, Post>{};
    final rasqKeyOf = <String, String>{};
    if (isList) {
      for (final p in detail.posts) {
        final post = p.toPost(detail.memberOf(p.memberKey));
        byKey[post.key] = post;
        rasqKeyOf[post.key] = p.key;
      }
    }
    final topics = isList ? indexForListTimeline(byKey.values.toList()) : const <IndexEntry>[];
    final selected = findIndexEntry(topics, ref.watch(listTopicSelectionProvider(topicScope)));
    final visibleKeys = selected == null ? null : {for (final k in selected.postKeys) ?rasqKeyOf[k]};
    return DefaultTabController(
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverToBoxAdapter(child: _Header(detail: detail, idOrCode: idOrCode)),
          SliverToBoxAdapter(child: TabBar(tabs: tabs, isScrollable: true, tabAlignment: TabAlignment.start)),
        ],
        body: TabBarView(children: [
          RefreshIndicator(
            onRefresh: () => ref.refresh(rasqCollectionProvider(idOrCode).future),
            child: isList
                ? Column(children: [
                    ListTopicFilterBar(scope: topicScope, entry: selected),
                    Expanded(child: _ListPosts(detail: detail, sessions: sessions, only: visibleKeys)),
                  ])
                : _ClipPosts(detail: detail, sessions: sessions),
          ),
          if (isList) ListTopicsTab(scope: topicScope, entries: topics, posts: byKey, postsTabIndex: 0),
          if (isList) _Members(detail: detail, idOrCode: idOrCode, sessions: sessions),
          if (hosts.isNotEmpty)
            ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
              for (final h in hosts) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: ServerInfoTile(host: h)),
            ]),
        ]),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.detail, required this.idOrCode});
  final RasqCollectionDetail detail;
  final String idOrCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = detail.collection;
    final isList = c.kind == RasqCollectionKind.list;
    final refreshed = c.refreshedAt;
    final status = switch (detail.refresh) {
      'done' => '見たときに新しくしました',
      'failed' => '取り直せませんでした(前の内容です)',
      _ when detail.eligible => null,
      _ when detail.following => '同じサーバーに所属しているか、入っている人をフォローしていると、見たときに新しくなります',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isList ? Icons.people_alt_outlined : Icons.workspaces_outlined, size: 16, color: RasqColors.sub),
          const SizedBox(width: RasqSpacing.xs),
          Text(isList ? 'RASQ リスト' : 'RASQ クリップ', style: RasqTypography.caption.copyWith(color: RasqColors.sub, fontWeight: FontWeight.w700)),
          const SizedBox(width: RasqSpacing.xs),
          if (!c.isPublic) Text('非公開', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(c.name, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        InkWell(
          onTap: () => context.push(Routes.rasqAccount(c.owner.handle)),
          child: Row(children: [
            RasqAvatar(imageUrl: c.owner.avatarUrl, size: 22, fallbackLabel: c.owner.displayName),
            const SizedBox(width: RasqSpacing.xs),
            Flexible(child: Text('${c.owner.displayName} @${c.owner.handle}', style: RasqTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (c.description != null) ...[const SizedBox(height: RasqSpacing.xs), Text(c.description!, style: RasqTypography.body)],
        const SizedBox(height: RasqSpacing.xs),
        Text(
          [
            isList ? '${c.itemCount}人' : '${c.itemCount}件',
            'フォロワー ${c.followerCount}',
            if (refreshed != null) '更新 ${_ago(refreshed)}',
          ].join(' ・ '),
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (status != null) Text(status, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (!detail.isOwner && c.isPublic) ...[
          const SizedBox(height: RasqSpacing.xs),
          _FollowButton(detail: detail, idOrCode: idOrCode),
        ],
      ]),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.detail, required this.idOrCode});
  final RasqCollectionDetail detail;
  final String idOrCode;
  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final following = widget.detail.following;
    final hasAccount = ref.watch(hasRasqAccountProvider);
    final onPressed = !hasAccount || _busy
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              await ref.read(rasqCollectionsApiProvider)!.follow(widget.detail.collection.id, on: !following);
              ref.invalidate(rasqCollectionProvider(widget.idOrCode));
              ref.invalidate(followingRasqCollectionsProvider);
            } catch (e) {
              ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text('できませんでした: $e')));
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          };
    return following
        ? OutlinedButton(key: const ValueKey('rasqCollection.follow'), onPressed: onPressed, child: const Text('フォロー中'))
        : FilledButton(key: const ValueKey('rasqCollection.follow'), onPressed: onPressed, child: const Text('フォロー'));
  }
}

/// 見ている人の、同じ種類・同じサーバーのアカウント(あれば、そのセッションでリアクションなどができる)。
AccountSession? _viewerFor(List<AccountSession> sessions, String kind, String instance) =>
    sessions.where((s) => s.account.kind.name == kind && s.account.instance == instance).firstOrNull;

class _ListPosts extends StatelessWidget {
  const _ListPosts({required this.detail, required this.sessions, this.only});
  final RasqCollectionDetail detail;
  final List<AccountSession> sessions;

  /// 話題の目次で選んだ話題の投稿(RASQ 側の key)。null = すべて。
  final Set<String>? only;

  @override
  Widget build(BuildContext context) {
    if (detail.posts.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        RasqEmptyView(title: 'まだ投稿がありません', hint: detail.items.isEmpty ? 'ユーザーページの … →「RASQ リストに追加」で人を入れられます' : '見られる人が開いたときに集まります'),
      ]);
    }
    final posts = only == null ? detail.posts : [for (final p in detail.posts) if (only!.contains(p.key)) p];
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, i) {
        final p = posts[i];
        final member = detail.memberOf(p.memberKey);
        return _SnsPostRow(key: ValueKey('rasqCollection.post.${p.key}'), kind: member?.kind ?? p.memberKey.split(':').first, instance: member?.instance ?? '', postFor: (viewer) => p.toPost(member, viewer: viewer), sessions: sessions);
      },
    );
  }
}

class _ClipPosts extends StatelessWidget {
  const _ClipPosts({required this.detail, required this.sessions});
  final RasqCollectionDetail detail;
  final List<AccountSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (detail.items.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [RasqEmptyView(title: 'クリップは空です')]);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: detail.items.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final item = detail.items[i];
        if (item.state == RasqItemState.ok && item.snapshot != null) {
          return _SnsPostRow(key: ValueKey('rasqCollection.item.${item.key}'), kind: item.kind, instance: item.instance, postFor: (viewer) => item.post(viewer: viewer)!, sessions: sessions);
        }
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          key: ValueKey('rasqCollection.item.${item.key}'),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
          child: Row(children: [
            Icon(item.state == RasqItemState.gone ? Icons.block : Icons.hourglass_empty, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(
              child: Text(
                item.state == RasqItemState.gone ? 'この投稿は見られなくなりました(消されたか、公開範囲が変わりました)' : '公開範囲を確かめています',
                style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// SNS の投稿の行。アカウントページの SNS の投稿 (S-027) と同じ扱い: 同じサーバーのアカウントを持っていれば操作できる、無ければ読むだけ。
class _SnsPostRow extends ConsumerWidget {
  const _SnsPostRow({super.key, required this.kind, required this.instance, required this.postFor, required this.sessions});
  final String kind;
  final String instance;

  /// 投稿を組む(見ている人の同じサーバーのアカウントを渡すと、そのアカウントの投稿として)。
  final Post Function(AccountId? viewer) postFor;
  final List<AccountSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = _viewerFor(sessions, kind, instance);
    final p = postFor(mine?.account);
    final session = mine == null ? null : ref.watch(sessionForAccountProvider(mine.account.key));
    return PostRow(
      post: p,
      actions: session?.actions ?? const [],
      onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
      onTap: mine != null
          ? () => context.pushPost(p)
          : () {
              final url = p.url;
              if (url != null) launchUrl(url, mode: LaunchMode.externalApplication);
            },
    );
  }
}

class _Members extends ConsumerWidget {
  const _Members({required this.detail, required this.idOrCode, required this.sessions});
  final RasqCollectionDetail detail;
  final String idOrCode;
  final List<AccountSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // メンバーを追加 (D-366): SNS / RASQ のフォロー中と検索から(作った人だけ)。いまの SNS アカウントから見た人で入れる。
    final add = detail.isOwner
        ? Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
            child: OutlinedButton.icon(
              key: const ValueKey('rasqCollection.members.add'),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('メンバーを追加'),
              onPressed: () async {
                final api = ref.read(rasqCollectionsApiProvider);
                final session = ref.read(currentSnsSessionProvider);
                if (api == null || session == null) return;
                try {
                  final n = await showListMemberPicker(ref, session: session, target: RasqListMemberTarget(api, detail.collection.id, session, detail.items));
                  if (n == null) return;
                  ref.invalidate(rasqCollectionProvider(idOrCode));
                  ref.invalidate(myRasqCollectionsProvider(RasqCollectionKind.list));
                  ref.read(rootMessengerKeyProvider).currentState?..clearSnackBars()..showSnackBar(SnackBar(content: Text('$n 人を追加しました')));
                } catch (e) {
                  ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text('追加できませんでした: $e')));
                }
              },
            ),
          )
        : null;
    if (detail.items.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ?add,
        Expanded(child: RasqEmptyView(title: 'メンバーはいません', hint: detail.isOwner ? '「メンバーを追加」か、ユーザーページの … →「RASQ リストに追加」' : null)),
      ]);
    }
    return ListView(children: [
      ?add,
      for (final m in detail.items)
        RasqListTile(
          key: ValueKey('rasqCollection.member.${m.key}'),
          title: m.user.displayName,
          subtitle: '@${m.handle ?? m.user.account.handle} ・ ${m.kind}',
          leading: RasqAvatar(imageUrl: m.user.avatarUrl, size: 36, fallbackLabel: m.user.displayName),
          chevron: !detail.isOwner,
          trailing: detail.isOwner
              ? IconButton(
                  key: ValueKey('rasqCollection.member.remove.${m.key}'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'リストから外す',
                  onPressed: () async {
                    final api = ref.read(rasqCollectionsApiProvider);
                    if (api == null) return;
                    try {
                      await removeRasqListMember(api, detail.collection.id, m.key);
                      ref.invalidate(rasqCollectionProvider(idOrCode));
                      ref.invalidate(myRasqCollectionsProvider(RasqCollectionKind.list));
                    } catch (e) {
                      ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text('外せませんでした: $e')));
                    }
                  },
                )
              : null,
          onTap: () {
            final mine = _viewerFor(sessions, m.kind, m.instance);
            if (mine != null) {
              // ユーザーページはこのアカウントのセッションで開く (D-155: initial のアカウントで展開)。id はそのサーバーのもの。
              context.pushUser(UserSummary(id: m.refId, account: mine.account, displayName: m.user.displayName, avatarUrl: m.user.avatarUrl));
            } else if (m.user.account.instance.isNotEmpty) {
              launchUrl(Uri.https(m.user.account.instance, '/@${m.user.account.handle}'), mode: LaunchMode.externalApplication);
            }
          },
        ),
    ]);
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes}分前';
  if (d.inDays < 1) return '${d.inHours}時間前';
  return '${d.inDays}日前';
}

/// RASQ リスト / クリップの詳細を、いまの保護者の表示制限に合わせる (D-407、指摘 #26)。中身(名前 + 説明 + 投稿の本文)が
/// 止める例に近ければ null(開かない)。そうでなければ、見せない投稿 / 項目を外した詳細。見守り中でなければそのまま。
RasqCollectionDetail? childSafeRasqCollection(ChildGate gate, RasqCollectionDetail d) {
  if (!gate.supervised) return d;
  final c = d.collection;
  final postOf = {for (final p in d.posts) p.key: p.toPost(null)};
  // クリップの項目は投稿のスナップショット(リストの項目は人なので、投稿としては読まない)。
  final itemPostOf = c.kind == RasqCollectionKind.list ? const <String, Post>{} : {for (final i in d.items) i.key: ?_itemPost(i)};
  final bodies = [for (final p in [...postOf.values, ...itemPostOf.values]) '${p.body} ${p.quote?.body ?? ''}'];
  if (gate.collectionHidden(childSafeCollectionMeta(c.name, c.description), bodies)) return null;
  return RasqCollectionDetail(
    collection: c,
    items: [for (final i in d.items) if (itemPostOf[i.key] == null || !gate.postHidden(itemPostOf[i.key]!)) i],
    posts: [for (final p in d.posts) if (!gate.postHidden(postOf[p.key]!)) p],
    isOwner: d.isOwner,
    following: d.following,
    eligible: d.eligible,
    canFetch: d.canFetch,
    refresh: d.refresh,
  );
}

Post? _itemPost(RasqCollectionItem i) {
  try {
    return i.post();
  } catch (_) {
    return null;
  }
}
