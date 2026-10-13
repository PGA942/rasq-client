import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import 'geometry.dart';
import 'nib.dart';
import 'spline.dart';

/// 落書きの中身 (D-473)。紙に載るものは全部 [PaintItem](不変。取り消しは並びの写しを積む)。
///
/// - [PaintStroke]: 描いた線。**中心線の節と節ごとの太さ**を持ち、形はそこから作る(ミリペンは `stroke` の曲線、
///   カプラペン / ブラシニブは太さの変わる輪郭を塗る)。消しゴムで切ったら節と太さを切り分けて輪郭を作り直す。
/// - [PaintFill]: オート塗りつぶしの塗り(閉じた輪の節。なめらかな曲線で結ぶ)。
/// - [PaintShape]: 読み込んだ、描き直せない形(そのまま書き戻す)。
/// - [PaintPath]: 動かした / 色を変えた [PaintShape](区間と描き方を自前で持つ)。

/// ペン先。
enum PaintNib {
  /// ミリペン: 太さが一定、端と角は丸い(`stroke` の曲線)。
  mili('ミリペン'),

  /// カプラペン(G ペン): 筆圧(無ければ速さ、速いほど細い)で太さが変わり、両端が細る(入り・抜き)。輪郭を塗る。
  kabura('カプラペン'),

  /// ブラシニブ: 太く、太さの変わり方と入り・抜きが強く、進む向きで少し太さが変わる(筆の角度)。輪郭を塗る。
  brush('ブラシニブ');

  const PaintNib(this.label);
  final String label;
}

sealed class PaintItem {
  /// 描く形(viewBox の単位)。
  Path get path;

  /// 線の太さまで含めた外接矩形。
  Rect get bounds;

  /// 投げ輪の判定に使う点(形の上に散らした点)。
  List<Offset> get samples;

  void paint(Canvas canvas);

  /// 動かした / 拡大縮小した / 回した写し(座標は 0.1 単位に丸める)。
  PaintItem transformed(Affine m);

  /// 色を変えた写し。
  PaintItem recolored(Color c);

  /// SVG の書き出し: (描き方の属性 = `<g>` でまとめられる部分、要素)。描き方が null なら要素だけで完結している。
  (String? style, String body) get svgParts;
}

/// 描いた線。[points] は中心線の節(0.1 単位)、[widths] は節ごとの太さ(全幅、0.1 単位。ミリペンは全部同じ)。
class PaintStroke extends PaintItem {
  PaintStroke({required this.nib, required this.color, required this.points, required this.widths, this.curve = true, this.offsets})
      : assert(points.isNotEmpty && points.length == widths.length);

  final PaintNib nib;
  final Color color;
  final List<Offset> points;
  final List<double> widths;

  /// 節を曲線で結ぶか(false = 折れ線: 前の版の落書きから読んだ線)。
  final bool curve;

  /// 輪郭の線の、節ごとの左への張り出し(読み込んだ輪郭をそのまま書き戻すため。null なら太さから作る)。
  final List<Offset>? offsets;

  bool get isOutline => nib != PaintNib.mili;

  /// ミリペンの太さ(輪郭の線は一番太いところ)。
  double get width => widths.reduce(math.max);

  late final List<Offset> _offsets = offsets ?? outlineOffsets(points, widths);

  /// 形の区間。ミリペン = 中心線(曲線 / 折れ線)、輪郭の線 = 閉じた輪郭。
  late final List<PSeg> segments = isOutline ? outlineSegments(points, _offsets, stretch: capStretch(nib)) : (curve ? splineSegments(points) : polylineSegments(points));

  @override
  late final Path path = segmentsToPath(segments);

  @override
  late final Rect bounds = isOutline ? path.getBounds() : path.getBounds().inflate(width / 2);

  /// 中心線を細かく分けた点と太さ(消しゴム / 塗りつぶしの壁 / 投げ輪に使う)。
  late final (List<Offset>, List<double>) dense = densifyCenterline(this);

  @override
  List<Offset> get samples => dense.$1;

