import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';

/// 通知 (すべて / フォロー中). Long-press dropdown (一括既読・通知オフ) is wired
/// through the Overlay Manager in M2 together with the 4 notification tiles.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tabs = [const RasqTabItem('すべて'), const RasqTabItem('フォロー中')];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: '通知プロファイル設定'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              RasqEmptyView(title: '通知はありません', hint: '通知タイル4種は M2'),
              RasqEmptyView(title: 'フォロー中の通知はありません'),
            ]),
          ),
        ]),
      ),
    );
  }
}
