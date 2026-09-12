import 'dart:ui';

/// RAi の移動スプライン (D-179): 今の位置から目標へ 3 次ベジエで動く。
///
/// パラメーターは 2 つだけ(「簡単な差分パラメーター」):
/// - [bulge]: 直線からの膨らみ(距離に対する比。正 = 進行方向の左側へ膨らむ)。
/// - [overshoot]: 目標を少し行き過ぎてから戻る量(距離に対する比)。
/// 端点は必ず [from] / [to]。
class RaiPath {
  RaiPath({required this.from, required this.to, this.bulge = 0.25, this.overshoot = 0.06});
  final Offset from;
  final Offset to;
  final double bulge;
  final double overshoot;

  double get distance => (to - from).distance;

  /// 制御点(距離 0 のときは端点のみ)。
  List<Offset> get controlPoints {
    final d = to - from;
    final len = d.distance;
    if (len < 0.5) return [from, from, to, to];
    final dir = d / len;
    final perp = Offset(-dir.dy, dir.dx);
    final p1 = from + dir * (len * 0.3) + perp * (len * bulge);
    final p2 = to + dir * (len * overshoot) + perp * (len * bulge * 0.4);
    return [from, p1, p2, to];
  }

  /// 0..1 → 位置。
  Offset at(double t) {
    final c = controlPoints;
    final u = 1 - t;
    return c[0] * (u * u * u) + c[1] * (3 * u * u * t) + c[2] * (3 * u * t * t) + c[3] * (t * t * t);
  }

  /// 見た目の長さ(折れ線近似)。所要時間の目安に使う。
  double get length {
    var sum = 0.0;
    var prev = from;
    for (var i = 1; i <= 16; i++) {
      final p = at(i / 16);
      sum += (p - prev).distance;
      prev = p;
    }
    return sum;
  }
}
