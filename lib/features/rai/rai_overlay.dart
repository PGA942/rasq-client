import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/app_overlay_root.dart';
import 'rai_layout.dart';
import 'rai_llm.dart';
import 'rai_models_fow.dart';
import 'rai_mascot_3d.dart';
import 'rai_motion.dart';
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
    final llm = ref.watch(raiLlmStatusProvider).value ?? ref.read(raiLlmProvider).current;
    // フッター(タブ)の上に置く。キーボードが出ていればその上。
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final dock = insets > 0 ? insets : fowDockInsetOf(context, ref.read(routerProvider));
    final screen = MediaQuery.sizeOf(context);
    // 指差す部品がバーの後ろ(画面下)にあるときはバーを上(ヘッダーの下)へ逃がす。
    final t = s.target;
    final atTop = t != null && s.mode == RaiMode.instruction && t.bottom > screen.height - dock - 200;
    final speech = s.bubble == null
        ? null
        : RaiSpeech(
            key: const ValueKey('rai.speech'),
            line: s.currentLine ?? '…',
            index: s.lineIndex,
            count: s.lines.length,
            hasMore: s.hasMoreLines || (!s.busy && s.hasNext),
            streaming: s.busy,
            error: s.error,
            onNext: n.advance,
            onClose: n.dismissBubble,
            onHistory: () => n.toggleHistory(open: true),
          );
    final bar = SizedBox(
      width: raiPanelWidth(context),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // RAi の発言は入力ウィジェットの上に 1 行ずつ (D-182)。
        if (speech != null) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: speech),
        RaiBar(
        key: raiBarKey,
        state: s,
        onToggleExpanded: n.toggleExpanded,
        onMode: n.setMode,
        onSubmit: n.ask,
        onClose: () => hideRai(ref),
        onModelTap: () => showRaiModelsFow(ref, context),
        onHistoryToggle: n.toggleHistory,
        historyMaxHeight: screen.height * 0.45,
        llmNote: switch (llm.phase) {
          RaiLlmPhase.ready || RaiLlmPhase.generating => null,
          RaiLlmPhase.loading => '読み込み中',
          RaiLlmPhase.downloading => '${llm.progress ?? 0}%',
          RaiLlmPhase.notInstalled => '未DL',
          RaiLlmPhase.unavailable => '使えません',
        },
      ),
      ]),
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
  /// 指差し時の大きさ (D-192: 150〜200 px)。移動の手前再接近では [raiApproachSizeFor] まで大きくなる。
  static const mascot = raiPointSize;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  /// 静止位置は右下 / 左下 (D-192): 直前に指した部品が右半分なら左下、それ以外は右下。
  bool _restLeft = false;
  RaiPath? _path;
  Offset? _pos;
  Rect? _lastTarget;
  RaiMode? _lastMode;

  /// 3D (D-191): 移動の計画(起動 / 走行 / 停止、腕の側)と進み具合、推論中の一時停止。
  final _ctrl3d = RaiMascot3dController();
  bool _pausedByBusy = false;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      _ctrl3d.advance(Curves.easeInOutCubic.transform(_anim.value));
      setState(() {});
    });
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed && _path != null) {
        _pos = _path!.to;
        _ctrl3d.finish();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl3d.dispose();
    super.dispose();
  }

  Offset _destination(RaiState s, Size screen) {
    if (s.mode == RaiMode.assistant || s.target == null) {
      // 右下 / 左下(バーの上)。
      final x = _restLeft ? mascot / 2 + RasqSpacing.md : screen.width - mascot / 2 - RasqSpacing.md;
      return Offset(x, screen.height - 180 - mascot * 0.7);
    }
    _restLeft = s.target!.center.dx > screen.width / 2;
    return raiAnchorFor(s.target!, screen, mascot: mascot);
  }

  void _moveTo(Offset dest, RaiState s, Size screen) {
    final from = _pos ?? dest;
    final armTo = raiArmFor(dest, s.mode == RaiMode.instruction ? s.target : null);
    if ((from - dest).distance < 1) {
      _pos = dest;
      _ctrl3d.idle(armTo);
      return;
    }
    _path = RaiPath(from: from, to: dest);
    // 起動 / 停止だけか、走行を挟むか(距離が画面幅 / カラム幅の半分以上)。
    final plan = planRaiMotion(from: from, to: dest, columnWidth: math.min(screen.width, raiPanelWidth(context)), centerX: screen.width / 2, armFrom: _ctrl3d.arm, armTo: armTo);
    _ctrl3d.start(plan);
    _anim.duration = raiMoveDuration(distance: (dest - from).distance, columnWidth: math.min(screen.width, raiPanelWidth(context)), long: plan.long);
    _anim.forward(from: 0);
  }

  /// LLM の推論中はアニメーションを止める(クリップも移動も)。終わったら続きから。
  void _syncBusy(bool busy) {
    if (busy == _pausedByBusy) return;
    _pausedByBusy = busy;
    _ctrl3d.paused = busy;
    if (busy) {
      if (_anim.isAnimating) _anim.stop();
    } else if (_path != null && _anim.value < 1 && !_anim.isAnimating) {
      _anim.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(raiProvider);
    final screen = MediaQuery.sizeOf(context);
    if (s.bubble == null) {
      return const SizedBox.shrink();
    }
    final dest = _destination(s, screen);
    _syncBusy(s.busy);
    if (s.target != _lastTarget || s.mode != _lastMode || _pos == null) {
      _lastTarget = s.target;
      _lastMode = s.mode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _moveTo(dest, s, screen));
      });
    }
    final path = _path;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    final moving = _anim.isAnimating && path != null;
    final pos = moving ? path.at(t) : (_pos ?? dest);
    final velocity = moving ? (path.at((t + 0.02).clamp(0, 1)) - pos) : Offset.zero;
    final tilt = moving ? (velocity.dx / (velocity.distance + 0.001)) * 0.18 : 0.0;
    final pointing = s.target == null ? null : pointingDirection(pos, s.target!.center);
    // 手前再接近 (D-192): 移動の中ほどで大きく(最大 700 px、画面に収まる範囲)。
    final size = moving ? raiSizeAt(t, approach: raiApproachSizeFor(screen)) : mascot;
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
          left: pos.dx - size / 2,
          top: pos.dy - size * 0.625,
          child: IgnorePointer(child: RaiMascot(size: size, tilt: tilt, pointing: pointing, controller3d: _ctrl3d)),
        ),
      ]),
    );
  }
}
