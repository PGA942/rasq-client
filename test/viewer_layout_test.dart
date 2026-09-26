import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-326: 全画面ビューワー — 下側 FOW(下側中央)の伸び縮みにメディアが逆サイドへ追従 / 下向きスワイプで閉じる /
/// 音声の添付は音符の面 + 再生の操作(開くと自動再生)。
void main() {
  Future<(ProviderContainer, Post)> open(WidgetTester tester, {required List<MediaItem> media, int index = 0, Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1080, 2340);
    tester.view.devicePixelRatio = size == null ? 3 : 1;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final acc = fakeSession().account;
    final post = Post(id: 'm1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 26), body: 'メディア', media: media);
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: index));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    return (c, post);
  }

  final image = MediaItem(id: 'i', type: MediaType.image, url: Uri.parse('https://example.test/i.jpg'));
  EdgeInsets insetOf(WidgetTester tester) => tester.widget<AnimatedPadding>(find.byKey(viewerMediaInsetKey)).padding as EdgeInsets;

  testWidgets('下側 FOW が伸び縮みするたびにメディアが逆サイド(上)へ寄る。逆サイドに 120px は必ず残す', (tester) async {
    final (c, _) = await open(tester, media: [image]);
    final manager = c.read(overlayManagerProvider);
    final spec = manager.entries.firstWhere((e) => e.id == viewerFowId).fow!;
    expect(spec.maxWidth, viewerFowMaxWidth, reason: '下側中央(最大 600px)');
    final screenH = tester.getSize(find.byType(MediaViewerScreen)).height;

    // 折りたたみ: FOW のぶんだけ下の余白。
    final collapsed = insetOf(tester).bottom;
    expect(collapsed, greaterThan(0));
    expect(collapsed, lessThan(screenH * 0.35));
    expect(insetOf(tester).top, 0);

    // 伸ばす → 追従して上へ寄る。
    spec.heightFactor.value = 0.5;
    await tester.pumpAndSettle();
    expect(insetOf(tester).bottom, greaterThan(collapsed));
    expect(insetOf(tester).bottom, inInclusiveRange(screenH * 0.4, screenH * 0.6));

    // いっぱいまで伸ばす → 逆サイドに 120px は残す(足りないぶんは FOW と重なる)。
    spec.heightFactor.value = spec.maxHeightFactor;
    await tester.pumpAndSettle();
    expect(screenH - insetOf(tester).bottom, closeTo(viewerMinFreeSpace, 0.5));
    // 上側のボタン群には被さらない (D-329): 最大でも FOW の上辺は「戻る」の下辺より下。
    final back = tester.getRect(find.byTooltip('戻る'));
    expect(spec.laidOut!.top, greaterThanOrEqualTo(back.bottom));
    expect(spec.maxHeightFactor, lessThan(0.92));

    // 縮める → 戻る。
    spec.heightFactor.value = spec.heightStops.first;
    await tester.pumpAndSettle();
    expect(insetOf(tester).bottom, closeTo(collapsed, 0.5));
  });

  testWidgets('幅の広い画面で FOW がカラム(縦に長い)に置かれたら、メディアは左右へ寄る(上下に潰さない、D-332)', (tester) async {
    final (c, _) = await open(tester, media: [image], size: const Size(2000, 1390));
    final manager = c.read(overlayManagerProvider);
    final spec = manager.entries.firstWhere((e) => e.id == viewerFowId).fow!;
    spec.heightFactor.value = spec.maxHeightFactor; // 実機のスクリーンショットと同じ: カラムいっぱいに伸ばした FOW
    await tester.pumpAndSettle();
    final r = spec.laidOut!;
    final inset = insetOf(tester);
    final screen = tester.getSize(find.byType(MediaViewerScreen));
    if (r.width < screen.width / 2) {
      // カラムに置かれた: 左右の逆サイドへ。上下には寄せない。
      expect(inset.top, 0);
      expect(inset.bottom, 0);
      expect(inset.left + inset.right, greaterThan(0));
      // FOW の左右のうち広いほうがメディアの場所(真ん中のカラムに置かれても)。
      expect(screen.width - inset.left - inset.right, closeTo(math.max(r.left, screen.width - r.right), 1));
    } else {
      // 下側中央(幅の広い FOW): 上へ。
      expect(inset.left, 0);
      expect(inset.right, 0);
      expect(inset.bottom, greaterThan(0));
    }
  });

  testWidgets('下向きにスワイプすると閉じる(短ければ戻る)', (tester) async {
    await open(tester, media: [image]);
    final face = find.byKey(viewerMediaInsetKey);
    await tester.drag(face, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget, reason: '短い = 戻る');
    await tester.drag(face, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsNothing, reason: '距離を超えたら閉じる');
  });

  testWidgets('音声の添付: 音符の面 + 下側 FOW に再生の操作。開くと自動再生(再生できない環境では案内)', (tester) async {
    final audio = MediaItem(id: 'a', type: MediaType.file, url: Uri.parse('https://example.test/voice.mp3'), fileName: 'voice.mp3');
    await open(tester, media: [image, audio], index: 1);
    expect(find.byKey(const ValueKey('viewer.audio.a')), findsOneWidget);
    expect(find.text('voice.mp3'), findsWidgets);
    expect(find.byKey(const ValueKey('video.controls')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.play')), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer.audio.error')), findsOneWidget); // プラグイン無し → 案内
    // 画像のページには操作は出ない。
    await tester.drag(find.byKey(viewerMediaInsetKey), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video.controls')), findsNothing);
    expect(find.byType(MediaViewerScreen), findsOneWidget, reason: '横スワイプでは閉じない');
  });
}
