import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/app_overlay_root.dart';
import '../../shell/third_column.dart';
import 'rai_face.dart';
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

class _RaiBarHost extends ConsumerStatefulWidget {
  const _RaiBarHost();
  @override
  ConsumerState<_RaiBarHost> createState() => _RaiBarHostState();
}

class _RaiBarHostState extends ConsumerState<_RaiBarHost> {
  /// ドラッグ中のずれ (D-233)。離したら列スロット / 縦の比率に精算して保存。
  Offset _drag = Offset.zero;
  final _barKey = GlobalKey();

  void _onDragEnd(BuildContext context, List<FowColumnSlot> slots, double top, double bottom) {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      setState(() => _drag = Offset.zero);
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final center = rect.center;
    var column = 0;
    if (slots.isNotEmpty) {
      var bestD = double.infinity;
      for (var i = 0; i < slots.length; i++) {
        final d = (center.dx - (slots[i].x + slots[i].width / 2)).abs();
        if (d < bestD) {
          bestD = d;
          column = i;
        }
      }
    }
    final avail = (bottom - top - rect.height).clamp(1.0, double.infinity);
    final y = ((rect.top - top) / avail).clamp(0.0, 1.0);
    ref.read(raiBarPlacementProvider.notifier).set(RaiBarPlacement(column: column, y: y));
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(raiProvider);
    final n = ref.read(raiProvider.notifier);
    // RAi ホームのサイドバー (D-214) が開いている間は入力タイルを隠す。
    if (s.sidebarOpen) return const SizedBox.shrink(key: ValueKey('rai.bar.hidden'));
    // チャット (D-218): RAi ホームのアシスタントでは発言 / 選択肢はチャットの行に出る(バーの上には出さない)。
    final chat = ref.watch(raiChatActiveProvider);
    final llm = ref.watch(raiLlmStatusProvider).value ?? ref.read(raiLlmProvider).current;
    // フッター(タブ)の上に置く。キーボードが出ていればその上。
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final dock = insets > 0 ? insets : fowDockInsetOf(context, ref.read(routerProvider));
    final screen = MediaQuery.sizeOf(context);
    // 指差す部品がバーの後ろ(画面下)にあるときはバーを上(ヘッダーの下)へ逃がす。
    final t = s.target;
    final atTop = t != null && s.mode == RaiMode.instruction && t.bottom > screen.height - dock - 200;
    final speech = s.bubble == null || chat
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
    // 置き場 (D-233): カラム(列スロット)と縦の比率。指差しの逃がし(atTop)は一時的に上へ。
    final placement = ref.watch(raiBarPlacementProvider);
    final slots = fowColumnSlotsOf(context, thirdColumnOccupied: ref.watch(thirdColumnProvider) != null);
    final top = fowTopInsetOf(context) + RasqSpacing.sm;
    final bottom = screen.height - (dock + RasqSpacing.sm + (insets > 0 ? 0 : MediaQuery.paddingOf(context).bottom));
    // 幅 (D-237): チャット列と同じ規則 — カラム幅 600px 未満なら最大幅、以上は増えた分の 1/2 まで。
    final colW = slots.isEmpty ? screen.width : slots[placement.column.clamp(0, slots.length - 1)].width;
    final barW = (colW < raiChatBaseWidth ? colW : raiChatBaseWidth + (colW - raiChatBaseWidth) / 2) - RasqSpacing.sm * 2;
    final bar = SizedBox(
      key: _barKey,
      width: barW,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 曖昧な質問の選択肢 (D-194): 吹き出しの上のタイル。
        if (s.choices.isNotEmpty && !chat)
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
        state: s,
        onToggleExpanded: n.toggleExpanded,
        onMode: n.setMode,
        onSubmit: n.ask,
        onClose: () => hideRai(ref),
        onModelTap: () => showRaiModelsFow(ref, context),
        onHistoryToggle: n.toggleHistory,
        onAskMore: n.cancelInstruction,
        onSuggest: n.suggest,
        onDragUpdate: (d) => setState(() => _drag += d),
        onDragEnd: () => _onDragEnd(context, slots, top, bottom),
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
    // 横: 列スロットの中心(単一スロットなら画面中央)。縦: 比率 → Alignment(-1 = 上、1 = 下)。
    double xAlign = 0;
    if (slots.isNotEmpty) {
      final slot = slots[placement.column.clamp(0, slots.length - 1)];
      final room = (screen.width - barW - RasqSpacing.sm * 2) / 2;
      xAlign = room <= 0 ? 0 : (((slot.x + slot.width / 2) - screen.width / 2) / room).clamp(-1.0, 1.0);
    }
    final yAlign = atTop ? -1.0 : placement.y * 2 - 1;
    return SizedBox.expand(
      child: AnimatedAlign(
        duration: _drag == Offset.zero ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: Alignment(xAlign, yAlign),
        child: Padding(
          padding: EdgeInsets.fromLTRB(RasqSpacing.sm, top, RasqSpacing.sm, screen.height - bottom),
          child: Transform.translate(offset: _drag, child: bar),
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

  /// チャットの背景 (D-218 → D-219): 枠の中でヨー方向(縦軸まわり)にゆっくり旋回(速さは 3D 側の描画ループが進める)。
  bool _inPlace = false;
  bool _holdingAnswer = false;
  bool _lastBusy = false;
  bool _lastError = false;


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
  int _lastStep = -1;
  String? _lastBubble;
  RaiProjector? _projector;

  /// 3D: 移動の計画(起動 / 走行 / 停止、腕の側)と進み具合、推論中の一時停止、空間の位置。
  final _ctrl3d = RaiMascot3dController();

  /// テスト用 (D-218): 背景の RAi の腕 / ロール / 1 回だけのクリップを確かめる。
  @visibleForTesting
  RaiMascot3dController get controller3d => _ctrl3d;
  bool _pausedByBusy = false;

  bool _downOnTarget = false;

  /// 指差した部品へのタップを見張る (D-193): どのウィジェットが処理しても届くグローバルな経路。
  /// 別のコンポーネントの同じボタン(TL の別の投稿のリアクションなど)でも続ける (D-204)。
  void _onPointer(PointerEvent e) {
    if (!mounted) return;
    final n = ref.read(raiProvider.notifier);
    if (e is PointerDownEvent) {
      _downOnTarget = n.isStepWidgetAt(e.position);
    } else if (e is PointerUpEvent) {
      final down = _downOnTarget;
      _downOnTarget = false;
      if (down && n.isStepWidgetAt(e.position)) n.targetTapped();
    } else if (e is PointerCancelEvent) {
      _downOnTarget = false;
    }
  }

  /// 表情 (D-211): FOW が出現したら 8 → 9 → 10 を順に出し、次の行程(吹き出し / 手順が変わる)まで 10 のまま。
  /// それ以外は目で、ときどきまばたき。
  OverlayManager? _overlayManager;
  Set<String> _fowIds = const {};
  Timer? _faceTimer;
  Timer? _blinkTimer;
  bool _holdingFow = false;

  void _onOverlays() {
    final m = _overlayManager;
    if (!mounted || m == null) return;
    final ids = {for (final e in m.entries) if (e.fow != null) e.id};
    final appeared = ids.difference(_fowIds).isNotEmpty;
    _fowIds = ids;
    if (appeared && ref.read(raiProvider).open) _playFowAppear();
  }

  void _playFowAppear() {
    _faceTimer?.cancel();
    _holdingFow = true;
    var i = 0;
    _ctrl3d.face = RaiFace.fowAppear[0];
    _faceTimer = Timer.periodic(const Duration(milliseconds: 140), (t) {
      i++;
      if (!mounted || i >= RaiFace.fowAppear.length) {
        t.cancel();
        return;
      }
      _ctrl3d.face = RaiFace.fowAppear[i];
    });
  }

  /// 次の行程へ: 目に戻す。
  void _faceIdle() {
    _faceTimer?.cancel();
    _holdingFow = false;
    _holdingAnswer = false;
    _ctrl3d.face = RaiFace.eyes;
  }

  /// 返事が出たときのランダムな表情 (D-215): 吹き出しが消えるまで保つ。
  static const _expressions = [RaiFace.eyes2, RaiFace.eyesRound, RaiFace.eyesNarrow, RaiFace.clip, RaiFace.camera, RaiFace.globe];
  final _faceRandom = math.Random();

  void _randomFace() {
    _faceTimer?.cancel();
    _holdingFow = false;
    _holdingAnswer = true;
    _ctrl3d.face = _expressions[_faceRandom.nextInt(_expressions.length)];
  }

  void _blink() {
    if (!mounted || _holdingFow || _holdingAnswer || _ctrl3d.face != RaiFace.eyes) return;
    _ctrl3d.face = RaiFace.blink;
    Timer(const Duration(milliseconds: 120), () {
      if (mounted && !_holdingFow && _ctrl3d.face == RaiFace.blink) _ctrl3d.face = RaiFace.eyes;
    });
  }

  @override
  void initState() {
    super.initState();
    _overlayManager = ref.read(overlayManagerProvider);
    _fowIds = {for (final e in _overlayManager!.entries) if (e.fow != null) e.id};
    _overlayManager!.addListener(_onOverlays);
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) => _blink());
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _anim.addListener(_onFrame);
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed && _path != null && mounted) {
        _pos = _path!.to;
        _ctrl3d.finish();
        _onFrame();
      }
    });
  }

