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
  testWidgets('リノートボタンは既定バンドル: タップでリノート/引用ノートのドロップダウン → 引用でコンポーザー (D-039)', (tester) async {
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
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // 最初の投稿のリノートボタン(tooltip 'リノート')をタップ → ドロップダウン。
    await tester.tap(find.byTooltip('リノート').first);
    await tester.pumpAndSettle();
    expect(find.text('リノート'), findsWidgets);
    expect(find.text('引用ノート'), findsOneWidget);

    // 引用ノート → コンポーザー(タイトル『引用』+ 対象プレビュー)。
    await tester.tap(find.text('引用ノート'));
    await tester.pumpAndSettle();
    expect(find.text('引用'), findsOneWidget);
  });
}
