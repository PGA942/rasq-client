import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../users/user_list.dart';
import 'notification_prefs.dart';

final notificationsProvider = FutureProvider<Page<NotificationItem>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  final page = await s.notifications(limit: 40);
  await ref.read(userListHelperProvider).primeRelationships(page.items.expand((n) => n.actors.map((a) => a.id)));
  return page;
});

/// 未読の通知数(現在の SNS アカウント分)。RASQ アカウント FOW の左端バッジ
/// (D-138)が使う。取得前・未ログインは 0。
final unreadNotificationCountProvider = Provider<int>((ref) => ref.watch(notificationsProvider).value?.items.where((n) => !n.read).length ?? 0);

/// 通知 (すべて / フォロー中). 4 tile types (アクション系 / フォロー系 / 投稿タイル系 / タイマー系),
/// 長押しドロップダウン(一括既読・通知オフ)は下ナビ側、⚙ = 通知プロファイル設定.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tabs = [const RasqTabItem('すべて'), const RasqTabItem('フォロー中')];
    final items = ref.watch(notificationsProvider);
    final prefs = ref.watch(notificationPrefsProvider);
    final viewer = ref.watch(currentAccountProvider);
    final follows = ref.watch(followStateProvider);
    bool isFollowed(UserSummary u) => viewer != null && (follows[followKey(viewer.key, '${viewer.kind.name}:${viewer.instance}:${u.id}')]?.following ?? false);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () => showNotificationPrefs(ref), tooltip: '通知プロファイル設定'),
          ]),
          Expanded(
            child: TabBarView(children: [
              _List(items: items.whenData((p) => p.items.where((n) => prefs.isOn(n.kind)).toList()), onRefresh: () => ref.refresh(notificationsProvider.future)),
              _List(items: items.whenData((p) => p.items.where((n) => prefs.isOn(n.kind) && n.actors.any(isFollowed)).toList()), onRefresh: () => ref.refresh(notificationsProvider.future), emptyTitle: 'フォロー中の通知はありません'),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 通知プロファイル設定 (bottom sheet): tabs すべて/フォロー中/通知オン + toggles + 通知専用のアクセストークン.
Future<void> showNotificationPrefs(WidgetRef ref) {
  final manager = ref.read(overlayManagerProvider);
  return manager.showBottomSheet<void>(
    id: 'notifications.prefs',
    title: '通知プロファイル設定',
    cancelText: null,
    confirmText: '閉じる',
    builder: (ctx) => Consumer(builder: (ctx, r, _) {
      final prefs = r.watch(notificationPrefsProvider);
      final store = r.read(notificationPrefsProvider.notifier);
      return ListView(shrinkWrap: true, children: [
        RasqSwitchListTile(title: '通知オン', value: prefs.enabled, onChanged: store.setEnabled),
        for (final row in notificationPrefRows)
          RasqSwitchListTile(
            title: row.$1,
            value: row.$2.every(prefs.isOn),
            onChanged: (v) {
              for (final k in row.$2) {
                store.setKind(k, v);
              }
            },
          ),
        RasqListTile(title: '通知専用のアクセストークン', onTap: () {}),
        const SizedBox(height: 8),
      ]);
    }),
  );
}

/// 下ナビ 通知/DM ボタン長押し: 全ての通知を既読 / フォロー中の通知を既読 / 通知オフ.
Future<void> showNotificationQuickMenu(WidgetRef ref, Rect anchor) async {
  final manager = ref.read(overlayManagerProvider);
  final pick = await manager.showDropdown<String>(id: 'notifications.quick', anchor: anchor, items: const [
    RasqDropdownItem('全ての通知を既読', 'readAll'),
    RasqDropdownItem('フォロー中の通知を既読', 'readFollowing'),
    RasqDropdownItem('通知オフ', 'off'),
  ]);
  switch (pick) {
    case 'readAll' || 'readFollowing':
      await ref.read(currentSnsSessionProvider)?.markNotificationsRead();
      ref.invalidate(notificationsProvider);
    case 'off':
      ref.read(notificationPrefsProvider.notifier).setEnabled(false);
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.onRefresh, this.emptyTitle = '通知はありません'});
  final AsyncValue<List<NotificationItem>> items;
  final Future<void> Function() onRefresh;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) => items.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: onRefresh, retryLabel: '再読み込み'),
        data: (list) => RefreshIndicator(
          onRefresh: onRefresh,
          child: list.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 120), RasqEmptyView(title: emptyTitle)])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => NotificationTile(item: list[i]),
                ),
        ),
      );
}

/// 通知アイテム(4種) — 原典: UI_Elements「通知アイテム（4種）」.
class NotificationTile extends ConsumerWidget {
  const NotificationTile({super.key, required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bg = item.read ? null : scheme.primaryContainer.withValues(alpha: 0.25);
    final child = switch (item.kind.tile) {
      NotificationTileType.action => _ActionTile(item: item),
      NotificationTileType.follow => _FollowTile(item: item),
      NotificationTileType.postTile => _PostTile(item: item),
      NotificationTileType.timer => _TimerTile(item: item),
      NotificationTileType.system => _SystemTile(item: item),
    };
    return InkWell(
      onTap: () {
        if (item.post != null) {
          context.pushPost(item.post!);
        } else if (item.kind == NotificationKind.followRequest) {
          context.pushFollowRequests();
        } else if (item.actors.isNotEmpty) {
          context.pushUser(item.actors.first);
        }
      },
      child: Container(color: bg, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md), child: child),
    );
  }
}