  @override
  void paint(Canvas canvas) {
    if (isOutline) {
      canvas.drawPath(path, Paint()
        ..isAntiAlias = true
        ..color = color);
      return;
    }
    if (points.length == 1 || points.every((p) => p == points.first)) {
      canvas.drawCircle(points.first, width / 2, Paint()..color = color);
      return;
    }
    canvas.drawPath(path, Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color);
  }

  @override
  PaintStroke transformed(Affine m) {
    final s = m.scaleFactor;
    return PaintStroke(
      nib: nib,
      color: color,
      points: [for (final p in points) qp(m.apply(p))],
      widths: [for (final w in widths) math.max(0.1, q1(w * s))],
      curve: curve,
    );
  }

  @override
  PaintStroke recolored(Color c) => PaintStroke(nib: nib, color: c, points: points, widths: widths, curve: curve, offsets: offsets);

  @override
  (String?, String) get svgParts {
    final d = segmentsToD(segments);
    final hex = svgLiteHex(color);
    final style = switch (nib) {
      PaintNib.mili => ' fill="none" stroke="$hex" stroke-width="${svgLiteNum(q1(width))}" stroke-linecap="round" stroke-linejoin="round"',
      // 輪郭の線の印: 線の無い塗りの path に `stroke-linejoin`(見た目は変わらない、許可リストの属性)。
      PaintNib.kabura => ' fill="$hex" stroke-linejoin="round"',
      PaintNib.brush => ' fill="$hex" stroke-linejoin="bevel"',
    };
    return (style, '<path d="$d"/>');
  }
}

/// オート塗りつぶしの塗り。[contours] は閉じた輪の節(始点は繰り返さない、0.1 単位)。外の輪と穴は向きが逆(nonzero で穴が空く)。
class PaintFill extends PaintItem {
  PaintFill({required this.color, required this.contours});
  final Color color;
  final List<List<Offset>> contours;

  late final List<PSeg> segments = [for (final c in contours) ...splineSegments(c, closed: true)];

  @override
  late final Path path = segmentsToPath(segments);

  @override
  late final Rect bounds = path.getBounds();

  @override
  List<Offset> get samples => [for (final c in contours) ...c];

  @override
  void paint(Canvas canvas) => canvas.drawPath(path, Paint()
    ..isAntiAlias = true
    ..color = color);

  @override
  PaintFill transformed(Affine m) => PaintFill(color: color, contours: [
        for (final c in contours) [for (final p in c) qp(m.apply(p))],
      ]);

  @override
  PaintFill recolored(Color c) => PaintFill(color: c, contours: contours);

  @override
  (String?, String) get svgParts => (' fill="${svgLiteHex(color)}"', '<path d="${segmentsToD(segments)}"/>');
}

/// 描き方(読み込んだ形の)。
@immutable
class ShapeStyle {
  const ShapeStyle({this.fill, this.stroke, this.strokeWidth = 1, this.cap = StrokeCap.butt, this.join = StrokeJoin.miter, this.fillOpacity = 1, this.strokeOpacity = 1, this.opacity = 1});
  factory ShapeStyle.of(SvgLiteShape s) => ShapeStyle(
        fill: s.kind == SvgLiteShapeKind.line ? null : s.fill,
        stroke: s.stroke,
        strokeWidth: s.strokeWidth,
        cap: s.strokeCap,
        join: s.strokeJoin,
        fillOpacity: s.fillOpacity,
        strokeOpacity: s.strokeOpacity,
        opacity: s.opacity,
      );
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
  final double fillOpacity;
  final double strokeOpacity;
  final double opacity;

  /// 線だけで、不透明(消しゴムで切れる線として扱える)。
  bool get isPlainLine => fill == null && stroke != null && strokeWidth > 0 && strokeOpacity == 1 && opacity == 1;

  ShapeStyle copyWith({Color? fill, Color? stroke, double? strokeWidth}) => ShapeStyle(
        fill: fill ?? this.fill,
        stroke: stroke ?? this.stroke,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        cap: cap,
        join: join,
        fillOpacity: fillOpacity,
        strokeOpacity: strokeOpacity,
        opacity: opacity,
      );

