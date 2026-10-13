import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'model.dart';
import 'spline.dart';

/// ペン先の作り (D-473): 太さの決め方、入り・抜き、切り口の丸め込み、輪郭。

/// ペン先の基準の太さ(viewBox の単位)。[size] は太さのボタンの値(ミリペンはそのままの太さ)。
double nibBaseWidth(PaintNib nib, double size) => switch (nib) {
      PaintNib.mili => size,
      PaintNib.kabura => size * 1.5,
      PaintNib.brush => size * 2.4,
    };

/// 入力の点 1 つ(手ぶれ補正の後、viewBox の単位)。[t] はミリ秒、[pressure] は 0〜1(筆圧が取れないときは null)。
class InkSample {
  const InkSample(this.p, this.t, [this.pressure]);
  final Offset p;
  final double t;
  final double? pressure;
}

/// 点ごとの太さ(入り・抜きの前)。描いている間に 1 点ずつ足す。
///
/// - ミリペン: いつも [size]。
/// - カプラペン: 筆圧があれば 0.2 + 0.8·p、無ければ画面の速さ v(px/ms、指数移動平均 0.35)で 1/(1 + 0.5v)(0.3〜1)。
/// - ブラシニブ: 筆圧 0.1 + 0.9·p^1.3、無ければ 1/(1 + 0.35v)(0.4〜1)。さらに筆の向き(45°)と進む向きの角度で 0.75〜1。
/// - 急に変わらないよう、太さも指数移動平均でならす(カプラ 0.4、ブラシ 0.25)。
class NibDynamics {
  NibDynamics(this.nib, this.size, {this.pxPerUnit = 1});
  final PaintNib nib;
  final double size;

  /// 画面の 1 単位あたりの px(速さを画面の上の速さで測る: 紙の拡大率で太さの出方が変わらない)。
  final double pxPerUnit;

  double _v = 0;
  double? _w;
  double _angle = 1;
  InkSample? _last;

  double next(InkSample s) {
    if (nib == PaintNib.mili) return size;
    final base = nibBaseWidth(nib, size);
    final last = _last;
    if (last != null) {
      final dt = math.max(1.0, s.t - last.t);
      final v = (s.p - last.p).distance * pxPerUnit / dt;
      _v += (v - _v) * 0.35;
      final dir = s.p - last.p;
      if (nib == PaintNib.brush && dir.distance > 0.05) {
        final a = math.atan2(dir.dy, dir.dx) - math.pi / 4;
        _angle += (0.75 + 0.25 * math.sin(a).abs() - _angle) * 0.5;
      }
    }
    final p = s.pressure;
    double f;
    if (p != null) {
      final c = p.clamp(0.0, 1.0);
      f = nib == PaintNib.kabura ? 0.2 + 0.8 * c : 0.1 + 0.9 * math.pow(c, 1.3);
    } else {
      f = nib == PaintNib.kabura ? (1 / (1 + 0.5 * _v)).clamp(0.3, 1.0) : (1 / (1 + 0.35 * _v)).clamp(0.4, 1.0);
    }
    if (nib == PaintNib.brush) f *= _angle;
    final w = base * f;
    final prev = _w;
    final out = prev == null ? w : prev + (w - prev) * (nib == PaintNib.brush ? 0.25 : 0.4);
    _w = out;
    _last = s;
    return out;
  }
}

/// 入りの長さと抜きの長さ(viewBox の単位)。
(double, double) taperLengths(PaintNib nib, double size) => switch (nib) {
      PaintNib.mili => (0, 0),
      PaintNib.kabura => (math.max(4, size * 3), math.max(6, size * 4)),
      PaintNib.brush => (math.max(6, size * 4.5), math.max(8, size * 6)),
    };

