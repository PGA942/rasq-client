import 'dart:math' as math;
import 'dart:ui';

import 'package:rrl_renderer/rrl_renderer.dart';

import 'geometry.dart';
import 'model.dart';
import 'nib.dart';
import 'spline.dart';

/// 落書きの SVG の書き出しと読み込み (D-473)。
///
/// **書き出し**(契約 v0.22 の許可リストの要素・属性だけ。メタデータの要素や `data-*` は置かない):
/// - ミリペン: `<path d="M…c…s…" fill="none" stroke="#rrggbb" stroke-width="W" stroke-linecap="round" stroke-linejoin="round"/>`。
///   d は節を通るなめらかな曲線([splineSegments])で、節は区間の終点そのもの(読み込みで節に戻せる)。節が 2 つなら直線 `l`、
///   点(タップ)は `h0`。
/// - カプラペン / ブラシニブ: 輪郭の塗り `<path d="M…c…z" fill="#rrggbb" stroke-linejoin="round"/>`(ブラシは `bevel`)。
///   線の無い塗りに付けた `stroke-linejoin` が印(見た目は変わらない)。区間は [outlineSegments] の決まった並び(2n 個)。
/// - 塗り: `<path d="M…c…z" fill="#rrggbb"/>`(閉じたなめらかな曲線、外の輪と穴は逆向き = nonzero で穴)。
/// - 続く同じ描き方は `<g 描き方>` にまとめる(SvgLite は `g` の描き方を子へ受け継いで平らにする)。
/// - 座標は 0.1 単位、最初の `M` 以外は相対、数の区切りは要るときだけ([segmentsToD])。
///
/// **読み込み**([SvgLite] で消毒してから): 形ごとに、書き出しの規則で節(と輪郭の張り出し)へ戻し、作り直した区間が
/// 元と一致したときだけ描き直せる線 / 塗りにする。前の版(`M` / `L` だけの線)は折れ線の線に。どれにも当たらなければ
/// [PaintShape](そのまま書き戻す)。viewBox が違えば紙へ縦横比を保って収める。
String encodeSvg(Size vb, List<PaintItem> items) {
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${svgLiteNum(vb.width)} ${svgLiteNum(vb.height)}">');
  final parts = [for (final i in items) i.svgParts];
  var i = 0;
  while (i < parts.length) {
    final (style, body) = parts[i];
    if (style == null) {
      b.write(body);
      i++;
      continue;
    }
    var j = i + 1;
    while (j < parts.length && parts[j].$1 == style) {
      j++;
    }
    if (j - i == 1) {
      // `<path d="…"/>` → `<path d="…" 描き方/>`。
      b.write('${body.substring(0, body.length - 2)}$style/>');
    } else {
      b.write('<g$style>');
      for (var k = i; k < j; k++) {
        b.write(parts[k].$2);
      }
      b.write('</g>');
    }
    i = j;
  }
  b.write('</svg>');
  return b.toString();
}

/// 続きの SVG を読む(SVG の文字列か `data:image/svg+xml` の URI)。読めなければ空。
List<PaintItem> decodeSvg(String? source, Size vb) {
  if (source == null || source.trim().isEmpty) return [];
  final doc = source.trimLeft().startsWith('data:') ? SvgLite.fromDataUri(source.trim()) : SvgLite.parse(source);
  if (doc == null) return [];
  final from = doc.viewBox;
  final s = math.min(vb.width / from.width, vb.height / from.height);
  final offset = Offset((vb.width - from.width * s) / 2 - from.left * s, (vb.height - from.height * s) / 2 - from.top * s);
  final same = s == 1 && offset == Offset.zero;
  // 動かして読んだ形は 0.1 の格子から外れるので、照合を緩める。
  final tol = same ? 0.06 : 0.3;
  final out = <PaintItem>[];
  for (final raw in doc.shapes) {
    final shape = same ? raw : raw.transformed(s, offset);
    out.addAll(_recognize(shape, tol) ?? [PaintShape(shape)]);
  }
  return out;
}

List<PaintItem>? _recognize(SvgLiteShape shape, double tol) {
  if (shape.opacity != 1) return null;
  final stroke = shape.stroke, fill = shape.fill;
  // 線(ミリペン)。
  if (stroke != null && fill == null && shape.strokeWidth > 0 && shape.strokeOpacity == 1) {
    final w = shape.strokeWidth;
    final lines = shape.polylines;
    if (lines != null) {
      // 前の版の線(M / L だけ): 折れ線のまま(端と角は丸に揃える)。
      final out = <PaintItem>[];
      for (final l in lines) {
        // 続く同じ点は 1 つに(点 = `h0` は 1 点に戻る)。
        final pts = <Offset>[];
        for (final p in l) {
          final q = qp(p);
          if (pts.isEmpty || pts.last != q) pts.add(q);
        }
        if (pts.isNotEmpty) out.add(PaintStroke(nib: PaintNib.mili, color: stroke, points: pts, widths: [for (final _ in pts) q1(w)], curve: false));
      }
      return out;
    }
    if (shape.kind != SvgLiteShapeKind.path || shape.strokeCap != StrokeCap.round) return null;
    final segs = parseCanonicalD(attrOf(shape.toSvgElement(), 'd') ?? '');
    if (segs.length < 3 || segs.first.cmd != 'M' || segs.skip(1).any((g) => g.cmd != 'C')) return null;
    final nodes = [for (final g in segs) qp(g.end)];
    if (!segmentsClose(splineSegments(nodes), segs, tol)) return null;
    return [PaintStroke(nib: PaintNib.mili, color: stroke, points: nodes, widths: [for (final _ in nodes) q1(w)])];
  }
  if (fill == null || stroke != null || shape.fillOpacity != 1 || shape.kind != SvgLiteShapeKind.path) return null;
  final segs = parseCanonicalD(attrOf(shape.toSvgElement(), 'd') ?? '');
  // 輪郭の線(カプラペン / ブラシニブ)。
  final nib = switch (shape.strokeJoin) {
    StrokeJoin.round => PaintNib.kabura,
    StrokeJoin.bevel => PaintNib.brush,
    _ => null,
  };
  if (nib != null) {
    final r = recoverOutline(segs, tolerance: tol, stretch: capStretch(nib));
    if (r == null) return null;
    final (c, v) = r;
    // 照合が緩いとき(動かして読んだ)は張り出しを持たず、太さから作り直す。
    return [PaintStroke(nib: nib, color: fill, points: c, widths: widthsFromOffsets(c, v), offsets: tol <= 0.06 ? v : null)];
  }
  // 塗り: 閉じた輪(M C… Z)の並び。
  final contours = <List<Offset>>[];
  var i = 0;
  while (i < segs.length) {
    if (segs[i].cmd != 'M') return null;
    final ring = <Offset>[qp(segs[i].end)];
    var j = i + 1;
    while (j < segs.length && segs[j].cmd == 'C') {
      ring.add(qp(segs[j].end));
      j++;
    }
    if (j >= segs.length || segs[j].cmd != 'Z' || ring.length < 4 || ring.last != ring.first) return null;
    ring.removeLast();
    contours.add(ring);
    i = j + 1;
  }
  if (contours.isEmpty) return null;
  final again = [for (final c in contours) ...splineSegments(c, closed: true)];
  if (!segmentsClose(again, segs, tol)) return null;
  return [PaintFill(color: fill, contours: contours)];
}