  @override
  void dispose() {
    _overlayManager?.removeListener(_onOverlays);
    _faceTimer?.cancel();
    _blinkTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _anim.dispose();
    _ctrl3d.dispose();
    super.dispose();
  }

  /// グローバル矩形 → このレイヤーのローカル矩形(2 カラムやホストの余白でずれないように、D-197)。
  Rect _toLocal(Rect global) {
    if (!mounted) return global;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }


  RaiPlacement _destination(RaiState s, Size screen, Rect? localTarget) {
    if (s.mode == RaiMode.assistant || localTarget == null) {
      // 右下 / 左下(バーの上)。
      final x = _restLeft ? mascot / 2 + RasqSpacing.md : screen.width - mascot / 2 - RasqSpacing.md;
      return (pos: Offset(x, screen.height - 180 - mascot * 0.7), cramped: false, armsDown: false);
    }
    _restLeft = localTarget.center.dx > screen.width / 2;
    return raiPlaceFor(localTarget, screen, mascot: mascot);
  }

  void _moveTo(RaiPlacement place, RaiState s, Size screen, Rect? localTarget) {
    final proj = _projector!;
    final dest = place.pos;
    final from = _pos ?? dest;
    // 空きが無いとき (D-203): 下側に空きが無ければ手を下ろす。
    final armTo = place.armsDown ? RaiArm.none : raiArmFor(dest, s.mode == RaiMode.instruction ? localTarget : null);
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
  /// 3D かどうか(build で更新。フレーム処理では ref を触らない)。
  bool _threeMode = false;

  void _onFrame() {
    final proj = _projector;
    if (proj == null || !mounted) return;
    final path = _path;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    final moving = _anim.isAnimating && path != null;
    final plan = _ctrl3d.plan;
    _ctrl3d.advance(t);
    RaiVec3 world;
    double yaw;
    final armTo = plan?.armTo ?? _ctrl3d.arm;
    if (moving) {
      final stopStart = plan == null ? 1.0 : 1 - plan.steps.last.fraction;
      final clockwise = path.to.dx >= path.from.dx;
      // 円運動は停止時の角度補正のときだけ (D-197)。
      RaiVec3 at(double u) => path.at(u) + raiStopLoop3(u, stopStart: stopStart, projector: proj, restSize: mascot, radiusPx: mascot * 0.25, clockwise: clockwise);
      world = at(t);
      // 向き (D-199): 3D の接線(地面に平行な成分)を向く。スプラインの延長として途切れなく回る。
      final tan = path.tangent(t);
      if ((tan.x.abs() + tan.z.abs()) > 1e-6) _face = raiUnwrap(_face, raiYaw3(tan.x, tan.z));
      // 停止の旋回の向きは山なりと逆側から合わせる(実機で確認、D-200)。
      yaw = raiYawAt(t, plan: plan, tangent: Offset.zero, armFrom: _yawArmFrom, armTo: armTo, face: _face, stopTurn: clockwise ? 1 : -1);
    } else {
      world = _standbyWorld ?? proj.worldAt(_pos ?? Offset(proj.screen.width / 2, proj.screen.height / 2), mascot);
      yaw = raiRestYawFor(_ctrl3d.arm);

    }
    final p = proj.project(world);
    // NaN は流さない (D-205: 実機で高さ NaN のアサート)。
    if (p.px.dx.isNaN || p.px.dy.isNaN || p.sizePx.isNaN || yaw.isNaN) return;
    _ctrl3d.setFrame(world: world, yaw: yaw, screenPos: p.px, sizePx: p.sizePx);
    if (!_threeMode && mounted) setState(() {});
  }

  /// アシスタントのスタンバイ (D-199): RAi ホームの枠(グローバル矩形)に大きく薄く出す。
  RaiVec3? _standbyWorld;
  Rect? _loggedStandby;

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
    _threeMode = three;
    final slot = ref.watch(raiStandbySlotProvider);
    _projector ??= RaiProjector(screen: screen);
    if (_projector!.screen != screen) {
      _projector = RaiProjector(screen: screen);
      // リサイズ (D-204): レイアウトが変わるので目標の矩形を取り直す。
      final n = ref.read(raiProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) => n.relocate());
    }
    final proj = _projector!;
    final outline = Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.85) : null;
    // 空間モードのウィジェットは常に同じ Stack の先頭に固定キーで置く (D-202): 出す / 隠す / スタンバイで
    // 木の形を変えると three_js が作り直され(テクスチャの再生成、破棄時の EGL 例外)、Stack の外に
    // Positioned を返すと ParentDataWidget の誤用になる(実機のログ)。
    final scene = three ? Positioned.fill(key: const ValueKey('rai.scene'), child: IgnorePointer(child: RaiMascot3d.scene(controller: _ctrl3d, projector: proj, outline: outline))) : null;
    Widget layer(List<Widget> children) => SizedBox(width: screen.width, height: screen.height, child: Stack(children: [?scene, ...children]));
    // 行程が進んだら表情を目に戻す (D-211)。アシスタントの返事が出たらランダムな表情 (D-215)。
    if (s.stepIndex != _lastStep || s.bubble != _lastBubble || s.busy != _lastBusy) {
      final answered = s.mode == RaiMode.assistant && !s.busy && s.bubble != null && s.bubble != '…' && (s.bubble != _lastBubble || _lastBusy);
      _lastStep = s.stepIndex;
      _lastBubble = s.bubble;
      _lastBusy = s.busy;
      if (answered) {
        _randomFace();
      } else if ((_holdingFow || _holdingAnswer) && s.bubble == null) {
        _faceIdle();
      }
    }
    // チャットの背景 (D-199 → D-218): アシスタントで RAi ホームの枠があるときは、吹き出しの有無に関わらず
    // 枠の中に薄く出して旋回する(下の inPlace)。それ以外で吹き出しが無ければ隠す。
    final assistantHome = s.mode == RaiMode.assistant && slot != null;
    if (s.bubble == null && !assistantHome) {
      // 何も出さない(3D は読み込み直しを避けるためウィジェットは残し、隠す)。
      _ctrl3d.opacity = 0;
      _standbyWorld = null;
      return layer(const []);
    }
    // 実機で中央の RAi が出ないときの手がかり (D-214): 枠 → 空間の位置 / 見かけの大きさ。
    if (kDebugMode && assistantHome && _loggedStandby != slot) {
      _loggedStandby = slot;
      final local = _toLocal(slot);
      final w = proj.worldAt(local.center, local.height / 1.25);
      final p = proj.project(w);
      debugPrint('RAi standby: slot=$slot local=$local world=$w px=${p.px} size=${p.sizePx.toStringAsFixed(0)} three=$three');
    }
    final localTarget = s.target == null ? null : _toLocal(s.target!);
    _syncBusy(s.busy);
    // チャットの背景 (D-215 → D-219): RAi ホームのアシスタントでは枠の中でヨー方向にゆっくり旋回する。
    // 考えている / 文字が流れているあいだは薄く(0.15)、速めに回る。返事が出たら 0.35 に戻る。
    // リンク / タイルが出た行が最新なら腕を上げる。失敗の返事は 5% で accident。
    final inPlace = assistantHome;
    if (inPlace != _inPlace) {
      _inPlace = inPlace;
      if (!inPlace) {
        _ctrl3d.spin = 0;
        _ctrl3d.spinSpeed = 0;
      }
    }
    if (inPlace) {
      final streaming = s.busy;
      // 1 周 24 秒、考えているあいだは 6 秒(ヨー方向)。
      _ctrl3d.spinSpeed = 2 * math.pi / (streaming ? 6 : 24);
      final local = _toLocal(slot);
      _standbyWorld = proj.worldAt(local.center, local.height / 1.25);
      _ctrl3d.opacity = streaming ? 0.12 : 0.28;
      final latest = s.log.firstOrNull;
      final hasTile = !streaming && latest != null && s.bubble != null && (latest.proposal != null || latest.choices.isNotEmpty || latest.links.isNotEmpty);
      final arm = hasTile ? RaiArm.right : RaiArm.none;
      if (_ctrl3d.plan != null || _ctrl3d.arm != arm) _ctrl3d.idle(arm);
      if (s.error && !_lastError && _faceRandom.nextInt(100) < 5) _ctrl3d.playOnce('accident');
      _lastError = s.error;
      _pos = null;
      _lastTarget = s.target;
      _lastMode = s.mode;
      _onFrame();
      return layer([
        if (!three)
          Positioned(
            key: const ValueKey('rai.mascot2d'),
            left: local.center.dx - local.width / 2,
            top: local.center.dy - local.height / 2,
            child: IgnorePointer(child: Opacity(opacity: _ctrl3d.opacity, child: RaiMascot(size: local.width, controller3d: _ctrl3d))),
          ),
      ]);
    }
    if (s.target != _lastTarget || s.mode != _lastMode || _pos == null) {
      _lastTarget = s.target;
      _lastMode = s.mode;
      // スタンバイから動き出すときは、その位置(射影)を出発点に。
      if (_pos == null && _standbyWorld != null) _pos = proj.project(_standbyWorld!).px;
      _standbyWorld = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lt = s.target == null ? null : _toLocal(s.target!);
        setState(() => _moveTo(_destination(s, screen, lt), s, screen, lt));
      });
    }
    final place = _destination(s, screen, localTarget);
    final dest = place.pos;
    // 空きが無いときは半透明 (D-203)。
    _ctrl3d.opacity = place.cramped ? 0.5 : 1;
    final moving = _anim.isAnimating && _path != null;
    // 2D の代替描画: 空間の位置を射影した点と大きさに置く。
    final pos = moving ? _ctrl3d.screenPos : (_pos ?? dest);
    final size = moving ? _ctrl3d.sizePx : mascot;
    final pointing = localTarget == null ? null : pointingDirection(pos, localTarget.center);
    return layer([
      // 目標の部品をハイライト(インストラクション)。
      if (localTarget != null && s.mode == RaiMode.instruction)
        Positioned.fromRect(
          key: const ValueKey('rai.highlight'),
          rect: localTarget.inflate(6),
          child: IgnorePointer(
            child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: RasqColors.accent, width: 2), borderRadius: BorderRadius.circular(RasqSizes.radiusSm))),
          ),
        ),
      if (three) ...[
        // 較正用 (D-200、デバッグビルドだけ): 写像が置いたつもりの位置と大きさ。毎フレーム追従する (D-202)。
        // モデルとずれていれば 3D 側の問題。
        if (kDebugMode)
          Positioned.fill(
            key: const ValueKey('rai.frame'),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctrl3d,
                builder: (_, _) {
                  final p = _ctrl3d.screenPos;
                  final sz = _ctrl3d.sizePx;
                  return Stack(children: [
                    Positioned(
                      left: p.dx - sz / 2,
                      top: p.dy - sz * 0.625,
                      child: SizedBox(width: sz, height: sz * 1.25, child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: RasqColors.accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)))),
                    ),
                  ]);
                },
              ),
            ),
          ),
      ] else
        Positioned(
          key: const ValueKey('rai.mascot2d'),
          left: pos.dx - size / 2,
          top: pos.dy - size * 0.625,
          child: IgnorePointer(child: RaiMascot(size: size, pointing: pointing, controller3d: _ctrl3d, opacity: place.cramped ? 0.5 : 1)),
        ),
    ]);
  }
}

