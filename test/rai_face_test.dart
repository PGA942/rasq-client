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