/// システム通知 (D-045): サーバー/アプリ発の見出し + 本文。actors に依存しない。
class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.campaign_outlined, color: scheme.primary, size: 24),
      const SizedBox(width: RasqSpacing.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title ?? 'システム通知', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          if (item.body != null && item.body!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.body!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      const SizedBox(width: RasqSpacing.sm),
      RasqTimestamp(item.createdAt),
    ]);
  }
}

String _names(List<UserSummary> actors) {
  if (actors.isEmpty) return '';
  final shown = actors.take(2).map((a) => '${a.displayName}さん').join('、');
  final rest = actors.length - 2;
  return rest > 0 ? '$shownと他$rest人' : shown;
}

/// アクション系: アイコンリスト(グループアバター) + 本文(DSL) + 投稿の省略.
class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final emojis = ref.watch(emojiCacheProvider);
    final (icon, color, verb) = switch (item.kind) {
      NotificationKind.reaction => (Icons.add_reaction, tokens.live, 'あなたの投稿にリアクションしました'),
      NotificationKind.repost => (Icons.repeat, tokens.inVc, 'あなたの投稿をリノートしました'),
      NotificationKind.pollEnded => (Icons.poll, scheme.primary, '投票が終了しました'),
      _ => (Icons.notifications_none, scheme.onSurfaceVariant, '通知'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: RasqSpacing.md),
        if (item.actors.isNotEmpty) RasqGroupAvatar(users: item.actors, size: RasqSizes.avatarMd, maxVisible: 3),
        const Spacer(),
        RasqTimestamp(item.createdAt),
        RasqIconButton(icon: Icons.more_horiz, size: 18, onPressed: () {}, tooltip: 'メニュー'),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 24 + RasqSpacing.md, top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RasqRichText([RasqTextSpan(_names(item.actors), bold: true), RasqTextSpan('が$verb')], style: RasqTypography.bodySmall),
          if (item.reactionsByActor.isNotEmpty || item.reaction != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(spacing: 4, children: [for (final r in (item.reactionsByActor.isNotEmpty ? item.reactionsByActor.values : [item.reaction!]).toSet()) _Reaction(r, emojis)]),
            ),
          if (item.post != null) Padding(padding: const EdgeInsets.only(top: 2), child: RasqRichText(InlineSpans.parse(item.post!.body, emojis: emojis), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ]);
  }
}

class _Reaction extends StatelessWidget {
  const _Reaction(this.r, this.emojis);
  final String r;
  final Map<String, Uri?> emojis;
  @override
  Widget build(BuildContext context) {
    if (r.startsWith(':')) {
      final url = emojis[r.substring(1, r.length - 1).replaceAll('@.', '')];
      return url == null ? Text(r, style: RasqTypography.caption) : Image.network(url.toString(), height: 18, errorBuilder: (_, _, _) => Text(r, style: RasqTypography.caption));
    }
    return Text(r, style: const TextStyle(fontSize: 16));
  }
}

/// フォロー/リスト追加系: material icon + ユーザーアイコン + フォローボタン.
class _FollowTile extends ConsumerWidget {
  const _FollowTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final viewer = ref.watch(currentAccountProvider);
    final u = item.actors.firstOrNull;
    final (icon, text) = switch (item.kind) {
      NotificationKind.follow => (Icons.person_add_alt_1, 'にフォローされました'),
      NotificationKind.followRequest => (Icons.person_add_alt_1_outlined, 'からフォロー申請が届きました'),
      NotificationKind.followAccepted => (Icons.how_to_reg, 'がフォローを承認しました'),
      _ => (Icons.playlist_add, 'がリストに追加しました'),
    };
    final st = (u == null || viewer == null) ? const FollowState() : ref.watch(followStateOfProvider((viewer: viewer.key, user: '${viewer.kind.name}:${viewer.instance}:${u.id}')));
    return Row(children: [
      Icon(icon, color: scheme.primary, size: 24),
      const SizedBox(width: RasqSpacing.md),
      if (u != null) RasqAvatar(imageUrl: u.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: u.displayName),
      const SizedBox(width: RasqSpacing.sm),
      Expanded(child: RasqRichText([RasqTextSpan(u?.displayName ?? '', bold: true), RasqTextSpan(text)], style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
      if (u != null && item.kind != NotificationKind.followRequest) RasqTogglePillButton(label: 'フォロー', activeLabel: 'フォロー中', active: st.following, onPressed: () => ref.read(userListHelperProvider).toggleFollow(u)),
      if (item.kind == NotificationKind.followRequest) const Icon(Icons.chevron_right),
    ]);
  }
}

/// 投稿タイル系(返信・引用・メンション): 省略表示コンポーネント内包 → PostRow をそのまま.
class _PostTile extends ConsumerWidget {
  const _PostTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = item.post;
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final label = switch (item.kind) { NotificationKind.reply => '返信', NotificationKind.quote => '引用', _ => 'メンション' };
    if (p == null) return Text(label, style: RasqTypography.bodySmall);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.subdirectory_arrow_left, size: 16, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text(label, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))]),
      Padding(
        padding: const EdgeInsets.only(left: 0),
        child: PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args), onTap: () => context.pushPost(p), dense: true, compactQuote: true),
      ),
    ]);
  }
}

/// タイマー通知: 投稿カード(埋め込みサイズ)を内包 (VC開始 / タイマー付きブックマーク).
class _TimerTile extends StatelessWidget {
  const _TimerTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.bookmark, color: RasqColors.accent, size: 24),
      const SizedBox(width: RasqSpacing.md),
      Expanded(child: Text(item.kind == NotificationKind.vc ? 'ブックマークしたVCが始まります！' : 'タイマー付きブックマーク', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurface))),
    ]);
  }
}
