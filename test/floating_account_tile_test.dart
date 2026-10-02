import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-411: トレンドTL・投稿の詳細に浮かべたアカウントのタイル(既定で出す、タップで別のアカウントに切り替える)。
void main() {
  final bsky = AccountSession(
    account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'tester.bsky.social'),
    pluginId: 'test.bsky',
    token: 't',
    createdAt: DateTime(2026, 9, 1),
    displayName: 'テスター(Bluesky)',
  );
  final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  final shared = Uri.parse('https://example.test/notes/p1');
  // Misskey: p1(URL あり)と p2(Misskey だけ)。Bluesky: p1 と同じ URL の投稿(id は同じでも別の SNS なので、URL の検索で引く)。
  List<Post> posts(AccountId v) => v.kind == SnsKind.bluesky
      ? [Post(id: 'p1', account: v, author: author, createdAt: DateTime(2026, 10, 1, 9), body: 'タグの投稿 bsky.social $shared', url: shared)]
      : [
          Post(id: 'p1', account: v, author: author, createdAt: DateTime(2026, 10, 1, 9), body: 'タグの投稿 example.test', url: shared),
          Post(id: 'p2', account: v, author: author, createdAt: DateTime(2026, 10, 1, 8), body: 'ここだけの投稿', url: Uri.parse('https://example.test/notes/p2')),
        ];

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: posts, trends: const [TrendTag(tag: '打上会', usersCount: 10)]))
      ..register(FakeSnsPlugin(posts: posts, id: 'test.bsky', kind: SnsKind.bluesky, trends: const [TrendTag(tag: '月見')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> pickAccount(WidgetTester tester, Finder tile, String label) async {
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('トレンドTL: アカウントのタイルを既定で出し、選び直すとそのアカウントで読み直す', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('${Routes.search}/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('trend.accountTile'));
    // アカウントを決めずに開いた(いまのアカウント)ときも出す。アイコン + @ハンドル + サーバー。
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.byType(RasqAvatar)), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('@tester')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('example.test')), findsOneWidget);
    expect(find.text('タグの投稿 example.test'), findsWidgets);

    // 選ぶ一覧: いまの RASQ アカウントの SNS アカウント。トレンドを出したアカウントに印。
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('${fakeSession().account}(トレンドに出したアカウント)'), findsOneWidget);
    await tester.tap(find.text('${bsky.account}').last);
    await tester.pumpAndSettle();
    // Bluesky のセッションで読み直す。
    expect(find.textContaining('タグの投稿 bsky.social', findRichText: true), findsWidgets);
    expect(find.text('タグの投稿 example.test'), findsNothing);
    expect(find.descendant(of: tile, matching: find.text('bsky.social')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('@tester.bsky.social')), findsOneWidget);
    // 続けて検索しても、選んだアカウントのまま。
    await tester.enterText(find.byType(TextField).first, '月見');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, bsky.account.key);

    // いまのアカウントに戻すと、指定を外す(読み直し)。
    await pickAccount(tester, tile, '${fakeSession().account}');
    expect(find.text('タグの投稿 example.test'), findsWidgets);
    expect(find.descendant(of: tile, matching: find.text('example.test')), findsOneWidget);
  });

  testWidgets('投稿の詳細: アカウントのタイルで別のアカウントに切り替えると投稿を引き直す。見つからなければそのまま', (tester) async {
    await pump(tester);
    await tester.tap(find.text('タグの投稿 example.test').first);
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    final tile = find.byKey(const ValueKey('post.accountTile'));
    expect(find.descendant(of: tile, matching: find.text('example.test')), findsOneWidget);

    // Bluesky で同じ投稿(同じ URL)を探して、そのアカウントでスレッドを開き直す。
    await pickAccount(tester, tile, '${bsky.account}');
    expect(find.descendant(of: tile, matching: find.text('bsky.social')), findsOneWidget);
    expect(find.textContaining('タグの投稿 bsky.social', findRichText: true), findsWidgets);
    expect(find.textContaining('見つけられませんでした'), findsNothing);
    // 元のアカウントに戻せる(開いたアカウントに印)。
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('${fakeSession().account}(開いたアカウント)'), findsOneWidget);
    await tester.tap(find.text('${fakeSession().account}(開いたアカウント)'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: tile, matching: find.text('example.test')), findsOneWidget);
    expect(find.text('タグの投稿 example.test'), findsWidgets);

    // Misskey にしか無い投稿: Bluesky では見つからない → メッセージを出して、いまのアカウントのまま。
    Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ここだけの投稿').first);
    await tester.pumpAndSettle();
    await pickAccount(tester, tile, '${bsky.account}');
    expect(find.text('${bsky.account} ではこの投稿を見つけられませんでした'), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('example.test')), findsOneWidget);
    expect(find.text('ここだけの投稿'), findsWidgets);
  });
}
