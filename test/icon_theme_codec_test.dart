import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/features/theme/icon_theme/icon_theme_codec.dart';

/// アイコンに埋め込むテーマのコーデック (D-561)。仮組み(theme_mock_icon_embed.html の JS)と同じ入出力か、再圧縮 / リサイズで
/// 読み戻せるか。基準の値は test/fixtures/icon_theme/gen_js_vectors.js(仮組みの Codec を node で動かす)で作った。
void main() {
  final js = jsonDecode(File('test/fixtures/icon_theme/js_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  const theme = IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 68], text: [255, 255, 255], accent: [0, 204, 255], particle: 3, amount: 10, speed: 5, hint: 5);
  List<IconThemeCmd> poly(int n, double ro, double ri) => [
        for (var i = 0; i < n * 2; i++)
          () {
            final a = -math.pi / 2 + i * math.pi / n, r = i.isOdd ? ri : ro;
            return IconThemeCmd(i == 0 ? 'M' : 'L', [(16 + math.cos(a) * r + 0.5).floor(), (16 + math.sin(a) * r + 0.5).floor()]);
          }(),
        const IconThemeCmd('Z'),
      ];
  final ext = IconThemeExt(
    shapes: [
      poly(5, 14, 6),
      const [IconThemeCmd('M', [16, 29]), IconThemeCmd('Q', [1, 17, 4, 9]), IconThemeCmd('Q', [7, 2, 16, 9]), IconThemeCmd('Q', [25, 2, 28, 9]), IconThemeCmd('Q', [31, 17, 16, 29]), IconThemeCmd('Z')],
    ],
    paths: const [
      [16, 0, 16, 16, 16, 31],
      [16, 31, 7, 16, 20, 0],
    ],
    angle: 6,
    anim: 1,
    animSpeed: 3,
    slots: const [
      IconThemeSlot(trigger: IconThemeTrigger.always, shape: 0, path: 0, rand: 15, angleRand: 1, easeA: 0, easeB: 1, mix: 2, sway: 2, spin: 3),
      IconThemeSlot(trigger: IconThemeTrigger.tap, shape: 1, path: 1, rand: 6, angleRand: 8, easeA: 2, easeB: 1, mix: 3, sway: 4, spin: 1),
    ],
  );
  const url = IconThemeExt.url('plugins.example.social/t/starfall');

  Uint8List source() {
    final d = Uint8List(iconThemeSize * iconThemeSize * 4);
    for (var y = 0; y < iconThemeSize; y++) {
      for (var x = 0; x < iconThemeSize; x++) {
        final i = (y * iconThemeSize + x) * 4;
        d[i] = (x * 255 / 399 + 0.5).floor();
        d[i + 1] = (y * 255 / 399 + 0.5).floor();
        d[i + 2] = ((x + y) * 127 / 399 + 0.5).floor();
        d[i + 3] = 255;
      }
    }
    return d;
  }

  group('仮組みの JS と同じ', () {
    test('ブロックの並び', () {
      final l = IconThemeLayout.instance, j = js['layout'] as Map<String, dynamic>;
      expect([l.palCal.length, l.palData.length, l.extCal.length, l.extData.length, l.extBytes, l.extK], [j['palCal'], j['palData'], j['extCal'], j['extData'], j['extBytes'], j['extK']]);
      expect([for (final (b, ref) in l.palCal) [b.$1, b.$2, ref]], j['palCalBlocks']);
      expect([for (final b in l.palData.take(8)) [b.$1, b.$2]], j['palDataFirst']);
      expect([for (final b in l.extData.take(8)) [b.$1, b.$2]], j['extDataFirst']);
    });

    test('DSL のシンボルと文・飾り枠の 4 段の色', () {
      expect(iconThemeToSymbols(theme), js['symbols']);
      expect(iconThemeSymbolsToText(iconThemeToSymbols(theme)), js['text']);
      expect(iconThemeRamp(theme.accent), js['ramp']);
      expect(iconThemeRamp(theme.bg, mono: true), js['rampMono']);
    });

    for (final (name, e) in [('plain', null), ('ext', ext), ('url', url)]) {
      test('書き込んだ画素が一致する($name)。読み戻しも同じ', () {
        final want = js[name] as Map<String, dynamic>;
        final d = source();
        final info = iconThemeEncode(d, theme, ext: e, ramp: iconThemeRamp(theme.accent));
        final wi = want['info'] as Map<String, dynamic>;
        expect([info.text, info.palBlocks, info.extBlocks, info.extUsed, info.extCapacity], [wi['text'], wi['palBlocks'], wi['extBlocks'], wi['extUsed'], wi['extCapacity']]);
        for (final p in (want['px'] as List).cast<List<dynamic>>()) {
          final x = p[0] as int, y = p[1] as int, i = (y * iconThemeSize + x) * 4;
          expect([x, y, d[i], d[i + 1], d[i + 2]], p);
        }
        expect(sha256.convert(d).toString(), want['sha256'], reason: 'RGBA の全画素が仮組みと同じ');
        final r = iconThemeDecode(d, iconThemeSize, iconThemeSize);
        final wd = want['decoded'] as Map<String, dynamic>;
        expect(r.ok, wd['ok']);
        expect(r.text, wd['text']);
        expect(r.palCorrected, wd['palCorrected']);
        expect(r.theme, theme);
        expect(r.ext != null, (wd['ext'] as Map)['ok']);
        if (e != null) expect(r.ext, e);

        // 壊したブロック(パレット 4 / 拡張 20)も、仮組みと同じ数を直して読める。
        final c = Uint8List.fromList(d);
        void fill((int, int) b, List<int> col) {
          for (var y = b.$2 * 8; y < b.$2 * 8 + 8; y++) {
            for (var x = b.$1 * 8; x < b.$1 * 8 + 8; x++) {
              final i = (y * iconThemeSize + x) * 4;
              c.setRange(i, i + 3, col);
            }
          }
        }

        for (final k in [0, 7, 15, 22]) {
          fill(IconThemeLayout.instance.palData[k], const [236, 236, 20]);
        }
        if (e != null) {
          for (var k = 0; k < 40; k += 2) {
            fill(IconThemeLayout.instance.extData[k], iconThemeRamp(theme.accent)[0]);
          }
        }
        final rc = iconThemeDecode(c, iconThemeSize, iconThemeSize), wc = want['corrupted'] as Map<String, dynamic>;
        expect([rc.ok, rc.text, rc.palCorrected], [wc['ok'], wc['text'], wc['palCorrected']]);
        expect(rc.ext != null, (wc['ext'] as Map)['ok']);
        if (e != null) expect(rc.extCorrected, (wc['ext'] as Map)['corrected']);
      });
    }
  });

  group('SNS の再圧縮 / リサイズのあとで読み戻せる', () {
    // 写真らしい元: なめらかな色 + 細かい模様(JPEG の劣化が出やすい)。
    Uint8List photo() {
      final d = source();
      final rnd = math.Random(7);
      for (var i = 0; i < d.length; i += 4) {
        final n = rnd.nextInt(40) - 20;
        for (var k = 0; k < 3; k++) {
          d[i + k] = (d[i + k] + n).clamp(0, 255);
        }
      }
      return d;
    }

    IconThemeDecoded roundTrip(Uint8List d, {required int quality, required int size}) {
      final im = img.Image.fromBytes(width: iconThemeSize, height: iconThemeSize, bytes: d.buffer, numChannels: 4);
      final resized = size == iconThemeSize ? im : img.copyResize(im, width: size, height: size, interpolation: img.Interpolation.average);
      final back = img.decodeJpg(img.encodeJpg(resized, quality: quality))!;
      final rgba = back.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      return iconThemeDecode(rgba, back.width, back.height);
    }

    // 128px は JPEG 品質 60 から(それより下は、4:2:0 の色の間引きで 2.56px のブロックの色が隣と混ざり、31 個中 11 個ほどが
    // 候補の外へ寄る。書き込みの形の限界)。144px なら品質 40 でも読める。アプリは縮めた見本ではなく元のアイコンから読む。
    for (final quality in [85, 75, 60, 50, 40]) {
      for (final size in [512, 400, 300, 256, 200, 144, 128]) {
        if (size == 128 && quality < 60) continue;
        test('JPEG 品質 $quality・$size px: 基本テーマ${size >= 256 ? 'と拡張領域' : ''}', () {
          final d = photo();
          iconThemeEncode(d, theme, ext: ext);
          final r = roundTrip(d, quality: quality, size: size);
          expect(r.ok, isTrue, reason: '${r.error}');
          expect(r.theme, theme);
          expect(r.theme!.hints!.roundedFrame, isTrue);
          expect(r.theme!.hints!.verticalMedia, isFalse);
          expect(r.theme!.hints!.packMedia, isTrue);
          // 拡張領域は 2 ビット / ブロック。256px より小さいとブロックが 5px 未満になり、読めないことがある(そのときは基本テーマだけ)。
          if (size >= 256) expect(r.ext, ext, reason: '拡張領域');
        });
      }
    }

    test('限界の外(128px・JPEG 品質 40 / 50)は、違うテーマを出さずに「読めない」', () {
      for (final quality in [40, 50]) {
        final d = photo();
        iconThemeEncode(d, theme, ext: ext);
        final r = roundTrip(d, quality: quality, size: 128);
        expect(r.ok == false || r.theme == theme, isTrue, reason: '品質 $quality');
      }
    });

    test('配信 URL の拡張も読み戻せる(JPEG 品質 60・300px)', () {
      final d = photo();
      iconThemeEncode(d, theme, ext: url);
      expect(roundTrip(d, quality: 60, size: 300).ext?.url, 'plugins.example.social/t/starfall');
    });

    test('ふつうの画像からは何も読まない', () {
      final r = iconThemeDecode(photo(), iconThemeSize, iconThemeSize);
      expect(r.ok, isFalse);
      expect(r.theme, isNull);
      expect(iconThemeDecode(Uint8List(16 * 16 * 4), 16, 16).ok, isFalse);
    });

    test('容量を超える拡張は書かない', () {
      expect(() => iconThemePackExt(IconThemeExt.url('x' * 80)), throwsA(isA<IconThemeCapacityError>()));
    });
  });
}
