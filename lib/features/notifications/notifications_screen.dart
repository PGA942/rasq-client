import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../settings/settings_dsl.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../../shell/scroll_memory.dart';
import '../../shell/rasq_shell.dart';
import '../../text/inline_spans.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../users/user_list.dart';
import '../vc/astell_actions.dart';
import '../vc/astell_bookmarks.dart';
import '../vc/astell_links.dart';
import 'notification_prefs.dart';

final notificationsProvider = FutureProvider<Page<NotificationItem>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  // チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): 通知に付いてくる投稿(返信 / メンション / 引用の本文、
  // リアクションされた投稿)にも、ホームと同じ保護者の表示制限を掛ける。見せない投稿は外し、通知そのものは残す。
  final gate = ref.watch(childGateProvider);
  final page = await s.notifications(limit: 40);
  await ref.read(userListHelperProvider).primeRelationships(page.items.expand((n) => n.actors.map((a) => a.id)));
  return gate.supervised ? Page(items: gate.filterNotifications(page.items), nextCursor: page.nextCursor) : page;
});

/// 未読の通知数(現在の SNS アカウント分)。RASQ アカウント FOW の左端バッジ
/// (D-138)が使う。取得前・未ログインは 0。
final unreadNotificationCountProvider = Provider<int>((ref) => ref.watch(notificationsProvider).value?.items.where((n) => !n.read).length ?? 0);

/// 通知 (すべて / フォロー中). 4 tile types (アクション系 / フォロー系 / 投稿タイル系 / タイマー系),
/// 長押しドロップダウン(一括既読・通知オフ)は下ナビ側、⚙ = 通知プロファイル設定.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.headerTrailing});

  /// ヘッダー右端の ↑(まだ押せない)の代わりに置く部品。第3カラムに出すときは第3カラムの設定ボタン (D-397)。
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    // RASQ の通知 (D-285): メンション / 返信 / 引用 / AsTell での引用。RASQ アカウントにログインしているときだけタブが出る。
    final rasq = ref.watch(orgateAccountProvider).value != null;
    final tabs = [const RasqTabItem('すべて'), const RasqTabItem('フォロー中'), if (rasq) const RasqTabItem('RASQ')];
    final items = ref.watch(notificationsProvider);
    final prefs = ref.watch(notificationPrefsProvider);
    final viewer = ref.watch(currentAccountProvider);
    final follows = ref.watch(followStateProvider);
    bool isFollowed(UserSummary u) => viewer != null && (follows[followKey(viewer.key, '${viewer.kind.name}:${viewer.instance}:${u.id}')]?.following ?? false);

    // 通知の表示形式 (D-238、設定 `appearance.notifications`): 最初に開くタブと、開始通知の予定の欄。
    final startFollowing = settingValue(ref, 'appearance.notifications', 'defaultTab', 'all') == 'following';
    final showReminders = settingValue(ref, 'appearance.notifications', 'showReminders', true) != false;
    return DefaultTabController(
      length: tabs.length,
      initialIndex: startFollowing && tabs.length > 1 ? 1 : 0,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref), trailing: headerTrailing),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () => showNotificationPrefs(ref), tooltip: '通知プロファイル設定'),
          ]),
          // 登録した開始通知 (D-160): 端末のローカル通知に入れた予定。
          if (showReminders) const _AstellReminders(),
          Expanded(
            child: TabBarView(children: [
              _List(memoryId: 'notifications.all', items: items.whenData((p) => p.items.where((n) => prefs.isOn(n.kind)).toList()), onRefresh: () => ref.refresh(notificationsProvider.future)),
              _List(memoryId: 'notifications.following', items: items.whenData((p) => p.items.where((n) => prefs.isOn(n.kind) && n.actors.any(isFollowed)).toList()), onRefresh: () => ref.refresh(notificationsProvider.future), emptyTitle: 'フォロー中の通知はありません'),
              if (rasq) const _RasqNotices(),
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
        RasqListTile(title: 'プッシュ通知の受け取り', detail: '通知専用のアクセストークン', onTap: () {
            ref.read(overlayManagerProvider).close('notifications.prefs');
            ref.read(routerProvider).push(Routes.settingsNotifyToken);
          }),
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
  const _List({required this.memoryId, required this.items, required this.onRefresh, this.emptyTitle = '通知はありません'});

  /// 位置を覚える一覧の名前 (D-504): タブを切り替えて戻っても / 第3カラムで作り直されても、前の位置から。
  final String memoryId;
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
              : RememberScroll(
                  id: memoryId,
                  builder: (context, controller) => ListView.separated(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => NotificationTile(item: list[i]),
                  ),
                ),
        ),
      );
}

