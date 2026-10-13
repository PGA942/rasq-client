import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/svg_paint_editor.dart';
import 'package:rasq_client/features/plugins/svgpaint/prefs.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// 落書きの編集画面の道具 (D-473): ペン先 / 切る消しゴム / 投げ輪 / 塗る / 取り消し・やり直し / 手ぶれ補正 / 道具の覚え。
void main() {
  late List<SvgPaintResult?> results;

  Widget editor({String? initialSvg, Key? key}) => MaterialApp(
        theme: RasqTheme.light(),
        home: SvgPaintEditor(key: key, initialSvg: initialSvg, onDone: results.add),
      );

  Future<void> pump(WidgetTester tester, {String? initialSvg}) async {
    results = [];
    await tester.pumpWidget(editor(initialSvg: initialSvg));
  }

  Offset at(WidgetTester tester, Offset vb) {
    final r = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    return r.topLeft + Offset(vb.dx * r.width / 300, vb.dy * r.height / 400);
  }

  Future<void> drag(WidgetTester tester, List<Offset> pts, {int steps = 10}) async {
    final g = await tester.startGesture(at(tester, pts.first));
    for (var k = 1; k < pts.length; k++) {
      for (var i = 1; i <= steps; i++) {
        await g.moveTo(at(tester, Offset.lerp(pts[k - 1], pts[k], i / steps)!));
      }
    }
    await g.up();
    await tester.pump();
  }

  Future<void> tapAt(WidgetTester tester, Offset vb) async {
    final g = await tester.startGesture(at(tester, vb));
    await g.up();
    await tester.pump();
  }

  Future<void> key(WidgetTester tester, String k) async {
    await tester.tap(find.byKey(ValueKey(k)));
    await tester.pump();
  }

  Future<SvgLite> done(WidgetTester tester) async {
    await key(tester, 'svgpaint.done');
    return SvgLite.parse(results.last!.svg)!;
  }

  bool enabled(WidgetTester tester, String k) => tester.widget<IconButton>(find.byKey(ValueKey(k))).onPressed != null;

  testWidgets('道具の並び: ペン先 3 つ・太さ・色、消しゴムの 2 種類、投げ輪 / 塗るの案内、手ぶれ補正', (tester) async {
    await pump(tester);
    for (final k in ['svgpaint.nib.mili', 'svgpaint.nib.kabura', 'svgpaint.nib.brush', 'svgpaint.width.0', 'svgpaint.color.7', 'svgpaint.redo']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.text('ミリペン'), findsOneWidget);
    // 手ぶれ補正(ペンの並びの端、強さ 0〜10、既定 3)。
    expect(find.byKey(const ValueKey('svgpaint.stabilizer')), findsNothing);
    await key(tester, 'svgpaint.settings');
    expect(find.byKey(const ValueKey('svgpaint.stabilizer')), findsOneWidget);
    expect(tester.widget<Slider>(find.byKey(const ValueKey('svgpaint.stabilizer'))).value, 3);
    await tester.drag(find.byKey(const ValueKey('svgpaint.stabilizer')), const Offset(-2000, 0));
    await tester.pump();
    expect(tester.widget<Slider>(find.byKey(const ValueKey('svgpaint.stabilizer'))).value, 0);
    expect(find.byKey(const ValueKey('svgpaint.eraser.cut')), findsNothing);
    await key(tester, 'svgpaint.tool.eraser');
    expect(find.byKey(const ValueKey('svgpaint.eraser.cut')), findsOneWidget);
    expect(find.byKey(const ValueKey('svgpaint.eraser.whole')), findsOneWidget);
    expect(find.byKey(const ValueKey('svgpaint.nib.mili')), findsNothing);
    await key(tester, 'svgpaint.tool.lasso');
    expect(find.textContaining('囲んで選ぶ'), findsOneWidget);
    await key(tester, 'svgpaint.tool.fill');
    expect(find.textContaining('閉じた形の中をタップ'), findsOneWidget);
    // 色を押すとペンに戻る(塗るの間は塗りの色)。
    await key(tester, 'svgpaint.color.2');
    expect(find.textContaining('閉じた形の中をタップ'), findsOneWidget);
    await key(tester, 'svgpaint.tool.eraser');
    await key(tester, 'svgpaint.color.2');
    expect(find.byKey(const ValueKey('svgpaint.nib.mili')), findsOneWidget);
    await key(tester, 'svgpaint.width.0');
    expect(find.byKey(const ValueKey('svgpaint.width.0')), findsOneWidget);
  });

  testWidgets('ペン先: カプラペン / ブラシニブは輪郭の塗り(印は stroke-linejoin)、ミリペンは線', (tester) async {
    await pump(tester);
    await key(tester, 'svgpaint.nib.kabura');
    await drag(tester, [const Offset(40, 60), const Offset(160, 120), const Offset(260, 60)]);
    await key(tester, 'svgpaint.nib.brush');
    await key(tester, 'svgpaint.color.1');
    await drag(tester, [const Offset(40, 200), const Offset(160, 260), const Offset(260, 200)]);
    await key(tester, 'svgpaint.nib.mili');
    await drag(tester, [const Offset(40, 330), const Offset(160, 360), const Offset(260, 330)]);
    final doc = await done(tester);
    expect(doc.shapes, hasLength(3));
    expect(doc.shapes[0].fill, svgPaintColors[0]);
    expect(doc.shapes[0].stroke, isNull);
    expect(doc.shapes[0].strokeJoin, StrokeJoin.round);
    expect(doc.shapes[1].fill, svgPaintColors[1]);
    expect(doc.shapes[1].strokeJoin, StrokeJoin.bevel);
    expect(doc.shapes[2].fill, isNull);
    expect(doc.shapes[2].stroke, svgPaintColors[1]);
    // 曲線(節を通る 3 次ベジェ)。
    expect(results.last!.svg, contains('c'));
    // 輪郭の線は入り・抜きで両端が細い: 外接矩形の高さは線の太さより十分大きく、端は中心線の端の近く。
    final b = doc.shapes[0].path.getBounds();
    expect(b.left, closeTo(40, 2));
    expect(b.right, closeTo(260, 2));
  });

  testWidgets('切る消しゴム: 線の途中で 2 本に分かれる。取り消し / やり直し', (tester) async {
    await pump(tester);
    await drag(tester, [const Offset(40, 200), const Offset(260, 200)], steps: 20);
    await key(tester, 'svgpaint.tool.eraser');
    expect(enabled(tester, 'svgpaint.redo'), isFalse);
    await drag(tester, [const Offset(150, 170), const Offset(150, 230)]);
    var doc = await done(tester);
    expect(doc.shapes, hasLength(2));
    final left = doc.shapes[0].polylines!.single, right = doc.shapes[1].polylines!.single;
    expect(left.first.dx, closeTo(40, 1));
    expect(left.last.dx, lessThan(145));
    expect(right.first.dx, greaterThan(155));
    expect(right.last.dx, closeTo(260, 1));
    await key(tester, 'svgpaint.undo');
    doc = await done(tester);
    expect(doc.shapes, hasLength(1));
    expect(enabled(tester, 'svgpaint.redo'), isTrue);
    await key(tester, 'svgpaint.redo');
    expect((await done(tester)).shapes, hasLength(2));
    // 新しく描いたらやり直しは消える。
    await key(tester, 'svgpaint.undo');
    await key(tester, 'svgpaint.tool.pen');
    await drag(tester, [const Offset(40, 300), const Offset(260, 300)]);
    expect(enabled(tester, 'svgpaint.redo'), isFalse);
    expect((await done(tester)).shapes, hasLength(2));
  });

  testWidgets('投げ輪: 囲んで選ぶ → ドラッグで動かす → 複製 / 色を変える / 削除、取り消しで戻る', (tester) async {
    await pump(tester);
    await drag(tester, [const Offset(60, 80), const Offset(140, 80)]);
    await drag(tester, [const Offset(60, 300), const Offset(140, 300)]);
    await key(tester, 'svgpaint.tool.lasso');
    await drag(tester, [const Offset(40, 50), const Offset(170, 50), const Offset(170, 120), const Offset(40, 120), const Offset(40, 52)], steps: 4);
    expect(find.byKey(const ValueKey('svgpaint.sel.delete')), findsOneWidget);
    // 選んだ線の上をつかんで右下へ 30 動かす。
    await drag(tester, [const Offset(100, 80), const Offset(130, 110)]);
    var doc = await done(tester);
    final moved = doc.shapes[0].polylines!.single;
    expect(moved.first, within(distance: 1, from: const Offset(90, 110)));
    expect(moved.last, within(distance: 1, from: const Offset(170, 110)));
    expect(doc.shapes[1].polylines!.single.first.dy, closeTo(300, 1));
    // 選んだまま: 複製 → 色を変える(今の色 = 赤)→ 削除。
    await key(tester, 'svgpaint.sel.duplicate');
    expect((await done(tester)).shapes, hasLength(3));
    await key(tester, 'svgpaint.color.1');
    doc = await done(tester);
    expect(doc.shapes[2].stroke, svgPaintColors[1]);
    expect(doc.shapes[0].stroke, svgPaintColors[0]);
    await key(tester, 'svgpaint.sel.delete');
    expect((await done(tester)).shapes, hasLength(2));
    expect(find.byKey(const ValueKey('svgpaint.sel.delete')), findsNothing);
    for (var i = 0; i < 4; i++) {
      await key(tester, 'svgpaint.undo');
    }
    doc = await done(tester);
    expect(doc.shapes[0].polylines!.single.first, within(distance: 1, from: const Offset(60, 80)));
    // 選ぶものが無い輪 / タップは何も選ばない。
    await tapAt(tester, const Offset(250, 380));
    expect(find.byKey(const ValueKey('svgpaint.sel.delete')), findsNothing);
  });

  testWidgets('塗る: 閉じた形の中をタップすると線の下に塗り、閉じていなければ案内だけ', (tester) async {
    await pump(tester);
    await drag(tester, [const Offset(60, 60), const Offset(240, 60), const Offset(240, 240), const Offset(60, 240), const Offset(60, 60)], steps: 15);
    await key(tester, 'svgpaint.tool.fill');
    await key(tester, 'svgpaint.color.4');
    await tapAt(tester, const Offset(150, 150));
    var doc = await done(tester);
    expect(doc.shapes, hasLength(2));
    expect(doc.shapes.first.fill, svgPaintColors[4]); // 線の下
    expect(doc.shapes.first.stroke, isNull);
    expect(doc.shapes.first.path.contains(const Offset(150, 150)), isTrue);
    expect(doc.shapes.first.path.contains(const Offset(150, 300)), isFalse);
    // 同じところをほかの色で塗り直すと置き換わる。
    await key(tester, 'svgpaint.color.5');
    await tapAt(tester, const Offset(120, 120));
    doc = await done(tester);
    expect(doc.shapes, hasLength(2));
    expect(doc.shapes.first.fill, svgPaintColors[5]);
    // 外は閉じていない → 案内(しばらくで消える)。
    await tapAt(tester, const Offset(150, 320));
    expect(find.byKey(const ValueKey('svgpaint.toast')), findsOneWidget);
    expect(find.textContaining('閉じた形の中'), findsWidgets);
    expect((await done(tester)).shapes, hasLength(2));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('svgpaint.toast')), findsNothing);
    // 取り消しで塗り直しの前、塗る前へ。
    await key(tester, 'svgpaint.undo');
    expect((await done(tester)).shapes.first.fill, svgPaintColors[4]);
    await key(tester, 'svgpaint.undo');
    expect((await done(tester)).shapes, hasLength(1));
  });

  testWidgets('前に保存した SVG(新しい書き方)を開き直して、続けて切れる', (tester) async {
    await pump(tester);
    await key(tester, 'svgpaint.nib.kabura');
    await drag(tester, [const Offset(40, 200), const Offset(150, 150), const Offset(260, 200)], steps: 15);
    await done(tester);
    final svg = results.last!.svg;
    await pump(tester, initialSvg: svg);
    await key(tester, 'svgpaint.done');
    expect(results.last!.svg, svg);
    await key(tester, 'svgpaint.tool.eraser');
    await drag(tester, [const Offset(150, 120), const Offset(150, 190)]);
    final doc = await done(tester);
    expect(doc.shapes, hasLength(2));
    expect(doc.shapes.every((s) => s.strokeJoin == StrokeJoin.round && s.fill != null), isTrue);
  });

  testWidgets('道具の覚え: ペン先・太さ・色・手ぶれ補正をユーザーごとの KV に残し、次に開いたときに戻す', (tester) async {
    final storage = MemorySessionStorage();
    results = [];
    Widget app(Key k) => ProviderScope(
          overrides: [sessionStorageProvider.overrideWithValue(storage)],
          child: editor(key: k),
        );
    await tester.pumpWidget(app(const ValueKey(1)));
    await tester.pump();
    await key(tester, 'svgpaint.nib.brush');
    await key(tester, 'svgpaint.width.2');
    await key(tester, 'svgpaint.color.6');
    await tester.pump();
    final stored = storage.keys.where((k) => k.startsWith(SvgPaintPrefsStore.keyPrefix)).single;
    expect(jsonDecode((await storage.read(stored))!), {'nib': 'brush', 'size': 2, 'color': 6, 'wholeEraser': false, 'stabilizer': 3});
    // 開き直す。
    await tester.pumpWidget(app(const ValueKey(2)));
    await tester.pump();
    await tester.pump();
    await drag(tester, [const Offset(40, 200), const Offset(260, 200)]);
    final doc = await done(tester);
    expect(doc.shapes.single.fill, svgPaintColors[6]);
    expect(doc.shapes.single.strokeJoin, StrokeJoin.bevel);
    // 壊れた値は既定に。
    expect(SvgPaintPrefs.fromJson({'nib': 'x', 'size': 9, 'color': -1, 'stabilizer': 99}, sizes: 3, colors: 8), const SvgPaintPrefs());
  });
}
