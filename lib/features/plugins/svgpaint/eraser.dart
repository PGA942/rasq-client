import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'model.dart';
import 'nib.dart';
import 'spline.dart';

/// 消しゴム (D-473)。
///
/// **切る消しゴム**(既定): 線の中心線を細かい点にして、消しゴムの円(半径 + その点の太さの半分 = インクに触れたところ)と
/// 交わる区間を抜き、残りを別々の線にする。切り口の点は線分と円の交点。なぞり終えたら切り口を丸め込み
/// ([roundCutEnds])、太さも見る RDP(0.35)で節に戻す。なぞっている間は細かい点のまま持つ(同じ線を何度切っても
/// 簡略化の誤差が溜まらない、丸め込みが重ならない)。
/// **線ごと消す消しゴム**: 触れた線 / 形をまるごと消す(前の版の消しゴム)。
/// どちらも、読み込んだ形は外接矩形で当てて丸ごと消す(線だけの形は、切る消しゴムでは折れ線に直してから切る = 近似)。
/// 塗りは線を消すついでには消さない: なぞりの間にどの線にも触れなかったときだけ、触れた塗りを消す。

/// 切っている途中の線(細かい点と太さ、両端が切り口か)。
class CutPiece {
  CutPiece(this.source, this.pts, this.w, {this.cutStart = false, this.cutEnd = false});
  factory CutPiece.of(PaintStroke s) {
    final (p, w) = s.dense;
    return CutPiece(s, p, w);
  }

  /// ペン先と色と、曲線か折れ線か。
  final PaintStroke source;
  final List<Offset> pts;
  final List<double> w;
  final bool cutStart;
  final bool cutEnd;

  late final Rect bounds = boundsOf(pts).inflate(w.reduce(math.max) / 2);

  /// 描く用(切り口を丸め込んだ細かい点の線)。
  late final PaintStroke preview = () {
    final (p, ww) = roundCutEnds(pts, w, source.nib, cutStart: cutStart, cutEnd: cutEnd);
    return PaintStroke(nib: source.nib, color: source.color, points: p, widths: ww, curve: false);
  }();

  /// なぞり終えた: 丸め込み → 簡略化。
  PaintStroke finish() {
    final (p, ww) = roundCutEnds(pts, w, source.nib, cutStart: cutStart, cutEnd: cutEnd);
    return simplifyStroke(nib: source.nib, color: source.color, points: p, widths: ww, epsilon: cutEpsilon, curve: source.curve);
  }
}

/// [piece] を円 (center, radius) で切る。当たらなければ null、当たれば残りの線(空 = 全部消えた)。
/// 円の半径には点ごとの太さの半分を足す(インクに触れたところで切る。丸い端は切り口から太さの半分だけ出るので、
/// 消しゴムの円の外に収まる)。
List<CutPiece>? cutPiece(CutPiece piece, Offset center, double radius) {
  if (!piece.bounds.inflate(radius).contains(center)) return null;
  final p = piece.pts, w = piece.w;
  if (p.length == 1) return (p[0] - center).distance < radius + w[0] / 2 ? const [] : null;
  final out = <CutPiece>[];
  var cp = <Offset>[p[0]], cw = <double>[w[0]];
  var startCut = piece.cutStart;
  var touched = false;
  void emit({required bool cutEnd}) {
    if (cp.length >= 2 && polylineLength(cp) >= 0.5) out.add(CutPiece(piece.source, cp, cw, cutStart: startCut, cutEnd: cutEnd));
    cp = [];
    cw = [];
  }

  void begin(Offset q, double qw) {
    cp = [q];
    cw = [qw];
    startCut = true;
  }

  for (var i = 1; i < p.length; i++) {
    final a = p[i - 1], b = p[i];
    final r = radius + (w[i - 1] + w[i]) / 4;
    // |a + t(b−a) − c|² = r² の解 t1 ≤ t2。[0, t1) と (t2, 1] が円の外。
    final d = b - a, f = a - center;
    final qa = dot(d, d), qb = 2 * dot(f, d), qc = dot(f, f) - r * r;
    final disc = qb * qb - 4 * qa * qc;
    final sq = disc > 0 && qa > 1e-12 ? math.sqrt(disc) : -1.0;
    final t1 = sq < 0 ? 2.0 : (-qb - sq) / (2 * qa), t2 = sq < 0 ? 2.0 : (-qb + sq) / (2 * qa);
    if (sq < 0 || t2 <= 0 || t1 >= 1) {
      if (sq < 0 && qa <= 1e-12 && qc < 0) {
        // 長さ 0 の線分が円の中。
        touched = true;
        emit(cutEnd: true);
        continue;
      }
      if (cp.isEmpty) begin(a, w[i - 1]);
      cp.add(b);
      cw.add(w[i]);
      continue;
    }
    touched = true;
    if (t1 > 0) {
      if (cp.isEmpty) begin(a, w[i - 1]);
      cp.add(Offset.lerp(a, b, t1)!);
      cw.add(w[i - 1] + (w[i] - w[i - 1]) * t1);
    }
    emit(cutEnd: true);
    if (t2 < 1) {
      begin(Offset.lerp(a, b, t2)!, w[i - 1] + (w[i] - w[i - 1]) * t2);
      cp.add(b);
      cw.add(w[i]);
    }
  }
  if (!touched) return null;
  emit(cutEnd: piece.cutEnd);
  return out;
}

