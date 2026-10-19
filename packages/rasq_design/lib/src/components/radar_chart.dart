import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// 触れるレーダーチャート(ワイヤーフレーム p.2「トレンドの刺激性」)。
///
/// 軸ごとの値 0〜1 を多角形で描き、軸の上をドラッグ/タップすると
/// その軸の値が変わる(触った点から中心までの距離 = 値)。標準 widget では
/// 組めないので CustomPaint(D-153)。
class RasqRadarChart extends StatefulWidget {
  const RasqRadarChart({super.key, required this.axes, required this.values, this.labels = const {}, this.onChanged, this.size = 240, this.rings = 4, this.color, this.claimDrag = false});

  /// 軸の並び(時計回り、先頭が真上)。
  final List<String> axes;

  /// 軸 → 値 0〜1(未設定は 1)。
  final Map<String, double> values;
  final Map<String, String> labels;

  /// 触った軸と新しい値。null なら表示だけ。
  final void Function(String axis, double value)? onChanged;
  final double size;
  final int rings;
  final Color? color;

  /// 触れたらすぐドラッグを取る (D-514)。スクロールする FOW の中に置くと、縦に動かした指を FOW のスクロールが取り、
  /// 軸を動かせなかった。true なら指を置いた時点でこのチャートのドラッグに決める(タップも置いた点で値が決まる)。
  final bool claimDrag;

  @override
  State<RasqRadarChart> createState() => _RasqRadarChartState();
}

class _RasqRadarChartState extends State<RasqRadarChart> {
  String? _dragging;

  double _radius(BoxConstraints c) => math.min(c.maxWidth, c.maxHeight) / 2 - 28; // ラベル分の余白

  void _handle(Offset local, Size size, {bool lockAxis = false}) {
    if (widget.onChanged == null || widget.axes.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 28;
    final d = local - center;
    String axis;
    if (lockAxis && _dragging != null) {
      axis = _dragging!;
    } else {
      // 角度 → 一番近い軸(真上 = 0、時計回り)。
      var angle = math.atan2(d.dx, -d.dy);
      if (angle < 0) angle += 2 * math.pi;
      final step = 2 * math.pi / widget.axes.length;
      axis = widget.axes[((angle + step / 2) ~/ step) % widget.axes.length];
      _dragging = axis;
    }
    final v = (d.distance / r).clamp(0.0, 1.0);
    widget.onChanged!(axis, (v * 20).round() / 20); // 0.05 刻み
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? RasqColors.danger;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final paint = CustomPaint(
          painter: _RadarPainter(
            axes: widget.axes,
            values: widget.values,
            labels: widget.labels,
            rings: widget.rings,
            color: color,
            lineColor: scheme.onSurface,
            gridColor: scheme.outlineVariant,
            textStyle: RasqTypography.caption.copyWith(color: scheme.onSurface),
            radius: _radius(c),
          ),
        );
        if (widget.claimDrag) {
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
                () => _EagerPanGestureRecognizer(debugOwner: this),
                (r) => r
                  ..onStart = ((d) => _handle(d.localPosition, size))
                  ..onUpdate = ((d) => _handle(d.localPosition, size, lockAxis: true))
                  ..onEnd = ((_) => _dragging = null)
                  ..onCancel = (() => _dragging = null),
              ),
            },
            child: paint,
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handle(d.localPosition, size),
          onPanStart: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size, lockAxis: true),
          onPanEnd: (_) => _dragging = null,
          child: paint,
        );
      }),
    );
  }
}

/// 指を置いた時点で勝つドラッグ([RasqRadarChart.claimDrag])。スクロール / 横のスワイプとの取り合いに負けない。
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.axes, required this.values, required this.labels, required this.rings, required this.color, required this.lineColor, required this.gridColor, required this.textStyle, required this.radius});
  final List<String> axes;
  final Map<String, double> values;
  final Map<String, String> labels;
  final int rings;
  final Color color, lineColor, gridColor;
  final TextStyle textStyle;
  final double radius;

  Offset _point(Size size, int i, double v) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = -math.pi / 2 + 2 * math.pi * i / axes.length;
    return center + Offset(math.cos(angle), math.sin(angle)) * (radius * v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.isEmpty) return;
    final grid = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var r = 1; r <= rings; r++) {
      final path = Path();
      for (var i = 0; i < axes.length; i++) {
        final p = _point(size, i, r / rings);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    final axisPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(_point(size, i, 0), _point(size, i, 1), axisPaint);
    }
    // 値の多角形。
    final poly = Path();
    for (var i = 0; i < axes.length; i++) {
      final p = _point(size, i, (values[axes[i]] ?? 1.0).clamp(0.0, 1.0));
      i == 0 ? poly.moveTo(p.dx, p.dy) : poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    canvas.drawPath(poly, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
        poly,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (var i = 0; i < axes.length; i++) {
      final p = _point(size, i, (values[axes[i]] ?? 1.0).clamp(0.0, 1.0));
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
    // ラベル。
    for (var i = 0; i < axes.length; i++) {
      final tp = TextPainter(text: TextSpan(text: labels[axes[i]] ?? axes[i], style: textStyle), textDirection: TextDirection.ltr)..layout();
      final p = _point(size, i, 1.0);
      final center = Offset(size.width / 2, size.height / 2);
      final dir = (p - center) / (p - center).distance;
      final at = p + dir * 14 - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values || old.axes != axes || old.color != color || old.radius != radius;
}
