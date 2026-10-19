import 'dart:math' as math;

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

/// 輪郭を 0.5px ずつたどって、隣どうしの接線の向きの差の最大(ラジアン)。角があると大きく跳ねる。
double maxTurn(Path path) {
  var worst = 0.0;
  for (final m in path.computeMetrics()) {
    double? prev;
    double? first;
    for (var d = 0.0; d <= m.length; d += 0.5) {
      final a = m.getTangentForOffset(d)!.angle;
      first ??= a;
      if (prev != null) worst = math.max(worst, _diff(a, prev));
      prev = a;
    }
    if (m.isClosed && prev != null && first != null) worst = math.max(worst, _diff(first, prev));
  }
  return worst;
}

double _diff(double a, double b) {
  var d = (a - b).abs() % (2 * math.pi);
  if (d > math.pi) d = 2 * math.pi - d;
  return d;
}

/// 首の形 (D-477 / D-479): ボタンの中心からパネルの外形の辺まで = アイコンの範囲の半分 + すき間([tetherReach])。
const r = 22.0;
final reach = tetherReach();

/// ボタンにつながったパネル (D-474 / D-477 / D-479)。
void main() {
  group('TetherOutline(形)', () {
    const button = Offset(180, 100);

    test('下に開く: 首は上辺から立ち上がってボタンを [clearance] 空けて包み、パネルとひと続きの輪郭になる', () {
      final rect = Rect.fromLTWH(30, button.dy + reach, 300, 200);
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
      // パネルの辺はアイコンの範囲の端まで寄る (D-479): ボタンの丸の下半分はパネルに埋まる。
      expect(reach, kTetherIconExtent / 2 + kTetherIconGap);
      expect(rect.top - button.dy, lessThan(r - 8)); // D-477 は r − 3 = 19、いまは 11
      expect(path.contains(Offset(button.dx, button.dy + r - 1)), isTrue);
      // 首は丸の真横より上(パネルと反対の側)で丸を離れる: 真横の丸の外側 1px はまだ首の中(裾が広がっている)。
      expect(path.contains(Offset(button.dx - r - 3 - 1, button.dy + 2)), isTrue);
      // 裾は横に長い: 丸の端から [kTetherNeckFlare] の手前まで、パネルの上辺より少し上も首の中。
      expect(path.contains(Offset(button.dx - r - 3 - 10, rect.top - 2)), isTrue);
      expect(path.contains(Offset(button.dx + r + 3 + 10, rect.top - 2)), isTrue);
      // 首の外(ボタンの横で、パネルより上)は外側。
      expect(path.contains(Offset(button.dx + r + 6, button.dy - 6)), isFalse);
      expect(path.contains(Offset(rect.left + 4, rect.top - 2)), isFalse);
      // 1 本の輪郭(穴やもう 1 つの島が無い)。
      expect(path.computeMetrics().length, 1);
      // つなぎ目に角が無い(接線がつながる)。
      expect(maxTurn(path), lessThan(0.15));
    });

    test('調整値: 首の角度を上げると丸を離れる点が高くなり、裾を伸ばすと首が横に広がる', () {
      final rect = Rect.fromLTWH(30, button.dy + reach, 300, 200);
      bool neckAt(TetherOutline o, Offset p) => o.path().contains(p);
      const probe = Offset(180 - 25 - 2, 100 - 4); // 丸の左、真横より少し上
      expect(neckAt(TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.below, neckAngle: 0), probe), isFalse);
      expect(neckAt(TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.below, neckAngle: 40), probe), isTrue);
      final far = Offset(180 - 25 - 30, rect.top - 2);
      expect(neckAt(TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.below, neckFlare: 16), far), isFalse);
      expect(neckAt(TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.below, neckFlare: 60), far), isTrue);
    });

    test('上に開く: 上下が裏返る(首は下辺)', () {
      final rect = Rect.fromLTWH(30, button.dy - reach - 200, 300, 200);
      final path = TetherOutline(rect: rect, button: button, buttonRadius: r, side: TetherSide.above).path();
      final b = tight(path);
      expect(b.bottom, closeTo(button.dy + r + 3, 0.5));
      expect(b.top, closeTo(rect.top, 0.5));
      expect(path.contains(button), isTrue);
      expect(path.contains(Offset(button.dx, rect.bottom + 1)), isTrue);
      expect(path.contains(Offset(button.dx + r + 6, button.dy + 6)), isFalse);
      expect(maxTurn(path), lessThan(0.15));
    });

    test('画面の端のボタン: 上辺に裾の場所が無ければ首を横の辺へ流す(輪郭は崩れず、角も出ない)', () {
      for (final (name, edge, rect) in [
        // 丸がパネルの横の辺より外へはみ出す(右端のカメラのボタン)。
        ('はみ出す', const Offset(334, 100), Rect.fromLTWH(52, 100 + reach, 300, 200)),
        // 丸はパネルの中だが、角までが近い(左端の絵文字のボタン)。
        ('角が近い', const Offset(52, 100), Rect.fromLTWH(8, 100 + reach, 300, 200)),
        // 角の丸みを詰めれば上辺に着く。
        ('角を詰める', const Offset(90, 100), Rect.fromLTWH(8, 100 + reach, 300, 200)),
      ]) {
        final path = TetherOutline(rect: rect, button: edge, buttonRadius: r, side: TetherSide.below).path();
        expect(path.contains(edge), isTrue, reason: name);
        expect(path.contains(rect.center), isTrue, reason: name);
        expect(path.computeMetrics().length, 1, reason: name);
        expect(maxTurn(path), lessThan(0.2), reason: name);
        final b = tight(path);
        expect(b.top, closeTo(edge.dy - r - 3, 0.5), reason: name);
        expect(b.left, greaterThanOrEqualTo(math.min(rect.left, edge.dx - r - 3) - 0.5), reason: name);
        expect(b.right, lessThanOrEqualTo(math.max(rect.right, edge.dx + r + 3) + 1), reason: name); // 横の辺へ流す S 字は丸より 1px 未満ふくらむことがある
      }
    });
  });

  group('tetherHitRect(首のタップの範囲、D-479)', () {
    const button = Offset(180, 100);
    test('下に開く: 範囲の下端 = パネルの辺(中身とぶつからない)、首のふくらみは範囲の中、大きさは最小のタップの大きさ以上', () {
      final hit = tetherHitRect(button: button, buttonRadius: r, reach: reach, side: TetherSide.below);
      expect(hit.bottom, closeTo(button.dy + reach, 0.01));
      expect(hit.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(hit.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(hit.center.dx, button.dx);
      expect(hit.center.dy, lessThan(button.dy)); // パネルと反対の側(上)へずれる
      expect(hit.contains(Offset(button.dx, button.dy - r - 2)), isTrue); // 首の丸のてっぺん
      expect(hit.contains(button), isTrue);
      // 範囲はパネルの外形の辺より内側(中身の側)へ入らない。
      final rect = Rect.fromLTWH(30, button.dy + reach, 300, 200);
      expect(hit.intersect(rect).height, lessThanOrEqualTo(0));
    });

    test('上に開く: 上下が裏返る', () {
      final hit = tetherHitRect(button: button, buttonRadius: r, reach: reach, side: TetherSide.above);
      expect(hit.top, closeTo(button.dy - reach, 0.01));
      expect(hit.center.dy, greaterThan(button.dy));
      expect(hit.contains(Offset(button.dx, button.dy + r + 2)), isTrue);
    });
  });

  group('tetherPlacement(置き場所)', () {
    const area = Rect.fromLTWH(8, 8, 344, 764);
    test('下に余裕があれば下(スケッチのとおり)、無ければ上', () {
      final top = tetherPlacement(anchor: const Rect.fromLTWH(160, 40, 44, 44), area: area, width: 320, reach: 19, preferred: TetherSide.below);
      expect(top.side, TetherSide.below);
      final bottom = tetherPlacement(anchor: const Rect.fromLTWH(160, 700, 44, 44), area: area, width: 320, reach: 19, preferred: TetherSide.below);
      expect(bottom.side, TetherSide.above);
      expect(bottom.maxHeight, closeTo(722 - 19 - 8, 0.01));
    });

    test('横はボタンの真ん中に合わせ、画面からはみ出さない', () {
      final mid = tetherPlacement(anchor: const Rect.fromLTWH(158, 40, 44, 44), area: area, width: 200, reach: 19, preferred: TetherSide.below);
      expect(mid.left, 80);
      final edge = tetherPlacement(anchor: const Rect.fromLTWH(310, 40, 44, 44), area: area, width: 200, reach: 19, preferred: TetherSide.below);
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
    // 外形の辺はアイコンの範囲の端(+ すき間)、中身はそこから細いふちの線のぶん内側 (D-479)。
    expect(body.top, closeTo(anchor.center.dy + kTetherIconExtent / 2 + kTetherIconGap + kFowRimWidth, 0.01));
    expect(body.width, 240 - 2 * kFowRimWidth); // 外形は中身から線 1 本ぶん外
    expect(tester.getCenter(find.byKey(const ValueKey('glyph'))), anchor.center);
    await tester.tap(find.byKey(const ValueKey('glyph')));
    expect(tapped, 1);
    // 首のふくらみ(パネルより上)も押せる。
    await tester.tapAt(Offset(anchor.center.dx, anchor.top));
    expect(tapped, 2);
    // 押せる範囲はパネルと反対の側へずれている: ボタンの下(パネルの中身)のタップは首に取られない。
    final hit = tester.getRect(find.byKey(const ValueKey('rasqOverlay.tether.hit')));
    expect(hit.bottom, closeTo(body.top - kFowRimWidth, 0.01));
    expect(hit.center.dy, lessThan(anchor.center.dy));
    await tester.tapAt(Offset(anchor.center.dx, body.top + 4));
    expect(tapped, 2);
  });

  test('tetherPlacement: lockSide なら空きが少なくても好みの側(親を持ち上げる子、D-517)', () {
    const area = Rect.fromLTWH(8, 8, 344, 764);
    final p = tetherPlacement(anchor: const Rect.fromLTWH(160, 700, 44, 44), area: area, width: 320, reach: 19, preferred: TetherSide.below, lockSide: true);
    expect(p.side, TetherSide.below);
  });

  testWidgets('TetheredPanel: ボタンがキーボードに隠れたら首を外してキーボードの上に置く。閉じればまたつながる (D-517)', (tester) async {
    const anchor = Rect.fromLTWH(100, 500, 44, 44);
    Widget app(double keyboard) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: const Size(400, 800), viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: const Scaffold(
              resizeToAvoidBottomInset: false,
              body: TetheredPanel(
                anchor: anchor,
                width: 240,
                preferredSide: TetherSide.above,
                anchorChild: Icon(Icons.tag, key: ValueKey('glyph')),
                child: SizedBox(key: ValueKey('body'), height: 120, child: TextField(key: ValueKey('field'))),
              ),
            ),
          ),
        );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(0));
    var body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.bottom, lessThan(anchor.center.dy), reason: 'ボタンの上につながる');
    await tester.tap(find.byKey(const ValueKey('field')));
    final field = tester.state(find.byType(EditableText));
    // キーボード 400px: ボタン(中心 522)は隠れる。
    await tester.pumpWidget(app(400));
    body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.bottom, lessThanOrEqualTo(800 - 400 - 8), reason: 'キーボードの上');
    expect(tester.getSize(find.byKey(const ValueKey('rasqOverlay.tether.hit'))), Size.zero, reason: '首は外す');
    expect(identical(tester.state(find.byType(EditableText)), field), isTrue, reason: '中身は作り直さない(入力のフォーカスが外れない)');
    await tester.pumpWidget(app(0));
    expect(tester.getSize(find.byKey(const ValueKey('rasqOverlay.tether.hit'))).width, greaterThan(0), reason: 'またつながる');
  });

  testWidgets('showTetheredPanel(footer:): 飾りのハンドルの代わりに標準のフッター (D-517)', (tester) async {
    final manager = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: OverlayHost(manager: manager, child: const SizedBox.expand())));
    manager.showTetheredPanel<void>(
      id: 'p',
      anchor: const Rect.fromLTWH(100, 60, 44, 44),
      title: 't',
      builder: (_) => const SizedBox(height: 40),
      footer: (_, handle) => FowFooter(leading: const Text('3 件'), actions: [TextButton(key: const ValueKey('close'), onPressed: handle.close, child: const Text('閉じる'))]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FowFooter), findsOneWidget);
    expect(find.text('3 件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close')));
    await tester.pumpAndSettle();
    expect(find.byType(FowFooter), findsNothing);
  });

  testWidgets('FowSpec.footer: ドックする FOW でも、ボタンにつながった FOW でも中身の下にフッター (D-517)', (tester) async {
    final manager = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: OverlayHost(manager: manager, child: const SizedBox.expand())));
    for (final anchor in [null, const Rect.fromLTWH(100, 60, 44, 44)]) {
      manager.showFow<void>(
        id: 'f',
        spec: FowSpec(title: 't', anchor: anchor, tether: anchor == null ? null : const FowTether(), footer: const FowFooter(leading: Text('footer'))),
        builder: (_, _) => const SizedBox.expand(key: ValueKey('body')),
      );
      await tester.pumpAndSettle();
      final footer = find.byType(FowFooter);
      expect(footer, findsOneWidget);
      expect(tester.getRect(footer).top, greaterThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('body'))).bottom - 0.01));
      manager.close('f');
      await tester.pumpAndSettle();
    }
  });
}
