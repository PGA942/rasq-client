import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/svgpaint/model.dart';

/// セキュリティ確認 2026-11-11 の #22: 投げ輪の点は、巨大な座標 / 長い曲線 / 多すぎる輪郭でも上限まで。
void main() {
  Path rect(Rect r) => Path()..addRect(r);

  test('画面をまたぐ巨大な矩形 / 巨大な有限座標でも上限を守る', () {
    for (final side in [1e6, 1e9, 1e15]) {
      final s = samplePath(rect(Rect.fromLTWH(-side, -side, 2 * side, 2 * side)));
      expect(s.length, lessThanOrEqualTo(maxPathSamples), reason: '$side');
      expect(s.length, greaterThan(3));
      expect(s.every((p) => p.dx.isFinite && p.dy.isFinite), isTrue);
    }
  });

  test('長い曲線と、輪郭がとても多い形も上限まで', () {
    final curve = Path()..moveTo(0, 0);
    for (var i = 0; i < 2000; i++) {
      curve.cubicTo(i * 1e4, 1e6, i * 1e4 + 5e3, -1e6, (i + 1) * 1e4, 0);
    }
    expect(samplePath(curve).length, lessThanOrEqualTo(maxPathSamples));
    final many = Path();
    for (var i = 0; i < 10000; i++) {
      many.addRect(Rect.fromLTWH(i * 10.0, 0, 5, 5));
    }
    expect(samplePath(many).length, lessThanOrEqualTo(maxPathSamples));
  });

  test('ふつうの大きさは今までどおり 3 単位ごと', () {
    final s = samplePath(rect(const Rect.fromLTWH(0, 0, 100, 100)));
    expect(s.length, inInclusiveRange(130, 140)); // 周 400 / 3
  });
}