/// RAi ホームのスタンバイ枠(グローバル矩形、D-199)。ホームが描画のたびに報告し、離れると null。
///
/// 報告元 [owner] ごとに覚えておき、状態は**最後に報告した生きている枠** (D-214: RAi ホームが積み直された
/// とき、古い画面の後始末で新しい枠が消えて中央の RAi が出なくなっていた)。
class RaiStandbySlot extends Notifier<Rect?> {
  final _rects = <Object, Rect>{};

  @override
  Rect? build() => null;

  void set(Rect? r, {Object? owner}) {
    if (!ref.mounted) return; // 画面の破棄後(テストの終了時など)は無視
    if (r == null) {
      if (owner == null) {
        _rects.clear();
      } else {
        _rects.remove(owner);
      }
    } else {
      final key = owner ?? this;
      _rects.remove(key);
      _rects[key] = r;
    }
    state = _rects.values.lastOrNull;
  }
}

final raiStandbySlotProvider = NotifierProvider<RaiStandbySlot, Rect?>(RaiStandbySlot.new);

/// チャットが出ているか (D-218): RAi ホームが見えていて(枠がある)アシスタントのとき。
final raiChatActiveProvider = Provider<bool>((ref) => ref.watch(raiProvider).mode == RaiMode.assistant && ref.watch(raiStandbySlotProvider) != null);
