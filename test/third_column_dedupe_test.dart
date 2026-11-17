import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/notifications/notifications_screen.dart';
import 'package:rasq_client/features/search/search_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/nav.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-588: 第3カラムの検索 / 通知は、左の通常カラムで同じものを開いているときはもう片方にする。
void main() {
  group('thirdColumnFillerOf', () {
    test('左と重なるときだけ、検索 ⇄ 通知を入れ替える', () {
      expect(thirdColumnFillerOf('search', RasqNavTab.search), 'notifications');
      expect(thirdColumnFillerOf('notifications', RasqNavTab.notifications), 'search');
      // 重ならなければ設定どおり。
      expect(thirdColumnFillerOf('search', RasqNavTab.home), 'search');
      expect(thirdColumnFillerOf('search', RasqNavTab.notifications), 'search');
      expect(thirdColumnFillerOf('notifications', RasqNavTab.search), 'notifications');
      expect(thirdColumnFillerOf('notifications', RasqNavTab.dm), 'notifications');
      expect(thirdColumnFillerOf('none', RasqNavTab.search), 'none');
      expect(thirdColumnFillerOf('search', null), 'search');
    });

    test('替えた先を見守りで止めていれば、表示しない', () {
      String? blockNotifications(String path) => path == '/notifications' ? '止めています' : null;
      expect(thirdColumnFillerOf('search', RasqNavTab.search, blockReason: blockNotifications), 'none');
      expect(thirdColumnFillerOf('notifications', RasqNavTab.notifications, blockReason: blockNotifications), 'search');
      // 重ならないときは関所を見ない(止めた案内は ThirdColumnView 側で出す)。
      expect(thirdColumnFillerOf('notifications', RasqNavTab.home, blockReason: blockNotifications), 'notifications');
    });
  });

  Future<ProviderContainer> pump(WidgetTester tester, {Map<String, String> extra = const {}}) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...extra,
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => const <Post>[]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  final col3 = find.byType(ThirdColumnView);
  Finder inCol3(Finder f) => find.descendant(of: col3, matching: f);

  Future<void> go(WidgetTester tester, ProviderContainer c, String location) async {
    c.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('検索を選んでいる: 左で検索を開くと第3カラムは通知、左が離れれば検索へ戻る', (tester) async {
    final c = await pump(tester);
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);

    await go(tester, c, Routes.search);
    expect(inCol3(find.byType(SearchScreen)), findsNothing);
    expect(inCol3(find.byType(NotificationsScreen)), findsOneWidget);
    // 替えたことは保存しない(設定は検索のまま)。
    expect(c.read(settingsAreaProvider('thirdColumn')).value?['empty'], isNot('notifications'));

    await go(tester, c, Routes.home);
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);
    expect(inCol3(find.byType(NotificationsScreen)), findsNothing);
  });

  testWidgets('通知を選んでいる: 左で通知を開くと第3カラムは検索', (tester) async {
    final c = await pump(tester, extra: {'thirdColumn.v1': jsonEncode({'empty': 'notifications'})});
    expect(inCol3(find.byType(NotificationsScreen)), findsOneWidget);

    await go(tester, c, Routes.notifications);
    expect(inCol3(find.byType(NotificationsScreen)), findsNothing);
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);

    // 左が検索へ移っても、通知は重ならないので第3カラムは通知に戻る。
    await go(tester, c, Routes.search);
    expect(inCol3(find.byType(NotificationsScreen)), findsOneWidget);
  });
}
