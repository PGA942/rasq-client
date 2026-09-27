import 'package:flutter/cupertino.dart' show CupertinoSlider;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 第3カラムのページのスワイプで戻る (D-350)。第3カラムのページは Navigator のルートではないので、端末の「スワイプで戻る」が
/// 効かなかった。ページの上で**右へスワイプ**したら、ヘッダーの < と同じ戻り([onBack])をする。
///
/// **競合するときは戻らない**: スワイプを始めた位置に
/// - 左に隠れた中身がある横スクロール(TL のタブの 2 枚目以降 = 隠れた TL、途中までスクロールした横のリストなど)
/// - 横にドラッグする部品(スライダー / スワイプで消す行 / ドラッグで動かす部品)
/// があれば、その部品に任せる。ジェスチャーの取り合い(アリーナ)には入らず、[Listener] で見ているだけなので、
/// 中の部品の動きは変わらない。
class PaneSwipeBack extends StatefulWidget {
  const PaneSwipeBack({super.key, required this.onBack, required this.child});
  final VoidCallback onBack;
  final Widget child;

  /// 戻るのに要る右への移動量(論理 px)。
  static const threshold = 72.0;

  @override
  State<PaneSwipeBack> createState() => _PaneSwipeBackState();
}

class _PaneSwipeBackState extends State<PaneSwipeBack> {
  int? _pointer;
  Offset _start = Offset.zero;
  double _dx = 0;

  /// null = まだ向きが決まっていない、true = 横(戻るの候補)、false = 縦 / 競合(このタッチでは戻らない)。
  bool? _horizontal;
  bool _blocked = false;

  void _down(PointerDownEvent e) {
    if (_pointer != null) {
      // 2 本目の指: このタッチでは戻らない(ピンチなど)。
      _blocked = true;
      return;
    }
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    _pointer = e.pointer;
    _start = e.position;
    _dx = 0;
    _horizontal = null;
    _blocked = _conflictsAt(e.position);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || _blocked) return;
    final d = e.position - _start;
    if (_horizontal == null) {
      if (d.distance < kTouchSlop) return;
      // 右向きで、横が縦の倍より大きいときだけ横と決める。
      _horizontal = d.dx > 0 && d.dx.abs() > d.dy.abs() * 2;
    }
    if (_horizontal != true) return;
    setState(() => _dx = d.dx.clamp(0, double.infinity));
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final go = !_blocked && _horizontal == true && _dx >= PaneSwipeBack.threshold;
    _reset();
    if (go) widget.onBack();
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _reset();
  }

  void _reset() {
    _pointer = null;
    _horizontal = null;
    _blocked = false;
    if (_dx != 0 && mounted) setState(() => _dx = 0);
  }

  /// 始めた位置に、右スワイプを使う部品があるか。
  bool _conflictsAt(Offset global) {
    var hit = false;
    bool contains(Element e) {
      final r = e.renderObject;
      if (r is! RenderBox || !r.attached || !r.hasSize) return false;
      return (r.localToGlobal(Offset.zero) & r.size).contains(global);
    }

    void visit(Element e) {
      if (hit) return;
      final w = e.widget;
      if (w is Slider || w is RangeSlider || w is CupertinoSlider || w is Dismissible || w is Draggable || w is LongPressDraggable) {
        if (contains(e)) {
          hit = true;
          return;
        }
      }
      if (e is StatefulElement && e.state is ScrollableState) {
        final s = e.state as ScrollableState;
        // 左(前)に隠れた中身があるときだけ競合(先頭にいる横スクロールは右へ引っ張っても何も出てこない)。
        if (s.position.axis == Axis.horizontal && s.position.hasPixels && s.position.pixels > s.position.minScrollExtent + 0.5 && contains(e)) {
          hit = true;
          return;
        }
      }
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return hit;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      behavior: HitTestBehavior.translucent,
      // 引いている間は、ページが指について右へずれる(戻れる量を超えたら少し薄く)。
      child: LayoutBuilder(builder: (context, box) {
        final t = (_dx / (box.maxWidth.isFinite ? box.maxWidth : 400)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(_dx * 0.6, 0),
          child: Opacity(opacity: _dx >= PaneSwipeBack.threshold ? 1 - t * 0.4 : 1, child: widget.child),
        );
      }),
    );
  }
}