/// 入り・抜き: 始点から [taperLengths] の間を細くする(端の太さは カプラ 8%、ブラシ 4%、sin のなめらかな立ち上がり)。
/// 短い線は入りと抜きを線の長さの 8 割に収める。[end] = false なら抜きは付けない(描いている途中)。
List<double> applyTaper(List<Offset> pts, List<double> w, PaintNib nib, double size, {bool start = true, bool end = true}) {
  if (nib == PaintNib.mili || pts.length < 2) return List.of(w);
  var (lin, lout) = taperLengths(nib, size);
  final total = polylineLength(pts);
  final want = (start ? lin : 0) + (end ? lout : 0);
  if (want > total * 0.8 && want > 0) {
    final k = total * 0.8 / want;
    lin *= k;
    lout *= k;
  }
  final minF = nib == PaintNib.kabura ? 0.08 : 0.04;
  double ease(double x) => minF + (1 - minF) * math.sin(x.clamp(0.0, 1.0) * math.pi / 2);
  final out = List.of(w);
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    if (i > 0) s += (pts[i] - pts[i - 1]).distance;
    final e = total - s;
    var f = 1.0;
    if (start && s < lin) f *= ease(s / lin);
    if (end && e < lout) f *= ease(e / lout);
    out[i] = w[i] * f;
  }
  return out;
}

/// 切り口の丸め込み(消しゴムで切った端)。ミリペンは丸い端(`stroke-linecap="round"`)なのでそのまま。
/// カプラペン / ブラシニブは、切り口から短い長さ(カプラ max(1.5, 0.6·太さ)、ブラシ max(2, 0.9·太さ))の太さを
/// 端で 70% / 55% まで細くし(smoothstep: 端と付け根で傾き 0 = 段もくびれも出ない)、輪郭の端の丸い蓋([capStretch]:
/// カプラは半円、ブラシは 1.25 倍に伸ばした半楕円)で閉じる。端の近くは 0.5 単位ごとに点を足す。
(List<Offset>, List<double>) roundCutEnds(List<Offset> pts, List<double> w, PaintNib nib, {bool cutStart = false, bool cutEnd = false}) {
  if (nib == PaintNib.mili || pts.length < 2 || (!cutStart && !cutEnd)) return (pts, w);
  final kab = nib == PaintNib.kabura;
  final floor = kab ? 0.7 : 0.55;
  double lenFor(double wEnd) => kab ? math.max(1.5, wEnd * 0.6) : math.max(2.0, wEnd * 0.9);
  var p = pts, ww = w;
  if (cutStart) (p, ww) = _refineEnd(p, ww, lenFor(ww.first));
  if (cutEnd) {
    final (rp, rw) = _refineEnd(p.reversed.toList(), ww.reversed.toList(), lenFor(ww.last));
    p = rp.reversed.toList();
    ww = rw.reversed.toList();
  }
  final out = List.of(ww);
  double ease(double x) {
    final c = x.clamp(0.0, 1.0);
    return floor + (1 - floor) * c * c * (3 - 2 * c);
  }

  final total = polylineLength(p);
  final ls = lenFor(ww.first), le = lenFor(ww.last);
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    if (i > 0) s += (p[i] - p[i - 1]).distance;
    var f = 1.0;
    if (cutStart && s < ls) f *= ease(s / ls);
    if (cutEnd && total - s < le) f *= ease((total - s) / le);
    out[i] = ww[i] * f;
  }
  return (p, out);
}

/// 始点から [len] の間を 0.5 単位ごとに細かくする(丸め込みの細りを点で表せるように)。
(List<Offset>, List<double>) _refineEnd(List<Offset> p, List<double> w, double len) {
  final op = <Offset>[p.first], ow = <double>[w.first];
  var s = 0.0;
  for (var i = 1; i < p.length; i++) {
    final seg = (p[i] - p[i - 1]).distance;
    if (s < len && seg > 0.75) {
      final k = (math.min(seg, len - s + 0.5) / 0.5).floor();
      for (var j = 1; j <= k; j++) {
        final t = j * 0.5 / seg;
        if (t >= 0.9) break;
        op.add(Offset.lerp(p[i - 1], p[i], t)!);
        ow.add(w[i - 1] + (w[i] - w[i - 1]) * t);
      }
    }
    op.add(p[i]);
    ow.add(w[i]);
    s += seg;
  }
  return (op, ow);
}

/// 簡略化の許し(viewBox の単位)。描き終えた線 / 消しゴムで切った線。
const strokeEpsilon = 0.75;
const cutEpsilon = 0.35;

