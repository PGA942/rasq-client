import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/features/servers/server_badge.dart';
import 'package:rasq_client/shell/headers.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-415(D-411 を置き換え): トレンドTL・投稿の詳細のヘッダーのアカウントのボタン(戻るの右の丸いアイコン、タップでその場にアカウントの選択)。
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

  Finder item(String id, AccountId a) => find.byKey(ValueKey('$id.item.${a.key}'));

  Future<void> pickAccount(WidgetTester tester, Finder button, String id, AccountId a) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(item(id, a));
    await tester.pumpAndSettle();
  }

  testWidgets('トレンドTL: 戻るの右に丸いアカウントのボタン、その右に丸い検索欄。浮かべたタイルは出さない', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('${Routes.search}/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('trend.accountButton'));
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.byType(RasqAvatar)), findsOneWidget);
    expect(find.byTooltip('${fakeSession().account} で読んでいます'), findsOneWidget);
    // 並び: < → アイコン → 検索欄。
    final back = tester.getCenter(find.byTooltip('トレンドホームへ戻る'));
    final avatar = tester.getCenter(button);
    final search = tester.getRect(find.byType(RasqExpandableSearchBox));
    expect(back.dx < avatar.dx && avatar.dx < search.left, isTrue);
    expect((avatar.dy - search.center.dy).abs() < 4, isTrue, reason: 'アイコンは検索欄と同じ高さ');
    // D-411 の左下のタイルは出さない。
    expect(find.byKey(const ValueKey('trend.accountTile')), findsNothing);
    expect(find.byType(ServerBadge), findsNothing);
  });

  testWidgets('トレンドTL: アイコンでアカウントの選択(RASQ アカウント + SNS アカウント、チェックと印)を開き、選ぶとそのアカウントで読み直す', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('${Routes.search}/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('trend.accountButton'));
    expect(find.text('タグの投稿 example.test'), findsWidgets);

    await tester.tap(button);
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('trend.account.picker'));
    expect(picker, findsOneWidget);
    // 上に RASQ アカウント(アイコン・表示名・@ハンドル・閉じる ^)。
    final rasq = c.read(rasqAccountProvider);
    expect(find.descendant(of: picker, matching: find.text(rasq.displayName)), findsOneWidget);
    expect(find.descendant(of: picker, matching: find.text('@${rasq.account.handle}')), findsOneWidget);
    expect(find.byKey(const ValueKey('trend.account.close')), findsOneWidget);
    // 下に SNS アカウント。いまのものにチェック、トレンドを出したアカウントに印。
    expect(item('trend.account', fakeSession().account), findsOneWidget);
    expect(item('trend.account', bsky.account), findsOneWidget);
    expect(find.byKey(ValueKey('trend.account.check.${fakeSession().account.key}')), findsOneWidget);
    expect(find.byKey(ValueKey('trend.account.check.${bsky.account.key}')), findsNothing);
    expect(find.byKey(ValueKey('trend.account.mark.${fakeSession().account.key}')), findsOneWidget);
    expect(find.text('トレンドに出したアカウント'), findsOneWidget);
    // ^ で閉じる(何も変わらない)。
    await tester.tap(find.byKey(const ValueKey('trend.account.close')));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(find.text('タグの投稿 example.test'), findsWidgets);

    // Bluesky を選ぶ → そのセッションで読み直す。
    await pickAccount(tester, button, 'trend.account', bsky.account);
    expect(find.textContaining('タグの投稿 bsky.social', findRichText: true), findsWidgets);
    expect(find.text('タグの投稿 example.test'), findsNothing);
    expect(find.byTooltip('${bsky.account} で読んでいます'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('trend.account.check.${bsky.account.key}')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trend.account.close')));
    await tester.pumpAndSettle();
    // 続けて検索しても、選んだアカウントのまま。
    await tester.enterText(find.byType(TextField).first, '月見');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, bsky.account.key);

    // いまのアカウントに戻すと、指定を外す(読み直し)。
    await pickAccount(tester, button, 'trend.account', fakeSession().account);
    expect(find.byTooltip('${fakeSession().account} で読んでいます'), findsOneWidget);
    expect(find.text('タグの投稿 example.test'), findsWidgets);
  });

  testWidgets('投稿の詳細: ヘッダーのアイコンで別のアカウントに切り替えると投稿を引き直す。見つからなければそのまま。浮かべたタイルは出さない', (tester) async {
    await pump(tester);
    await tester.tap(find.text('タグの投稿 example.test').first);
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    final button = find.byKey(const ValueKey('post.accountButton'));
    expect(button, findsOneWidget);
    expect(find.descendant(of: find.byType(RasqPageHeader), matching: button), findsOneWidget, reason: 'ヘッダーの中');
    expect(find.byKey(const ValueKey('post.accountTile')), findsNothing);
    expect(find.byTooltip('${fakeSession().account} で読んでいます'), findsOneWidget);

    // Bluesky で同じ投稿(同じ URL)を探して、そのアカウントでスレッドを開き直す。
    await pickAccount(tester, button, 'post.account', bsky.account);
    expect(find.byTooltip('${bsky.account} で読んでいます'), findsOneWidget);
    expect(find.textContaining('タグの投稿 bsky.social', findRichText: true), findsWidgets);
    expect(find.textContaining('見つけられませんでした'), findsNothing);
    // 元のアカウントに戻せる(開いたアカウントに印、いまの Bluesky にチェック)。
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('post.account.mark.${fakeSession().account.key}')), findsOneWidget);
    expect(find.text('開いたアカウント'), findsOneWidget);
    expect(find.byKey(ValueKey('post.account.check.${bsky.account.key}')), findsOneWidget);
    await tester.tap(item('post.account', fakeSession().account));
    await tester.pumpAndSettle();
    expect(find.byTooltip('${fakeSession().account} で読んでいます'), findsOneWidget);
    expect(find.text('タグの投稿 example.test'), findsWidgets);

    // Misskey にしか無い投稿: Bluesky では見つからない → メッセージを出して、いまのアカウントのまま。
    Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ここだけの投稿').first);
    await tester.pumpAndSettle();
    await pickAccount(tester, button, 'post.account', bsky.account);
    expect(find.text('${bsky.account} ではこの投稿を見つけられませんでした'), findsOneWidget);
    expect(find.byTooltip('${fakeSession().account} で読んでいます'), findsOneWidget);
    expect(find.text('ここだけの投稿'), findsWidgets);
  });

  testWidgets('アカウントの選択は暗い表示でも描ける', (tester) async {
    final c = await pump(tester);
    c.read(themeModeProvider.notifier).set(ThemeModeSetting.dark);
    c.read(routerProvider).go('${Routes.search}/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend.accountButton')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('trend.account.picker'));
    expect(picker, findsOneWidget);
    expect(Theme.of(tester.element(picker)).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