/// 消しゴムのなぞり 1 回分。
class EraseSession {
  EraseSession(List<PaintItem> items, {this.whole = false})
      : before = items,
        _entries = List<Object>.of(items);

  /// なぞる前の並び。
  final List<PaintItem> before;

  /// 線ごと消す。
  final bool whole;

  /// [PaintItem] か、切っている途中の [CutPiece]。
  final List<Object> _entries;

  /// 線 / 形に触れた。
  bool changed = false;

  /// 触れた塗り(なぞり終えたとき、線に触れていなければ消す)。
  final Set<PaintFill> touchedFills = {};

  /// 描く用の並び(切っている途中の線は丸め込んだ細かい点の線)。
  List<PaintItem> get preview => [
        for (final e in _entries)
          if (e is CutPiece) e.preview else e as PaintItem,
      ];

  /// 円 (center, radius) を当てる。
  void apply(Offset center, double radius) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e is PaintFill) {
        if (e.bounds.contains(center) && e.path.contains(center)) touchedFills.add(e);
        continue;
      }
      if (whole) {
        if (e is PaintItem && hitsItem(e, center, radius)) {
          _entries.removeAt(i);
          changed = true;
        }
        continue;
      }
      final List<CutPiece> pieces;
      switch (e) {
        case CutPiece():
          pieces = [e];
        case PaintStroke():
          if (!e.bounds.inflate(radius).contains(center)) continue;
          pieces = [CutPiece.of(e)];
        case PaintShape() || PaintPath():
          final item = e as PaintItem;
          if (!item.bounds.inflate(radius).contains(center)) continue;
          final lines = shapeAsLines(item);
          if (lines == null) {
            // 塗りのある形は丸ごと。
            _entries.removeAt(i);
            changed = true;
            continue;
          }
          pieces = lines;
        default:
          continue;
      }
      final next = <CutPiece>[];
      var cut = false;
      for (final p in pieces) {
        final r = cutPiece(p, center, radius);
        if (r == null) {
          next.add(p);
        } else {
          cut = true;
          next.addAll(r);
        }
      }
      if (!cut) continue;
      _entries.replaceRange(i, i + 1, next);
      changed = true;
    }
  }

  /// なぞり終えた並び。何も変わらなければ null。
  List<PaintItem>? finish() {
    if (!changed) {
      if (touchedFills.isEmpty) return null;
      return [
        for (final e in _entries)
          if (!touchedFills.contains(e)) e as PaintItem,
      ];
    }
    return [
      for (final e in _entries)
        if (e is CutPiece) e.finish() else e as PaintItem,
    ];
  }
}

/// 線ごと消す消しゴムの当たり: 線は中心線までの距離 ≤ 半径 + 太さの半分、形は外接矩形。
bool hitsItem(PaintItem item, Offset q, double r) {
  switch (item) {
    case PaintStroke():
      if (!item.bounds.inflate(r).contains(q)) return false;
      final (p, w) = item.dense;
      if (p.length == 1) return (p.first - q).distance <= r + w.first / 2;
      for (var i = 1; i < p.length; i++) {
        if (segmentDistance(q, p[i - 1], p[i]) <= r + math.max(w[i - 1], w[i]) / 2) return true;
      }
      return false;
    case PaintFill():
      return item.path.contains(q);
    case PaintShape() || PaintPath():
      return item.bounds.inflate(r).contains(q);
  }
}

/// 線だけの不透明な形を、切れる折れ線(ミリペン)に直す(近似)。塗りがある / 透けている形は null。
List<CutPiece>? shapeAsLines(PaintItem item) {
  final (segs, style) = switch (item) {
    PaintShape(:final generic) => (generic.segments, generic.style),
    PaintPath(:final segments, :final style) => (segments, style),
    _ => (null, null),
  };
  if (segs == null || style == null || !style.isPlainLine) return null;
  final color = style.stroke!;
  final out = <CutPiece>[];
  for (final line in flattenSegments(segs, step: 1)) {
    if (line.isEmpty) continue;
    final ws = [for (final _ in line) style.strokeWidth];
    final src = PaintStroke(nib: PaintNib.mili, color: color, points: [qp(line.first)], widths: [q1(style.strokeWidth)], curve: false);
    out.add(CutPiece(src, line, ws));
  }
  return out;
}
