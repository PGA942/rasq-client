import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';


import '../../shell/headers.dart';
import 'rai_layout.dart';
import 'rai_motion.dart';
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
      // 大画面はコラム形式 (D-185): 入力ウィジェットと同じ幅の列を中央に。
      body: Center(
        child: SizedBox(
          width: raiPanelWidth(context) + RasqSpacing.page * 2,
          child: LayoutBuilder(builder: (context, c) {
            // スタンバイ (D-192): 大きな RAi を薄く敷き、その上に「マクロとか、お任せください！」。
            final screen = MediaQuery.sizeOf(context);
            final standby = raiApproachSize.clamp(raiPointSize, math.max(raiPointSize, math.min(c.maxWidth * 0.95, screen.height * 0.55))).toDouble();
            return Stack(children: [
              Positioned(top: RasqSpacing.md, left: 0, right: 0, child: IgnorePointer(child: Center(child: RaiMascot(key: const ValueKey('rai.home.mascot'), size: standby, opacity: 0.35)))),
              ListView(padding: EdgeInsets.fromLTRB(RasqSpacing.page, standby * 0.9, RasqSpacing.page, 240), children: [
                Text('マクロとか、お任せください！', textAlign: TextAlign.center, style: RasqTypography.title),
                const SizedBox(height: RasqSpacing.xs),
                Text('インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント: 端末内モデルで答えます。モデルはバーのチップから選べます(マクロは第二期)。', textAlign: TextAlign.center, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
            ]);
          }),
        ),
      ),
    );
  }
}
