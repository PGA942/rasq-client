import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/text/inline_spans.dart';
import 'package:rasq_design/rasq_design.dart';

/// MFM の描画を Misskey に合わせたことの確かめ (D-509)。
///
/// - 花の MFM アート(ユーザー指定の確かめ用、test/fixtures/mfm/rasq_mfm_samples.json の `flower`): 花びら 8 枚が顔の
///   まわりに、それぞれの回転の向きに並ぶこと(Misskey: 箱ごとの transform、position は em、絵文字 2em)。
/// - 確かめ用の MFM をすべて描いて例外が出ないこと(静止 / アニメーションの途中)。
/// - `MFM_PREVIEW_DIR` があれば、その下に PNG を書く(`<name>_static.png` / `<name>_anim.png`)。`MFM_PREVIEW_FONT`
///   (`,` 区切りの ttf)があればその書体で描く(無ければテストの既定の書体)。
void main() {
  final samples = {
    for (final c in (jsonDecode(File('test/fixtures/mfm/rasq_mfm_samples.json').readAsStringSync()) as List).cast<Map<String, dynamic>>()) c['name'] as String: c['input'] as String,
  };
  final previewDir = Platform.environment['MFM_PREVIEW_DIR'];
  final fonts = Platform.environment['MFM_PREVIEW_FONT'];
  const family = 'MfmPreview';
  final emojis = {for (final n in ['ablobblewobble', 'm_head']) n: Uri.parse('https://emoji.test/$n.png')};

  // 1 つ目の ttf を `MfmPreview`、2 つ目からを `MfmPreview1`… として読み、後ろを代わりの書体にする(英字 + 日本語)。
  // `monospace=/path.ttf` のように名前を付けたものはその名前の書体(`font.monospace` やコード)。
  final entries = fonts?.split(',') ?? const <String>[];
  final fontPaths = entries.where((p) => !p.contains('=') && File(p).existsSync()).toList();
  setUpAll(() async {
    for (final (i, path) in fontPaths.indexed) {
      final loader = FontLoader(i == 0 ? family : '$family$i')..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
      await loader.load();
    }
    for (final e in entries.where((p) => p.contains('='))) {
      final [name, path] = e.split('=');
      if (!File(path).existsSync()) continue;
      await (FontLoader(name)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())))).load();
    }
  });

  /// 正方形の仮の絵文字(花びら = 上に向きの印のある桃色、顔 = 黄色の丸顔)を画像のキャッシュに入れる。
  Future<void> seedEmoji(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final e in emojis.entries) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        const s = 64.0;
        if (e.key == 'm_head') {
          c.drawRect(const Rect.fromLTWH(0, 0, s, s), Paint()..color = const Color(0xFF8BC34A));
          c.drawCircle(const Offset(s / 2, s / 2), s * 0.42, Paint()..color = const Color(0xFFFFD54F));
          c.drawCircle(const Offset(s * 0.36, s * 0.42), 4, Paint()..color = const Color(0xFF3E2723));
          c.drawCircle(const Offset(s * 0.64, s * 0.42), 4, Paint()..color = const Color(0xFF3E2723));
          c.drawArc(const Rect.fromLTWH(s * 0.32, s * 0.45, s * 0.36, s * 0.25), 0.2, math.pi - 0.4, false, Paint()
            ..color = const Color(0xFF3E2723)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
        } else {
          c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2, s - 8, s - 4), const Radius.circular(28)), Paint()..color = const Color(0xFFF48FB1));
          c.drawPath(Path()
            ..moveTo(s / 2, 4)
            ..lineTo(s / 2 + 10, 22)
            ..lineTo(s / 2 - 10, 22)
            ..close(), Paint()..color = const Color(0xFFAD1457));
        }
        final img = await rec.endRecording().toImage(64, 64);
        final provider = RasqMediaPolicy.unrestricted.imageFor(e.value);
        final key = await provider.obtainKey(ImageConfiguration.empty);
        PaintingBinding.instance.imageCache.putIfAbsent(key, () => OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: img))));
      }
    });
  }

  const boundaryKey = ValueKey('mfm-preview');
  TextStyle bodyStyle() => RasqTypography.body.copyWith(
        fontFamily: fontPaths.isEmpty ? null : family,
        fontFamilyFallback: [for (var i = 1; i < fontPaths.length; i++) '$family$i'],
        color: const Color(0xFF1B1B1F),
      );

  Widget frame(String mfm, {required bool animate}) => MaterialApp(
        theme: RasqTheme.light(),
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: const Size(480, 900), disableAnimations: !animate),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  width: 440,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 140, 16, 140),
                  child: RasqRichText(InlineSpans.parse(mfm, emojis: emojis), style: bodyStyle()),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> capture(WidgetTester tester, String file) async {
    if (previewDir == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(previewDir).createSync(recursive: true);
      File('$previewDir/$file').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  setUp(() => RasqMfmTransform.motion.value = (enabled: true, speed: 1.0));

  testWidgets('花の MFM: 花びら 8 枚が顔のまわりに回転の向きどおりに並ぶ(静止)', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedEmoji(tester);
    await tester.pumpWidget(frame(samples['flower']!, animate: false));
    await tester.pump();
    final emojiFinder = find.byType(RasqCustomEmoji);
    expect(emojiFinder, findsNWidgets(9));
    final centers = [for (var i = 0; i < 9; i++) tester.getCenter(emojiFinder.at(i))];
    final head = centers.last;
    final petals = centers.sublist(0, 8);
    // 本文 15px × x2 = 30px が 1em。絵文字は 2em(60px)。
    const em = 30.0;
    final centroid = petals.fold(Offset.zero, (a, b) => a + b) / petals.length.toDouble();
    expect((head - centroid).distance, lessThan(0.35 * em), reason: 'head $head / centroid $centroid');
    // 花びら 8 枚(行ごとに 1 / 2 / 2 / 2 / 1)の回転(木の順)。回転 d の花びらは顔から (sin d, -cos d) の向き。
    const degs = [0, -45, 45, -90, 90, -135, 135, 180];
    for (var i = 0; i < 8; i++) {
      final d = degs[i] * math.pi / 180;
      final p = petals[i] - head;
      final expected = Offset(math.sin(d), -math.cos(d));
      final angle = math.acos(((p.dx * expected.dx + p.dy * expected.dy) / p.distance).clamp(-1.0, 1.0)) * 180 / math.pi;
      expect(angle, lessThan(25), reason: 'petal ${degs[i]}°: offset $p');
      expect(p.distance / em, inInclusiveRange(1.5, 2.7), reason: 'petal ${degs[i]}°: distance ${p.distance / em}em');
    }
    await capture(tester, 'flower_static.png');
  });

  for (final name in samples.keys) {
    testWidgets('確かめ用の MFM を描く: $name(静止 / アニメーションの途中)', (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seedEmoji(tester);
      await tester.pumpWidget(frame(samples[name]!, animate: false));
      await tester.pump();
      if (name != 'flower') await capture(tester, '${name}_static.png');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(frame(samples[name]!, animate: true));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 650));
      await capture(tester, '${name}_anim.png');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // 動き続けるティッカーを止める
    });
  }

  group('Misskey の CSS の値', () {
    test('keyframes: bounce / jump / twitch / tada / spin(left / alternate)', () {
      Offset tr(Matrix4 m) => Offset(m.storage[12], m.storage[13]);
      expect(tr(RasqMfmTransform.transformAt('bounce', const {}, 0.75 * 0.25)), const Offset(0, -16));
      final squash = RasqMfmTransform.transformAt('bounce', const {}, 0.75 * 0.75);
      expect((squash.storage[0], squash.storage[5]), (1.5, 0.75));
      expect(tr(RasqMfmTransform.transformAt('jump', const {}, 0.75 * 0.75)).dy, closeTo(-8, 1e-9));
      // twitch は 0.5s、0% = translate(7px, -2px)、ease の区間
      expect(tr(RasqMfmTransform.transformAt('twitch', const {}, 0)), const Offset(7, -2));
      expect(tr(RasqMfmTransform.transformAt('twitch', const {'speed': '5s'}, 0.25)), const Offset(-3, 1));
      // spin.speed=6s の 1.5 秒 = 90°、left は逆回り、delay の前は動かない
      final q = RasqMfmTransform.transformAt('spin', const {'speed': '6s'}, 1.5);
      expect(q.storage[1], closeTo(1, 1e-9)); // sin 90°
      expect(RasqMfmTransform.transformAt('spin', const {'speed': '6s', 'left': true}, 1.5).storage[1], closeTo(-1, 1e-9));
      expect(RasqMfmTransform.transformAt('spin', const {'delay': '2s'}, 1.0), Matrix4.identity());
      expect(RasqMfmTransform.transformAt('spin', const {'speed': '6'}, 0.375).storage[1], closeTo(1, 1e-9), reason: '"6" は無効 → 既定の 1.5s');
      // 静止(animate: false)では動く関数は単位行列、静止の変形はそのまま
      expect(RasqMfmTransform.transformAt('spin', const {}, 0.3, animate: false), Matrix4.identity());
      expect(tr(RasqMfmTransform.transformAt('position', const {'x': '1', 'y': '-1.5'}, 0, em: 30)), const Offset(30, -45));
      final sc = RasqMfmTransform.transformAt('scale', const {'x': '10', 'y': '-2'}, 0);
      expect((sc.storage[0], sc.storage[5]), (5.0, -2.0), reason: 'scale は 5 まで(Math.min)');
    });

    test('x2 / x3 / x4 の入れ子(200/400/600%、2 段目は /2+50%、3 段目からは 100%)', () {
      expect([for (final f in ['x2', 'x3', 'x4']) RasqMfmTransform.zoomOf(f, 0)], [2, 4, 6]);
      expect([for (final f in ['x2', 'x3', 'x4']) RasqMfmTransform.zoomOf(f, 1)], [1.5, 2.5, 3.5]);
      expect(RasqMfmTransform.zoomOf('x4', 2), 1);
    });

    test('fg / bg の色(validColor、既定 f00)と font / tada / parseFloat', () {
      const base = TextStyle(fontSize: 10, color: Color(0xFF123456));
      expect(RasqMfmTransform.childStyle('fg', const {'color': '0f0'}, base).color, const Color(0xFF00FF00));
      expect(RasqMfmTransform.childStyle('fg', const {'color': 'xyz'}, base).color, const Color(0xFFFF0000));
      expect(RasqMfmTransform.childStyle('fg', const {'color': 'abcde'}, base).color, base.color, reason: '5 桁は CSS で無効 → 継承');
      expect(RasqMfmTransform.childStyle('font', const {'monospace': true}, base).fontFamily, 'monospace');
      expect(RasqMfmTransform.childStyle('tada', const {}, base).fontSize, 15);
      expect(RasqMfmTransform.parseNum('1.5abc'), 1.5);
      expect(RasqMfmTransform.parseNum('abc'), isNull);
    });
  });

  group('InlineSpans(mfm.js の木 → スパン)', () {
    test('ruby: 「本文 読み」/ 最後の text が読み', () {
      final a = InlineSpans.parse(r'$[ruby 漢字 かんじ]').single as RasqTransformSpan;
      expect((a.fn, a.args['rt'], (a.children.single as RasqTextSpan).text), ('ruby', 'かんじ', '漢字'));
      final b = InlineSpans.parse(r'$[ruby $[fg.color=f00 赤] あか]').single as RasqTransformSpan;
      expect(b.args['rt'], 'あか');
      expect((b.children.single as RasqTransformSpan).fn, 'fg');
    });

    test('unixtime は秒、知らない関数と書体の無い font は `\$[name 中身]` を文字のまま', () {
      final t = InlineSpans.parse(r'$[unixtime 1700000000]').single as RasqTransformSpan;
      expect(t.args['time'], 1700000000);
      String flat(List<RasqSpan> s) => s.map((e) => e is RasqTextSpan ? e.text : '?').join();
      expect(flat(InlineSpans.parse(r'$[unknown.a=1 中身]')), r'$[unknown 中身]');
      expect(flat(InlineSpans.parse(r'$[font 中身]')), r'$[font 中身]');
    });

    test('***big*** は tada、<small> は small、silent link もリンク', () {
      expect((InlineSpans.parse('***big***').single as RasqTransformSpan).fn, 'tada');
      expect((InlineSpans.parse('<small>s</small>').single as RasqTransformSpan).fn, 'small');
      final link = InlineSpans.parse('?[ラベル](https://example.com/)').single as RasqLinkSpan;
      expect((link.text, link.url.toString()), ('ラベル', 'https://example.com/'));
    });
  });
}
