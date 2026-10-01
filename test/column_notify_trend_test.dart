import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/notifications/notifications_screen.dart';
import 'package:rasq_client/features/search/search_screen.dart';
import 'package:rasq_client/features/trend/trend_menu.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/headers.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-397: 第3カラムの通知 / 設定ボタンの場所 / 第3カラムの検索のアカウント / トレンドを開くアカウントと「…」/
/// stick FOW のぶんカラムを縮める。
void main() {
  final bsky = AccountSession(
    account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'tester.bsky.social'),
    pluginId: 'test.bsky',
    token: 't',
    createdAt: DateTime(2026, 9, 1),
    displayName: 'テスター(Bluesky)',
  );
  final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  // タグの TL は id p1 の投稿を返す。本文に読んだアカウントのサーバーを入れて、どのアカウントで開いたかを見分ける。
  List<Post> posts(AccountId v) => [Post(id: 'p1', account: v, author: author, createdAt: DateTime(2026, 10, 1, 9), body: 'タグの投稿 ${v.instance}')];

  late MemorySessionStorage storage;
  Future<ProviderContainer> pump(WidgetTester tester, {bool wide = true, Map<String, String> extra = const {}}) async {
    tester.view.physicalSize = wide ? const Size(2400, 1600) : const Size(1080, 2340); // 1200x800 / 360x780 論理
    tester.view.devicePixelRatio = wide ? 2 : 3;
    addTearDown(tester.view.reset);
    storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': fakeSession().account.key}),
      ...extra,
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: posts, trends: const [TrendTag(tag: '打上会', usersCount: 10), TrendTag(tag: '花火', usersCount: 5)]))
      ..register(FakeSnsPlugin(posts: posts, id: 'test.bsky', kind: SnsKind.bluesky, trends: const [TrendTag(tag: '#花火'), TrendTag(tag: '月見')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  final col3 = find.byType(ThirdColumnView);
  Finder inCol3(Finder f) => find.descendant(of: col3, matching: f);
  final gear = find.byKey(const ValueKey('thirdColumn.settings'));

  Future<void> pickEmpty(WidgetTester tester, String label) async {
    await tester.tap(inCol3(gear));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('第3カラムに通知を出せる・設定ボタンは検索欄の横 / 通知ヘッダーの右端(押せない ↑ の代わり)', (tester) async {
    await pump(tester);
    // 検索: 設定ボタンは検索欄と同じ行(右隣)。以前のような検索の上の段は無い。
    expect(inCol3(gear), findsOneWidget);
    final field = inCol3(find.byType(TextField)).first;
    expect(tester.getCenter(inCol3(gear)).dy, closeTo(tester.getCenter(field).dy, 12));
    expect(tester.getTopLeft(inCol3(gear)).dx, greaterThan(tester.getTopRight(field).dx - 1));

    // 選べるのは 検索 / 通知 / 表示しない。
    await tester.tap(inCol3(gear));
    await tester.pumpAndSettle();
    for (final l in ['検索', '通知', '表示しない']) {
      expect(find.text(l), findsWidgets);
    }
    await tester.tap(find.text('通知').last);
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(NotificationsScreen)), findsOneWidget);
    expect(inCol3(find.byType(SearchScreen)), findsNothing);
    // 押せない ↑(先頭へ)は無くなり、そこに設定ボタン。
    expect(inCol3(find.byTooltip('先頭へ')), findsNothing);
    expect(find.descendant(of: inCol3(find.byType(RasqNotificationHeader)), matching: gear), findsOneWidget);
    // 通知の中身は左カラムと同じアカウントのもの。
    expect(inCol3(find.text('タグの投稿 example.test')), findsWidgets);
    // 保存は検索 / 表示しないと同じ KV。
    expect((jsonDecode((await storage.read('thirdColumn.v1'))!) as Map)['empty'], 'notifications');

    // 表示しない: 設定ボタンは右上に残る。検索へ戻せる。
    await pickEmpty(tester, '表示しない');
    expect(inCol3(find.byType(NotificationsScreen)), findsNothing);
    expect(find.text('第3カラム'), findsOneWidget);
    await pickEmpty(tester, '検索');
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);
  });

  testWidgets('通知を選んでいれば、起動時から第3カラムは通知', (tester) async {
    await pump(tester, extra: {'thirdColumn.v1': jsonEncode({'empty': 'notifications'})});
    expect(inCol3(find.byType(NotificationsScreen)), findsOneWidget);
  });

  testWidgets('第3カラムの検索は左カラムと同じアカウント: 個別の SNS アカウントならそのアカウントのトレンドとアイコン、切り替えるとついてくる', (tester) async {
    final c = await pump(tester);
    String avatarLabel() => tester.widget<RasqAvatar>(inCol3(find.byKey(const ValueKey('search.account')))).fallbackLabel ?? '';
    // Misskey(example.test)を選んでいる: そのアカウントが出したトレンドだけ。
    expect(avatarLabel(), 'テスター');
    expect(inCol3(find.byKey(const ValueKey('trend.tile.打上会'))), findsOneWidget);
    expect(inCol3(find.byKey(const ValueKey('trend.tile.#花火'))), findsOneWidget);
    expect(inCol3(find.byKey(const ValueKey('trend.tile.月見'))), findsNothing);
    // 両方のアカウントのトレンドなら、いまのアカウントの印が先。
    expect(find.descendant(of: inCol3(find.byKey(const ValueKey('trend.server.#花火'))), matching: find.text('example.test')), findsOneWidget);
    // 入力中の語は、アカウントを切り替えると残らない。
    await tester.enterText(inCol3(find.byType(TextField)).first, '書きかけ');
    await tester.pump();

    // Bluesky に切り替える → アイコンもトレンドもついてくる。
    await c.read(sessionsProvider.notifier).setCurrent(bsky.account);
    await tester.pumpAndSettle();
    // アイコンは左カラム(ホームのヘッダー)と同じ、いまの SNS アカウントのプロフィール。
    expect(c.read(currentUserProvider).account, bsky.account);
    expect(avatarLabel(), c.read(currentUserProvider).displayName);
    expect(inCol3(find.byKey(const ValueKey('trend.tile.月見'))), findsOneWidget);
    expect(inCol3(find.byKey(const ValueKey('trend.tile.#花火'))), findsOneWidget);
    expect(inCol3(find.byKey(const ValueKey('trend.tile.打上会'))), findsNothing);
    expect(inCol3(find.text('書きかけ')), findsNothing);
    // 開くと、いまのアカウント(Bluesky)で読む。
    await tester.tap(inCol3(find.byKey(const ValueKey('trend.tile.月見'))));
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(TrendScreen)), findsOneWidget);
    expect(inCol3(find.text('タグの投稿 bsky.social')), findsWidgets);
    await tester.tap(inCol3(find.byTooltip('トレンドホームへ戻る')));
    await tester.pumpAndSettle();

    // 総合表示(RASQ アカウント)では、D-388 のとおり全部のアカウントから。
    await c.read(sessionsProvider.notifier).setBundleView(true);
    await tester.pumpAndSettle();
    for (final t in ['打上会', '#花火', '月見']) {
      expect(inCol3(find.byKey(ValueKey('trend.tile.$t'))), findsOneWidget);
    }
  });

  testWidgets('トレンドの行はそのトレンドを出したアカウントで開く・「…」で別のアカウントで開く / 通報', (tester) async {
    final c = await pump(tester, wide: false);
    c.read(routerProvider).go(Routes.search);
    await tester.pumpAndSettle();

    // 「月見」は Bluesky だけが出した → Bluesky で開く(いまは Misskey)。
    await tester.tap(find.byKey(const ValueKey('trend.tile.月見')));
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, bsky.account.key);
    expect(find.text('タグの投稿 bsky.social'), findsWidgets);
    expect(find.text('タグの投稿 example.test'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('trend.openedAs')), matching: find.text('bsky.social')), findsOneWidget);
    // 続けて検索しても、同じアカウントのまま。
    await tester.enterText(find.byType(TextField).first, '月');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).tag, '月');
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, bsky.account.key);
    await tester.tap(find.byTooltip('トレンドホームへ戻る'));
    await tester.pumpAndSettle();

    // 「#花火」は両方が出した → いまのアカウント(指定なし = 切り替えについてくる)。
    await tester.tap(find.byKey(const ValueKey('trend.tile.#花火')));
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, isNull);
    expect(find.text('タグの投稿 example.test'), findsWidgets);
    expect(find.byKey(const ValueKey('trend.openedAs')), findsNothing);
    await tester.tap(find.byTooltip('トレンドホームへ戻る'));
    await tester.pumpAndSettle();

    // 「…」→ 別のアカウントで開く → アカウントを選ぶ。
    await tester.tap(find.byKey(const ValueKey('trend.more.打上会')));
    await tester.pumpAndSettle();
    expect(find.text('別のアカウントで開く'), findsOneWidget);
    expect(find.text('通報'), findsOneWidget);
    await tester.tap(find.text('別のアカウントで開く'));
    await tester.pumpAndSettle();
    expect(find.text('${fakeSession().account}(トレンドに出したアカウント)'), findsOneWidget);
    await tester.tap(find.text('${bsky.account}'));
    await tester.pumpAndSettle();
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).tag, '打上会');
    expect(tester.widget<TrendScreen>(find.byType(TrendScreen)).account, bsky.account.key);
    expect(find.text('タグの投稿 bsky.social'), findsWidgets);
    await tester.tap(find.byTooltip('トレンドホームへ戻る'));
    await tester.pumpAndSettle();

    // 「…」→ 通報 → 理由を選んで通報する (D-402)。RASQ アカウントが無い(Central に繋がらない)ので端末に控え、あとで送る。
    await tester.tap(find.byKey(const ValueKey('trend.more.月見')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通報'));
    await tester.pumpAndSettle();
    expect(find.textContaining('送信はされません'), findsNothing);
    expect(find.textContaining('RASQ の審査で確認します'), findsOneWidget);
    await tester.tap(find.text('嫌がらせ・暴言'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trend.report.send')));
    await tester.pumpAndSettle();
    final saved = jsonDecode((await storage.read('$trendReportsArea.v1'))!) as Map;
    expect(saved['月見'], containsPair('reason', 'harassment'));
    expect(saved['月見'], containsPair('account', bsky.account.key));
    expect(saved['月見'], containsPair('sent', false));
    expect(find.textContaining('端末に控えました'), findsOneWidget);
    // 通報したトレンドは一覧に出ない。スナックバーの「表示に戻す」で戻る(控えは残る)。
    expect(find.byKey(const ValueKey('trend.tile.月見')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trend.report.unhide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trend.tile.月見')), findsWidgets);
    expect((jsonDecode((await storage.read('$trendReportsArea.v1'))!) as Map)['月見'], containsPair('hidden', false));
  });

  testWidgets('stick FOW がカラムにある間は、そのカラムの中身を縮める(第3カラム)', (tester) async {
    final c = await pump(tester);
    final before = tester.getSize(find.byType(SearchScreen).last).height;
    final spec = FowSpec(stickCollapse: true, initialHeightFactor: 0.15, minHeightFactor: 0.1, heightStops: const [0.15, 0.6], columnIndex: 1);
    c.read(overlayManagerProvider).showFow<void>(id: 'stick.test', spec: spec, builder: (context, handle) => const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.getSize(inCol3(find.byType(SearchScreen))).height, closeTo(before - 120, 1));
    // 左カラムはそのまま。
    expect(tester.getSize(find.byKey(const ValueKey('pane.swipe.left'))).height, closeTo(800, 1));
    c.read(overlayManagerProvider).close('stick.test');
    await tester.pumpAndSettle();
    expect(tester.getSize(inCol3(find.byType(SearchScreen))).height, closeTo(before, 1));
  });
}
