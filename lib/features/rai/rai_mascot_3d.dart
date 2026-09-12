import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_js/three_js.dart' as three;

import 'rai_motion.dart';

/// RAi の 3D 描画 (D-191): three_js(flutter_angle)で `assets/models/rai.glb` を透過背景に描き、
/// glb のクリップ(idle / run_* / accident)を [RaiMascot3dController] の計画どおりに再生する。
/// LLM の推論中は [RaiMascot3dController.paused] でミキサーを止める。
///
/// テスト(FLUTTER_TEST)と Web では使わず、2D の painter に落ちる([raiMascot3dProvider])。
final raiMascot3dProvider = Provider<bool>((_) => !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST'));

/// 3D 側へ渡す状態: 静止時の腕、移動中の計画と進み具合、一時停止。
class RaiMascot3dController extends ChangeNotifier {
  RaiArm _arm = RaiArm.none;
  RaiMotionPlan? _plan;
  double _progress = 0;
  bool _paused = false;

  RaiArm get arm => _arm;
  RaiMotionPlan? get plan => _plan;
  double get progress => _progress;
  bool get paused => _paused;

  /// 到着後 / 静止の腕。
  void idle(RaiArm arm) {
    _arm = arm;
    _plan = null;
    _progress = 0;
    notifyListeners();
  }

  void start(RaiMotionPlan plan) {
    _plan = plan;
    _progress = 0;
    notifyListeners();
  }

  void advance(double progress) {
    _progress = progress.clamp(0, 1);
    notifyListeners();
  }

  void finish() {
    final p = _plan;
    if (p != null) _arm = p.armTo;
    _plan = null;
    _progress = 0;
    notifyListeners();
  }

  set paused(bool v) {
    if (_paused == v) return;
    _paused = v;
    notifyListeners();
  }

  /// いま再生すべきクリップ(移動中は計画の段、静止は idle 系)。
  String get clip => _plan == null ? raiIdleClip(_arm) : _plan!.at(_progress).clip;
  bool get loop => _plan == null ? true : _plan!.at(_progress).loop;
}

class RaiMascot3d extends StatefulWidget {
  const RaiMascot3d({super.key, required this.size, this.controller, this.asset = 'assets/models/rai.glb'});
  final double size;
  final RaiMascot3dController? controller;
  final String asset;

  @override
  State<RaiMascot3d> createState() => _RaiMascot3dState();
}

class _RaiMascot3dState extends State<RaiMascot3d> {
  late three.ThreeJS _three;
  three.AnimationMixer? _mixer;
  final _actions = <String, three.AnimationAction>{};
  three.AnimationAction? _current;
  String? _currentName;
  bool _failed = false;
  bool _ready = false;
  late final RaiMascot3dController _fallback = RaiMascot3dController();
  RaiMascot3dController get _ctrl => widget.controller ?? _fallback;

  @override
  void initState() {
    super.initState();
    _three = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) setState(() => _ready = true);
      },
      setup: _setup,
      size: Size(widget.size, widget.size * 1.25),
      settings: three.Settings(alpha: true, clearAlpha: 0, clearColor: 0x000000, animate: true, antialias: true, enableShadowMap: false),
    );
    _ctrl.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant RaiMascot3d old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _fallback).removeListener(_sync);
      _ctrl.addListener(_sync);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_sync);
    _fallback.dispose();
    _three.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      _three.scene = three.Scene();
      _three.camera = three.PerspectiveCamera(28, _three.width / _three.height, 0.1, 100);
      _three.scene.add(three.AmbientLight(0xffffff, 0.9));
      final key = three.DirectionalLight(0xffffff, 1.2);
      key.position.setValues(1.5, 3, 4);
      _three.scene.add(key);
      final fill = three.DirectionalLight(0xffffff, 0.5);
      fill.position.setValues(-2, 1, 2);
      _three.scene.add(fill);
      final gltf = await three.GLTFLoader().fromAsset(widget.asset);
      if (gltf == null) throw StateError('glb を読めません');
      final model = gltf.scene;
      // 高さ 1 に正規化して足元を原点へ(モデルの寸法に依らずカメラに収める)。
      final box = three.BoundingBox().setFromObject(model);
      final h = (box.max.y - box.min.y).abs();
      final s = h == 0 ? 1.0 : 1.0 / h;
      model.scale.setValues(s, s, s);
      model.position.setValues(-(box.min.x + box.max.x) / 2 * s, -box.min.y * s, -(box.min.z + box.max.z) / 2 * s);
      _three.scene.add(model);
      _three.camera.position.setValues(0, 0.6, 3.2);
      _three.camera.lookAt(three.Vector3(0, 0.5, 0));
      final mixer = three.AnimationMixer(model);
      for (final c in (gltf.animations ?? const []).cast<three.AnimationClip>()) {
        final a = mixer.clipAction(c);
        if (a != null) _actions[c.name] = a;
      }
      _mixer = mixer;
      _three.addAnimationEvent((dt) {
        if (!_ctrl.paused) _mixer?.update(dt);
      });
      _sync();
    } catch (e) {
      debugPrint('RAi 3D: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// コントローラーの状態 → クリップの切り替え(クロスフェード)。
  void _sync() {
    final mixer = _mixer;
    if (mixer == null) return;
    final name = _ctrl.clip;
    if (name == _currentName) return;
    final next = _actions[name] ?? _actions[_ctrl.plan?.idleClip ?? 'idle'] ?? _actions['idle'];
    if (next == null) return;
    next
      ..reset()
      ..setLoop(_ctrl.loop ? three.LoopRepeat : three.LoopOnce, _ctrl.loop ? double.infinity : 1)
      ..clampWhenFinished = true
      ..enabled = true
      ..play();
    final prev = _current;
    if (prev != null && prev != next) {
      next.crossFadeFrom(prev, 0.15);
    }
    _current = next;
    _currentName = name;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.25,
      child: Opacity(opacity: _ready ? 1 : 0, child: _three.build()),
    );
  }
}
