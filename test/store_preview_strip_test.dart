import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/store/store_widgets.dart';
import 'package:rasq_design/rasq_design.dart';

/// プラグインページのプレビュー (D-374): 帯の高さを、見ている画像の縦横比に合わせる(範囲に収める)。
void main() {
  test('高さ = 1 枚の幅 ÷ 縦横比(範囲に収める)。分からなければ既定', () {
    expect(StorePreviewStrip.heightFor(300, 2), 150);
    expect(StorePreviewStrip.heightFor(300, 0.5), 480, reason: '縦長は上限で止める');
    expect(StorePreviewStrip.heightFor(300, 4), 140, reason: '横長は下限で止める');
    expect(StorePreviewStrip.heightFor(300, null), 200);
  });

  testWidgets('横長の画像では低く、縦長の画像へ送ると高くなる', (tester) async {
    Future<ImageProvider> png(int w, int h) async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF3355CC));
      final img = await rec.endRecording().toImage(w, h);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return MemoryImage(bytes!.buffer.asUint8List());
    }

    final wide = (await tester.runAsync(() => png(400, 200)))!;
    final tall = (await tester.runAsync(() => png(200, 400)))!;
    final a = Uri.parse('https://x.test/a.png');
    final b = Uri.parse('https://x.test/b.png');
    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: StorePreviewStrip(images: [a, b], imageProvider: (u) => u == a ? wide : tall)),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final itemWidth = 400 * 0.86 - RasqSpacing.page - RasqSpacing.xs;
    double height() => tester.getSize(find.byKey(const ValueKey('store.preview.strip'))).height;
    expect(height(), closeTo(StorePreviewStrip.heightFor(itemWidth, 2), 0.5));
    await tester.drag(find.byKey(const ValueKey('store.preview.strip')), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(height(), closeTo(StorePreviewStrip.heightFor(itemWidth, 0.5), 0.5));
  });
}
