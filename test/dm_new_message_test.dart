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

void main() {
  testWidgets('DM 新規メッセージ (D-045/D-046): + FAB → ユーザー検索 → コンポーザー付きルーム', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('DM'));
    await tester.pumpAndSettle();

    // 投稿と同じ + ボタン(FAB)。
    await tester.tap(find.byTooltip('新規メッセージ'));
    await tester.pumpAndSettle();
    expect(find.text('新規メッセージ'), findsOneWidget); // シート見出し

    final target = MockData.timeline(fakeSession().account).first.author;
    await tester.enterText(find.byType(TextField).last, target.displayName);
    await tester.pumpAndSettle();
    await tester.tap(find.text('@${target.handle}').last);
    await tester.pumpAndSettle();

    // 既存ルームが無くてもコンポーザー付きのルーム画面が開く。
    expect(find.text('ダイレクト投稿を入力..'), findsOneWidget);
  });
}
