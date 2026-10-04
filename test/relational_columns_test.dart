import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_event_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-434: 関連TL のイベントのページも、アカウントページ (D-425) と同じく幅の広い画面では第3カラムに開く。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String author, String body, {int minute = 0}) => Post(
        id: id,
        account: acc,
        author: UserSummary(id: author, account: acc, displayName: author),
        createdAt: DateTime(2026, 10, 4, 12, minute),
        body: body,
      );
  ConversationEvent event() => ConversationEvent.root(post('1', 'alice', '花火の写真 #打上会'))..add(post('2', 'bob', '花火きれい #打上会', minute: 1));

  Future<ProviderContainer> pumpAt(WidgetTester tester, Size logical) async {
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const [])))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Finder inCol3(Finder f) => find.descendant(of: find.byType(ThirdColumnView), matching: f);

  testWidgets('広い画面: 第3カラムに開き、第2カラムはホームのまま。< で閉じる', (tester) async {
    final c = await pumpAt(tester, const Size(1200, 800));
    tester.element(find.byType(HomeScreen)).pushRelationalEvent(event());
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(RelationalEventScreen)), findsOneWidget);
    expect(find.byType(RelationalEventScreen), findsOneWidget, reason: '全画面のルートには積まない');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(c.read(thirdColumnProvider)!.location, '/home${Routes.relationalEvent}');
    expect(inCol3(find.text('alice+1人')), findsOneWidget);
    await tester.tap(inCol3(find.byTooltip('戻る')).first);
    await tester.pumpAndSettle();
    expect(find.byType(RelationalEventScreen), findsNothing);
    expect(c.read(thirdColumnProvider), isNull);
  });

  testWidgets('広い画面: 第3カラムのページから別のイベントを開くと、居たページは第2カラム(タブの中)へ', (tester) async {
    final c = await pumpAt(tester, const Size(1200, 800));
    tester.element(find.byType(HomeScreen)).pushRelationalEvent(event());
    await tester.pumpAndSettle();
    final second = ConversationEvent.root(post('9', 'carol', '月見の団子'));
    tester.element(inCol3(find.byType(RelationalEventScreen))).pushRelationalEvent(second);
    await tester.pumpAndSettle();
    expect(inCol3(find.text('carol')), findsWidgets);
    expect(find.text('alice+1人'), findsOneWidget, reason: '第2カラムへ移った');
    expect(visibleLocationOf(c.read(routerProvider).routerDelegate.currentConfiguration), '/home${Routes.relationalEvent}');
  });

  testWidgets('狭い画面: これまでどおり全画面のページ', (tester) async {
    final c = await pumpAt(tester, const Size(400, 800));
    tester.element(find.byType(HomeScreen)).pushRelationalEvent(event());
    await tester.pumpAndSettle();
    expect(find.byType(RelationalEventScreen), findsOneWidget);
    expect(find.byType(ThirdColumnView), findsNothing);
    expect(visibleLocationOf(c.read(routerProvider).routerDelegate.currentConfiguration), '/home${Routes.relationalEvent}');
  });
}
