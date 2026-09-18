import 'dart:convert';
import 'dart:io';
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
import 'package:rasq_client/features/media/audio_visualizer_video.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 音声だけのファイル (D-250): 動画ボタンの「ファイルから」で選べて、加工を開くと Visualizer の動画へ変換する。
void main() {
  test('フレームの割り当て: 短い音声は 8fps、長い音声は上限の枚数に収めて 1 枚を長く', () {
    final short = audioFramePlan(const Duration(seconds: 10));
    expect(short.frames, 80);
    expect(short.each, const Duration(milliseconds: 125));
    final long = audioFramePlan(const Duration(minutes: 5));
    expect(long.frames, audioMaxFrames);
    expect(long.each.inMicroseconds * long.frames, closeTo(const Duration(minutes: 5).inMicroseconds, audioMaxFrames));
    expect(audioFramePlan(Duration.zero).frames, 8); // 長さが取れなくても 1 秒ぶん
  });

  test('バー: 区間ごとの最大値、全体の最大で正規化、空の波形は 0', () {
    final bars = audioBars([0, 0.1, -0.5, 0.25], bars: 2);
    expect(bars, [closeTo(0.2, 1e-9), 1.0]);
    expect(audioBars(const [], bars: 3), [0, 0, 0]);
    expect(audioBars([0, 0], bars: 2), [0, 0]);
  });

  testWidgets('フレームの絵: 左は黒地、右のバーは再生位置までアクセント色・その先は灰色', (tester) async {
    const accent = Color(0xFF00FF00);
    final image = await tester.runAsync(() async {
      final png = await renderAudioFramePng(bars: List.filled(audioVisualizerBars, 1.0), progress: 0.5, size: const ui.Size(640, 360), accent: accent);
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect((image!.width, image.height), (640, 360));
    final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    (int, int, int) px(double fx, double fy) {
      final o = ((fy * 360).floor() * 640 + (fx * 640).floor()) * 4;
      return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
    }

    expect(px(0.02, 0.05), (0, 0, 0)); // 左上 = 黒地
    // 右半分の中央の高さで、緑(再生済み)と灰色(これから)の両方が見つかる。
    final row = [for (var x = 0.52; x < 0.98; x += 0.002) px(x, 0.5)];
    expect(row.where((p) => p == (0, 255, 0)), isNotEmpty);
    expect(row.where((p) => p == (0x3A, 0x3F, 0x47)), isNotEmpty);
    final firstGrey = row.indexWhere((p) => p == (0x3A, 0x3F, 0x47));
    expect(row.sublist(firstGrey).where((p) => p == (0, 255, 0)), isEmpty, reason: '再生位置より先にアクセント色は無い');
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
