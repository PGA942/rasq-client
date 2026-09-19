import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/post_video.dart';

/// 加工画面の「動く投稿」(D-261): レイヤーの位置 → 絵の画素での枠、書き出す動画の大きさ。
void main() {
  test('postObjectRectInImage: 中心からのずれ × 表示倍率。拡縮も掛かる', () {
    // 2000×1000 の絵を 400×200 で表示(k = 5)。幅 100・縦横比 0.5 のタイルを、右へ 40 / 上へ 20 ずらして 2 倍に。
    final r = postObjectRectInImage(image: const Size(2000, 1000), shown: const Size(400, 200), offset: const Offset(40, -20), width: 100, aspect: 0.5, scale: 2);
    expect(r.center, const Offset(1200, 400));
    expect(r.size, const Size(1000, 500));
    // 真ん中・等倍。
    final c = postObjectRectInImage(image: const Size(800, 600), shown: const Size(800, 600), offset: Offset.zero, width: 200, aspect: 1, scale: 1);
    expect(c, const Rect.fromLTWH(300, 200, 200, 200));
  });

  test('postCanvasFor: 長辺 1920 まで縮めて偶数に', () {
    final big = postCanvasFor(const Size(4000, 3001));
    expect(big.factor, closeTo(0.48, 1e-9));
    expect(big.canvas, const Size(1920, 1440));
    final small = postCanvasFor(const Size(641, 481));
    expect(small.factor, 1);
    expect(small.canvas.width % 2, 0);
    expect(small.canvas.height % 2, 0);
  });

  test('mediaContainerExt: 中身の先頭から入れ物を当てる', () {
    List<int> ftyp(String brand) => [0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0];
    expect(mediaContainerExt(ftyp('isom')), 'mp4');
    expect(mediaContainerExt(ftyp('qt  ')), 'mov');
    expect(mediaContainerExt(ftyp('M4A ')), 'm4a');
    expect(mediaContainerExt([0x1A, 0x45, 0xDF, 0xA3, 0, 0]), 'webm');
    expect(mediaContainerExt('OggS....'.codeUnits), 'ogg');
    expect(mediaContainerExt([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]), 'wav');
    expect(mediaContainerExt('ID3.....'.codeUnits), 'mp3');
    expect(mediaContainerExt([1, 2, 3]), isNull);
  });

  test('objectRectFromScreen: 画面で測った枠 → 絵の画素 (D-265)', () {
    // 2560×1440 の動画が、画面の (160, 290) から 1504×846 で出ている。オブジェクトは (686, 368) から 451×248。
    final r = objectRectFromScreen(reference: const Rect.fromLTWH(160, 290, 1504, 846), object: const Rect.fromLTWH(686, 368, 451, 248), image: const Size(2560, 1440));
    expect(r.left, closeTo(526 * 2560 / 1504, 1e-6));
    expect(r.top, closeTo(78 * 1440 / 846, 1e-6));
    expect(r.width, closeTo(451 * 2560 / 1504, 1e-6));
    expect(objectRectFromScreen(reference: Rect.zero, object: const Rect.fromLTWH(0, 0, 1, 1), image: const Size(10, 10)), Rect.zero);
  });
}
