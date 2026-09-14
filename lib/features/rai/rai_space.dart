import 'dart:math' as math;
import 'dart:ui';

/// RAi の 3D 空間 (D-197): 画面(2D)の座標を、カメラ正面の 2 つの奥行き(待機 = 180 px / 再接近 = 700 px)の
/// 平面へ写像し、その間を 3 次元スプライン(3 次ベジエ)で結ぶ。three_js のウィジェットは画面いっぱいに
/// 固定し、モデルだけが空間の中を動く(ウィジェットを動かさないので滑らか)。
///
/// カメラは原点で −Z を向く。モデルは高さ 1(正規化済み)。奥行き d に置いた高さ 1 のものは、
/// 画面上で `H / (2 d tan(fov/2))` px に見える(H = 画面の高さ px)。
class RaiVec3 {
  const RaiVec3(this.x, this.y, this.z);
  final double x, y, z;
  RaiVec3 operator +(RaiVec3 o) => RaiVec3(x + o.x, y + o.y, z + o.z);
  RaiVec3 operator -(RaiVec3 o) => RaiVec3(x - o.x, y - o.y, z - o.z);
  RaiVec3 operator *(double k) => RaiVec3(x * k, y * k, z * k);
  double get length => math.sqrt(x * x + y * y + z * z);
  static const zero = RaiVec3(0, 0, 0);
  @override
  String toString() => 'RaiVec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

class RaiProjector {
  const RaiProjector({required this.screen, this.fovDeg = 30});
  final Size screen;

  /// 縦の画角(度)。
  final double fovDeg;

  double get _tanHalf => math.tan(fovDeg * math.pi / 360);

  /// 奥行き d で見える縦の幅(ワールド単位)。
  double visibleHeight(double d) => 2 * d * _tanHalf;
  double visibleWidth(double d) => visibleHeight(d) * (screen.height <= 0 ? 1 : screen.width / screen.height);

  /// 高さ 1 のモデルが [sizePx] に見える奥行き。
  double depthForSize(double sizePx) => math.max(1, screen.height) / (math.max(1, sizePx) * 2 * _tanHalf);

  /// 奥行き d に置いた高さ 1 のモデルの見かけの大きさ(px)。
  double sizeAtDepth(double d) => math.max(1, screen.height) / visibleHeight(d);

  /// 画面の点 [px](モデルの中心)と見かけの大きさ [sizePx] → ワールド座標(モデルの中心)。
  RaiVec3 worldAt(Offset px, double sizePx) {
    final d = depthForSize(sizePx);
    final x = (px.dx / screen.width - 0.5) * visibleWidth(d);
    final y = -(px.dy / screen.height - 0.5) * visibleHeight(d);
    return RaiVec3(x, y, -d);
  }

  /// ワールド座標(モデルの中心)→ 画面の点と見かけの大きさ(px)。
  ({Offset px, double sizePx}) project(RaiVec3 w) {
    final d = math.max(0.01, -w.z);
    final px = Offset((w.x / visibleWidth(d) + 0.5) * screen.width, (-w.y / visibleHeight(d) + 0.5) * screen.height);
    return (px: px, sizePx: sizeAtDepth(d));
  }
}

/// 3 次元の 3 次ベジエ (D-197): 両端は待機の奥行き、制御点は再接近の奥行き(山なりに手前へ寄る)。
/// 膨らみ [bulge] は 2D の距離に対する比。横移動は下へ膨らむ U、縦移動は S 字(D-199)。
class RaiPath3 {
  RaiPath3({required this.projector, required this.from, required this.to, required this.restSize, required this.approachSize, this.bulge = 0.25, this.ribbon = false});
  final RaiProjector projector;
  final Offset from;
  final Offset to;
  final double restSize;
  final double approachSize;
  final double bulge;
  final bool ribbon;

  late final List<RaiVec3> controlPoints = _controls();

  /// 横移動(|dx| ≥ |dy|)か。横移動は画面で **下へ膨らむ U**、縦移動は **S 字(リボン)**(D-199 の図)。
  bool get horizontal => (to.dx - from.dx).abs() >= (to.dy - from.dy).abs();

  List<RaiVec3> _controls() {
    final p0 = projector.worldAt(from, restSize);
    final p3 = projector.worldAt(to, restSize);
    final d = to - from;
    final len = d.distance;
    if (len < 0.5) return [p0, p0, p3, p3];
    final dir = d / len;
    final Offset side1;
    final Offset side2;
    if (horizontal) {
      // U: 両方の制御点を画面の下へ。
      side1 = Offset(0, len * bulge);
      side2 = Offset(0, len * bulge);
    } else {
      // S(リボン): 進行方向の左へ → 右へ。
      final perp = Offset(-dir.dy, dir.dx);
      side1 = perp * (len * bulge);
      side2 = perp * (len * bulge * (ribbon ? -1 : -1));
    }
    final c1 = projector.worldAt(from + dir * (len * 0.3) + side1, approachSize);
    final c2 = projector.worldAt(to - dir * (len * 0.3) + side2, approachSize);
    return [p0, c1, c2, p3];
  }

  RaiVec3 at(double t) {
    final c = controlPoints;
    final u = 1 - t;
    return c[0] * (u * u * u) + c[1] * (3 * u * u * t) + c[2] * (3 * u * t * t) + c[3] * (t * t * t);
  }

  /// 接線(ワールド)。
  RaiVec3 tangent(double t) {
    final c = controlPoints;
    final u = 1 - t;
    return (c[1] - c[0]) * (3 * u * u) + (c[2] - c[1]) * (6 * u * t) + (c[3] - c[2]) * (3 * t * t);
  }

  /// 画面上の見た目の長さ(折れ線近似、px)。
  double get screenLength {
    var sum = 0.0;
    var prev = projector.project(at(0)).px;
    for (var i = 1; i <= 24; i++) {
      final p = projector.project(at(i / 24)).px;
      sum += (p - prev).distance;
      prev = p;
    }
    return sum;
  }
}

/// 停止時の角度補正の円運動 (D-197): 停止の段だけ、画面と平行な面で半径 [radiusPx] 相当の円を 1 周する。
/// 位置は待機の奥行きで換算。段の端では 0(端点は不変)。
RaiVec3 raiStopLoop3(double progress, {required double stopStart, required RaiProjector projector, required double restSize, required double radiusPx, bool clockwise = true}) {
  final t = progress.clamp(0.0, 1.0);
  if (t < stopStart || t >= 1 || stopStart >= 1) return RaiVec3.zero;
  final phase = (t - stopStart) / (1 - stopStart);
  final a = 2 * math.pi * phase * (clockwise ? 1 : -1);
  final d = projector.depthForSize(restSize);
  final r = radiusPx / projector.screen.height * projector.visibleHeight(d);
  return RaiVec3(r * math.sin(a), r * (1 - math.cos(a)), 0);
}
