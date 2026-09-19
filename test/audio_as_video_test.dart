import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/compose/media_file_pick.dart';
import 'package:rasq_client/features/media/audio_visualizer_fow.dart';
import 'package:rasq_client/features/media/audio_visualizer_video.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 音声だけのファイル (D-250): 動画ボタンの「ファイルから」で選べて、加工を開くと Visualizer の動画へ変換する。
void main() {
  /// 16bit の WAV(正弦波)。
  Uint8List sineWav({required double hz, int rate = 48000, int channels = 2, double seconds = 1, double gain = 0.8}) {
    final n = (rate * seconds).round();
    final data = ByteData(44 + n * channels * 2);
    void tag(int o, String t) {
      for (var i = 0; i < 4; i++) {
        data.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    data.setUint32(4, 36 + n * channels * 2, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    data.setUint32(40, n * channels * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (math.sin(2 * math.pi * hz * i / rate) * gain * 32767).round();
      for (var c = 0; c < channels; c++) {
        data.setInt16(44 + (i * channels + c) * 2, v, Endian.little);
      }
    }
    return data.buffer.asUint8List();
  }

  test('フレームの割り当て: 既定 25fps、長い音声は上限の枚数に収まるよう fps を下げる', () {
    final short = audioFramePlan(const Duration(seconds: 10));
    expect((short.frames, short.fps), (250, 25.0));
    expect(const AudioVisualizerConfig().fps, 25);
    expect(audioFramePlan(const Duration(seconds: 10), fps: 60).frames, 600);
    final long = audioFramePlan(const Duration(minutes: 10));
    expect(long.frames, audioMaxFrames);
    expect(long.fps, closeTo(12.5, 0.01));
    expect(long.each.inMicroseconds * long.frames, closeTo(const Duration(minutes: 10).inMicroseconds, audioMaxFrames));
    expect(audioFramePlan(Duration.zero).frames, 25); // 長さが取れなくても 1 秒ぶん
  });

  test('フェードと背景のループ (D-253): 先頭 / 末尾で明るさが 0 → 1 → 0、背景の時刻は動画の長さで折り返す', () {
    const c = AudioVisualizerConfig(fadeIn: 2, fadeOut: 4);
    const total = Duration(seconds: 60);
    expect(audioFadeAt(Duration.zero, total, c), 0);
    expect(audioFadeAt(const Duration(seconds: 1), total, c), closeTo(0.5, 1e-9));
    expect(audioFadeAt(const Duration(seconds: 30), total, c), 1);
    expect(audioFadeAt(const Duration(seconds: 58), total, c), closeTo(0.5, 1e-9));
    expect(audioFadeAt(total, total, c), 0);
    expect(audioFadeAt(Duration.zero, total, const AudioVisualizerConfig()), 1); // 既定はフェードなし
    expect(audioBackgroundTimeAt(const Duration(seconds: 25), const Duration(seconds: 10)), const Duration(seconds: 5));
    expect(audioBackgroundTimeAt(const Duration(seconds: 3), const Duration(seconds: 10)), const Duration(seconds: 3));
    expect(audioBackgroundTimeAt(const Duration(seconds: 3), Duration.zero), Duration.zero);
  });

  test('WAV: ステレオ 48kHz → モノラル 24kHz、長さはそのまま。WAV でなければ FormatException', () {
    final pcm = AudioPcm.parseWav(sineWav(hz: 440));
    expect(pcm.sampleRate, 24000);
    expect(pcm.samples.length, 24000);
    expect(pcm.duration, const Duration(seconds: 1));
    expect(pcm.samples.reduce(math.max), greaterThan(20000));
    expect(() => AudioPcm.parseWav(Uint8List.fromList(List.filled(64, 0))), throwsFormatException);
  });

  test('スペクトル: 左から右に 低音 → 高音(440Hz の山は 4kHz の山より左)、無音は 0、前のフレームからはゆっくり下がる', () {
    int peak(List<double> s) => s.indexOf(s.reduce(math.max));
    final low = spectrumAt(AudioPcm.parseWav(sineWav(hz: 440)), const Duration(milliseconds: 500));
    final high = spectrumAt(AudioPcm.parseWav(sineWav(hz: 4000)), const Duration(milliseconds: 500));
    expect(low.length, 64);
    expect(peak(low), lessThan(peak(high)));
    expect(low[peak(low)], greaterThan(0.8));
    expect(low.last, lessThan(0.3)); // 高音の端は静か
    final silent = AudioPcm(samples: Int16List(24000), sampleRate: 24000);
    expect(spectrumAt(silent, const Duration(milliseconds: 500)).every((v) => v == 0), isTrue);
    final falling = spectrumAt(silent, const Duration(milliseconds: 500), previous: low);
    expect(falling[peak(low)], closeTo(low[peak(low)] * 0.82, 1e-9));
  });

  test('設定: JSON の往復(タイトル / 説明は保存しない)、範囲外は丸める、旧形の showIcon を引き継ぐ、壊れた保存値は既定', () {
    const c = AudioVisualizerConfig(fps: 24, bands: 96, style: AudioVisualizerStyle.line, background: Color(0xFF0B1020), barColor: Color(0xFFFF5C8A), left: AudioVisualizerLeft.file, leftImagePath: '/x/left.png', textPosition: AudioVisualizerTextPosition.above, textColor: Color(0xFFFFD54F), textScale: 1.4, backgroundVideoPath: '/x/bg.mp4', backgroundDim: 0.5, fadeIn: 1.5, fadeOut: 3, fine: true);
    expect(AudioVisualizerConfig.decode(jsonEncode(c.toJson())), c);
    final withText = c.copyWith(title: '曲名', description: '説明');
    expect(withText.toJson().containsKey('title'), isFalse);
    expect(AudioVisualizerConfig.decode(jsonEncode(withText.toJson())).title, isNull);
    expect(withText == c, isFalse); // 同じ設定でも文字が違えば書き出し直す
    expect(AudioVisualizerConfig.fromJson({'fps': 500, 'bands': 1, 'textScale': 9, 'fadeIn': 99, 'backgroundDim': 2}).toJson(), containsPair('fps', 60));
    final clamped = AudioVisualizerConfig.fromJson({'fps': 500, 'bands': 1, 'textScale': 9, 'fadeIn': 99, 'backgroundDim': 2});
    expect((clamped.bands, clamped.textScale, clamped.fadeIn, clamped.backgroundDim), (16, 2.0, 5.0, 0.8));
    expect(AudioVisualizerConfig.fromJson({'showIcon': false}).left, AudioVisualizerLeft.none);
    expect(const AudioVisualizerConfig().left, AudioVisualizerLeft.avatar);
    expect(c.copyWith(clearBackgroundVideo: true).backgroundVideoPath, isNull);
    expect(AudioVisualizerConfig.decode('{broken'), const AudioVisualizerConfig());
    expect(const AudioVisualizerConfig().paintSize, const ui.Size(1280, 720));
  });

  testWidgets('フレームの絵: 背景色、バーは設定の色、中央のシークバーは再生位置まで色が付く', (tester) async {
    const config = AudioVisualizerConfig(barColor: Color(0xFF00FF00), background: Color(0xFF000010), left: AudioVisualizerLeft.none);
    final image = await tester.runAsync(() async {
      final png = await renderAudioFramePng(spectrum: List.filled(64, 0.8), progress: 0.5, size: const ui.Size(640, 360), config: config);
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect((image!.width, image.height), (640, 360));
    final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    (int, int, int) px(double fx, double fy) {
      final o = ((fy * 360).floor() * 640 + (fx * 640).floor()) * 4;
      return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
    }

    expect(px(0.01, 0.02), (0, 0, 0x10)); // 背景色
    // バー(上半分の高さ 0.3 の行)に設定の色がある。
    expect([for (var x = 0.1; x < 0.9; x += 0.002) px(x, 0.3)].where((p) => p == (0, 255, 0)), isNotEmpty);
    // シークバー(中央の高さ): 左(再生済み)は色つき、右はまだ。
    expect(px(0.25, 0.5), (0, 255, 0));
    expect(px(0.75, 0.5), isNot((0, 255, 0)));
  });

  testWidgets('フレームの絵 (D-253): 背景の動画のコマ + 暗さ、左の絵、フェードで全体が暗くなる', (tester) async {
    Future<ui.Image> solid(Color c) async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = c);
      return rec.endRecording().toImage(8, 8);
    }

    Future<ByteData> render(AudioVisualizerConfig config, {ui.Image? bg, ui.Image? left, double fade = 1}) async {
      final png = await renderAudioFramePng(spectrum: List.filled(32, 0.1), progress: 0.2, size: const ui.Size(640, 360), config: config, background: bg, leftImage: left, fade: fade);
      final codec = await ui.instantiateImageCodec(png);
      return (await (await codec.getNextFrame()).image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    }

    (int, int, int) px(ByteData d, double fx, double fy) {
      final o = ((fy * 360).floor() * 640 + (fx * 640).floor()) * 4;
      return (d.getUint8(o), d.getUint8(o + 1), d.getUint8(o + 2));
    }

    await tester.runAsync(() async {
      final red = await solid(const Color(0xFFFF0000)), blue = await solid(const Color(0xFF0000FF));
      // 背景の動画(赤)に暗さ 50% → 隅は暗い赤。左の絵(青)は左の列の中央に出る。
      final d = await render(const AudioVisualizerConfig(left: AudioVisualizerLeft.file, backgroundDim: 0.5, showTitle: false), bg: red, left: blue);
      final corner = px(d, 0.01, 0.02);
      expect(corner.$1, inInclusiveRange(120, 135));
      expect((corner.$2, corner.$3), (0, 0));
      expect(px(d, 0.17, 0.5), (0, 0, 255));
      // フェード 0 = 真っ黒。
      final black = await render(const AudioVisualizerConfig(left: AudioVisualizerLeft.none), bg: red, fade: 0);
      expect(px(black, 0.5, 0.5), (0, 0, 0));
      expect(px(black, 0.01, 0.02), (0, 0, 0));
    });
  });

  testWidgets('設定 FOW: 値を変えるとプレビューが描き直され、決定で設定が返る(左の絵 / 文字 / 背景の動画 / フェード、D-253)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final manager = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OverlayHost(manager: manager, child: const SizedBox.expand()))));
    final pcm = AudioPcm.parseWav(sineWav(hz: 440));
    final future = showAudioVisualizerFow(manager, initial: const AudioVisualizerConfig(), pcm: pcm, position: const Duration(milliseconds: 500), title: 'a.m4a', host: AudioVisualizerFowHost(pickVideo: () async => '/keep/bg_1.mp4', pickImage: () async => '/keep/left_1.png'));
    await tester.pumpAndSettle();
    expect(find.byKey(audioVisualizerPreviewKey), findsOneWidget);
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    Future<void> tapKey(String key) async {
      await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 80, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await tapKey('viz.style.line');
    await tapKey('viz.left.file');
    await tapKey('viz.left.pick');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('viz.description.text')), 80, scrollable: list);
    await tester.enterText(find.byKey(const ValueKey('viz.title.text')), '曲名');
    await tester.enterText(find.byKey(const ValueKey('viz.description.text')), 'アルバムより');
    await tester.pumpAndSettle();
    await tapKey('viz.text.above');
    await tapKey('viz.bgvideo.pick');
    expect(find.byKey(const ValueKey('viz.bgvideo.dim')), findsOneWidget); // 選ぶと暗さの項目が出る
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    final c = (await future)!;
    expect((c.style, c.left, c.leftImagePath, c.fps), (AudioVisualizerStyle.line, AudioVisualizerLeft.file, '/keep/left_1.png', 25));
    expect((c.title, c.description, c.textPosition, c.backgroundVideoPath), ('曲名', 'アルバムより', AudioVisualizerTextPosition.above, '/keep/bg_1.mp4'));
  });

  test('MIME: 端末が返した動画 / 音声の型を優先、無ければ拡張子、どちらでもなければ null', () {
    expect(mediaMimeFor('a.MP3'), 'audio/mpeg');
    expect(mediaMimeFor('voice.m4a'), 'audio/mp4');
    expect(mediaMimeFor('clip.mov'), 'video/quicktime');
    expect(mediaMimeFor('x.bin', reported: 'audio/x-custom'), 'audio/x-custom');
    expect(mediaMimeFor('a.mp3', reported: 'application/octet-stream'), 'audio/mpeg');
    expect(mediaMimeFor('memo.txt'), isNull);
  });

  testWidgets('コンポーザー: 動画ボタン →「ファイルから」で音声が添付になる。加工を開くと、この端末(テスト = Linux)では変換できない旨を出す', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // 本物のファイル(XFile.fromData は io では名前を持てない)。
    final dir = Directory.systemTemp.createTempSync('rasq-d250');
    addTearDown(() => dir.deleteSync(recursive: true));
    final audio = File('${dir.path}/voice memo.m4a')..writeAsBytesSync([1, 2, 3]);
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 19), body: 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        mediaFilePickerProvider.overrideWithValue(() async => XFile(audio.path)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('動画 / 音声'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ファイルから(動画 / 音声)'));
    await tester.pumpAndSettle(); // ドロップダウンが閉じて選択が返る → ファイルの読み込み(本物の I/O)
    // 読み込みは何段かの本物の I/O(段ごとに 本物の待ち → フレーム を回す)。
    for (var i = 0; i < 10 && find.byIcon(Icons.graphic_eq).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.text('voice memo.m4a'), findsOneWidget);

    // 加工画面: 音声は動画のエディター(構成も動画のバー)で開く。テスト環境は変換に対応しない。
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: Uint8List.fromList([1, 2, 3]), name: 'voice memo.m4a', mimeType: 'audio/mp4'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.textContaining('この端末では音声を動画にできません'), findsOneWidget);
  });
}
