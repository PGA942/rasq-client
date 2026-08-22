import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';

/// 検索ホーム: 広告枠(AdSlot 固定位置) / トレンド / Today. M0 = layout only.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: RasqSearchHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
      body: ListView(children: [
        // AdSlot — renderer-owned insertion point (検索ホーム固定位置).
        Container(
          height: 200,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            color: scheme.surfaceContainerHighest,
            child: Text('広告', style: TextStyle(fontSize: 28, color: scheme.onSurfaceVariant)),
          ),
        ),
        RasqSectionHeader(title: 'トレンド', trailing: RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'トレンド設定')),
        const RasqListTile(title: 'ストラトローンチ', subtitle: '117 Post   発射  バルバトスⅢ  周回軌道', chevron: false, trailing: Icon(Icons.more_horiz, size: 18)),
        const RasqListTile(title: '映画化', subtitle: '42 Post   コーヒー道  シードスタディオ', chevron: false, trailing: Icon(Icons.more_horiz, size: 18)),
        const RasqListTile(title: '新定理', subtitle: '25 Post   ブラックホール  情報もつれ', chevron: false, trailing: Icon(Icons.more_horiz, size: 18)),
        const RasqSectionHeader(title: 'Today'),
        const RasqEmptyView(title: 'Today', hint: 'トレンドプロバイダー (M5)'),
      ]),
    );
  }
}
