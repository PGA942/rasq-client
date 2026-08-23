import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../../text/inline_spans.dart';

final notificationsProvider = FutureProvider<Page<NotificationItem>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  return s.notifications(limit: 30);
});

/// 通知 (すべて / フォロー中). M1 shows a compact row per item; the 4 tile types,
/// grouping and the long-press dropdown (一括既読・通知オフ) are M2.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tabs = [const RasqTabItem('すべて'), const RasqTabItem('フォロー中')];
    final items = ref.watch(notificationsProvider);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: '通知プロファイル設定'),
          ]),
          Expanded(
            child: TabBarView(children: [
              _List(items: items, onRefresh: () => ref.refresh(notificationsProvider.future)),
              const RasqEmptyView(title: 'フォロー中の通知', hint: 'M2でフィルタを実装'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.onRefresh});
  final AsyncValue<Page<NotificationItem>> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => items.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: onRefresh, retryLabel: '再読み込み'),
        data: (page) => RefreshIndicator(
          onRefresh: onRefresh,
          child: page.items.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), RasqEmptyView(title: '通知はありません')])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => _Row(item: page.items[i]),
                ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final actor = item.actors.firstOrNull;
    final (icon, color, verb) = switch (item.kind) {
      NotificationKind.reaction => (Icons.add_reaction, tokens.live, 'リアクションしました ${item.reaction ?? ''}'),
      NotificationKind.repost => (Icons.repeat, tokens.inVc, 'リノートしました'),
      NotificationKind.quote => (Icons.format_quote, scheme.primary, '引用しました'),
      NotificationKind.reply => (Icons.subdirectory_arrow_left, scheme.primary, '返信しました'),
      NotificationKind.mention => (Icons.alternate_email, scheme.primary, 'メンションしました'),
      NotificationKind.follow => (Icons.person_add_alt_1, scheme.primary, 'フォローしました'),
      NotificationKind.followRequest => (Icons.person_add_alt_1_outlined, scheme.primary, 'フォロー申請が届きました'),
      NotificationKind.followAccepted => (Icons.how_to_reg, scheme.primary, 'フォローを承認しました'),
      NotificationKind.pollEnded => (Icons.poll, scheme.primary, '投票が終了しました'),
      _ => (Icons.notifications_none, scheme.onSurfaceVariant, '通知'),
    };
    return InkWell(
      onTap: item.post == null ? null : () => context.pushPost(item.post!),
      child: Container(
      color: item.read ? null : scheme.primaryContainer.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: RasqSpacing.md),
        if (actor != null) ...[RasqAvatar(imageUrl: actor.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: actor.displayName), const SizedBox(width: RasqSpacing.sm)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: RasqRichText([if (actor != null) RasqTextSpan(actor.displayName, bold: true), RasqTextSpan(actor == null ? verb : 'さんが$verb')], style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
              RasqTimestamp(item.createdAt),
            ]),
            if (item.post != null && item.post!.body.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: RasqRichText(InlineSpans.parse(item.post!.body), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
      ),
    );
  }
}
