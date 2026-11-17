import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/features/profile/header_hint/header_hint_codec.dart';
import 'package:rasq_client/features/profile/header_hint/header_hint_reader.dart';

/// ヘッダーの手がかり (D-591): 上の縁の 1 段に RASQ のハンドルを書き、縮めて再圧縮しても読み戻せる。
void main() {
  const key = 'misskey:example.test:bob';

  /// 写真らしいヘッダー(空のグラデーション + ざらつき + 上の縁にも模様)。
  img.Image photo({int w = 1500, int h = 500, int seed = 1}) {
    final rnd = math.Random(seed);
    final im = img.Image(width: w, height: h, numChannels: 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final t = y / h, s = x / w;
        final n = rnd.nextInt(30) - 15;
        final wave = (40 * math.sin(x / 37 + y / 23)).round();
        im.setPixelRgb(x, y, (90 + 120 * s + n + wave).clamp(0, 255), (140 + 60 * t + n).clamp(0, 255), (200 - 80 * t + n - wave).clamp(0, 255));
      }
    }
    return im;
  }

  Uint8List jpg(img.Image im) => Uint8List.fromList(img.encodeJpg(im, quality: 92));

  /// SNS に上げて戻ってきたもの(縮める → JPEG、色差は 4:2:0)。
  Uint8List served(Uint8List written, int width, int quality) {
    final im = img.decodeImage(written)!;
    final resized = width == im.width ? im : img.copyResize(im, width: width, height: width ~/ 3, interpolation: img.Interpolation.average);
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality, chroma: img.JpegChroma.yuv420));
  }

  group('中身', () {
    test('ハンドルを詰めて戻す(1 字 / 3 字 / 32 字、数字と _、大文字は小文字に)', () {
      for (final h in ['a', 'bob', 'Taro_99', 'abcdefghijklmnopqrstuvwxyz012345']) {
        final hint = headerHintUnpack(headerHintPack(h, key))!;
        expect(hint.handle, h.toLowerCase());
        expect(hint.writtenFor(key), isTrue);
        expect(hint.writtenFor('KEY:Example.test:BOB'.replaceFirst('KEY', 'misskey')), isTrue, reason: '大小文字は区別しない');
        expect(hint.writtenFor('misskey:example.test:alice'), isFalse);
      }
    });

    test('書けないハンドルは断る', () {
      expect(headerHintCanEmbed('ok_name'), isTrue);
      for (final h in ['', 'with-dash', 'dot.name', 'ひらがな', 'a' * 33]) {
        expect(headerHintCanEmbed(h), isFalse, reason: h);
        expect(() => headerHintPack(h, key), throwsA(isA<HeaderHintHandleError>()));
      }
    });

    test('印が違う / 詰め物の後ろに字がある → 読まない', () {
      final b = headerHintPack('bob', key);
      expect(headerHintUnpack([0, ...b.skip(1)]), isNull);
      final tail = [...b]..[_last] = 1;
      expect(headerHintUnpack(tail), isNull);
    });
  });

  group('画像', () {
    test('書いたまま読み戻す(帯は上の縁の 1/48 だけ、下は元のまま)', () {
      final written = headerHintWriteImage(HeaderHintWriteJob(source: jpg(photo()), handle: 'Taro_99', accountKey: key))!;
      final im = img.decodeImage(written)!;
      expect((im.width, im.height), (headerHintWidth, headerHintHeight));
      final hint = decodeHeaderHintBytes(written)!;
      expect((hint.handle, hint.writtenFor(key)), ('taro_99', true));
    });

    test('縮めて再圧縮しても読める(1000 / 750 / 600 幅、JPEG 60〜85)', () {
      for (final (seed, handle) in [(1, 'bob'), (2, 'abcdefghijklmnopqrstuvwxyz012345'), (3, 'x_y_z')]) {
        final written = headerHintWriteImage(HeaderHintWriteJob(source: jpg(photo(seed: seed)), handle: handle, accountKey: key))!;
        for (final (w, q) in [(1440, 85), (1000, 80), (750, 70), (600, 70), (600, 60)]) {
          final hint = decodeHeaderHintBytes(served(written, w, q));
          expect(hint?.handle, handle, reason: 'seed $seed / ${w}px / q$q');
          printOnFailure('$hint');
        }
      }
    });

    test('3:1 でない画像は真ん中で切ってから書く', () {
      final tall = jpg(photo(w: 1200, h: 800));
      final written = headerHintWriteImage(HeaderHintWriteJob(source: tall, handle: 'bob', accountKey: key))!;
      final im = img.decodeImage(written)!;
      expect(im.width / im.height, closeTo(3, 0.01));
      expect(decodeHeaderHintBytes(written)?.handle, 'bob');
    });

    test('ふつうのヘッダー / 無地 / 横長すぎ・縦長は読まない', () {
      for (var seed = 1; seed <= 5; seed++) {
        expect(decodeHeaderHintBytes(jpg(photo(seed: seed))), isNull);
      }
      expect(decodeHeaderHintBytes(jpg(img.Image(width: 1500, height: 500)..clear(img.ColorRgb8(255, 255, 255)))), isNull);
      // 縦横の比が 3:1 から外れたもの(書いたものを横に伸ばした)。
      final written = img.decodeImage(headerHintWriteImage(HeaderHintWriteJob(source: jpg(photo()), handle: 'bob', accountKey: key))!)!;
      expect(decodeHeaderHintBytes(jpg(img.copyResize(written, width: 2000, height: 480))), isNull);
      expect(decodeHeaderHintBytes(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('手がかりを消すと読めなくなる(大きさは変えない)', () {
      final written = served(headerHintWriteImage(HeaderHintWriteJob(source: jpg(photo()), handle: 'bob', accountKey: key))!, 1000, 80);
      expect(decodeHeaderHintBytes(written), isNotNull);
      final erased = headerHintEraseImage(written)!;
      final im = img.decodeImage(erased)!;
      expect((im.width, im.height), (1000, 333));
      expect(decodeHeaderHintBytes(erased), isNull);
    });
  });
}

const _last = 23;