/// 描き終えた線を作る: 入り・抜き → 太さも見る RDP → 0.1 単位に丸める。
/// [points] / [widths] は手ぶれ補正の後の点と [NibDynamics] の太さ(同じ数)。
PaintStroke buildStroke({required PaintNib nib, required Color color, required double size, required List<Offset> points, required List<double> widths}) {
  // 続く同じ点は 1 つに。
  final p = <Offset>[], w = <double>[];
  for (var i = 0; i < points.length; i++) {
    if (p.isNotEmpty && (points[i] - p.last).distance < 0.05) continue;
    p.add(points[i]);
    w.add(widths[i]);
  }
  if (p.length == 1) {
    final dot = nib == PaintNib.mili ? size : nibBaseWidth(nib, size) * 0.8;
    return PaintStroke(nib: nib, color: color, points: [qp(p.first)], widths: [q1(dot)]);
  }
  final tw = nib == PaintNib.mili ? [for (final _ in p) size] : applyTaper(p, w, nib, size);
  return simplifyStroke(nib: nib, color: color, points: p, widths: tw, epsilon: strokeEpsilon);
}

/// 細かい点と太さ → 節(0.1 単位)。曲線の線は [splineDecimate]、折れ線は太さも見る RDP。
PaintStroke simplifyStroke({required PaintNib nib, required Color color, required List<Offset> points, required List<double> widths, required double epsilon, bool curve = true}) {
  final ws = nib == PaintNib.mili ? null : widths;
  final keep = curve ? splineDecimate(points, epsilon, widths: ws) : rdpIndices(points, epsilon, widths: ws);
  final np = <Offset>[], nw = <double>[];
  for (final i in keep) {
    final q = qp(points[i]);
    if (np.isNotEmpty && np.last == q) continue;
    np.add(q);
    nw.add(math.max(0.1, q1(widths[i])));
  }
  if (nib == PaintNib.mili) {
    final c = q1(widths.first);
    for (var i = 0; i < nw.length; i++) {
      nw[i] = c;
    }
  }
  return PaintStroke(nib: nib, color: color, points: np, widths: nw, curve: curve);
}

/// 輪郭の線の、節ごとの左への張り出し(0.1 単位)。左 = 中心 + 張り出し、右 = 中心 − 張り出し。
/// 向きは前後の節を結ぶ向き(Catmull-Rom の接線)に直角。曲がり角はマイター(1/cos(θ/2)、2 倍まで)で太さを保つ。
List<Offset> outlineOffsets(List<Offset> c, List<double> w) {
  final n = c.length;
  if (n == 1) return [qp(Offset(0, -w[0] / 2))];
  final out = <Offset>[];
  var lastT = unit(c[1] - c[0]);
  for (var i = 0; i < n; i++) {
    final prev = i > 0 ? c[i - 1] : c[i];
    final next = i < n - 1 ? c[i + 1] : c[i];
    final t = unit(next - prev, lastT);
    lastT = t;
    final nrm = Offset(-t.dy, t.dx);
    var m = 1.0;
    if (i > 0 && i < n - 1) {
      final seg = unit(c[i] - c[i - 1], t);
      final cosHalf = dot(nrm, Offset(-seg.dy, seg.dx));
      m = 1 / math.max(cosHalf, 0.5);
    }
    out.add(qp(nrm * (w[i] / 2 * m)));
  }
  return out;
}

/// 輪郭の線の端の蓋の伸ばし(1 = 半円)。カプラペンは半円、ブラシニブは少し長い半楕円(筆の丸い穂先)。
/// 入り・抜きの端は太さがほぼ 0 なので、効くのは切り口(と太いまま止めた点)だけ。
double capStretch(PaintNib nib) => nib == PaintNib.brush ? 1.25 : 1.0;

