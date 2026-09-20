import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
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

  testWidgets('リノートは何度でも。自分のリノートとして流れてきたタイルでだけ「リノートを取り消す」になる (D-276)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final me = fakeSession().account;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': me.key}),
    });
    // 1 つ目 = ふつうの投稿、2 つ目 = 自分のリノートとして流れてきた投稿。
    List<Post> posts(AccountId viewer) => [
          Post(id: 'n1', account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: 'ふつうの投稿'),
          Post(id: 'n2', account: viewer, author: MockData.douglas, createdAt: DateTime.now().subtract(const Duration(minutes: 1)), body: 'リノートした投稿', repostedBy: UserSummary(id: 'me', account: me, displayName: 'テスター')),
        ];
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    // 帯の … はやめた。
    expect(find.byTooltip('リノートの操作'), findsNothing);
    // ふつうのタイル: リノートしたあとも、バンドルは「リノート / 引用ノート」のまま(取り消しは出ない)。
    for (var n = 0; n < 2; n++) {
      await tester.tap(find.byTooltip('リノート').first);
      await tester.pumpAndSettle();
      expect(find.text('リノートを取り消す'), findsNothing);
      expect(find.text('引用ノート'), findsOneWidget);
      await tester.tap(find.text('リノート').last);
      await tester.pumpAndSettle();
    }
    // 自分のリノートのタイル: 1 つ目が「リノートを取り消す」。
    await tester.tap(find.byTooltip('リノート').last);
    await tester.pumpAndSettle();
    expect(find.text('リノートを取り消す'), findsOneWidget);
    expect(find.text('引用ノート'), findsOneWidget);
    expect(find.text('リノート'), findsNothing);
  });
}
