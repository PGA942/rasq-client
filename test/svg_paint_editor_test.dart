import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart' show openSvgPaintEditor;
import 'package:rasq_client/features/plugins/svg_paint_editor.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// 落書きの編集画面 (D-465、契約 v0.22 の `media.editor.open {format: "svg"}`)。
void main() {
  late List<SvgPaintResult?> results;
  late bool called;

  Future<void> pump(WidgetTester tester, {String aspect = '3:4', String? initialSvg}) async {
    results = [];
    called = false;
    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: SvgPaintEditor(
        aspect: aspect,
        initialSvg: initialSvg,
        onDone: (r) {
          called = true;
          results.add(r);
        },
      ),
    ));
  }

  /// viewBox の点 → 画面の点。
  Offset at(WidgetTester tester, Offset vb, {Size size = const Size(300, 400)}) {
    final r = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    return r.topLeft + Offset(vb.dx * r.width / size.width, vb.dy * r.height / size.height);
  }

  /// viewBox の [from] から [to] へ、[steps] 回に分けてなぞる。
  Future<void> stroke(WidgetTester tester, Offset from, Offset to, {int steps = 12}) async {
    final g = await tester.startGesture(at(tester, from));
    for (var i = 1; i <= steps; i++) {
      await g.moveTo(at(tester, Offset.lerp(from, to, i / steps)!));
    }
    await g.up();
    await tester.pump();
  }

  Future<SvgLite> done(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
    await tester.pump();
    final r = results.last!;
    expect(r.width, 300);
    expect(r.height, 400);
    return SvgLite.parse(r.svg)!;
  }

  test('svgPaintViewBox: 長い辺 400、読めなければ 3:4', () {
    expect(svgPaintViewBox('3:4'), const Size(300, 400));
    expect(svgPaintViewBox('1:1'), const Size(400, 400));
    expect(svgPaintViewBox('16:9'), const Size(400, 225));
    expect(svgPaintViewBox('7:3'), const Size(400, 171));
    for (final bad in ['', '0:4', '17:4', '3/4', 'a:b', '3:4:5', '-3:4']) {
      expect(svgPaintViewBox(bad), const Size(300, 400), reason: bad);
    }
  });

  testWidgets('なぞる → 完了: path 1 本、選んだ色と太さ、紙は 3:4', (tester) async {
    await pump(tester);
    expect(find.text('落書き'), findsOneWidget);
    final r = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    expect(r.width / r.height, closeTo(0.75, 0.01));

    await tester.tap(find.byKey(const ValueKey('svgpaint.color.5')));
    await tester.tap(find.byKey(const ValueKey('svgpaint.width.2')));
    await tester.pump();
    await stroke(tester, const Offset(50, 50), const Offset(200, 300));
    final doc = await done(tester);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 300, 400));
    final s = doc.shapes.single;
    expect(s.kind, SvgLiteShapeKind.path);
    expect(s.fill, isNull);
    expect(s.stroke, svgPaintColors[5]);
    expect(s.strokeWidth, svgPaintWidths[2]);
    expect(s.strokeCap, StrokeCap.round);
    expect(s.strokeJoin, StrokeJoin.round);
    final line = s.polylines!.single;
    expect((line.first - const Offset(50, 50)).distance, lessThan(1.5));
    expect((line.last - const Offset(200, 300)).distance, lessThan(1.5));
    // 座標は整数。
    expect(results.last!.svg, matches(RegExp(r'd="M\d+ \d+L[\d ]+"')));
  });

  testWidgets('まっすぐな線は 2 点に簡略化、タップは点(M x yL x y)', (tester) async {
    await pump(tester);
    await stroke(tester, const Offset(60, 200), const Offset(240, 200), steps: 30);
    final g = await tester.startGesture(at(tester, const Offset(100, 100)));
    await g.up();
    await tester.pump();
    final doc = await done(tester);
    expect(doc.shapes, hasLength(2));
    final line = doc.shapes[0].polylines!.single;
    expect(line, hasLength(2));
    expect(line.first.dy, line.last.dy);
    expect(doc.shapes[1].polylines!.single, [const Offset(100, 100), const Offset(100, 100)]);
    expect(results.last!.svg, contains('d="M100 100L100 100"'));
  });

  testWidgets('消しゴムは線をまるごと消し、取り消しで戻る。全部消すも戻せる', (tester) async {
    await pump(tester);
    await stroke(tester, const Offset(50, 100), const Offset(250, 100));
    await stroke(tester, const Offset(50, 300), const Offset(250, 300));
    await tester.tap(find.byKey(const ValueKey('svgpaint.tool.eraser')));
    await tester.pump();
    // 1 本目だけを縦に横切る。
    await stroke(tester, const Offset(150, 60), const Offset(150, 140));
    var doc = await done(tester);
    expect(doc.shapes, hasLength(1));
    expect(doc.shapes.single.polylines!.single.first.dy, closeTo(300, 1.5));

    await tester.tap(find.byKey(const ValueKey('svgpaint.undo')));
    await tester.pump();
    doc = await done(tester);
    expect(doc.shapes, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('svgpaint.clear')));
    await tester.pump();
    expect((await done(tester)).shapes, isEmpty);
    await tester.tap(find.byKey(const ValueKey('svgpaint.undo')));
    await tester.pump();
    expect((await done(tester)).shapes, hasLength(2));
    // 描いたのも取り消せる。
    await tester.tap(find.byKey(const ValueKey('svgpaint.undo')));
    await tester.tap(find.byKey(const ValueKey('svgpaint.undo')));
    await tester.pump();
    expect((await done(tester)).shapes, isEmpty);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('svgpaint.undo'))).onPressed, isNull);
  });

  testWidgets('initialSvg から続きを描く: 前の線と形は残り、新しい線は後ろに足す', (tester) async {
    await pump(tester, initialSvg: '<svg viewBox="0 0 300 400">'
        '<path d="M10 10L100 100" fill="none" stroke="#e53935" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'
        '<circle cx="250" cy="350" r="20" fill="#1e88e5"/>'
        '<script>alert(1)</script>'
        '</svg>');
    await stroke(tester, const Offset(50, 200), const Offset(250, 200));
    final doc = await done(tester);
    expect(doc.shapes, hasLength(3));
    expect(doc.shapes[0].polylines, [
      [const Offset(10, 10), const Offset(100, 100)],
    ]);
    expect(doc.shapes[0].stroke, const Color(0xFFE53935));
    expect(doc.shapes[0].strokeWidth, 5);
    expect(doc.shapes[1].kind, SvgLiteShapeKind.circle);
    expect(doc.shapes[1].fill, const Color(0xFF1E88E5));
    expect(doc.shapes[2].stroke, svgPaintColors.first);
    expect(results.last!.svg, isNot(contains('script')));

    // 動かない形も消しゴムで消せる(外接矩形で当てる)。
    await tester.tap(find.byKey(const ValueKey('svgpaint.tool.eraser')));
    await tester.pump();
    await stroke(tester, const Offset(240, 340), const Offset(260, 360), steps: 2);
    final after = await done(tester);
    expect(after.shapes.map((s) => s.kind), [SvgLiteShapeKind.path, SvgLiteShapeKind.path]);
  });

  testWidgets('出力は SvgLite で読み直すと同じ線(書き戻しも同じ文字列)', (tester) async {
    await pump(tester);
    await stroke(tester, const Offset(30, 30), const Offset(120, 80));
    await stroke(tester, const Offset(120, 80), const Offset(60, 300));
    expect(results, isEmpty); // 完了を押すまで返さない
    final doc = await done(tester);
    expect(doc.toSvg(), results.last!.svg);

    // 読み直して続きを描いても、前の線は変わらない。
    final svg = results.last!.svg;
    await pump(tester, initialSvg: svg);
    final again = await done(tester);
    expect(results.last!.svg, svg);
    expect(again.shapes.map((s) => s.polylines), doc.shapes.map((s) => s.polylines));
  });

  testWidgets('キャンセル → onDone(null)', (tester) async {
    await pump(tester);
    await stroke(tester, const Offset(30, 30), const Offset(120, 80));
    await tester.tap(find.byKey(const ValueKey('svgpaint.cancel')));
    await tester.pump();
    expect(called, isTrue);
    expect(results, [null]);
  });

  testWidgets('違う viewBox の initialSvg は紙へ縦横比を保って収める', (tester) async {
    await pump(tester, initialSvg: 'data:image/svg+xml,${Uri.encodeComponent('<svg viewBox="0 0 30 40"><path d="M0 0L30 40" fill="none" stroke="#000" stroke-width="1"/></svg>')}');
    final doc = await done(tester);
    expect(doc.shapes.single.polylines, [
      [Offset.zero, const Offset(300, 400)],
    ]);
    expect(doc.shapes.single.strokeWidth, 10);
  });

  testWidgets('開き方 (D-465): 狭い画面は全画面のルートで SVG モード。やめたら null / 外から閉じる口でも閉じる', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    })));
    var h = openSvgPaintEditor(ctx, aspect: '3:4', title: '落書き');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media.svg.editor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('svgpaint.cancel')));
    await tester.pumpAndSettle();
    expect(await h.result, isNull);
    expect(find.byKey(const ValueKey('media.svg.editor')), findsNothing);

    h = openSvgPaintEditor(ctx, aspect: '1:1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media.svg.editor')), findsOneWidget);
    h.close();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media.svg.editor')), findsNothing);
  });
}