/// 輪郭の線の区間: `M 左0` → 左の側(なめらかな曲線)→ 終わりの蓋(3 次ベジェ 1 つ、腕 4/3·r·[stretch] = 半円 / 半楕円)→
/// 右の側を戻る → 始まりの蓋 → `Z`。区間の数はいつも 2n(n = 節の数)なので、読み込むときに節と張り出しへ戻せる([recoverOutline])。
List<PSeg> outlineSegments(List<Offset> c, List<Offset> v, {double stretch = 1}) {
  final n = c.length;
  final left = [for (var i = 0; i < n; i++) c[i] + v[i]];
  final right = [for (var i = n - 1; i >= 0; i--) c[i] - v[i]];
  final segs = <PSeg>[moveTo(left.first)];
  void side(List<Offset> pts) {
    if (pts.length < 2) return;
    final ctl = smoothControls(pts);
    for (var s = 0; s < ctl.length; s++) {
      segs.add(cubicTo(ctl[s].$1, ctl[s].$2, pts[s + 1]));
    }
  }

  // 半円: 張り出し v の向きから進む向き t = (v.y, −v.x)/|v| を出し、[forward] なら前へ、でなければ後ろへ膨らませる。
  void cap(Offset from, Offset to, Offset vv, {required bool forward}) {
    final r = vv.distance;
    final t = r < 1e-9 ? Offset.zero : Offset(vv.dy, -vv.dx) / r;
    final arm = t * (4 / 3 * r * stretch) * (forward ? 1 : -1);
    segs.add(cubicTo(qp(from + arm), qp(to + arm), to));
  }

  side(left);
  cap(left.last, right.first, v[n - 1], forward: true);
  side(right);
  cap(right.last, left.first, v[0], forward: false);
  segs.add(closePath);
  return segs;
}

/// [outlineSegments] の区間(読み込んだもの)から節と張り出しを戻す。形が合わなければ null。
/// 戻した節と張り出しで作り直した区間が、どの点も [tolerance] 以内で一致したときだけ認める(よその塗りの形を線と取り違えない)。
(List<Offset>, List<Offset>)? recoverOutline(List<PSeg> segs, {double tolerance = 0.12, double stretch = 1}) {
  if (segs.length < 4 || segs.first.cmd != 'M' || segs.last.cmd != 'Z') return null;
  final body = segs.sublist(1, segs.length - 1);
  if (body.isEmpty || body.length.isOdd || body.any((s) => s.cmd != 'C')) return null;
  final n = body.length ~/ 2;
  final left = <Offset>[segs.first.end, for (var i = 0; i < n - 1; i++) body[i].end];
  final right = <Offset>[for (var j = 0; j < n; j++) body[n - 1 + j].end]; // R[n−1] … R[0]
  final c = <Offset>[], v = <Offset>[];
  for (var i = 0; i < n; i++) {
    final l = qp(left[i]), r = qp(right[n - 1 - i]);
    final mid = qp((l + r) / 2);
    c.add(mid);
    v.add(qp(l - mid));
  }
  final again = outlineSegments(c, v, stretch: stretch);
  if (!segmentsClose(again, segs, tolerance)) return null;
  return (c, v);
}

/// 張り出しから太さ(全幅)を戻す(曲がり角のマイターを割り戻す)。
List<double> widthsFromOffsets(List<Offset> c, List<Offset> v) {
  final n = c.length;
  if (n == 1) return [q1(v[0].distance * 2)];
  final out = <double>[];
  var lastT = unit(c[1] - c[0]);
  for (var i = 0; i < n; i++) {
    final prev = i > 0 ? c[i - 1] : c[i];
    final next = i < n - 1 ? c[i + 1] : c[i];
    final t = unit(next - prev, lastT);
    lastT = t;
    var m = 1.0;
    if (i > 0 && i < n - 1) {
      final seg = unit(c[i] - c[i - 1], t);
      m = 1 / math.max(dot(Offset(-t.dy, t.dx), Offset(-seg.dy, seg.dx)), 0.5);
    }
    out.add(math.max(0.1, q1(v[i].distance * 2 / m)));
  }
  return out;
}

/// 区間の列が同じ形か(命令が同じで、どの点も [tolerance] 以内)。
bool segmentsClose(List<PSeg> a, List<PSeg> b, double tolerance) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].cmd != b[i].cmd || a[i].pts.length != b[i].pts.length) return false;
    for (var k = 0; k < a[i].pts.length; k++) {
      final d = a[i].pts[k] - b[i].pts[k];
      if (d.dx.abs() > tolerance || d.dy.abs() > tolerance) return false;
    }
  }
  return true;
}

