import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/media/video_player.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 動画 (D-200): ビューアの動画ページは video_player で再生する。テスト環境(プラグイン無し)では
/// 初期化に失敗してサムネイル + 案内に落ちる(落ちない・固まらない)。
void main() {
  testWidgets('ビューアの動画ページ: 初期化できない環境では案内に落ち、ページ切り替えで壊れない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final acc = fakeSession().account;
    final post = Post(
      id: 'v1',
      account: acc,
      author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: DateTime(2026, 9, 1),
      body: '動画つき',
      media: [
        MediaItem(id: 'v', type: MediaType.video, url: Uri.parse('https://example.test/v.mp4'), thumbnailUrl: Uri.parse('https://example.test/v.jpg')),
        MediaItem(id: 'i', type: MediaType.image, url: Uri.parse('https://example.test/i.jpg')),
      ],
    );
    const videoIndex = 0;
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: videoIndex));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(find.byType(RasqVideoView), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer.video.error')), findsOneWidget); // プラグイン無し → 案内
    // 操作 (D-201): アクションバーの上に 再生 / シーク / 5 秒 / 速度(初期化前は無効)。
    expect(find.byKey(const ValueKey('video.controls')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.play')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.back5')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.forward5')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.seek')), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('video.controls'))).bottom, lessThanOrEqualTo(tester.getRect(find.byTooltip('共有')).top + 1)); // アクションバーの上
    // 次のページへ(画像)→ 戻っても動画ページは生きている。
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(RasqVideoView), findsOneWidget);
  });

  testWidgets('TL のタイルの再生バッジ → インライン再生の FOW(動画 + 操作)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final acc = fakeSession().account;
    final post = Post(
      id: 'v2',
      account: acc,
      author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: DateTime(2026, 9, 1),
      body: '動画つき',
      media: [MediaItem(id: 'v', type: MediaType.video, url: Uri.parse('https://example.test/v.mp4'))],
    );
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    expect(find.byType(PostRow), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('media.play.v')));
    await tester.pumpAndSettle();
    expect(find.text('動画'), findsOneWidget); // FOW タイトル
    expect(find.byType(VideoPlayerBlock), findsOneWidget);
    expect(find.byKey(const ValueKey('video.controls')), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer.video.error')), findsOneWidget);
    expect(find.byType(MediaViewerScreen), findsNothing); // ビューアは開かない
    await tester.tap(find.text('閉じる').last);
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayerBlock), findsNothing);
  });
}
