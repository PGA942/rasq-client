import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

Widget app({bool loggedIn = true}) {
  final storage = MemorySessionStorage(loggedIn
      ? {
          SessionsNotifier.storageKey: jsonEncode({
            'sessions': [fakeSession().toJson()],
            'current': fakeSession().account.key,
          }),
        }
      : null);
  final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(registry),
    ],
    child: const RasqApp(),
  );
}

void main() {
  testWidgets('no session → login screen (Misskey enabled, others disabled)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(loggedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('SNSにログイン'), findsOneWidget);
    expect(find.text('Misskeyでログイン'), findsOneWidget);

    // Overlays must render above root-level pages too (regression: terms sheet never appeared).
    await tester.tap(find.text('BlueSkyでログイン'));
    await tester.pumpAndSettle();
    expect(find.text('BlueSky は準備中です'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('BlueSky は準備中です'), findsNothing);

    // Misskey → server screen → terms sheet appears through the Overlay Manager.
    await tester.tap(find.text('Misskeyでログイン'));
    await tester.pumpAndSettle();
    expect(find.text('PDSを変更'), findsOneWidget);
  });

  testWidgets('session → home timeline from plugin; action updates store; sidebar opens/closes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('フォロー中'), findsWidgets);
    expect(find.text('ダグラス'), findsOneWidget);

    // Tap "リアクション" on the first post → optimistic done state.
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsOneWidget);
    expect(find.text('@tester@example.test'), findsOneWidget);

    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsNothing);
  });

  testWidgets('post → thread screen, search → trend tag → trend TL, dm → room', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Thread: tap a post body.
    await tester.tap(find.textContaining('Take off'));
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsOneWidget); // page header
    expect(find.text('返信'), findsWidgets); // 返信 row + reply bar
    expect(find.text('リアクションを表示'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // Search tab → trend words from plugin → trend TL.
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    expect(find.text('打上会'), findsOneWidget);
    expect(find.text('117 Users'), findsOneWidget);
    await tester.tap(find.text('打上会'));
    await tester.pumpAndSettle();
    expect(find.text('フォロー中の反応'), findsOneWidget);
    expect(find.text('トレンド'), findsWidgets);
    expect(find.text('ダグラス'), findsOneWidget); // tag timeline row

    // DM tab → room list → room timeline.
    await tester.tap(find.byTooltip('DM'));
    await tester.pumpAndSettle();
    expect(find.text('事故アピール'), findsWidgets);
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('都市伝説'), findsOneWidget);
  });

  testWidgets('tablet width switches to the 2-pane layout', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('第3カラム'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
