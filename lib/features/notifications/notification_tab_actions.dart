import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import 'notification_nodes.dart';

/// 通知のタブを足す (D-590): 雛形(空 / アカウントごと / 種類ごと)を選んで、構成を書いてからタブの並びの末尾へ。
/// 戻り値 = 足したタブのスコープ(やめたら null)。
Future<String?> addNotificationTab(WidgetRef ref, BuildContext context, Rect anchor) async {
  final manager = ref.read(overlayManagerProvider);
  final l10n = appL10n;
  final template = await manager.showDropdown<NotifTabTemplate>(id: 'notifications.addTab', anchor: anchor, dense: true, items: [
    RasqDropdownItem(l10n.notificationsTemplateAccount, NotifTabTemplate.account),
    RasqDropdownItem(l10n.notificationsTemplateKind, NotifTabTemplate.kind),
    RasqDropdownItem(l10n.notificationsTemplateEmpty, NotifTabTemplate.empty),
  ]);
  if (template == null) return null;
  var account = '';
  NotifKindGroup? group;
  var label = '';
  switch (template) {
    case NotifTabTemplate.account:
      final accounts = [for (final s in ref.read(usableSessionsProvider)) s.account];
      final picked = accounts.length == 1
          ? accounts.first
          : await manager.showDropdown<AccountId>(id: 'notifications.addTab.account', anchor: anchor, dense: true, items: [for (final a in accounts) RasqDropdownItem('$a', a)]);
      if (picked == null) return null;
      account = '$picked';
      label = '@${picked.handle}';
    case NotifTabTemplate.kind:
      group = await manager.showDropdown<NotifKindGroup>(id: 'notifications.addTab.kind', anchor: anchor, dense: true, items: [for (final g in NotifKindGroup.values) RasqDropdownItem(g.label(l10n), g)]);
      if (group == null) return null;
      label = group.label(l10n);
    case NotifTabTemplate.empty:
      label = l10n.notificationsTabCustomFallback;
  }
  if (!context.mounted) return null;
  final container = ProviderScope.containerOf(context, listen: false);
  final tabs = ref.read(notifTabsProvider);
  final tab = NotifTab(id: nextNotifTabId(tabs), label: label);
  await writeNotifConfig(container, ref.read(currentAccountProvider)?.key, tab.scope, notifTemplateConfig(template, account: account, group: group));
  await saveNotifTabs(container, [...tabs, tab]);
  return tab.scope;
}

