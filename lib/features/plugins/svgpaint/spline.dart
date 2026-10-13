import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;

import 'geometry.dart';

/// なめらかな曲線 (D-473): 節を必ず通る 3 次ベジェの列と、その書き出し / 読み込み。
///
/// 節 p[i] での接線の向きは Catmull-Rom と同じ t = p[i+1] − p[i−1]。腕は前後で同じ長さ(折り返し = SVG の `s` で
/// 4 つの数に縮められる)で、a = t/6 · 4sₚsₙ/(sₚ+sₙ)²(sₚ / sₙ は前後の区間の長さ)。間隔が揃っていれば一様な Catmull-Rom
/// (t/6)そのもので、揃わない(RDP の後)ときは短い方に合わせて縮み(さらに短い区間の 0.45 倍まで)、輪や行き過ぎが出ない。
/// 腕は節の前後で同じ向き・同じ長さ(C1)なので、つなぎ目に角が出ない。開いた線の両端は、隣の制御点へ向けた半分の腕(放物線の端)。

/// path の区間 1 つ(絶対座標)。`M` / `L` は [pts] = [p]、`C` は [c1, c2, p]、`Z` は空。
@immutable
class PSeg {
  const PSeg(this.cmd, this.pts);
  final String cmd;
  final List<Offset> pts;

  Offset get end => pts.last;

  @override
  String toString() => '$cmd${pts.map((p) => '${p.dx},${p.dy}').join(' ')}';
}

PSeg moveTo(Offset p) => PSeg('M', [p]);
PSeg lineTo(Offset p) => PSeg('L', [p]);
PSeg cubicTo(Offset c1, Offset c2, Offset p) => PSeg('C', [c1, c2, p]);
const closePath = PSeg('Z', []);

/// 区間ごとの制御点 (c1, c2)。開いた線は nodes.length − 1 個、閉じた輪は nodes.length 個(最後は p[n−1] → p[0])。
/// 制御点は 0.1 単位に丸める(描くのも書き出すのも同じ値)。
List<(Offset, Offset)> smoothControls(List<Offset> p, {bool closed = false}) {
  final n = p.length;
  final segs = closed ? n : n - 1;
  if (segs <= 0 || (closed && n < 3)) return const [];
  if (!closed && n == 2) return [(qp(Offset.lerp(p[0], p[1], 1 / 3)!), qp(Offset.lerp(p[0], p[1], 2 / 3)!))];
  Offset at(int i) => p[(i % n + n) % n];
  // 腕は 0.1 単位に丸めてから足し引きする(前後の制御点がきっちり折り返しになる)。
  final arm = List.filled(n, Offset.zero);
  for (var i = 0; i < n; i++) {
    if (!closed && (i == 0 || i == n - 1)) continue;
    final t = at(i + 1) - at(i - 1);
    final sp = (at(i) - at(i - 1)).distance, sn = (at(i + 1) - at(i)).distance;
    if (sp < 1e-9 || sn < 1e-9) continue;
    var a = t * (4 * sp * sn / ((sp + sn) * (sp + sn)) / 6);
    final cap = 0.45 * math.min(sp, sn);
    if (a.distance > cap) a = a * (cap / a.distance);
    arm[i] = qp(a);
  }
  final out = <(Offset, Offset)>[];
  for (var s = 0; s < segs; s++) {
    out.add((at(s) + arm[s], at(s + 1) - arm[(s + 1) % n]));
  }
  if (!closed) {
    // 両端: 隣の制御点へ向けた半分の腕。
    out[0] = (p[0] + (out[0].$2 - p[0]) / 2, out[0].$2);
    final l = out.length - 1;
    out[l] = (out[l].$1, p[n - 1] + (out[l].$1 - p[n - 1]) / 2);
  }
  return [for (final (a, b) in out) (qp(a), qp(b))];
}

/// 節を通るなめらかな曲線の区間(`M` + `C`…、閉じた輪は最後に `Z`)。節が 2 つの開いた線は直線(`L`)。
List<PSeg> splineSegments(List<Offset> nodes, {bool closed = false}) {
  if (nodes.isEmpty) return const [];
  if (nodes.length == 1) return [moveTo(nodes[0]), lineTo(nodes[0])];
  if (!closed && nodes.length == 2) return [moveTo(nodes[0]), lineTo(nodes[1])];
  final ctl = smoothControls(nodes, closed: closed);
  return [
    moveTo(nodes[0]),
    for (var s = 0; s < ctl.length; s++) cubicTo(ctl[s].$1, ctl[s].$2, nodes[(s + 1) % nodes.length]),
    if (closed) closePath,
  ];
}

