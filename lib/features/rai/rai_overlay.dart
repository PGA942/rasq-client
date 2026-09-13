import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import 'rai_space.dart';
import 'rai_providers.dart';
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
        // 曖昧な質問の選択肢 (D-194): 吹き出しの上のタイル。
        if (s.choices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: RasqSpacing.xs),
            child: Material(
              type: MaterialType.transparency,
              child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, alignment: WrapAlignment.center, children: [
                for (final c in s.choices)
                  ActionChip(key: ValueKey('rai.choice.${c.id}'), label: Text(c.index, style: RasqTypography.bodySmall), backgroundColor: Theme.of(context).colorScheme.surface, onPressed: () => n.pick(c.id)),
              ]),
            ),
          ),
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
        onSuggest: n.suggest,
        modelLabel: ref.watch(raiLlmProvider).spec.codename,
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
  /// 指差し時の大きさ (D-192: 150〜200 px)。移動の中ほどは再接近の奥行き(最大 700 px)へ寄る。
  static const mascot = raiPointSize;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  /// レイヤーのローカル座標系(グローバル → ローカルの変換に使う。2 カラムやホストの余白でずれないように、D-197)。
  final _layerKey = GlobalKey();

  RaiArm _yawArmFrom = RaiArm.none;

  /// 走行の顔(連続な角度、D-198)。
  double _face = 0;

  /// 静止位置は右下 / 左下 (D-192): 直前に指した部品が右半分なら左下、それ以外は右下。
  bool _restLeft = false;

  /// 3 次元スプライン (D-197) と、いまの画面上の位置(ローカル座標)。
  RaiPath3? _path;
  Offset? _pos;
  Rect? _lastTarget;
  RaiMode? _lastMode;
  RaiProjector? _projector;

  /// 3D: 移動の計画(起動 / 走行 / 停止、腕の側)と進み具合、推論中の一時停止、空間の位置。
  final _ctrl3d = RaiMascot3dController();
  bool _pausedByBusy = false;

  Rect? _downOnTarget;

  /// 指差した部品へのタップを見張る (D-193): どのウィジェットが処理しても届くグローバルな経路。
  void _onPointer(PointerEvent e) {
    final t = ref.read(raiProvider).target;
    if (t == null) {
      _downOnTarget = null;
      return;
    }
    final hit = t.inflate(4);
    if (e is PointerDownEvent) {
      _downOnTarget = hit.contains(e.position) ? hit : null;
    } else if (e is PointerUpEvent) {
      final down = _downOnTarget;
      _downOnTarget = null;
      if (down != null && hit.contains(e.position)) ref.read(raiProvider.notifier).targetTapped();
    } else if (e is PointerCancelEvent) {
      _downOnTarget = null;
    }
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _anim.addListener(_onFrame);
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed && _path != null) {
        _pos = _path!.to;
        _ctrl3d.finish();
        _onFrame();
      }
    });
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _anim.dispose();
    _ctrl3d.dispose();
    super.dispose();
  }

  /// グローバル矩形 → このレイヤーのローカル矩形。
  Rect _toLocal(Rect global) {
    final box = _layerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  Offset _destination(RaiState s, Size screen, Rect? localTarget) {
    if (s.mode == RaiMode.assistant || localTarget == null) {
      // 右下 / 左下(バーの上)。
      final x = _restLeft ? mascot / 2 + RasqSpacing.md : screen.width - mascot / 2 - RasqSpacing.md;
      return Offset(x, screen.height - 180 - mascot * 0.7);
    }
    _restLeft = localTarget.center.dx > screen.width / 2;
    return raiAnchorFor(localTarget, screen, mascot: mascot);
  }

  void _moveTo(Offset dest, RaiState s, Size screen, Rect? localTarget) {
    final proj = _projector!;
    final from = _pos ?? dest;
    final armTo = raiArmFor(dest, s.mode == RaiMode.instruction ? localTarget : null);
    if ((from - dest).distance < 1) {
      _pos = dest;
      _path = null;
      _ctrl3d.idle(armTo);
      _onFrame();
      return;
    }
    // 起動 / 停止だけか、走行を挟むか(距離が画面幅 / カラム幅の半分以上)。
    final plan = planRaiMotion(from: from, to: dest, columnWidth: math.min(screen.width, raiPanelWidth(context)), centerX: screen.width / 2, armFrom: _ctrl3d.arm, armTo: armTo);
    // 3 次元スプライン (D-197): 両端は待機の奥行き、途中は再接近の奥行き。同サイドの長距離はリボン。
    _path = RaiPath3(projector: proj, from: from, to: dest, restSize: mascot, approachSize: raiApproachSizeFor(screen), ribbon: plan.long && !plan.crossesCenter);
    _yawArmFrom = _ctrl3d.arm;
    _face = raiRestYawFor(_ctrl3d.arm);
    _ctrl3d.start(plan);
    _anim.duration = raiMoveDuration(distance: (dest - from).distance, columnWidth: math.min(screen.width, raiPanelWidth(context)), long: plan.long);
    _anim.forward(from: 0);
  }

  /// 1 フレームぶんの位置 / 向きを空間の座標で計算してコントローラーへ (D-197)。
  /// 3D はウィジェットを動かさずモデルだけ動く。2D の代替描画のときだけ再構築する。
  void _onFrame() {
    final proj = _projector;
    if (proj == null) return;
    final path = _path;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    final moving = _anim.isAnimating && path != null;
    final plan = _ctrl3d.plan;
    _ctrl3d.advance(t);
    RaiVec3 world;
    Offset tangent2d;
    if (moving) {
      final stopStart = plan == null ? 1.0 : 1 - plan.steps.last.fraction;
      final clockwise = path.to.dx >= path.from.dx;
      // 円運動は停止時の角度補正のときだけ (D-197)。
      RaiVec3 at(double u) => path.at(u) + raiStopLoop3(u, stopStart: stopStart, projector: proj, restSize: mascot, radiusPx: mascot * 0.25, clockwise: clockwise);
      world = at(t);
      tangent2d = proj.project(at((t + 0.01).clamp(0, 1))).px - proj.project(at((t - 0.01).clamp(0, 1))).px;
    } else {
      world = proj.worldAt(_pos ?? Offset(proj.screen.width / 2, proj.screen.height / 2), mascot);
      tangent2d = Offset.zero;
    }
    // 回転は地面に垂直な軸まわりで途切れなく (D-198): 走行の顔を直前のフレームから連続に追う。
    if (moving && tangent2d.distance > 0.01) _face = raiFaceYawNear(tangent2d, _face, arm: plan?.armTo ?? _ctrl3d.arm);
    final yaw = raiYawAt(moving ? t : 1, plan: plan, tangent: tangent2d, armFrom: _yawArmFrom, armTo: plan?.armTo ?? _ctrl3d.arm, face: _face, stopTurn: (path != null && path.to.dx >= path.from.dx) ? -1 : 1);
    final p = proj.project(world);
    _ctrl3d.setFrame(world: world, yaw: yaw, screenPos: p.px, sizePx: p.sizePx);
    if (!ref.read(raiMascot3dProvider) && mounted) setState(() {});
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
    final three = ref.watch(raiMascot3dProvider);
    if (s.bubble == null) {
      return const SizedBox.shrink();
    }
    _projector ??= RaiProjector(screen: screen);
    if (_projector!.screen != screen) _projector = RaiProjector(screen: screen);
    final proj = _projector!;
    final localTarget = s.target == null ? null : _toLocal(s.target!);
    _syncBusy(s.busy);
    if (s.target != _lastTarget || s.mode != _lastMode || _pos == null) {
      _lastTarget = s.target;
      _lastMode = s.mode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lt = s.target == null ? null : _toLocal(s.target!);
        setState(() => _moveTo(_destination(s, screen, lt), s, screen, lt));
      });
    }
    final dest = _destination(s, screen, localTarget);
    final moving = _anim.isAnimating && _path != null;
    // 2D の代替描画: 空間の位置を射影した点と大きさに置く。
    final pos = moving ? _ctrl3d.screenPos : (_pos ?? dest);
    final size = moving ? _ctrl3d.sizePx : mascot;
    final pointing = localTarget == null ? null : pointingDirection(pos, localTarget.center);
    return SizedBox(
      key: _layerKey,
      width: screen.width,
      height: screen.height,
      child: Stack(children: [
        // 目標の部品をハイライト(インストラクション)。
        if (localTarget != null && s.mode == RaiMode.instruction)
          Positioned.fromRect(
            rect: localTarget.inflate(6),
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: RasqColors.accent, width: 2), borderRadius: BorderRadius.circular(RasqSizes.radiusSm))),
            ),
          ),
        if (three)
          // 空間モード (D-197): 画面いっぱいの固定ウィジェット。モデルだけが動く。
          Positioned.fill(child: IgnorePointer(child: RaiMascot3d.scene(controller: _ctrl3d, projector: proj, outline: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.85) : null)))
        else
          Positioned(
            left: pos.dx - size / 2,
            top: pos.dy - size * 0.625,
            child: IgnorePointer(child: RaiMascot(size: size, pointing: pointing, controller3d: _ctrl3d)),
          ),
      ]),
    );
  }
}
