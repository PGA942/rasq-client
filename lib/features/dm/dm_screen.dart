import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';

/// DMホーム (全て / フォロー中) — shares the 検索ヘッダー with the search tab.
class DmScreen extends ConsumerWidget {
  const DmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tabs = [const RasqTabItem('全て'), const RasqTabItem('フォロー中')];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'DM設定'),
          ]),
          const Padding(padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm), child: RasqSearchBar()),
          const Expanded(
            child: TabBarView(children: [
              RasqEmptyView(title: 'DMはありません', hint: 'アイテム行コンポーネント + DMルーム は M2'),
              RasqEmptyView(title: 'フォロー中のDMはありません'),
            ]),
          ),
        ]),
      ),
    );
  }
}
