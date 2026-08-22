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