  /// [SvgLiteShape.toSvgElement] と同じ規則の属性(既定と同じものは書かない)。
  String get attrs {
    final b = StringBuffer();
    final f = fill;
    if (f == null) {
      b.write(' fill="none"');
    } else if (f.toARGB32() != 0xFF000000) {
      b.write(' fill="${svgLiteHex(f)}"');
    }
    if (fillOpacity != 1) b.write(' fill-opacity="${svgLiteNum(fillOpacity)}"');
    if (stroke case final s?) {
      b.write(' stroke="${svgLiteHex(s)}"');
      if (strokeOpacity != 1) b.write(' stroke-opacity="${svgLiteNum(strokeOpacity)}"');
      if (strokeWidth != 1) b.write(' stroke-width="${svgLiteNum(strokeWidth)}"');
      if (cap != StrokeCap.butt) b.write(' stroke-linecap="${cap.name}"');
      if (join != StrokeJoin.miter) b.write(' stroke-linejoin="${join.name}"');
    }
    if (opacity != 1) b.write(' opacity="${svgLiteNum(opacity)}"');
    return b.toString();
  }

  void paint(Canvas canvas, Path path) {
    final f = fill;
    if (f != null) {
      canvas.drawPath(path, Paint()
        ..isAntiAlias = true
        ..color = f.withValues(alpha: (fillOpacity * opacity).clamp(0.0, 1.0)));
    }
    final s = stroke;
    if (s != null && strokeWidth > 0) {
      canvas.drawPath(path, Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = cap
        ..strokeJoin = join
        ..strokeMiterLimit = 4
        ..color = s.withValues(alpha: (strokeOpacity * opacity).clamp(0.0, 1.0)));
    }
  }
}

/// 読み込んだ、描き直せない形(手を付けていなければ [SvgLiteShape.toSvgElement] でそのまま書き戻す)。
class PaintShape extends PaintItem {
  PaintShape(this.shape);
  final SvgLiteShape shape;

  @override
  Path get path => shape.path;

  @override
  Rect get bounds => shape.bounds;

  @override
  late final List<Offset> samples = samplePath(shape.path);

  @override
  void paint(Canvas canvas) => shape.paint(canvas);

  /// 自前の区間に直したもの(動かす / 色を変えるとき)。
  late final PaintPath generic = PaintPath(shapeSegments(shape), ShapeStyle.of(shape));

  @override
  PaintItem transformed(Affine m) => generic.transformed(m);

  @override
  PaintItem recolored(Color c) => generic.recolored(c);

  @override
  (String?, String) get svgParts => (null, shape.toSvgElement());
}

/// 動かした / 色を変えた形(区間は `M L C Z`、絶対座標)。
class PaintPath extends PaintItem {
  PaintPath(this.segments, this.style);
  final List<PSeg> segments;
  final ShapeStyle style;

  @override
  late final Path path = segmentsToPath(segments);

  @override
  late final Rect bounds = style.stroke != null && style.strokeWidth > 0 ? path.getBounds().inflate(style.strokeWidth / 2) : path.getBounds();

  @override
  late final List<Offset> samples = samplePath(path);

  @override
  void paint(Canvas canvas) => style.paint(canvas, path);

  @override
  PaintPath transformed(Affine m) => PaintPath(
        [for (final s in segments) PSeg(s.cmd, [for (final p in s.pts) qp(m.apply(p))])],
        style.copyWith(strokeWidth: q1(style.strokeWidth * m.scaleFactor)),
      );

  /// 線があれば線の色を、無ければ塗りの色を変える。
  @override
  PaintPath recolored(Color c) => PaintPath(segments, style.stroke != null ? style.copyWith(stroke: c) : style.copyWith(fill: c));

  @override
  (String?, String) get svgParts => (style.attrs, '<path d="${segmentsToD(segments)}"/>');
}

/// Path の上に [step] 単位ごとに点を散らす(投げ輪の判定用)。点が取れなければ外接矩形の真ん中。
List<Offset> samplePath(Path path, {double step = 3}) {
  final out = <Offset>[];
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += step) {
      final t = m.getTangentForOffset(d);
      if (t != null) out.add(t.position);
    }
  }
  if (out.isEmpty) out.add(path.getBounds().center);
  return out;
}

