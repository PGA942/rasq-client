import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/app_overlay_root.dart';
import 'rai_providers.dart';
import 'rai_spline.dart';
import 'rai_widgets.dart';

/// RAi のオーバーレイ (D-179): `rai` 層(常に最前面、バリア無し)にバーとマスコットを置く。
/// 画面を移っても残る(「入力欄のみ残したまま起動直前まで見ていたページへ移動」)。
const raiBarOverlayId = 'rai.bar';
const raiMascotOverlayId = 'rai.mascot';

/// RAi を出す(既に出ていればモードだけ合わせる)。
void showRai(WidgetRef ref, {RaiMode? mode, bool asking = false}) {
  final manager = ref.read(overlayManagerProvider);
  ref.read(raiProvider.notifier).open(mode: mode, asking: asking);
  if (manager.contains(raiBarOverlayId)) return;
  // バーが先(下)、マスコット + 吹き出しが後(上): 指差しがバーに隠れない。
  manager.show(RasqOverlayEntry(
    id: raiBarOverlayId,
    layer: OverlayLayer.rai,
    alignment: Alignment.bottomCenter,
    semanticsLabel: 'RAi バー',
    builder: (_, _) => const _RaiBarHost(),
  ));
  manager.show(RasqOverlayEntry(
    id: raiMascotOverlayId,
    layer: OverlayLayer.rai,
    alignment: Alignment.topLeft,
    semanticsLabel: 'RAi',
    builder: (_, _) => const RaiMascotLayer(),
  ));
}

void hideRai(WidgetRef ref) {
  final manager = ref.read(overlayManagerProvider);
  manager.close(raiBarOverlayId);
  manager.close(raiMascotOverlayId);
  ref.read(raiProvider.notifier).close();
}

class _RaiBarHost extends ConsumerWidget {
  const _RaiBarHost();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(raiProvider);
    final n = ref.read(raiProvider.notifier);
    // フッター(タブ)の上に置く。キーボードが出ていればその上。
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final dock = insets > 0 ? insets : fowDockInsetOf(context, ref.read(routerProvider));
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width;
    // 指差す部品がバーの後ろ(画面下)にあるときはバーを上(ヘッダーの下)へ逃がす。
    final t = s.target;
    final atTop = t != null && s.mode == RaiMode.instruction && t.bottom > screen.height - dock - 200;
    final bar = SizedBox(
      width: width < 560 ? width - RasqSpacing.sm * 2 : 520,
      child: RaiBar(
        state: s,
        onToggleExpanded: n.toggleExpanded,
        onMode: n.setMode,
        onAskTap: () => n.setAsking(!s.asking),
        onSubmit: n.ask,
        onClose: () => hideRai(ref),
      ),
    );
    return SizedBox.expand(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: atTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: atTop
              ? EdgeInsets.fromLTRB(RasqSpacing.sm, fowTopInsetOf(context) + RasqSpacing.sm, RasqSpacing.sm, 0)
              : EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, dock + RasqSpacing.sm + (insets > 0 ? 0 : MediaQuery.paddingOf(context).bottom)),
          child: bar,
        ),
      ),
    );
  }
}

/// マスコット層: 吹き出しがある間だけ描く。インストラクションは目標の部品の脇へ
/// スプラインで移動、アシスタントは中央固定。
class RaiMascotLayer extends ConsumerStatefulWidget {
  const RaiMascotLayer({super.key});
  @override
  ConsumerState<RaiMascotLayer> createState() => _RaiMascotLayerState();
}

class _RaiMascotLayerState extends ConsumerState<RaiMascotLayer> with SingleTickerProviderStateMixin {
  static const mascot = 72.0;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  RaiPath? _path;
  Offset? _pos;
  Rect? _lastTarget;
  RaiMode? _lastMode;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() {}));
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed && _path != null) _pos = _path!.to;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Offset _destination(RaiState s, Size screen) {
    if (s.mode == RaiMode.assistant || s.target == null) return Offset(screen.width / 2, screen.height * 0.42);
    return raiAnchorFor(s.target!, screen, mascot: mascot);
  }

  void _moveTo(Offset dest) {
    final from = _pos ?? dest;
    if ((from - dest).distance < 1) {
      _pos = dest;
      return;
    }
    _path = RaiPath(from: from, to: dest);
    _anim.duration = Duration(milliseconds: (350 + _path!.length * 0.6).clamp(350, 1100).round());
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(raiProvider);
    final screen = MediaQuery.sizeOf(context);
    if (s.bubble == null) {
      return const SizedBox.shrink();
    }
    final dest = _destination(s, screen);
    if (s.target != _lastTarget || s.mode != _lastMode || _pos == null) {
      _lastTarget = s.target;
      _lastMode = s.mode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _moveTo(dest));
      });
    }
    final path = _path;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    final moving = _anim.isAnimating && path != null;
    final pos = moving ? path.at(t) : (_pos ?? dest);
    final velocity = moving ? (path.at((t + 0.02).clamp(0, 1)) - pos) : Offset.zero;
    final tilt = moving ? (velocity.dx / (velocity.distance + 0.001)) * 0.18 : 0.0;
    final pointing = s.target == null ? null : pointingDirection(pos, s.target!.center);
    // 吹き出しは RAi の上(画面の下半分にいるとき。下の RAi バーと被らない)か下。横は画面内に収める。
    final bubbleW = (screen.width - 16).clamp(120.0, 300.0);
    final bubbleLeft = (pos.dx - bubbleW / 2).clamp(8.0, screen.width - bubbleW - 8);
    final above = pos.dy > screen.height * 0.45;
    final headTop = pos.dy - mascot * 0.625;
    final feet = pos.dy + mascot * 0.625;
    return SizedBox(
      width: screen.width,
      height: screen.height,
      child: Stack(children: [
        // 目標の部品をハイライト(インストラクション)。
        if (s.target != null && s.mode == RaiMode.instruction)
          Positioned.fromRect(
            rect: s.target!.inflate(6),
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: RasqColors.accent, width: 2), borderRadius: BorderRadius.circular(RasqSizes.radiusSm))),
            ),
          ),
        Positioned(
          left: pos.dx - mascot / 2,
          top: pos.dy - mascot * 0.625,
          child: IgnorePointer(child: RaiMascot(size: mascot, tilt: tilt, pointing: pointing)),
        ),
        if (!moving)
          Positioned(
            left: bubbleLeft,
            top: above ? null : feet + 8,
            bottom: above ? (screen.height - headTop + 8).clamp(8.0, screen.height - 80) : null,
            child: RaiBubble(
              text: s.bubble!,
              hasNext: s.hasNext,
              onNext: ref.read(raiProvider.notifier).next,
              onClose: ref.read(raiProvider.notifier).dismissBubble,
              maxWidth: bubbleW,
            ),
          ),
      ]),
    );
  }
}
