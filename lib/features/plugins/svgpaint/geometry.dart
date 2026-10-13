import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;

/// 落書きのエンジン (D-473) の小さな幾何。座標はすべて viewBox の単位。

/// 保存する座標の格子(0.1 単位)。描き終えた線・塗りの点は全部この格子に載せる(書き出し → 読み直し → 書き出しが同じ文字列になる)。
double q1(double v) => (v * 10).roundToDouble() / 10;

/// [q1] の点版。
Offset qp(Offset p) => Offset(q1(p.dx), q1(p.dy));

/// 0.1 単位の整数(書き出しの数の計算は整数でする: 相対座標の足し引きで誤差が溜まらない)。
int tenths(double v) => (v * 10).round();

/// 点から線分までの距離。
double segmentDistance(Offset p, Offset a, Offset b) {
  final t = segmentParam(p, a, b);
  return (p - Offset.lerp(a, b, t)!).distance;
}

/// 線分 a→b の上で [p] に一番近い位置(0〜1)。
double segmentParam(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return 0;
  return (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
}

/// 長さ 1 にした向き(長さ 0 なら [fallback])。
Offset unit(Offset v, [Offset fallback = const Offset(1, 0)]) {
  final d = v.distance;
  return d < 1e-9 ? fallback : v / d;
}

double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// 折れ線の長さ。
double polylineLength(List<Offset> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += (pts[i] - pts[i - 1]).distance;
  }
  return l;
}

/// Ramer–Douglas–Peucker の簡略化で残す点の番号(両端は残す)。
///
/// [widths] があれば、太さの食い違い × [widthWeight] も誤差に数える(入り・抜きの細り方を少ない点で残す)。
/// 再帰の代わりに区間の山(長い線でもスタックを使い切らない)。
List<int> rdpIndices(List<Offset> pts, double epsilon, {List<double>? widths, double widthWeight = 0.6}) {
  final n = pts.length;
  if (n < 3) return [for (var i = 0; i < n; i++) i];
  final keep = List.filled(n, false);
  keep[0] = keep[n - 1] = true;
  final stack = <(int, int)>[(0, n - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var far = -1;
    var farErr = epsilon;
    for (var i = a + 1; i < b; i++) {
      final t = segmentParam(pts[i], pts[a], pts[b]);
      var err = (pts[i] - Offset.lerp(pts[a], pts[b], t)!).distance;
      if (widths != null) {
        // 太さは線の長さに沿った位置で比べる(射影は端で潰れるので、番号の比で補う)。
        final u = (i - a) / (b - a);
        final w = widths[a] + (widths[b] - widths[a]) * u;
        err = math.max(err, (widths[i] - w).abs() * widthWeight);
      }
      if (err > farErr) {
        far = i;
        farErr = err;
      }
    }
    if (far < 0) continue;
    keep[far] = true;
    stack
      ..add((a, far))
      ..add((far, b));
  }
  return [for (var i = 0; i < n; i++) if (keep[i]) i];
}

/// 閉じた輪の RDP(始点と、そこから一番遠い点で 2 つに割って簡略化する)。輪は始点を繰り返さない。
List<Offset> rdpClosed(List<Offset> ring, double epsilon) {
  final n = ring.length;
  if (n < 4) return List.of(ring);
  var far = 0;
  var farD = -1.0;
  for (var i = 1; i < n; i++) {
    final d = (ring[i] - ring[0]).distanceSquared;
    if (d > farD) {
      farD = d;
      far = i;
    }
  }
  final a = ring.sublist(0, far + 1);
  final b = [...ring.sublist(far), ring[0]];
  final ka = rdpIndices(a, epsilon);
  final kb = rdpIndices(b, epsilon);
  return [for (final i in ka) a[i], for (final i in kb.skip(1).take(kb.length - 2)) b[i]];
}

/// 多角形の符号つき面積(y が下向きの座標で、時計回りが正)。
double signedArea(List<Offset> ring) {
  var s = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s / 2;
}

/// 点が多角形の中か(偶奇規則)。
bool pointInPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
  }
  return inside;
}

/// 点の列の外接矩形(空なら Rect.zero)。
Rect boundsOf(Iterable<Offset> pts) {
  var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (final p in pts) {
    l = math.min(l, p.dx);
    t = math.min(t, p.dy);
    r = math.max(r, p.dx);
    b = math.max(b, p.dy);
  }
  return l.isFinite ? Rect.fromLTRB(l, t, r, b) : Rect.zero;
}

/// 2 次元のアフィン変換(x' = a·x + c·y + e、y' = b·x + d·y + f)。投げ輪の移動 / 拡大縮小 / 回転に使う。
@immutable
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = Affine(1, 0, 0, 1, 0, 0);
  factory Affine.translate(Offset t) => Affine(1, 0, 0, 1, t.dx, t.dy);

  /// [center] を中心に [scale] 倍して [angle](ラジアン、時計回り)回し、[shift] だけずらす。
  factory Affine.around(Offset center, {double scale = 1, double angle = 0, Offset shift = Offset.zero}) {
    final cs = math.cos(angle) * scale, sn = math.sin(angle) * scale;
    // p' = R·S·(p - center) + center + shift
    return Affine(cs, sn, -sn, cs, center.dx - cs * center.dx + sn * center.dy + shift.dx, center.dy - sn * center.dx - cs * center.dy + shift.dy);
  }

  final double a, b, c, d, e, f;

  Offset apply(Offset p) => Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  /// 向きだけ(ずらしを除く)。
  Offset applyVector(Offset v) => Offset(a * v.dx + c * v.dy, b * v.dx + d * v.dy);

  /// 長さの倍率(面積の倍率の平方根。太さに掛ける)。
  double get scaleFactor => math.sqrt((a * d - b * c).abs());

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  /// this の後に [o] を掛ける(o ∘ this)。
  Affine then(Affine o) => Affine(
        o.a * a + o.c * b,
        o.b * a + o.d * b,
        o.a * c + o.c * d,
        o.b * c + o.d * d,
        o.a * e + o.c * f + o.e,
        o.b * e + o.d * f + o.f,
      );

  /// `Canvas.transform` に渡す 4×4(列優先)。
  Float64List get matrix4 => Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

  @override
  bool operator ==(Object other) => other is Affine && other.a == a && other.b == b && other.c == c && other.d == d && other.e == e && other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);
}

