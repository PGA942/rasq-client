import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_js/three_js.dart' as three;

import 'rai_motion.dart';
import 'rai_space.dart';

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
  /// ヨー(ラジアン、正 = 左を向く)。描画は毎フレーム読むので通知しない。
  double yaw = 0;

  /// 空間の中の位置(モデルの中心、D-197)。描画は毎フレーム読む。
  RaiVec3 world = const RaiVec3(0, 0, -10);

  /// 2D の代替描画用: 画面上の位置と見かけの大きさ。
  Offset screenPos = Offset.zero;
  double sizePx = raiPointSize;

  void setFrame({required RaiVec3 world, required double yaw, required Offset screenPos, required double sizePx}) {
    this.world = world;
    this.yaw = yaw;
    this.screenPos = screenPos;
    this.sizePx = sizePx;
  }

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
  const RaiMascot3d({super.key, required this.size, this.controller, this.asset = 'assets/models/rai.glb', this.outline, this.opacity = 1}) : projector = null;

  /// 空間モード (D-197): 画面いっぱいの固定ウィジェット。カメラは原点で −Z を向き、モデルは
  /// [RaiMascot3dController.world] の位置(中心)に毎フレーム置かれる。
  const RaiMascot3d.scene({super.key, required RaiMascot3dController this.controller, required RaiProjector this.projector, this.asset = 'assets/models/rai.glb', this.outline, this.opacity = 1}) : size = 0;
  final double size;
  final RaiMascot3dController? controller;
  final RaiProjector? projector;
  final String asset;
  bool get isScene => projector != null;

  /// ダークモードの縁取り色(null なら縁取り無し)。
  final Color? outline;
  final double opacity;

  /// 描画は固定解像度で行い、表示サイズは拡縮で合わせる(サイズが毎フレーム変わってもテクスチャを作り直さない)。
  static const renderWidth = 400.0;
  static const renderHeight = 500.0;

  @override
  State<RaiMascot3d> createState() => _RaiMascot3dState();
}

class _RaiMascot3dState extends State<RaiMascot3d> {
  late three.ThreeJS _three;
  three.AnimationMixer? _mixer;
  three.Group? _root;
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
    final proj = widget.projector;
    _three = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) setState(() => _ready = true);
      },
      setup: _setup,
      size: proj == null ? const Size(RaiMascot3d.renderWidth, RaiMascot3d.renderHeight) : proj.screen,
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
      final proj = widget.projector;
      _three.camera = three.PerspectiveCamera(proj?.fovDeg ?? 28, _three.width / _three.height, 0.05, 200);
      // 金属部分(腕 / コマ)が暗く沈まないよう、環境光を強めに + キー / フィル / リム。
      _three.scene.add(three.AmbientLight(0xffffff, 1.4));
      final key = three.DirectionalLight(0xffffff, 1.8);
      key.position.setValues(1.5, 3, 4);
      _three.scene.add(key);
      final fill = three.DirectionalLight(0xdfe8ff, 0.9);
      fill.position.setValues(-2.5, 1, 2.5);
      _three.scene.add(fill);
      final rim = three.DirectionalLight(0xffffff, 1.0);
      rim.position.setValues(0, 2, -3);
      _three.scene.add(rim);
      final gltf = await three.GLTFLoader().fromAsset(widget.asset);
      if (gltf == null) throw StateError('glb を読めません');
      final model = gltf.scene;
      // 環境マップ無しの metalness=1 は真っ黒に見えるので、金属材質は少し下げて粗さを上げる。
      model.traverse((o) {
        if (o is three.Mesh) {
          final m = o.material;
          if (m is three.MeshStandardMaterial) {
            if (m.metalness > 0.4) m.metalness = 0.4;
            if (m.roughness < 0.45) m.roughness = 0.45;
          }
        }
      });
      // 高さ 1 に正規化して足元を原点へ(モデルの寸法に依らずカメラに収める)。
      final box = three.BoundingBox().setFromObject(model);
      final h = (box.max.y - box.min.y).abs();
      final s = h == 0 ? 1.0 : 1.0 / h;
      model.scale.setValues(s, s, s);
      // 中心が原点に来るように(空間モードでは中心 = world、待機モードでは足元基準でカメラに収める)。
      final cy = proj == null ? 0.0 : 0.5;
      model.position.setValues(-(box.min.x + box.max.x) / 2 * s, -box.min.y * s - cy, -(box.min.z + box.max.z) / 2 * s);
      final root = three.Group()..add(model);
      _root = root;
      _three.scene.add(root);
      if (proj == null) {
        _three.camera.position.setValues(0, 0.6, 3.2);
        _three.camera.lookAt(three.Vector3(0, 0.5, 0));
      } else {
        _three.camera.position.setValues(0, 0, 0);
        _three.camera.lookAt(three.Vector3(0, 0, -1));
        final w = _ctrl.world;
        root.position.setValues(w.x, w.y, w.z);
      }
      final mixer = three.AnimationMixer(model);
      for (final c in (gltf.animations ?? const []).cast<three.AnimationClip>()) {
        final a = mixer.clipAction(c);
        if (a != null) _actions[c.name] = a;
      }
      _mixer = mixer;
      _three.addAnimationEvent((dt) {
        if (!_ctrl.paused) _mixer?.update(dt);
        final r = _root;
        if (r == null) return;
        r.rotation.y = _ctrl.yaw;
        if (proj != null) {
          final w = _ctrl.world;
          r.position.setValues(w.x, w.y, w.z);
        }
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
    final tex = _three.texture;
    final outline = widget.outline;
    // 縁取り (D-192): 同じテクスチャを一色に塗って 8 方向へずらし、本体の下に敷く。
    Widget copy() => Transform.scale(scaleY: Platform.isAndroid ? 1 : -1, child: Texture(textureId: tex!.textureId));
    final scene = SizedBox(
      width: RaiMascot3d.renderWidth,
      height: RaiMascot3d.renderHeight,
      child: Stack(fit: StackFit.expand, children: [
        if (outline != null && tex != null && _ready)
          for (final d in const [Offset(-3, 0), Offset(3, 0), Offset(0, -3), Offset(0, 3), Offset(-2, -2), Offset(2, -2), Offset(-2, 2), Offset(2, 2)])
            Transform.translate(offset: d, child: ColorFiltered(colorFilter: ColorFilter.mode(outline, BlendMode.srcIn), child: copy())),
        _three.build(),
      ]),
    );
    if (widget.isScene) {
      final sz = widget.projector!.screen;
      return SizedBox(width: sz.width, height: sz.height, child: Opacity(opacity: _ready ? widget.opacity : 0, child: Stack(fit: StackFit.expand, children: [
        if (outline != null && tex != null && _ready)
          for (final d in const [Offset(-3, 0), Offset(3, 0), Offset(0, -3), Offset(0, 3), Offset(-2, -2), Offset(2, -2), Offset(-2, 2), Offset(2, 2)])
            Transform.translate(offset: d, child: ColorFiltered(colorFilter: ColorFilter.mode(outline, BlendMode.srcIn), child: copy())),
        _three.build(),
      ])));
    }
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.25,
      child: Opacity(
        opacity: _ready ? widget.opacity : 0,
        child: FittedBox(fit: BoxFit.contain, child: scene),
      ),
    );
  }
}
