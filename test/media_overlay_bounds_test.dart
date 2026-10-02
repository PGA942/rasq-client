import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';

/// D-407 (セキュリティ指摘 #24): プラグインの重ねの Box の大きさで、ホストの点線描画の仕事を増やさせない。
void main() {
  test('Box の矩形: 数でない / 無限 / NaN / 負の大きさは捨て、巨大な座標は切り詰める', () {
    expect(overlayBoxRect(10, 20, 30, 40), const Rect.fromLTWH(10, 20, 30, 40));
    expect(overlayBoxRect(double.nan, 0, 10, 10), isNull);
    expect(overlayBoxRect(0, 0, double.infinity, 10), isNull);
    expect(overlayBoxRect(0, 0, -5, 10), isNull);
    expect(overlayBoxRect('0', 0, 10, 10), isNull);
    final huge = overlayBoxRect(-1e300, -1e300, 1e300, 1e300)!;
    expect(huge.left, -overlayBoxMaxExtent);
    expect(huge.right, overlayBoxMaxExtent);
    expect(huge.width, lessThanOrEqualTo(overlayBoxMaxExtent * 2));
  });

  test('点線: 巨大でも有限でも、1 辺の線分の数は上限まで', () {
    final segs = snapDashSegments(const Offset(-1e12, 0), const Offset(1e12, 0));
    expect(segs.length, lessThanOrEqualTo(snapMaxDashesPerEdge));
    expect(snapDashSegments(const Offset(0, 0), Offset(double.infinity, 0)), isEmpty);
    expect(snapDashSegments(const Offset(0, 0), Offset(double.nan, 0)), isEmpty);
  });

  test('点線: 見える範囲の外の辺は描かず、はみ出した辺は見える範囲だけ', () {
    const bounds = Rect.fromLTWH(0, 0, 100, 100);
    expect(snapDashSegments(const Offset(0, 5000), const Offset(100, 5000), bounds: bounds), isEmpty);
    final clipped = snapDashSegments(const Offset(-overlayBoxMaxExtent, 50), const Offset(overlayBoxMaxExtent, 50), bounds: bounds);
    expect(clipped, isNotEmpty);
    for (final (a, b) in clipped) {
      expect(a.dx, inInclusiveRange(0, 100));
      expect(b.dx, inInclusiveRange(0, 100));
    }
    expect(clipped.length, lessThanOrEqualTo(10)); // 100px なら 6px の点線で 9 本ほど
  });

  test('ふつうの大きさの点線はこれまでどおり(6px の線、6px の隙間)', () {
    final segs = snapDashSegments(const Offset(0, 0), const Offset(60, 0));
    expect(segs.length, 5);
    expect(segs.first, (const Offset(0, 0), const Offset(6, 0)));
    expect(segs[1].$1, const Offset(12, 0));
  });
}
