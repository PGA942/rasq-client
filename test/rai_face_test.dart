import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_face.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';

/// 表情シート (D-211): 4 列 × 3 行の枠を割合で切り出し、コントローラーの face が通知する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('枠の位置は割合(1920×1080 で 40 + 422c / 133 + 308.5r、378 × 252)', () {
    final r0 = raiFaceFrameRect(0, width: 1920, height: 1080);
    expect(r0.left, 40);
    expect(r0.top, 133);
    expect(r0.width, 378);
    expect(r0.height, 252);
    final r10 = raiFaceFrameRect(RaiFace.fow3, width: 1920, height: 1080);
    expect(r10.left, 40 + 422 * 2);
    expect(r10.top, closeTo(133 + 308.5 * 2, 0.01));
    expect(RaiFace.fowAppear, [8, 9, 10]);
  });

  testWidgets('シートの資産を読んで 11 枠の PNG に切り出す', (tester) async {
    late RaiFaceSheet sheet;
    await tester.runAsync(() async {
      sheet = await RaiFaceSheet.load(frameWidth: 64, frameHeight: 43);
    });
    expect(sheet.frames.length, RaiFace.count);
    // PNG シグネチャ。
    expect(sheet.frames.first.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('枠はシートの黒い枠から検出する(仮の絵でも固定の割合と数 px 以内で一致)', (tester) async {
    late List<ui.Rect>? detected;
    late int w, h;
    await tester.runAsync(() async {
      final png = (await rootBundle.load(RaiFaceSheet.asset)).buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      w = image.width;
      h = image.height;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      detected = raiFaceDetectFrames(rgba!.buffer.asUint8List(), w, h);
    });
    expect(detected, isNotNull);
    expect(detected!.length, 12);
    for (var i = 0; i < RaiFace.count; i++) {
      final fixed = raiFaceFrameRect(i, width: w.toDouble(), height: h.toDouble());
      expect((detected![i].left - fixed.left).abs(), lessThan(4), reason: 'frame $i left');
      expect((detected![i].top - fixed.top).abs(), lessThan(4), reason: 'frame $i top');
    }
  });

  test('コントローラーの face は変わったときだけ通知する', () {
    final c = RaiMascot3dController();
    var n = 0;
    c.addListener(() => n++);
    c.face = RaiFace.fow1;
    c.face = RaiFace.fow1;
    expect(n, 1);
    expect(c.face, RaiFace.fow1);
    c.dispose();
  });
}
