import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../app/router.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../text/inline_spans.dart';
import '../clips/clip_providers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import 'user_list.dart';
import 'user_providers.dart';

/// ユーザーページ(通常 / 自分 / 制限 / ノーヒット). タブ: ノート / 引用 / メディア / クリップ.
class UserPageScreen extends ConsumerStatefulWidget {
  const UserPageScreen({super.key, required this.userId, this.initial});
  final String userId;
  final UserSummary? initial;
  @override
  ConsumerState<UserPageScreen> createState() => _UserPageScreenState();
}

class _UserPageScreenState extends ConsumerState<UserPageScreen> {
  bool _showRestricted = false;

  @override
  Widget build(BuildContext context) {
    final acct = widget.initial?.account.key; // 属するアカウントで展開 (D-155)
    final profile = ref.watch(userProfileProvider((id: widget.userId, account: acct)));
    final me = ref.watch(currentUserProvider);
    final viewer = ref.watch(currentAccountProvider);
    final manager = ref.watch(overlayManagerProvider);
    final title = profile.value?.summary.displayName ?? widget.initial?.displayName ?? (profile.hasError ? '@${widget.initial?.handle ?? ''}' : '');

    return Scaffold(
      appBar: RasqPageHeader(
        title: title,
        onMore: () => _userMenu(context, manager, profile.value?.summary ?? widget.initial, profile.value),
      ),
      body: profile.when(
        loading: () => const RasqLoading(),
        error: (e, _) {
          final code = e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e');
          if (code.code == '404' || code.code == '400') return const _NoHit();
          return RasqErrorView(code: code, onRetry: () => ref.invalidate(userProfileProvider((id: widget.userId, account: acct))), retryLabel: '再読み込み');
        },
        data: (p) {
          final isSelf = p.summary.id == me.id || (p.summary.handle == me.handle && p.summary.account.instance == me.account.instance);
          final keyUser = viewer == null ? p.summary.key : '${viewer.kind.name}:${viewer.instance}:${p.summary.id}';
          final st = viewer == null ? const FollowState() : ref.watch(followStateOfProvider((viewer: viewer.key, user: keyUser)));
          final restricted = (p.isSuspended || st.blocked || st.blockedBy) && !_showRestricted;
          // 返信TL / 引用TL (D-069): 返信と引用はそれぞれのタブに振り分ける
          // (ノートには両方とも流さない。純リノートはノートに残る)。
          final tabs = [const RasqTabItem('ノート'), const RasqTabItem('返信'), const RasqTabItem('引用'), const RasqTabItem('メディア'), const RasqTabItem('クリップ/Play')];
          return RasqCollapsibleTabScaffold(
            header: RasqUserTileLarge(
              profile: p,
              isSelf: isSelf,
              following: isSelf ? null : st.following,
              followedBy: st.followedBy,
              requested: st.requested,
              restricted: restricted,
              onShowRestricted: () => setState(() => _showRestricted = true),
              bio: p.description == null ? null : RasqRichText(InlineSpans.parse(p.description!, emojis: ref.watch(emojiCacheProvider), onLink: (u) => launchUrl(u, mode: LaunchMode.externalApplication), onHashtag: (t) => context.pushTrend(t)), style: RasqTypography.body),
              onFollowTap: () => ref.read(userListHelperProvider).toggleFollow(p.summary),
              onEditTap: () => context.push(Routes.profileEdit),
              onNotifyTap: () {},
              onFollowingTap: () => context.pushFollows(p.summary, followers: false),
              onFollowersTap: () => context.pushFollows(p.summary, followers: true),
              onLinkTap: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
            ),
            tabs: RasqTabs(items: tabs),
            tabViews: restricted
                ? [for (final _ in tabs) const RasqEmptyView(title: '制限されたユーザーです', hint: '「表示」を押すと内容を表示します')]
                : [
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.posts, pinned: p.pinnedPosts),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.replies),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.quotes),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.media),
                    _UserClips(userId: p.summary.id),
                  ],
          );
        },
      ),
    );
  }

  Future<void> _userMenu(BuildContext context, OverlayManager manager, UserSummary? u, UserProfile? p) async {
    if (u == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 80, 1, 1) : Rect.fromLTWH(box.size.width - 48, 56, 40, 40);
    final viewer = ref.read(currentAccountProvider);
    final st = viewer == null ? const FollowState() : ref.read(followStateProvider.notifier).of(viewer.key, '${viewer.kind.name}:${viewer.instance}:${u.id}');
    final pick = await manager.showDropdown<String>(id: 'user.menu', anchor: anchor, items: [
      const RasqDropdownItem('リンクをコピー', 'copy'),
      RasqDropdownItem(st.muted ? 'ミュート解除' : 'ミュート', 'mute', accent: true),
      RasqDropdownItem(st.blocked ? 'ブロック解除' : 'ブロック', 'block', destructive: true),
      const RasqDropdownItem('報告', 'report', destructive: true),
    ]);
    final s = ref.read(currentSnsSessionProvider);
    if (pick == null || s == null || viewer == null) return;
    final store = ref.read(followStateProvider.notifier);
    final key = '${viewer.kind.name}:${viewer.instance}:${u.id}';
    switch (pick) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: (p?.profileUrl ?? Uri.https(u.account.instance, '/@${u.handle}')).toString()));
      case 'mute':
        store.apply(viewer.key, key, await s.setMuted(u.id, !st.muted));
      case 'block':
        final ok = st.blocked || await manager.showAlert(id: 'user.block', title: '${u.displayName} をブロックしますか？', message: '相手からのフォロー・リアクション・返信が届かなくなります。', confirmText: 'ブロック', cancelText: 'キャンセル', destructive: true);
        if (ok) store.apply(viewer.key, key, await s.setBlocked(u.id, !st.blocked));
      case 'report':
        final ok = await manager.showAlert(id: 'user.report', title: '${u.displayName} を報告しますか？', message: 'サーバー管理者に報告します(コメントは次バッチで入力可能)。', confirmText: '報告', cancelText: 'キャンセル', destructive: true);
        if (ok) await s.reportUser(u.id, 'Reported from RASQ');
    }
  }
}