/// 中心線を細かく分けた点と太さ(曲線は描く形と同じ曲線の上、1 単位ごと。太さは節の間で直線に補う)。
(List<Offset>, List<double>) densifyCenterline(PaintStroke s, {double step = 1}) {
  final pts = s.points, w = s.widths;
  if (pts.length == 1) return ([pts.first], [w.first]);
  final op = <Offset>[pts.first], ow = <double>[w.first];
  final ctl = s.curve && pts.length > 2 ? smoothControls(pts) : null;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    if (ctl == null) {
      final k = ((b - a).distance / step).ceil().clamp(1, 4096);
      for (var j = 1; j <= k; j++) {
        op.add(Offset.lerp(a, b, j / k)!);
        ow.add(w[i] + (w[i + 1] - w[i]) * j / k);
      }
    } else {
      final (c1, c2) = ctl[i];
      final est = (c1 - a).distance + (c2 - c1).distance + (b - c2).distance;
      final k = (est / step).ceil().clamp(1, 4096);
      for (var j = 1; j <= k; j++) {
        op.add(cubicPoint(a, c1, c2, b, j / k));
        ow.add(w[i] + (w[i + 1] - w[i]) * j / k);
      }
    }
  }
  return (op, ow);
}

/// 描いている途中の線の形(細かい点のまま。輪郭の線は入りだけ付ける)。
PaintStroke liveStroke({required PaintNib nib, required Color color, required double size, required List<Offset> points, required List<double> widths}) {
  if (nib == PaintNib.mili) return PaintStroke(nib: nib, color: color, points: List.of(points), widths: [for (final _ in points) size], curve: false);
  final w = applyTaper(points, widths, nib, size, end: false);
  return PaintStroke(nib: nib, color: color, points: List.of(points), widths: w, curve: false);
}

/// 曲線のための間引き: まず許しの半分の RDP で節を選び、そこから節を 1 つずつ抜いてみて、抜いた後のなめらかな曲線
/// ([smoothControls])が元の細かい点から [epsilon] 以内(太さは × [widthWeight] で比べる)に収まる限り抜く。
/// 折れ線の近似(RDP)より節がずっと少なくて済む(曲線は節の間をふくらんで通るので)。調べるのは抜いた節の前後 2 区間だけ。
List<int> splineDecimate(List<Offset> pts, double epsilon, {List<double>? widths, double widthWeight = 0.5}) {
  var keep = rdpIndices(pts, epsilon * 0.5, widths: widths, widthWeight: widthWeight);
  if (keep.length <= 2) return keep;
  var changed = true;
  while (changed) {
    changed = false;
    var j = 1;
    while (j < keep.length - 1) {
      final cand = [...keep]..removeAt(j);
      if (_fits(pts, widths, cand, math.max(0, j - 2), math.min(cand.length - 1, j + 1), epsilon, widthWeight)) {
        keep = cand;
        changed = true;
      }
      j++;
    }
  }
  return keep;
}

/// 節 [keep] の曲線の区間 from..to が、その間の元の点を許しの中で通るか。
bool _fits(List<Offset> pts, List<double>? widths, List<int> keep, int from, int to, double eps, double ww) {
  final nodes = [for (final i in keep) pts[i]];
  final ctl = smoothControls(nodes);
  for (var s = from; s < to; s++) {
    final a = keep[s], b = keep[s + 1];
    if (b - a < 2) continue;
    final (c1, c2) = ctl[s];
    final p0 = nodes[s], p1 = nodes[s + 1];
    final est = (c1 - p0).distance + (c2 - c1).distance + (p1 - c2).distance;
    final k = (est / 0.75).ceil().clamp(2, 400);
    final poly = [for (var i = 0; i <= k; i++) cubicPoint(p0, c1, c2, p1, i / k)];
    var lo = 0;
    for (var q = a + 1; q < b; q++) {
      // 元の点は曲線に沿って進むので、近い線分の探し始めを前へ送る(後ろへ戻らない)。
      var best = double.infinity;
      var bestAt = lo;
      for (var i = lo; i < poly.length - 1; i++) {
        final d = segmentDistance(pts[q], poly[i], poly[i + 1]);
        if (d < best) {
          best = d;
          bestAt = i;
        }
        if (best <= eps * 0.25 && i > bestAt + 4) break;
      }
      if (best > eps) return false;
      lo = math.max(0, bestAt - 2);
      if (widths != null) {
        final u = (q - a) / (b - a);
        final wl = widths[a] + (widths[b] - widths[a]) * u;
        if ((widths[q] - wl).abs() * ww > eps) return false;
      }
    }
  }
  return true;
}
