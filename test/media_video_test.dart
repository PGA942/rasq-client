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
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 動画 (D-200 → D-202): ビューアの動画ページは video_player で再生する。テスト環境(プラグイン無し)では
/// 初期化に失敗してサムネイル + 案内に落ちる(落ちない・固まらない)。下側はダークモードの FOW。
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
    // 下側はダークモードの FOW (D-202): 動画の操作(左にシークバー、右にボタン類)/ アクションバー / 投稿のインライン表示。
    expect(find.byKey(viewerPanelKey), findsOneWidget);
    expect(find.byKey(const ValueKey('video.controls')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.play')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.back5')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.forward5')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('video.seek')), findsOneWidget);
    expect(Theme.of(tester.element(find.byKey(const ValueKey('video.controls')))).brightness, Brightness.dark);
    // 幅 360dp の小画面 → ボタン類はシークバーの下の行。
    expect(find.byKey(const ValueKey('video.controls.stacked')), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('video.seek'))).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('video.play'))).top + 1));
    expect(tester.getRect(find.byKey(const ValueKey('video.controls'))).bottom, lessThanOrEqualTo(tester.getRect(find.byTooltip('共有')).top + 1)); // アクションバーの上
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.byType(PostRow)), findsOneWidget); // 投稿のインライン表示
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.byType(RasqMediaGrid)), findsNothing); // 添付は出さない
    // 折りたたみ(操作 + アクションバー)⇄ 展開(投稿まで): ハンドルを上へ → 高くなる、外側タップ → 折りたたみに戻る。
    final collapsed = tester.getRect(find.byKey(viewerPanelKey)).height;
    await tester.drag(find.bySemanticsLabel('サイズ変更ハンドル'), const Offset(0, -350));
    await tester.pumpAndSettle();
    final expanded = tester.getRect(find.byKey(viewerPanelKey)).height;
    expect(expanded, greaterThan(collapsed + 100));
    await tester.tapAt(const Offset(180, 120)); // バリア(展開中だけ)
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(viewerPanelKey)).height, lessThan(expanded - 100));
    // 次のページへ(画像)→ 動画の操作は消え、戻ると動画ページは生きている。
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video.controls')), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(RasqVideoView), findsOneWidget);
    expect(find.byKey(const ValueKey('video.controls')), findsOneWidget);
    // 全画面アクションバー (D-212): ヘッダーの「…」の左に並ぶ。下の FOW は投稿アクションバー。
    expect(find.byKey(const ValueKey('viewer.action.reply')), findsOneWidget);
    expect(tester.getCenter(find.byKey(const ValueKey('viewer.action.reply'))).dx, lessThan(tester.getCenter(find.descendant(of: find.byType(MediaViewerScreen), matching: find.byTooltip('メニュー'))).dx));
    // FOW が消えても、面のタップで開き直せる (D-203)。面のタップは再生を止めない(トグルのジェスチャーは無い)。
    expect(find.byKey(const ValueKey('viewer.video.toggle')), findsNothing);
    c.read(overlayManagerProvider).close(viewerFowId);
    await tester.pumpAndSettle();
    expect(find.byKey(viewerPanelKey), findsNothing);
    await tester.tapAt(const Offset(180, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(viewerPanelKey), findsOneWidget);
    // FOW を展開して投稿をタップ → スレッド展開画面 (D-204: ビューワーはタブ外なので二重マッチで落ちない)。
    await tester.drag(find.bySemanticsLabel('サイズ変更ハンドル'), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('動画つき')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.byKey(viewerPanelKey), findsNothing); // 上に画面が積まれたら FOW は閉じる (D-205)
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsNothing);
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(find.byKey(viewerPanelKey), findsOneWidget); // 戻ってきたら開き直す
    // 展開中はバリアがあるので折りたたんでから、ビューワーを閉じる → FOW も閉じる。
    await tester.tapAt(const Offset(180, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsNothing);
    expect(find.byKey(viewerPanelKey), findsNothing);
  });

  testWidgets('上側バーの最右の PiP ボタン → ビューワーを閉じてインライン再生 FOW へ (D-204)', (tester) async {
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
      id: 'v3',
      account: acc,
      author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: DateTime(2026, 9, 1),
      body: '動画つき',
      media: [MediaItem(id: 'v', type: MediaType.video, url: Uri.parse('https://example.test/v.mp4'))],
    );
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer.pip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer.pip')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsNothing);
    expect(find.byKey(viewerPanelKey), findsNothing);
    expect(find.byType(VideoPlayerBlock), findsOneWidget); // インライン再生 FOW
    expect(find.byKey(const ValueKey('video.fow.post')), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
    // 動画の下に投稿のインラインフレーム(「リアクションを表示」ページと同じ、D-203)→ タップでスレッド展開画面、FOW は閉じる。
    expect(find.byKey(const ValueKey('video.fow.post')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video.fow.post')));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.byType(VideoPlayerBlock), findsNothing);
  });
}
