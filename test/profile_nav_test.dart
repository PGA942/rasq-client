import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/users/profile_image_viewer.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-177: ユーザー行(リノート欄 / フォロワー等)からプロフィールへ、プロフィールのアイコン /
/// バナーは全画面表示、スレッド展開のメイン投稿は添付を 5 枚目以降も並べる。
void main() {
  const bob = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob');
  final bobUser = UserSummary(id: 'bob', account: bob, displayName: 'ボブ', avatarUrl: Uri.parse('https://example.test/bob.png'));
  List<MediaItem> media(int n) => [for (var i = 0; i < n; i++) MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://example.test/$i.png'))];

  Future<ProviderContainer> pump(WidgetTester tester, List<Post> Function(AccountId) posts) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('スレッド展開: メイン投稿は 6 枚全部、TL は 4 枚 + 「+2」', (tester) async {
    await pump(tester, (v) => [Post(id: 'p1', account: v, author: bobUser, createdAt: DateTime(2026, 9, 1), body: '写真 6 枚', media: media(6))]);
    // TL: 4 枚に畳まれて最後のタイルに +2。
    expect(find.descendant(of: find.byType(RasqMediaGrid), matching: find.text('+2')), findsOneWidget);
    await tester.tap(find.text('写真 6 枚'));
    await tester.pumpAndSettle();
    // スレッド: メイン投稿の grid に 6 タイル(画像は読めないので壊れ画像アイコン)、+N 無し。
    expect(find.descendant(of: find.byType(RasqMediaGrid), matching: find.text('+2')), findsNothing);
    final grid = find.byType(RasqMediaGrid).first;
    expect(find.descendant(of: grid, matching: find.byIcon(Icons.broken_image_outlined)), findsNWidgets(6));
    // 奇数(5 枚)は最後の行が 1 枚で全幅。
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RasqMediaGrid(items: media(5), maxVisible: 5))));
    await tester.pumpAndSettle();
    final tiles = find.byIcon(Icons.broken_image_outlined);
    expect(tiles, findsNWidgets(5));
    final last = tester.getRect(tiles.at(4));
    final first = tester.getRect(tiles.at(0));
    expect(last.center.dx, closeTo(tester.getRect(find.byType(RasqMediaGrid)).center.dx, 1));
    expect(first.center.dx, lessThan(last.center.dx));
  });

  testWidgets('ユーザー行(フォロワー欄)のタップ → プロフィール、アイコンのタップ → 全画面表示', (tester) async {
    await pump(tester, (v) => [Post(id: 'p1', account: v, author: bobUser, createdAt: DateTime(2026, 9, 1), body: 'こんにちは')]);
    // 作者名 → ボブのプロフィール。
    await tester.tap(find.text('ボブ').first);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    // フォロワー(Fake は投稿者一覧)→ 行タップ → プロフィール(もう 1 枚積まれる)。
    await tester.tap(find.text('フォロワー'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqUserRow), findsWidgets);
    await tester.tap(find.byType(RasqUserRow).first);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    // アイコン → 全画面(黒背景のビューワー)。戻るで閉じる。
    await tester.tap(find.descendant(of: find.byType(RasqUserTileLarge), matching: find.byType(RasqAvatar)));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileImageViewerScreen), findsOneWidget);
    expect(find.text('ボブ'), findsOneWidget); // タイトル = 表示名
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileImageViewerScreen), findsNothing);
    expect(find.byType(UserPageScreen), findsOneWidget);
  });

  testWidgets('バナーのタップも全画面表示(タイル単体)', (tester) async {
    var banner = 0;
    var avatar = 0;
    final p = UserProfile(summary: bobUser, bannerUrl: Uri.parse('https://example.test/banner.png'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RasqUserTileLarge(profile: p, onBannerTap: () => banner++, onAvatarTap: () => avatar++))));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('バナー画像'));
    await tester.tap(find.byType(RasqAvatar));
    expect((banner, avatar), (1, 1));
  });
}
