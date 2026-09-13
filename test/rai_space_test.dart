import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_space.dart';

/// RAi の 3D 空間 (D-197): 画面座標 ⇄ 空間の写像(待機 / 再接近の 2 つの奥行き)と 3 次元スプライン。
void main() {
  const screen = Size(360, 780);
  const proj = RaiProjector(screen: screen);

  test('写像は往復で元に戻り、大きいほど手前(奥行きが浅い)', () {
    for (final (px, size) in [(const Offset(40, 100), 180.0), (const Offset(300, 600), 180.0), (const Offset(180, 390), 700.0)]) {
      final w = proj.worldAt(px, size);
      final back = proj.project(w);
      expect((back.px - px).distance, lessThan(1e-6));
      expect(back.sizePx, closeTo(size, 1e-6));
    }
    expect(proj.depthForSize(700), lessThan(proj.depthForSize(180)));
    expect(proj.worldAt(const Offset(180, 390), 180).x, closeTo(0, 1e-9)); // 画面中央は光軸上
    expect(proj.worldAt(const Offset(180, 390), 180).y, closeTo(0, 1e-9));
    expect(proj.worldAt(const Offset(0, 390), 180).x, lessThan(0)); // 左は −x
    expect(proj.worldAt(const Offset(180, 0), 180).y, greaterThan(0)); // 上は +y
  });

  test('スプライン: 両端は待機の奥行きで 2D の端点に一致、途中は再接近の奥行きへ寄って大きく見える', () {
    final path = RaiPath3(projector: proj, from: const Offset(40, 100), to: const Offset(300, 600), restSize: 180, approachSize: 700);
    expect((proj.project(path.at(0)).px - const Offset(40, 100)).distance, lessThan(1e-6));
    expect((proj.project(path.at(1)).px - const Offset(300, 600)).distance, lessThan(1e-6));
    expect(proj.project(path.at(0)).sizePx, closeTo(180, 1e-6));
    final mid = proj.project(path.at(0.5)).sizePx;
    expect(mid, greaterThan(400));
    expect(mid, lessThanOrEqualTo(700 + 1e-6));
    expect(path.tangent(0.5).length, greaterThan(0));
    expect(path.screenLength, greaterThan((const Offset(300, 600) - const Offset(40, 100)).distance));
    // 形 (D-199): 横移動は画面の下へ膨らむ U(途中の y が両端より下)、縦移動は S 字(前半と後半で横のずれが逆)。
    final horiz = RaiPath3(projector: proj, from: const Offset(40, 300), to: const Offset(320, 320), restSize: 180, approachSize: 700);
    expect(horiz.horizontal, isTrue);
    expect(proj.project(horiz.at(0.5)).px.dy, greaterThan(320));
    final vert = RaiPath3(projector: proj, from: const Offset(200, 100), to: const Offset(220, 600), restSize: 180, approachSize: 700);
    expect(vert.horizontal, isFalse);
    final line = (const Offset(220, 600) - const Offset(200, 100));
    double side(Offset p) => (p - const Offset(200, 100)).dx * line.dy - (p - const Offset(200, 100)).dy * line.dx;
    expect(side(proj.project(vert.at(0.25)).px).sign, isNot(side(proj.project(vert.at(0.75)).px).sign));
    // 距離 0 は動かない。
    final still = RaiPath3(projector: proj, from: const Offset(50, 50), to: const Offset(50, 50), restSize: 180, approachSize: 700);
    expect((still.at(0.5) - still.at(0)).length, lessThan(1e-9));
  });

  test('停止時の円運動: 停止の段だけ、端では 0、画面と平行な面で回る', () {
    expect(raiStopLoop3(0.5, stopStart: 0.8, projector: proj, restSize: 180, radiusPx: 45), RaiVec3.zero);
    expect(raiStopLoop3(0.8, stopStart: 0.8, projector: proj, restSize: 180, radiusPx: 45).length, lessThan(1e-9));
    final midLoop = raiStopLoop3(0.9, stopStart: 0.8, projector: proj, restSize: 180, radiusPx: 45);
    expect(midLoop.length, greaterThan(0));
    expect(midLoop.z, 0);
    expect(raiStopLoop3(1, stopStart: 0.8, projector: proj, restSize: 180, radiusPx: 45), RaiVec3.zero);
    // 半径は画面上で radiusPx になる(待機の奥行きで換算)。
    final d = proj.depthForSize(180);
    final r = proj.visibleHeight(d) * 45 / screen.height;
    expect(raiStopLoop3(0.85, stopStart: 0.8, projector: proj, restSize: 180, radiusPx: 45).length, closeTo(r * 2 * 0.7071, 0.01 * r * 2)); // 1/4 周 → 弦の長さ r√2
  });
}
