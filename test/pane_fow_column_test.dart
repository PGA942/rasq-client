import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/search/search_screen.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-481: 第3カラムが空で検索(既定)を出しているときに、そこに並ぶ投稿のボタン(リノート / 引用 / リアクション / 共有)で開く
/// FOW も**第3カラム**に出す。以前はページを開いている(entry がある)ときだけ第3カラム扱いで、検索に並ぶ投稿から開くと
/// 第2カラムに出ていた。
void main() {
  final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  List<Post> posts(AccountId v) => [Post(id: 'p1', account: v, author: author, createdAt: DateTime(2026, 10, 1, 9), body: '花火の投稿')];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    // リアクションピッカーを開くので、絵文字でリアクションできる SNS として (D-321)。
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts, localEmojis: const {}, trends: const [TrendTag(tag: '花火', usersCount: 5)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  final col3 = find.byType(ThirdColumnView);
  Finder inCol3(Finder f) => find.descendant(of: col3, matching: f);
  Finder fowPanel() => find.byWidgetPredicate(isFrontmostFowPanel);

  /// いま最前面の FOW が第3カラムの中(左端が第3カラムの左端より右)にあるか。
  /// ボタンにつながった FOW (D-513) は、そのパネル(ボタンのカラムの中に収める)で見る。
  void expectFowInCol3(WidgetTester tester, String what) {
    final tethered = find.byKey(kTetherPanelKey);
    final panel = tethered.evaluate().isNotEmpty ? tethered : fowPanel();
    expect(panel, findsOneWidget, reason: what);
    expect(tester.getTopLeft(panel).dx, greaterThanOrEqualTo(tester.getTopLeft(col3).dx - 1), reason: '$what の FOW が第2カラムに出ている');
  }

  /// ふつうの(ドックする)フッター付きの FOW (D-521): 最前面の FOW のパネルが第3カラムの左右の中にあり、フッターがその下の辺。
  void expectFooterFowInCol3(WidgetTester tester, String what) {
    final panel = fowPanel();
    expect(panel, findsOneWidget, reason: what);
    final rect = tester.getRect(panel);
    final c3 = tester.getRect(col3);
    expect(rect.left, greaterThanOrEqualTo(c3.left - 1), reason: what);
    expect(rect.right, lessThanOrEqualTo(c3.right + 1), reason: what);
    final footer = find.descendant(of: panel, matching: find.byType(FowFooter));
    expect(footer, findsOneWidget, reason: '$what のフッター');
    expect(tester.getRect(footer).bottom, closeTo(rect.bottom, 1), reason: what);
  }

  Future<void> closeFow(WidgetTester tester) async {
    // 第2カラム(ホームの TL の上)の何も無い所 = FOW の外を押して閉じる。
    await tester.tapAt(Offset(tester.getTopLeft(col3).dx - 40, 780));
    await tester.pumpAndSettle();
  }

  testWidgets('第3カラムの検索に並ぶ投稿のリノート → 引用ノートは第3カラムに出る (D-481)', (tester) async {
    await pump(tester);
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);
    // 第3カラムは空(entry 無し = 検索)のまま。
    expect(ProviderScope.containerOf(tester.element(col3)).read(thirdColumnProvider), isNull);
    final row = inCol3(find.byType(PostRow));
    expect(row, findsWidgets);
    expect(fowColumnOf(tester.element(row.first)), 1);
    // 第2カラム(ホーム)の投稿は 0 のまま。
    final homeRow = find.byType(PostRow).first;
    expect(tester.getTopLeft(homeRow).dx, lessThan(tester.getTopLeft(col3).dx));
    expect(fowColumnOf(tester.element(homeRow)), 0);

    // リノートのバンドル FOW。
    await tester.tap(inCol3(find.byTooltip('リノート')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionbar.bundle.pick.renote')), findsOneWidget);
    expectFowInCol3(tester, 'リノート');
    // 引用ノート → コンポーザーも第3カラム。
    await tester.tap(find.text('引用ノート'));
    await tester.pumpAndSettle();
    expect(find.text('引用'), findsOneWidget);
    expectFowInCol3(tester, '引用');
  });

  testWidgets('第3カラムの検索に並ぶ投稿のリアクション / 共有の FOW も第3カラム (D-481)', (tester) async {
    await pump(tester);
    // 長押しはすぐ選べる絵文字 (D-512)、その「その他」でピッカー全体。どちらも第3カラム。
    await tester.longPress(inCol3(find.byTooltip('リアクション')).first);
    await tester.pumpAndSettle();
    expectFowInCol3(tester, 'すぐ選べる絵文字');
    await tester.tap(find.byKey(const ValueKey('quickEmoji.more')));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsOneWidget);
    expectFowInCol3(tester, 'リアクション');
    await closeFow(tester);
    expect(find.byType(EmojiPanel), findsNothing);
    await tester.tap(inCol3(find.byTooltip('共有')).first);
    await tester.pumpAndSettle();
    expectFowInCol3(tester, '共有');
    // D-521: 共有はボタンにつながらない、ふつうのフッター付きの FOW。第3カラムの幅に収まる。
    expect(find.byType(TetheredPanel), findsNothing);
    expectFooterFowInCol3(tester, '共有');
  });

  testWidgets('第3カラムのユーザーページの「ノートの表示」は、第3カラムのフッター付きの FOW (D-521 / D-481)', (tester) async {
    await pump(tester);
    tester.element(inCol3(find.byType(PostRow)).first).pushUser(author);
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(UserPageScreen)), findsOneWidget);
    final tab = inCol3(find.descendant(of: find.byType(TabBar), matching: find.text('ノート')));
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('user.tabView.panel')), findsOneWidget);
    expect(find.byType(TetheredPanel), findsNothing);
    expectFowInCol3(tester, 'ノートの表示');
    expectFooterFowInCol3(tester, 'ノートの表示');
    expect(find.descendant(of: find.byType(FowFooter), matching: find.byKey(const ValueKey('user.tabView.reset'))), findsOneWidget);
    // フッターの「閉じる」で閉じる。
    await tester.tap(find.byKey(const ValueKey('user.tabView.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('user.tabView.panel')), findsNothing);
  });

  testWidgets('検索して第3カラムに開いた結果のリノートも第3カラムのまま (D-481)', (tester) async {
    await pump(tester);
    await tester.enterText(inCol3(find.byType(TextField)).first, '花火');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(TrendScreen)), findsOneWidget);
    await tester.tap(inCol3(find.byTooltip('リノート')).first);
    await tester.pumpAndSettle();
    expectFowInCol3(tester, 'リノート');
  });
}
