import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/clips/host_clips.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

Widget app({Map<String, String> extraStorage = const {}}) {
  final storage = MemorySessionStorage({
    SessionsNotifier.storageKey: jsonEncode({
      'sessions': [fakeSession().toJson()],
      'current': fakeSession().account.key,
    }),
    ...extraStorage,
  });
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
  Future<void> journey(WidgetTester tester) async {
    addTearDown(tester.view.reset);

    final host = HostClip(id: 'h1', name: '旅の記録', createdAt: DateTime(2026, 8, 27), entries: []);
    await tester.pumpWidget(app(extraStorage: {hostClipsStorageKey: jsonEncode([host.toJson()])}));
    await tester.pumpAndSettle();

    // サイドバー → リスト。公開クリップだけが出る(非公開は既定非表示)。
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リスト'));
    await tester.pumpAndSettle();
    expect(find.text('公開クリップ'), findsOneWidget);
    expect(find.text('内緒のクリップ'), findsNothing);
    expect(find.text('旅の記録'), findsNothing, reason: 'RASQ 横断クリップはブックマーク欄');

    // クリップ詳細 → 戻る(連打)→ もう一度開く。
    await tester.tap(find.text('公開クリップ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('目次'), findsWidgets);
    // 戻る連打(遷移アニメーション中の 2 度目タップ)。
    await tester.tap(find.byTooltip('戻る').last);
    await tester.pump(const Duration(milliseconds: 40));
    final backs = find.byTooltip('戻る');
    if (backs.evaluate().isNotEmpty) {
      await tester.tap(backs.last, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // リスト詳細(タブあり)→ タブ切替 → 外す → 戻る。
    if (find.text('リスト').evaluate().isEmpty) {
      await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('リスト'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fediverse Banner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ユーザー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外す'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('戻る').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // クリップ行を素早く 2 回タップ(二重 push)。
    await tester.tap(find.text('公開クリップ'));
    await tester.pump(const Duration(milliseconds: 30));
    final row = find.text('公開クリップ');
    if (row.evaluate().isNotEmpty) {
      await tester.tap(row, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('リスト⇄クリップページ往復・連打(モバイル幅)でページキーが重複しない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    await journey(tester);
  });

  testWidgets('リスト⇄クリップページ往復・連打(デスクトップ 2 ペイン)でページキーが重複しない', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    await journey(tester);
  });
}
