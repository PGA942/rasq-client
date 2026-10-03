import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/features/onboarding/discover_image_crop.dart';

/// 「囲って検索」(D-418) の囲みの幾何と、端末での切り抜き(合成した画像で確かめる)。
void main() {
  /// 左半分が赤、右半分が青の画像。
  img.Image halves(int w, int h) {
    final im = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (x < w ~/ 2) {
          im.setPixelRgb(x, y, 230, 20, 20);
        } else {
          im.setPixelRgb(x, y, 20, 20, 230);
        }
      }
    }
    return im;
  }

  Uint8List png(int w, int h) => img.encodePng(halves(w, h));

  group('囲みの幾何', () {
    test('四角: ドラッグの向きによらず外接の四角。整数の画素に外向きに丸め、画像に収める', () {
      const size = Size(200, 100);
      final s = DiscoverSelection.rect(const Offset(150.7, 80.9), const Offset(50.4, 20.2));
      expect(discoverSelectionBounds(s, size), const Rect.fromLTRB(50, 20, 151, 81));
      final out = DiscoverSelection.rect(const Offset(-30, -10), const Offset(80, 300));
      expect(discoverSelectionBounds(out, size), const Rect.fromLTRB(0, 0, 80, 100));
      expect(discoverSelectionBounds(DiscoverSelection.rect(const Offset(300, 10), const Offset(400, 50)), size), isNull, reason: '画像の外');
    });

    test('輪: 点の外接の四角。四角の頂点は 4 隅', () {
      final s = DiscoverSelection.lasso(const [Offset(100, 10), Offset(140, 50), Offset(100, 90), Offset(60, 50)]);
      expect(discoverSelectionBounds(s, const Size(200, 100)), const Rect.fromLTRB(60, 10, 140, 90));
      expect(DiscoverSelection.rect(const Offset(1, 2), const Offset(3, 4)).polygon, const [Offset(1, 2), Offset(3, 2), Offset(3, 4), Offset(1, 4)]);
    });

    test('小さすぎる囲み(タップ)・点の足りない輪は使わない', () {
      const size = Size(200, 100);
      expect(DiscoverSelection.rect(const Offset(10, 10), const Offset(12, 40)).usable(size), isFalse);
      expect(DiscoverSelection.rect(const Offset(10, 10), const Offset(40, 40)).usable(size), isTrue);
      expect(DiscoverSelection.lasso(const [Offset(10, 10), Offset(60, 60)]).usable(size), isFalse);
    });

    test('縮めた大きさ: 長辺 1600 まで、縦横比を保つ', () {
      expect(discoverScaledSize(4000, 1000), (1600, 400));
      expect(discoverScaledSize(1000, 3200), (500, 1600));
      expect(discoverScaledSize(800, 600), (800, 600));
    });

    test('画像の大きさはヘッダから', () {
      expect(discoverImageSizeOf(png(37, 21)), const Size(37, 21));
      expect(discoverImageSizeOf(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('切り抜き', () {
    test('囲まなければ画像全体(JPEG)', () {
      final out = img.decodeJpg(prepareDiscoverImage(png(200, 100), null)!)!;
      expect((out.width, out.height), (200, 100));
    });

    test('四角: 外接の四角で切り抜く(右下の青だけ)', () {
      final out = img.decodeJpg(prepareDiscoverImage(png(200, 100), DiscoverSelection.rect(const Offset(120, 30), const Offset(180, 90)))!)!;
      expect((out.width, out.height), (60, 60));
      final p = out.getPixel(30, 30);
      expect(p.b, greaterThan(180));
      expect(p.r, lessThan(70));
    });

    test('四角が左右の境をまたぐ: 左は赤・右は青のまま', () {
      final out = img.decodeJpg(prepareDiscoverImage(png(200, 100), DiscoverSelection.rect(const Offset(50, 20), const Offset(150, 80)))!)!;
      expect((out.width, out.height), (100, 60));
      expect(out.getPixel(10, 30).r, greaterThan(180));
      expect(out.getPixel(90, 30).b, greaterThan(180));
    });

    test('輪: 外接の四角で切り抜き、輪の外は中間の灰色・中はそのまま', () {
      final diamond = DiscoverSelection.lasso(const [Offset(100, 10), Offset(140, 50), Offset(100, 90), Offset(60, 50)]);
      final out = img.decodeJpg(prepareDiscoverImage(png(200, 100), diamond)!)!;
      expect((out.width, out.height), (80, 80));
      for (final (x, y) in [(2, 2), (77, 2), (2, 77), (77, 77)]) {
        final p = out.getPixel(x, y);
        expect(p.r, closeTo(discoverMaskGray, 10), reason: '角 ($x, $y) は輪の外');
        expect(p.b, closeTo(discoverMaskGray, 10));
      }
      expect(out.getPixel(25, 40).r, greaterThan(180), reason: '中の左は赤');
      expect(out.getPixel(55, 40).b, greaterThan(180), reason: '中の右は青');
    });

    test('大きな画像は長辺 1600 まで縮める。輪の外の塗りも縮めた座標で合う', () {
      final big = png(4000, 1000);
      final whole = img.decodeJpg(prepareDiscoverImage(big, null)!)!;
      expect((whole.width, whole.height), (1600, 400));
      final tri = DiscoverSelection.lasso(const [Offset(0, 0), Offset(3200, 0), Offset(0, 1000)]);
      final out = img.decodeJpg(prepareDiscoverImage(big, tri)!)!;
      expect((out.width, out.height), (1600, 500));
      expect(out.getPixel(1590, 490).g, closeTo(discoverMaskGray, 10), reason: '斜辺の外');
      expect(out.getPixel(10, 10).r, greaterThan(180), reason: '中の左上は赤');
    });

    test('透過の PNG は白の上に重ねる / 読めない画像は null', () {
      final im = img.Image(width: 10, height: 10, numChannels: 4);
      final out = img.decodeJpg(prepareDiscoverImage(img.encodePng(im), null)!)!;
      expect(out.getPixel(5, 5).r, greaterThan(240));
      expect(prepareDiscoverImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]), null), isNull);
    });

    test('EXIF の向き(90 度)を直してから囲みの座標で切る', () {
      final raw = halves(200, 100)..exif.imageIfd.orientation = 6;
      final jpg = img.encodeJpg(raw, quality: 95);
      expect(discoverImageSizeOf(jpg), const Size(100, 200), reason: '表示は縦長');
      final out = img.decodeJpg(prepareDiscoverImage(jpg, DiscoverSelection.rect(const Offset(0, 0), const Offset(100, 100)))!)!;
      expect((out.width, out.height), (100, 100));
    });
  });
}
