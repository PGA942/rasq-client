import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_editor_screen.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-090: ノードプログラミング画面 — TL 選択行の設定ボタンから開き、
/// パレット(プラグインノードを検索)からタップ/長押しドラッグで追加、
/// グラフは KV(`nodeprog.<scope>`)に保存される。
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
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
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  test('NodeGraph JSON 往復', () {
    const g = NodeGraph(
      nodes: [GraphNode(id: 'n1', type: 'clock', title: 'クロックメーカー', x: 10, y: 20, inputs: [NodePort(label: '間隔', value: '15秒')], outputs: [NodePort(label: 'クロック')])],
      edges: [GraphEdge(from: 'n1', fromPort: 0, to: 'n2', toPort: 1)],
    );
    final back = NodeGraph.fromJson((jsonDecode(jsonEncode(g.toJson())) as Map).cast<String, Object?>());
    expect(back.nodes.single.inputs.single.value, '15秒');
    expect(back.edges.single.toPort, 1);
  });

  testWidgets('設定ボタン → エディタ。パレットからタップ/長押しドラッグで追加、KV に保存', (tester) async {
    final container = await pump(tester);

    // TL 選択行: RAi(準備中)と設定ボタン。設定はアクティブなタブの
    // スコープ(tl.<id>)を開くので、フォロー中(home)に合わせておく。
    expect(find.byTooltip('RAi(準備中)'), findsOneWidget);
    await tester.tap(find.text('フォロー中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    expect(find.text('タイムラインをカスタマイズ'), findsOneWidget);
    expect(find.byType(NodeEditorScreen), findsOneWidget);

    // パレットを開いてタップで追加。
    await tester.tap(find.text('プラグインノードを検索'));
    await tester.pumpAndSettle();
    expect(find.text('関連順'), findsOneWidget);
    await tester.tap(find.text('クロックメーカー'));
    await tester.pumpAndSettle();
    // パレットは閉じ、キャンバスにノードカードが載る。
    expect(find.text('クロックメーカー'), findsOneWidget);
    expect(find.text('入力'), findsOneWidget);
    expect(find.text('出力'), findsOneWidget);

    // 長押しドラッグでキャンバスへ(タイル長押し → ホバープレビュー → ドロップ)。
    await tester.tap(find.byTooltip('ノード一覧を開く'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.text('ランダム').hitTestable()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(const Offset(160, 260));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('ランダム'), findsOneWidget); // パレットは折りたたまれ、キャンバス側だけ

    // KV に保存されている(scope = tl.home)。
    final saved = (await container.read(settingsAreaProvider('nodeprog.tl.home').future))['graph'];
    expect(saved, isA<String>());
    final graph = NodeGraph.fromJson((jsonDecode(saved! as String) as Map).cast<String, Object?>());
    expect({for (final n in graph.nodes) n.type}, {'clock', 'random'});

    // 戻って開き直してもノードが残る。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    expect(find.text('クロックメーカー'), findsOneWidget);
    expect(find.text('ランダム'), findsOneWidget);
  });

  testWidgets('コンポーザーの「投稿先のカスタマイズ」→ composer スコープのエディタ', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@tester').last); // バンドルタイルを開く
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿先のカスタマイズ'));
    await tester.pumpAndSettle();
    // 画面タイトル(コンポーザー FOW のリンクはオーバーレイ側に残る)。
    expect(find.descendant(of: find.byType(NodeEditorScreen), matching: find.text('投稿先のカスタマイズ')), findsOneWidget);
  });
}
