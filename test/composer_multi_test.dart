import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-128: コンポーザーの複数選択モード — バンドルタイルの行タップで
/// 非選択 → 通常投稿 → ノード連動投稿を循環し、送信で選択分へ連動投稿する。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);

  Post postOf(AccountId v) => Post(
      id: 'p-${v.handle}',
      account: v,
      author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle),
      createdAt: DateTime(2026, 8, 31, 10),
      body: '${v.handle} の投稿');

  testWidgets('複数選択モード: 通常投稿/ノード連動の循環 + 送信で連動投稿', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // ポスト先グラフ: second の素のポスト先ノード(条件なし = 常に成立)。
    final target = builtinNodeCatalog.firstWhere((e) => e.type == 'composer.target').instantiate('t0', Offset.zero);
    final graph = NodeGraph(nodes: [
      target.copyWith(inputs: [target.inputs.first.copyWith(value: '@second@example.test')]),
    ]);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
      }),
      'nodeprog.${acc1.key}.composer.v1': jsonEncode({'graph': jsonEncode(graph.toJson())}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // コンポーザーを開いて、まず通常モードで投稿先を tester に固定する
    // (素のポスト先ノードが second をサジェストするため)。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    expect(find.text('複数選択モード'), findsOneWidget); // 「投稿先のカスタマイズ」の下 (D-128)
    await tester.tap(find.text('@tester@example.test'));
    await tester.pumpAndSettle();

    // 複数選択モードへ: second を 通常投稿 → ノード連動 に循環。
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('複数選択モード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('通常投稿'), findsOneWidget);
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('ノード連動'), findsOneWidget); // グラフに second のノード設定あり

    // 送信 → 本体(tester)+ ノード連動(second、グラフ成立)の両方へ。
    await tester.enterText(find.byType(TextField).last, '連動テストです');
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    final s1 = registry.session(session(acc1)) as FakeSnsSession;
    final s2 = registry.session(session(acc2)) as FakeSnsSession;
    expect(s1.lastDraft?.text, '連動テストです');
    expect(s2.lastDraft?.text, '連動テストです');
  });
}