/// [SvgLiteShape] → 自前の区間(`Q` は `C` に、円 / 楕円 / 角丸は 3 次ベジェの近似)。
List<PSeg> shapeSegments(SvgLiteShape s) {
  final el = s.toSvgElement();
  double n(String k) => double.tryParse(attrOf(el, k) ?? '') ?? 0;
  const k = 0.5522847498;
  List<PSeg> ellipse(Offset c, double rx, double ry) => [
        moveTo(Offset(c.dx + rx, c.dy)),
        cubicTo(Offset(c.dx + rx, c.dy + ry * k), Offset(c.dx + rx * k, c.dy + ry), Offset(c.dx, c.dy + ry)),
        cubicTo(Offset(c.dx - rx * k, c.dy + ry), Offset(c.dx - rx, c.dy + ry * k), Offset(c.dx - rx, c.dy)),
        cubicTo(Offset(c.dx - rx, c.dy - ry * k), Offset(c.dx - rx * k, c.dy - ry), Offset(c.dx, c.dy - ry)),
        cubicTo(Offset(c.dx + rx * k, c.dy - ry), Offset(c.dx + rx, c.dy - ry * k), Offset(c.dx + rx, c.dy)),
        closePath,
      ];
  List<Offset> points() {
    final nums = RegExp(r'-?(?:\d+\.?\d*|\.\d+)').allMatches(attrOf(el, 'points') ?? '').map((m) => double.parse(m[0]!)).toList();
    return [for (var i = 0; i + 1 < nums.length; i += 2) Offset(nums[i], nums[i + 1])];
  }

  switch (s.kind) {
    case SvgLiteShapeKind.path:
      final out = <PSeg>[];
      var cur = Offset.zero;
      for (final seg in parseCanonicalD(attrOf(el, 'd') ?? '')) {
        if (seg.cmd == 'Q') {
          final c = seg.pts[0], e = seg.pts[1];
          out.add(cubicTo(Offset.lerp(cur, c, 2 / 3)!, Offset.lerp(e, c, 2 / 3)!, e));
        } else {
          out.add(seg);
        }
        if (seg.pts.isNotEmpty) cur = seg.end;
      }
      return out;
    case SvgLiteShapeKind.polyline:
    case SvgLiteShapeKind.polygon:
      final pts = points();
      return [...polylineSegments(pts), if (s.kind == SvgLiteShapeKind.polygon) closePath];
    case SvgLiteShapeKind.line:
      return [moveTo(Offset(n('x1'), n('y1'))), lineTo(Offset(n('x2'), n('y2')))];
    case SvgLiteShapeKind.rect:
      final x = n('x'), y = n('y'), w = n('width'), h = n('height');
      var rx = n('rx'), ry = n('ry');
      if (rx <= 0 && ry > 0) rx = ry;
      if (ry <= 0 && rx > 0) ry = rx;
      if (rx <= 0) return [moveTo(Offset(x, y)), lineTo(Offset(x + w, y)), lineTo(Offset(x + w, y + h)), lineTo(Offset(x, y + h)), closePath];
      return [
        moveTo(Offset(x + rx, y)),
        lineTo(Offset(x + w - rx, y)),
        cubicTo(Offset(x + w - rx + rx * k, y), Offset(x + w, y + ry - ry * k), Offset(x + w, y + ry)),
        lineTo(Offset(x + w, y + h - ry)),
        cubicTo(Offset(x + w, y + h - ry + ry * k), Offset(x + w - rx + rx * k, y + h), Offset(x + w - rx, y + h)),
        lineTo(Offset(x + rx, y + h)),
        cubicTo(Offset(x + rx - rx * k, y + h), Offset(x, y + h - ry + ry * k), Offset(x, y + h - ry)),
        lineTo(Offset(x, y + ry)),
        cubicTo(Offset(x, y + ry - ry * k), Offset(x + rx - rx * k, y), Offset(x + rx, y)),
        closePath,
      ];
    case SvgLiteShapeKind.circle:
      return ellipse(Offset(n('cx'), n('cy')), n('r'), n('r'));
    case SvgLiteShapeKind.ellipse:
      return ellipse(Offset(n('cx'), n('cy')), n('rx'), n('ry'));
  }
}