/// 登録済みの AsTell 開始通知 (D-160): タップでルームへ、右端で解除。
class _AstellReminders extends ConsumerWidget {
  const _AstellReminders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(astellRemindersProvider).value ?? const <AstellReminder>[];
    if (reminders.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const RasqSectionHeader(title: '開始通知を登録した VC', topMargin: 0),
      for (final r in reminders)
        RasqListTile(
          title: r.title,
          subtitle: '開催予定 ${formatAstellSchedule(r.at)}',
          leading: const Icon(Icons.notifications_active, color: RasqColors.accent),
          trailing: TextButton(
            onPressed: () async {
              final room = await ref.read(astellRoomProvider(r.roomId).future);
              if (!context.mounted) return;
              if (room != null) {
                await remindAstellRoom(context, ref, room);
              } else {
                await ref.read(localNotifierCancelProvider)(r);
              }
            },
            child: const Text('解除'),
          ),
          chevron: false,
          onTap: () async {
            final room = await ref.read(astellRoomProvider(r.roomId).future);
            if (room != null && context.mounted) await openAstellRoomTile(context, ref, room);
          },
        ),
      const Divider(height: 1),
    ]);
  }
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
          context.pushUser(item.actors.first, account: item.account.key);
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

/// 通知のアイコンを押した (D-449): その人のページへ。何人もいれば、名前から選ぶ。
/// [account] = 通知を受けたアカウント(人の id はそのサーバーのもの、D-469)。
Future<void> openNotificationActor(BuildContext context, WidgetRef ref, List<UserSummary> actors, {String? account}) async {
  if (actors.isEmpty) return;
  if (actors.length == 1) return context.pushUser(actors.first, account: account);
  final box = context.findRenderObject() as RenderBox;
  final pick = await ref.read(overlayManagerProvider).showDropdown<int>(id: 'notif.actors', anchor: box.localToGlobal(Offset.zero) & box.size, dense: true, items: [
    for (var i = 0; i < actors.length; i++) RasqDropdownItem(actors[i].displayName.isEmpty ? '@${actors[i].account.handle}' : actors[i].displayName, i),
  ]);
  if (pick != null && context.mounted) context.pushUser(actors[pick], account: account);
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
        // アイコンからその人のページへ (D-449)。何人もいれば選ぶ。
        if (item.actors.isNotEmpty)
          Builder(
            builder: (bctx) => GestureDetector(
              key: ValueKey('notif.avatar.${item.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openNotificationActor(bctx, ref, item.actors, account: item.account.key),
              child: RasqGroupAvatar(users: item.actors, size: RasqSizes.avatarMd, maxVisible: 3),
            ),
          ),
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
      return url == null ? Text(r, style: RasqTypography.caption) : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, url.toString(), height: 18, errorBuilder: (_, _, _) => Text(r, style: RasqTypography.caption));
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
      if (u != null) RasqAvatar(key: ValueKey('notif.avatar.${item.id}'), imageUrl: u.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: u.displayName, onTap: () => context.pushUser(u, account: item.account.key)),
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

/// RASQ の通知の一覧 (D-285)。押すと、その投稿のスレッドへ。
class _RasqNotices extends ConsumerWidget {
  const _RasqNotices();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(rasqNoticesProvider);
    final gate = ref.watch(childGateProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(rasqNoticesProvider.future),
      child: notices.when(
        loading: () => const RasqLoading(),
        error: (e, _) => ListView(children: [const SizedBox(height: 120), RasqEmptyView(title: '読み込めませんでした', hint: '$e')]),
        data: (list) => list.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), RasqEmptyView(title: 'RASQ の通知はありません', hint: 'メンション / 返信 / 引用 / Swing の招待が届くと、ここに出ます')])
            : RememberScroll(
                id: 'notifications.rasq',
                builder: (context, controller) => ListView.separated(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final n = list[i];
                  return RasqListTile(
                    key: ValueKey('rasqNotice.${n.id}'),
                    leading: Stack(clipBehavior: Clip.none, children: [
                      // アイコンからその人の RASQ のページへ (D-449)。
                      RasqAvatar(
                        key: ValueKey('rasqNotice.${n.id}.avatar'),
                        imageUrl: n.actor?.avatarUrl,
                        size: RasqSizes.avatarSm,
                        fallbackLabel: n.actor?.label ?? 'R',
                        onTap: n.actor == null ? null : () => context.pushRasqAccount(n.actor!.handle),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: scheme.surface,
                          child: Icon(switch (n.kind) { 'post.mention' => Icons.alternate_email, 'post.reply' => Icons.reply, 'astell.quote' => Icons.graphic_eq, 'swing.invite' => Icons.groups, 'swing.notify' => Icons.waves, _ => Icons.format_quote }, size: 12, color: scheme.primary),
                        ),
                      ),
                    ]),
                    title: n.title,
                    // チャイルドセーフ (D-454、[9]): 抜粋が見せない内容なら出さない(開いた先の投稿は、詳細の側で止める)。
                    subtitle: gate.textHidden(n.body) ? null : n.body,
                    // Swing の通知 (D-424): その人の Swing のビューワーへ(招待ならプラグインのページから一緒に入る)。
                    onTap: n.isSwing && n.actor != null
                        ? () => context.push(Routes.swing(n.actor!.handle))
                        : n.postId == null
                            ? null
                            : () => context.push(Routes.rasqPost(n.postId!)),
                  );
                },
              ),
              ),
      ),
    );
  }
}
