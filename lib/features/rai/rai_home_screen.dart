import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../shell/headers.dart';
import 'rai_overlay.dart';
import 'rai_providers.dart';
import 'rai_widgets.dart';

/// RAi ホーム (D-179、ワイヤーフレーム p.4): マスコット + 「マクロとか、お任せください！」+
/// 直近の質問。開くと RAi バー(アシスタントモード)が出る。マクロ / チャット履歴は第二期。
class RaiHomeScreen extends ConsumerStatefulWidget {
  const RaiHomeScreen({super.key});
  @override
  ConsumerState<RaiHomeScreen> createState() => _RaiHomeScreenState();
}

class _RaiHomeScreenState extends ConsumerState<RaiHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRai(ref, mode: RaiMode.assistant);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(raiProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: 'RAi', onBack: () => Navigator.of(context).maybePop()),
      body: ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xl, RasqSpacing.page, 160), children: [
        const Center(child: RaiMascot(size: 180)),
        const SizedBox(height: RasqSpacing.md),
        Text('マクロとか、お任せください！', textAlign: TextAlign.center, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        Text('インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント / マクロ: 第二期(LLM 接続)。', textAlign: TextAlign.center, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (s.history.isNotEmpty) ...[
          const RasqSectionHeader(title: '最近の質問', topMargin: RasqSpacing.xl),
          for (final h in s.history)
            RasqListTile(
              title: h,
              leading: Icon(Icons.history, size: 20, color: scheme.onSurfaceVariant),
              chevron: false,
              onTap: () {
                showRai(ref, mode: RaiMode.instruction);
                ref.read(raiProvider.notifier).ask(h);
              },
            ),
        ],
      ]),
    );
  }
}
