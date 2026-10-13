// 描画確認用 (D-473): 落書きのエンジンの見本(ペン先 3 種・切り口の丸め込み・投げ輪の変形・オート塗りつぶし)と編集画面。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/svg_paint_preview_test.dart --update-goldens
// → tool/preview/svgpaint_<nibs|cut|lasso|fill|editor|editor_lasso>.png と、同じ名前の .svg(書き出した SVG そのもの。
//   SVGPAINT_PREVIEW_OUT で置き場を変えられる)。見本の SVG は SvgLite(プラグインが表示に使う消毒済みの描き手)で描く。
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/svg_paint_editor.dart';
import 'package:rasq_client/features/plugins/svgpaint/eraser.dart';
import 'package:rasq_client/features/plugins/svgpaint/fill.dart';
import 'package:rasq_client/features/plugins/svgpaint/geometry.dart';
import 'package:rasq_client/features/plugins/svgpaint/lasso.dart';
import 'package:rasq_client/features/plugins/svgpaint/model.dart';
import 'package:rasq_client/features/plugins/svgpaint/nib.dart';
import 'package:rasq_client/features/plugins/svgpaint/svg_io.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display', 'FlutterTest']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    // アイコン: Flutter SDK の控えから Material Icons を読む(homeshots_test.dart と同じ)。
    const inSdk = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var icons = '${Platform.environment['FLUTTER_ROOT'] ?? ''}/$inSdk';
    for (var d = File(Platform.resolvedExecutable).parent; !File(icons).existsSync() && d.path != d.parent.path; d = d.parent) {
      icons = '${d.path}/$inSdk';
    }
    if (File(icons).existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File(icons).readAsBytesSync().buffer)));
      await loader.load();
    }
  });
  final out = Platform.environment['SVGPAINT_PREVIEW_OUT'] ?? 'tool/preview';
  const vb = Size(300, 400);

  PaintStroke draw(List<Offset> pts, {PaintNib nib = PaintNib.mili, double size = 5, Color color = const Color(0xFF212121), double msPerPoint = 16}) {
    final dyn = NibDynamics(nib, size);
    // 速さに緩急を付ける(払いのように、ところどころ速く)。
    var t = 0.0;
    final ws = <double>[];
    for (var i = 0; i < pts.length; i++) {
      ws.add(dyn.next(InkSample(pts[i], t)));
      t += msPerPoint * (0.5 + 1.5 * math.sin(i / 9).abs());
    }
    return buildStroke(nib: nib, color: color, size: size, points: pts, widths: ws);
  }

  List<Offset> wave(double y, {double amp = 30, double x0 = 30, double x1 = 270, int n = 160}) =>
      [for (var i = 0; i <= n; i++) Offset(x0 + (x1 - x0) * i / n, y + amp * math.sin(i / n * math.pi * 2))];

  String save(String name, List<PaintItem> items) {
    final svg = encodeSvg(vb, items);
    File('$out/$name.svg')
      ..createSync(recursive: true)
      ..writeAsStringSync(svg);
    print('$name.svg: ${svg.length} バイト');
    return svg;
  }

  Widget panel(String label, String svg) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(label, style: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 22, color: Color(0xFF333333))),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCCCCCC))),
                child: SvgLiteView(doc: SvgLite.parse(svg)!),
              ),
            ),
          ]),
        ),
      );

  Future<void> shoot(WidgetTester tester, String name, List<(String, String)> panels, {Size size = const Size(1200, 760)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: const Color(0xFFF2F2F2), child: Row(children: [for (final (l, s) in panels) panel(l, s)])),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('svgpaint_$name.png'));
  }

  testWidgets('ペン先 3 種', (tester) async {
    final panels = <(String, String)>[];
    for (final nib in PaintNib.values) {
      final items = <PaintItem>[
        draw(wave(70, amp: 25), nib: nib, size: 2),
        draw(wave(150, amp: 30), nib: nib, size: 5, color: const Color(0xFFE53935)),
        draw(wave(240, amp: 35), nib: nib, size: 10, color: const Color(0xFF1E88E5)),
        // 速い払い(点がまばら)と、ゆっくりの円。
        draw([for (var i = 0; i <= 12; i++) Offset(40 + i * 18.0, 360 - i * 6.0)], nib: nib, size: 6, msPerPoint: 3),
        draw([for (var i = 0; i <= 120; i++) const Offset(230, 330) + Offset.fromDirection(i / 120 * math.pi * 1.9, 28)], nib: nib, size: 4, color: const Color(0xFF43A047)),
      ];
      panels.add(('${nib.label}(太さ 2 / 5 / 10)', save('svgpaint_nibs_${nib.name}', items)));
    }
    await shoot(tester, 'nibs', panels);
  });

  testWidgets('切り口の丸め込み', (tester) async {
    final panels = <(String, String)>[], zoomed = <(String, String)>[];
    for (final nib in PaintNib.values) {
      final s1 = draw(wave(110, amp: 40), nib: nib, size: 10);
      final s2 = draw([for (var i = 0; i <= 100; i++) Offset(150 + 110 * math.cos(i / 100 * math.pi), 300 - 70 * math.sin(i / 100 * math.pi))], nib: nib, size: 8, color: const Color(0xFFE53935));
      final e = EraseSession([s1, s2]);
      // 2 か所を消しゴムでなぞる(縦に 1 回、点で 1 回)。
      for (var y = 50.0; y <= 170; y += 4) {
        e.apply(Offset(120, y), 7);
      }
      e
        ..apply(const Offset(205, 110), 6)
        ..apply(const Offset(150, 232), 9);
      final pieces = e.finish()!;
      panels.add(('${nib.label}: 切った端', save('svgpaint_cut_${nib.name}', pieces)));
      // 縦に切ったところを 3.5 倍に(投げ輪と同じ変形で)。
      final zoom = Affine.around(const Offset(120, 110), scale: 3.5, shift: const Offset(30, 90));
      zoomed.add(('${nib.label}: 切り口(3.5 倍)', encodeSvg(vb, [for (final p in pieces) p.transformed(zoom)])));
    }
    await shoot(tester, 'cut', panels);
    await shoot(tester, 'cut_zoom', zoomed);
  });

  List<PaintItem> face() => [
        draw([for (var i = 0; i <= 120; i++) const Offset(150, 150) + Offset.fromDirection(i / 120 * math.pi * 2, 90)], size: 5),
        draw([for (var i = 0; i <= 20; i++) Offset(110, 120 + i * 1.5)], nib: PaintNib.kabura, size: 6),
        draw([for (var i = 0; i <= 20; i++) Offset(190, 120 + i * 1.5)], nib: PaintNib.kabura, size: 6),
        draw([for (var i = 0; i <= 60; i++) Offset(100 + i * 100 / 60, 185 + 25 * math.sin(i / 60 * math.pi))], nib: PaintNib.brush, size: 5, color: const Color(0xFFE53935)),
        draw([for (var i = 0; i <= 80; i++) Offset(40 + i * 2.8, 330 + 20 * math.sin(i / 8))], nib: PaintNib.brush, size: 4, color: const Color(0xFF1E88E5)),
      ];

  testWidgets('投げ輪の変形', (tester) async {
    final before = face();
    // 顔だけを囲んで選び、回して大きくしてずらす。
    final sel = lassoSelect(before, [const Offset(40, 40), const Offset(260, 40), const Offset(260, 260), const Offset(40, 260)]);
    final m = Affine.around(const Offset(150, 150), scale: 0.8, angle: 0.4, shift: const Offset(10, 30));
    final (after, moved) = transformSelection(before, sel, m);
    final (dup, copies) = duplicateSelection(after, moved, shift: Offset.zero);
    final (small, smallSel) = transformSelection(dup, copies, Affine.around(const Offset(160, 180), scale: 0.35, shift: const Offset(70, 150)));
    final (recolored, _) = recolorSelection(small, smallSel, const Color(0xFF8E24AA));
    await shoot(tester, 'lasso', [
      ('前', save('svgpaint_lasso_before', before)),
      ('顔を選んで 0.8 倍・回転 23°・移動', save('svgpaint_lasso_after', after)),
      ('さらに複製して縮小・色を変える', save('svgpaint_lasso_dup', recolored)),
    ]);
  });

  testWidgets('オート塗りつぶし', (tester) async {
    final ring = [
      draw([for (var i = 0; i <= 140; i++) const Offset(150, 140) + Offset.fromDirection(i / 140 * math.pi * 2, 100)], size: 4),
      draw([for (var i = 0; i <= 80; i++) const Offset(150, 140) + Offset.fromDirection(i / 80 * math.pi * 2, 40)], size: 4),
      draw([for (var i = 0; i <= 20; i++) Offset(70 + i * 1.0, 130 + i * 1.0)], nib: PaintNib.kabura, size: 4),
    ];
    // 角の 1 つに 2 単位の切れ目がある三角形(すき間の許しで閉じる)。
    final tri = [
      draw([for (var i = 0; i <= 40; i++) Offset.lerp(const Offset(60, 360), const Offset(150, 270), i / 40)!], nib: PaintNib.brush, size: 3),
      draw([for (var i = 0; i <= 40; i++) Offset.lerp(const Offset(151.5, 271.5), const Offset(240, 360), i / 40)!], nib: PaintNib.brush, size: 3),
      draw([for (var i = 0; i <= 40; i++) Offset.lerp(const Offset(240, 360), const Offset(60, 360), i / 40)!], nib: PaintNib.brush, size: 3),
    ];
    var items = <PaintItem>[...ring, ...tri];
    final lines = save('svgpaint_fill_lines', items);
    for (final (tap, color) in [(const Offset(150, 60), const Color(0xFFFDD835)), (const Offset(150, 140), const Color(0xFF1E88E5)), (const Offset(150, 330), const Color(0xFF43A047))]) {
      final f = autoFill(items, vb, tap, color).fill!;
      items = [f, ...items];
    }
    final leak = autoFill([...ring.sublist(0, 1), tri[0], tri[2]], vb, const Offset(150, 330), Colors.red).failure;
    print('閉じていない三角形: $leak');
    await shoot(tester, 'fill', [
      ('線だけ', lines),
      ('3 か所をタップ(ドーナツの穴・切れ目 2 の三角形)', save('svgpaint_fill', items)),
    ], size: const Size(820, 760));
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Offset at(WidgetTester tester, Offset p) {
    final r = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    return r.topLeft + Offset(p.dx * r.width / 300, p.dy * r.height / 400);
  }

  Future<void> drag(WidgetTester tester, List<Offset> pts, {int steps = 8}) async {
    final g = await tester.startGesture(at(tester, pts.first));
    for (var k = 1; k < pts.length; k++) {
      for (var i = 1; i <= steps; i++) {
        await g.moveTo(at(tester, Offset.lerp(pts[k - 1], pts[k], i / steps)!), timeStamp: Duration(milliseconds: (k * steps + i) * 16));
      }
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('編集画面(スマホ)', (tester) async {
    await phone(tester);
    final initial = encodeSvg(vb, face());
    String? result;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RasqTheme.light(),
      home: SvgPaintEditor(title: 'みんなで落書き', initialSvg: initial, onDone: (r) => result = r?.svg),
    ));
    await tester.tap(find.byKey(const ValueKey('svgpaint.nib.kabura')));
    await tester.tap(find.byKey(const ValueKey('svgpaint.color.5')));
    await tester.pump();
    await drag(tester, [const Offset(40, 290), const Offset(120, 270), const Offset(200, 300), const Offset(260, 280)]);
    await expectLater(find.byType(SvgPaintEditor), matchesGoldenFile('svgpaint_editor.png'));
    // 投げ輪で顔を選んで回す途中。
    await tester.tap(find.byKey(const ValueKey('svgpaint.tool.lasso')));
    await tester.pump();
    await drag(tester, [const Offset(45, 45), const Offset(255, 45), const Offset(255, 255), const Offset(45, 255), const Offset(45, 48)], steps: 6);
    final handle = await tester.startGesture(at(tester, const Offset(150, 57.5)) - const Offset(0, 26));
    await handle.moveTo(at(tester, const Offset(210, 70)));
    await tester.pump();
    await expectLater(find.byType(SvgPaintEditor), matchesGoldenFile('svgpaint_editor_lasso.png'));
    await handle.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
    await tester.pump();
    File('$out/svgpaint_editor.svg').writeAsStringSync(result!);
    print('svgpaint_editor.svg: ${result!.length} バイト');
  });
}