class _UserPosts extends ConsumerWidget {
  const _UserPosts({required this.userId, required this.filter, this.pinned = const [], this.account});
  final String userId;
  final UserPostsFilter filter;
  final List<Post> pinned;
  final String? account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(userPostsProvider((id: userId, filter: filter, account: account)));
    final actions = ref.watch(sessionForAccountProvider(account))?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final scheme = Theme.of(context).colorScheme;
    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(userPostsProvider((id: userId, filter: filter, account: account))), retryLabel: '再読み込み'),
      data: (p) {
        final items = [...pinned, ...p.items.where((x) => !pinned.any((pin) => pin.id == x.id))];
        if (items.isEmpty) return const RasqEmptyView(title: '投稿はありません');
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) {
            final post = items[i];
            final isPinned = i < pinned.length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isPinned) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page + RasqSizes.avatarLg + RasqSpacing.md, 6, 0, 0), child: Row(children: [Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text('ピン留め', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))])),
              PostRow(post: post, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(post, a, args: args), onTap: () => context.pushPost(post)),
            ]);
          },
        );
      },
    );
  }
}

/// クリップ/Play タブ (D-032/D-039): 対象ユーザーの公開クリップ一覧
/// (タップでクリップTL)+ **Play の外部リンク**(RASQ 内では実行しない)。
/// SNS がどちらも非対応なら従来どおりのプレースホルダー。
class _UserClips extends ConsumerWidget {
  const _UserClips({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(userClipsProvider(userId));
    final plays = ref.watch(userPlaysProvider(userId)).value;
    final scheme = Theme.of(context).colorScheme;
    return clips.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(userClipsProvider(userId)), retryLabel: '再読み込み'),
      data: (list) {
        if (list == null && plays == null) return const RasqEmptyView(title: 'クリップ / Play', hint: 'この SNS はクリップ・Play に対応していません(プラグインタイルは M4)');
        if ((list ?? const []).isEmpty && (plays ?? const []).isEmpty) return const RasqEmptyView(title: '公開クリップ・Play はありません');
        return ListView(children: [
          if ((list ?? const []).isNotEmpty) ...[
            const RasqSectionHeader(title: 'クリップ', topMargin: 0),
            for (final c in list!) ...[
              RasqListTile(
                title: c.name,
                subtitle: [if (c.notesCount != null) '${c.notesCount}件', if (c.description?.isNotEmpty == true) c.description!].join(' ・ '),
                leading: Icon(Icons.collections_bookmark_outlined, color: scheme.onSurfaceVariant),
                onTap: () => context.pushClip(c),
              ),
              const Divider(height: 1),
            ],
          ],
          if ((plays ?? const []).isNotEmpty) ...[
            const RasqSectionHeader(title: 'Play'),
            for (final p in plays!) ...[
              RasqListTile(
                title: p.title,
                subtitle: p.summary,
                leading: Icon(Icons.play_circle_outline, color: scheme.onSurfaceVariant),
                trailing: const Icon(Icons.north_east, size: 18),
                onTap: () => launchUrl(p.url, mode: LaunchMode.externalApplication),
              ),
              const Divider(height: 1),
            ],
          ],
        ]);
      },
    );
  }
}

/// ユーザーページ(ノーヒット): グレーの空タイル + 「このユーザーは存在しないようです。」
class _NoHit extends StatelessWidget {
  const _NoHit();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Container(height: 120, color: scheme.surfaceContainerLow),
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle)),
          const Spacer(),
          Container(width: 96, height: 32, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16))),
        ]),
      ),
      const SizedBox(height: 24),
      const Text('このユーザーは存在しないようです。', style: RasqTypography.bodySmall),
    ]);
  }
}