/// 折れ線の区間(`M` + `L`…。1 点なら同じ点への `L` = 点)。
List<PSeg> polylineSegments(List<Offset> pts) {
  if (pts.isEmpty) return const [];
  return [moveTo(pts[0]), if (pts.length == 1) lineTo(pts[0]) else for (final p in pts.skip(1)) lineTo(p)];
}

/// 区間 → `dart:ui` の Path。
Path segmentsToPath(Iterable<PSeg> segs, [Path? into]) {
  final path = into ?? Path();
  for (final s in segs) {
    final v = s.pts;
    switch (s.cmd) {
      case 'M':
        path.moveTo(v[0].dx, v[0].dy);
      case 'L':
        path.lineTo(v[0].dx, v[0].dy);
      case 'C':
        path.cubicTo(v[0].dx, v[0].dy, v[1].dx, v[1].dy, v[2].dx, v[2].dy);
      case 'Q':
        path.quadraticBezierTo(v[0].dx, v[0].dy, v[1].dx, v[1].dy);
      case 'Z':
        path.close();
    }
  }
  return path;
}

/// 区間を折れ線に細かく分ける([step] 単位ごと、曲線は制御点の長さで分割数を見積もる)。`M` ごとに 1 本。
List<List<Offset>> flattenSegments(List<PSeg> segs, {double step = 1.5}) {
  final out = <List<Offset>>[];
  var cur = Offset.zero;
  var start = Offset.zero;
  for (final s in segs) {
    switch (s.cmd) {
      case 'M':
        cur = start = s.pts[0];
        out.add([cur]);
      case 'L':
        final p = s.pts[0];
        final k = ((p - cur).distance / step).ceil().clamp(1, 4096);
        for (var i = 1; i <= k; i++) {
          out.last.add(Offset.lerp(cur, p, i / k)!);
        }
        cur = p;
      case 'C':
      case 'Q':
        final c = s.cmd == 'C' ? s.pts : [Offset.lerp(cur, s.pts[0], 2 / 3)!, Offset.lerp(s.pts[1], s.pts[0], 2 / 3)!, s.pts[1]];
        final est = (c[0] - cur).distance + (c[1] - c[0]).distance + (c[2] - c[1]).distance;
        final k = (est / step).ceil().clamp(1, 4096);
        for (var i = 1; i <= k; i++) {
          out.last.add(cubicPoint(cur, c[0], c[1], c[2], i / k));
        }
        cur = c[2];
      case 'Z':
        if (out.isNotEmpty && cur != start) out.last.add(start);
        cur = start;
    }
  }
  return out;
}

/// 3 次ベジェの t の点。
Offset cubicPoint(Offset p0, Offset c1, Offset c2, Offset p1, double t) {
  final u = 1 - t;
  final a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
  return Offset(a * p0.dx + b * c1.dx + c * c2.dx + d * p1.dx, a * p0.dy + b * c1.dy + c * c2.dy + d * p1.dy);
}

/// 区間 → 小さな `d`。
///
/// - 座標は 0.1 単位の整数で計算し、最初の `M` だけ絶対、あとは相対(`l` / `h` / `v` / `c` / `s` / `z`。サブパスの頭の `M` は絶対)。
/// - 前の `c` の 2 つ目の制御点を折り返した点が次の 1 つ目と同じなら `s`(4 つの数)。同じ命令が続けば字を省く。
/// - 数は先頭の 0 を落とし(`.5`)、区切りは要るときだけ(`-` の前と、小数点を含む数の後の `.` の前は要らない)。
String segmentsToD(Iterable<PSeg> segs) {
  final w = _DWriter();
  for (final s in segs) {
    switch (s.cmd) {
      case 'M':
        w.move(s.pts[0]);
      case 'L':
        w.line(s.pts[0]);
      case 'C':
        w.cubic(s.pts[0], s.pts[1], s.pts[2]);
      case 'Z':
        w.close();
    }
  }
  return w.toString();
}

