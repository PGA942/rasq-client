import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// 輪郭の上の点から測った矩形(Path.getBounds は制御点まで含むので使わない)。
Rect tight(Path path) {
  var r = Rect.zero;
  var first = true;
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += 0.25) {
      final p = m.getTangentForOffset(d)!.position;
      r = first ? Rect.fromPoints(p, p) : r.expandToInclude(Rect.fromPoints(p, p));
      first = false;
    }
  }
  return r;
}

/// ボタンにつながったパネル (D-474)。
void main() {
  group('TetherOutline(形)', () {
    const button = Offset(180, 100);
    const r = 22.0;

    test('下に開く: 首は上辺から立ち上がってボタンを [clearance] 空けて包み、パネルとひと続きの輪郭になる', () {
      final rect = Rect.fromLTWH(30, button.dy + r + 3 + 10, 300, 200);
      final o = TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.below);
      final path = o.path();
      final b = tight(path);
      expect(b.top, closeTo(button.dy - r - 3, 0.5)); // 首の丸の上 = ボタン + 3px
      expect(b.bottom, closeTo(rect.bottom, 0.5));
      expect(b.left, closeTo(rect.left, 0.5));
      expect(b.right, closeTo(rect.right, 0.5));
      expect(path.contains(button), isTrue); // ボタンは首の中
      expect(path.contains(rect.center), isTrue);
      expect(path.contains(Offset(button.dx, rect.top - 1)), isTrue); // 首はパネルとつながっている
      // 首の外(ボタンの横で、パネルより上)は外側。
      expect(path.contains(Offset(button.dx + r + 6, button.dy)), isFalse);
      expect(path.contains(Offset(rect.left + 4, rect.top - 2)), isFalse);
      // 1 本の輪郭(穴やもう 1 つの島が無い)。
      expect(path.computeMetrics().length, 1);
    });

    test('上に開く: 上下が裏返る(首は下辺)', () {
      final rect = Rect.fromLTWH(30, button.dy - r - 3 - 10 - 200, 300, 200);
      final path = TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.above).path();
      final b = tight(path);
      expect(b.bottom, closeTo(button.dy + r + 3, 0.5));
      expect(b.top, closeTo(rect.top, 0.5));
      expect(path.contains(button), isTrue);
      expect(path.contains(Offset(button.dx, rect.bottom + 1)), isTrue);
      expect(path.contains(Offset(button.dx + r + 6, button.dy)), isFalse);
    });

    test('画面の端のボタン: 角の丸みを詰めて首を角から始める(輪郭は崩れない)', () {
      const edge = Offset(26, 100);
      final rect = Rect.fromLTWH(8, edge.dy + r + 3 + 10, 300, 200);
      final path = TetherOutline(rect: rect, button: edge, buttonRadius: r, side: TetherSide.below).path();
      expect(path.contains(edge), isTrue);
      expect(tight(path).left, closeTo(edge.dx - r - 3, 0.5)); // 首の丸はパネルより外まで出てよい(ボタンを包む)
      expect(path.computeMetrics().length, 1);
    });
  });

  group('tetherPlacement(置き場所)', () {
    const area = Rect.fromLTWH(8, 8, 344, 764);
    test('下に余裕があれば下(スケッチのとおり)、無ければ上', () {
      final top = tetherPlacement(anchor: const Rect.fromLTWH(160, 40, 44, 44), area: area, width: 320, neckGap: 10, headRadius: 25, preferred: TetherSide.below);
      expect(top.side, TetherSide.below);
      final bottom = tetherPlacement(anchor: const Rect.fromLTWH(160, 700, 44, 44), area: area, width: 320, neckGap: 10, headRadius: 25, preferred: TetherSide.below);
      expect(bottom.side, TetherSide.above);
      expect(bottom.maxHeight, closeTo(722 - 25 - 10 - 8, 0.01));
    });

    test('横はボタンの真ん中に合わせ、画面からはみ出さない', () {
      final mid = tetherPlacement(anchor: const Rect.fromLTWH(158, 40, 44, 44), area: area, width: 200, neckGap: 10, headRadius: 25, preferred: TetherSide.below);
      expect(mid.left, 80);
      final edge = tetherPlacement(anchor: const Rect.fromLTWH(310, 40, 44, 44), area: area, width: 200, neckGap: 10, headRadius: 25, preferred: TetherSide.below);
      expect(edge.left, area.right - 200);
    });
  });

  testWidgets('TetheredPanel: 中身はボタンの下に置かれ、首(元のボタンの位置)を押すと onAnchorTap', (tester) async {
    var tapped = 0;
    const anchor = Rect.fromLTWH(100, 60, 44, 44);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TetheredPanel(
          anchor: anchor,
          width: 240,
          onAnchorTap: () => tapped++,
          anchorChild: const Icon(Icons.tag, key: ValueKey('glyph')),
          child: const SizedBox(key: ValueKey('body'), height: 80),
        ),
      ),
    ));
    final body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.top, greaterThan(anchor.bottom));
    expect(body.width, 240 - 12); // 外形は中身から 6px 外
    expect(tester.getCenter(find.byKey(const ValueKey('glyph'))), anchor.center);
    await tester.tap(find.byKey(const ValueKey('glyph')));
    expect(tapped, 1);
  });
}
