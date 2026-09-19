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

  test('フレームの割り当て: 既定 30fps、長い音声は上限の枚数に収まるよう fps を下げる', () {
    final short = audioFramePlan(const Duration(seconds: 10));
    expect((short.frames, short.fps), (300, 30.0));
    expect(audioFramePlan(const Duration(seconds: 10), fps: 60).frames, 600);
    final long = audioFramePlan(const Duration(minutes: 10));
    expect(long.frames, audioMaxFrames);
    expect(long.fps, closeTo(15, 0.01));
    expect(long.each.inMicroseconds * long.frames, closeTo(const Duration(minutes: 10).inMicroseconds, audioMaxFrames));
    expect(audioFramePlan(Duration.zero).frames, 30); // 長さが取れなくても 1 秒ぶん
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

  test('設定: JSON の往復、範囲外は丸める、壊れた保存値は既定', () {
    const c = AudioVisualizerConfig(fps: 24, bands: 96, style: AudioVisualizerStyle.line, background: Color(0xFF0B1020), barColor: Color(0xFFFF5C8A), showIcon: false, fine: true);
    expect(AudioVisualizerConfig.decode(jsonEncode(c.toJson())), c);
    expect(AudioVisualizerConfig.fromJson({'fps': 500, 'bands': 1}).fps, 60);
    expect(AudioVisualizerConfig.fromJson({'fps': 500, 'bands': 1}).bands, 16);
    expect(AudioVisualizerConfig.decode('{broken'), const AudioVisualizerConfig());
    expect(const AudioVisualizerConfig().paintSize, const ui.Size(1280, 720));
  });

  testWidgets('フレームの絵: 背景色、バーは設定の色、中央のシークバーは再生位置まで色が付く', (tester) async {
    const config = AudioVisualizerConfig(barColor: Color(0xFF00FF00), background: Color(0xFF000010), showIcon: false);
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

  testWidgets('設定 FOW: 値を変えるとプレビューが描き直され、決定で設定が返る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final manager = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OverlayHost(manager: manager, child: const SizedBox.expand()))));
    final pcm = AudioPcm.parseWav(sineWav(hz: 440));
    final future = showAudioVisualizerFow(manager, initial: const AudioVisualizerConfig(), pcm: pcm, position: const Duration(milliseconds: 500), title: 'a.m4a');
    await tester.pumpAndSettle();
    expect(find.byKey(audioVisualizerPreviewKey), findsOneWidget);
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('viz.style.line')), 60, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('viz.style.line')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('viz.icon')), 80, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('viz.icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    final c = (await future)!;
    expect((c.style, c.showIcon, c.fps), (AudioVisualizerStyle.line, false, 30));
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