class _DWriter {
  final _b = StringBuffer();
  int _x = 0, _y = 0, _sx = 0, _sy = 0;
  String? _cmd;

  /// 直前に書いた数(null = 直前は命令の字)。
  String? _num;

  /// 直前の `c` / `s` の 2 つ目の制御点(絶対、0.1 単位)。
  (int, int)? _c2;

  static String fmt(int v) {
    final a = v.abs();
    final i = a ~/ 10, f = a % 10;
    final s = f == 0 ? '$i' : (i == 0 ? '.$f' : '$i.$f');
    return v < 0 ? '-$s' : s;
  }

  void _letter(String c) {
    if (c == _cmd && c != 'M' && c != 'z') return;
    _b.write(c);
    _cmd = c;
    _num = null;
  }

  void _n(int v) {
    final s = fmt(v);
    final prev = _num;
    if (prev != null && !s.startsWith('-') && !(s.startsWith('.') && prev.contains('.'))) _b.write(' ');
    _b.write(s);
    _num = s;
  }

  void move(Offset p) {
    final x = tenths(p.dx), y = tenths(p.dy);
    _letter('M');
    _n(x);
    _n(y);
    _x = _sx = x;
    _y = _sy = y;
    _c2 = null;
  }

  void line(Offset p) {
    final x = tenths(p.dx), y = tenths(p.dy);
    final dx = x - _x, dy = y - _y;
    if (dy == 0) {
      _letter('h');
      _n(dx);
    } else if (dx == 0) {
      _letter('v');
      _n(dy);
    } else {
      _letter('l');
      _n(dx);
      _n(dy);
    }
    _x = x;
    _y = y;
    _c2 = null;
  }

  void cubic(Offset c1, Offset c2, Offset p) {
    final x1 = tenths(c1.dx), y1 = tenths(c1.dy), x2 = tenths(c2.dx), y2 = tenths(c2.dy), x = tenths(p.dx), y = tenths(p.dy);
    final prev = _c2;
    if (prev != null && 2 * _x - prev.$1 == x1 && 2 * _y - prev.$2 == y1) {
      _letter('s');
    } else {
      _letter('c');
      _n(x1 - _x);
      _n(y1 - _y);
    }
    _n(x2 - _x);
    _n(y2 - _y);
    _n(x - _x);
    _n(y - _y);
    _c2 = (x2, y2);
    _x = x;
    _y = y;
  }

  void close() {
    _letter('z');
    _x = _sx;
    _y = _sy;
    _c2 = null;
  }

  @override
  String toString() => _b.toString();
}

/// [SvgLiteShape.toSvgElement] が書く `d`(絶対の `M L C Q Z`、数は空白区切り)を区間に読む。読めない字が来たらそこまで。
List<PSeg> parseCanonicalD(String d) {
  final out = <PSeg>[];
  final tokens = RegExp(r'[MLCQZ]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m[0]!).toList();
  String? cmd;
  final nums = <double>[];
  // 同じ字の続き(`M` の後の数の組は `L`)。
  var run = 0;
  const argc = {'M': 2, 'L': 2, 'C': 6, 'Q': 4, 'Z': 0};
  void flush() {
    final c = cmd;
    if (c == null) return;
    final k = argc[c]!;
    if (k == 0) return;
    while (nums.length >= k) {
      final v = nums.sublist(0, k);
      nums.removeRange(0, k);
      final pts = [for (var i = 0; i < k; i += 2) Offset(v[i], v[i + 1])];
      out.add(PSeg(c == 'M' && run > 0 ? 'L' : c, pts));
      run++;
    }
  }

  for (final t in tokens) {
    if (argc.containsKey(t)) {
      flush();
      nums.clear();
      cmd = t;
      run = 0;
      if (t == 'Z') out.add(closePath);
    } else {
      final v = double.tryParse(t);
      if (v == null) break;
      nums.add(v);
      final c = cmd;
      if (c != null && argc[c]! > 0 && nums.length == argc[c]) flush();
    }
  }
  flush();
  return out;
}

/// 要素の文字列から属性の値を読む(`name="…"`)。
String? attrOf(String element, String name) => RegExp('\\s${RegExp.escape(name)}="([^"]*)"').firstMatch(element)?[1];
