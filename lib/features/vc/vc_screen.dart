import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';

/// グローバルVCホーム (おすすめ / トレンド / フォロー中). M0 = sections only.
class VcScreen extends ConsumerWidget {
  const VcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: RasqSearchHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
      body: ListView(children: [
        const RasqSectionHeader(title: 'おすすめ', topMargin: 0),
        SizedBox(
          height: 180,
          child: Center(child: RasqGradientButton(label: '見てみる', onPressed: () {}, height: 40)),
        ),
        RasqSectionHeader(title: 'トレンド', trailing: RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: '設定')),
        const RasqEmptyView(title: 'VCタイル', hint: 'AsTell (M5): 名前・タイトル・ざっくり要約・ジャンル・共有メディア'),
        RasqSectionHeader(title: 'フォロー中', trailing: RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: '設定')),
      ]),
    );
  }
}
