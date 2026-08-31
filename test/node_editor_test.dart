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

/// D-090/D-092: ノードプログラミング画面 — TL 選択行の設定ボタンから開き、
/// パレット(プラグインノードを検索、FOW 製)からタイルタップ → 詳細 →
/// 追加、または長押しドラッグで追加。ノードはクリックでドロップダウン
/// (情報/コピー/ペースト/削除)。グラフは KV(`nodeprog.<scope>`)に保存。
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

  Finder onCanvas(Finder f) => find.descendant(of: find.byType(NodeEditorScreen), matching: f);

  test('NodeGraph JSON 往復(データ形式付き)+ 接続可否', () {
    const g = NodeGraph(
      nodes: [
        GraphNode(id: 'n1', type: 'clock', title: 'クロックメーカー', x: 10, y: 20, inputs: [NodePort(label: '間隔', value: '15秒', dataType: '数値')], outputs: [NodePort(label: 'クロック', dataType: 'クロック')]),
      ],
      edges: [GraphEdge(from: 'n1', fromPort: 0, to: 'n2', toPort: 1)],
    );
    final back = NodeGraph.fromJson((jsonDecode(jsonEncode(g.toJson())) as Map).cast<String, Object?>());
    expect(back.nodes.single.inputs.single.value, '15秒');
    expect(back.nodes.single.outputs.single.dataType, 'クロック');
    expect(back.edges.single.toPort, 1);

    // 形式ゲート (D-092): ジャンル一致が必須、format の食い違いも不可。
    const posts = NodePort(label: '投稿リスト', dataType: '投稿リスト');
    const clock = NodePort(label: 'クロック', dataType: 'クロック');
    const dicText = NodePort(label: 'テキスト(.dic)', dataType: 'テキスト', format: '.dic');
    const genericText = NodePort(label: 'テキスト', dataType: 'テキスト');
    const csvText = NodePort(label: 'テキスト(.csv)', dataType: 'テキスト', format: '.csv');
    expect(portsCompatible(posts, posts), isTrue);
    expect(portsCompatible(clock, posts), isFalse); // 色(ジャンル)違い
    expect(portsCompatible(genericText, dicText), isTrue); // 片側だけ形式指定は許容
    expect(portsCompatible(csvText, dicText), isFalse); // 形式の食い違い
  });

  testWidgets('パレット FOW: タイルタップ → 詳細 → 追加 / 長押しドラッグ → 追加、KV に保存', (tester) async {
    final container = await pump(tester);

    // フォロー中(home)タブに合わせてから設定を開く(スコープ = tl.home)。
    await tester.tap(find.text('フォロー中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    expect(find.text('タイムラインをカスタマイズ'), findsOneWidget);

    // パレットは FOW (D-092)。検索欄(検索ホームと同じデザイン)にフォーカス
    // すると展開してタイルが見える。
    expect(find.text('プラグインノードを検索'), findsOneWidget);
    await tester.tap(find.text('プラグインノードを検索'));
    await tester.pumpAndSettle();

    // タイルには 1 行の入出力情報。タップで詳細 → 「キャンバスに追加」。
    expect(find.textContaining('入力: 間隔(数値)'), findsOneWidget);
    await tester.tap(find.text('クロックメーカー'));
    await tester.pumpAndSettle();
    expect(find.text('キャンバスに追加'), findsOneWidget); // 詳細情報シート
    expect(find.text('条件(下辺)'), findsNothing); // クロックに条件接続部はない
    await tester.tap(find.text('キャンバスに追加'));
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('クロックメーカー')), findsOneWidget);

    // 長押しドラッグでキャンバスへ(ドラッグ中は FOW が最小表示へ)。
    final gesture = await tester.startGesture(tester.getCenter(find.text('ランダム').hitTestable()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // FOW(下側)より上、かつクロックメーカーのカードに被らない位置へ。
    await gesture.moveTo(const Offset(300, 170));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('ランダム')), findsOneWidget);

    // KV に保存されている(scope = tl.home)。
    final saved = (await container.read(settingsAreaProvider('nodeprog.tl.home').future))['graph'];
    expect(saved, isA<String>());
    final graph = NodeGraph.fromJson((jsonDecode(saved! as String) as Map).cast<String, Object?>());
    expect({for (final n in graph.nodes) n.type}, {'clock', 'random'});

    // ノードのクリック → ドロップダウン (D-092): コピー/ペースト/削除。
    await tester.tap(onCanvas(find.text('クロックメーカー')));
    await tester.pumpAndSettle();
    expect(find.text('ノード情報'), findsOneWidget);
    expect(find.text('プラグインストアに移動'), findsOneWidget); // 一旦無効
    await tester.tap(find.text('コピー'));
    await tester.pumpAndSettle();
    await tester.tap(onCanvas(find.text('クロックメーカー')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ペースト'));
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('クロックメーカー')), findsNWidgets(2));

    await tester.tap(onCanvas(find.text('ランダム')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('ランダム')), findsNothing);

    // 戻って開き直してもノードが残る(クロック×2)。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('クロックメーカー')), findsNWidgets(2));
  });

  testWidgets('D-096: パレット FOW を閉じても「ノードを検索」ボタンで開き直せる', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsOneWidget);

    final manager = container.read(overlayManagerProvider);
    manager.close(nodePaletteFowId);
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsNothing);

    await tester.tap(find.byTooltip('ノードを検索'));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsOneWidget);
  });

  testWidgets('コンポーザーの「投稿先のカスタマイズ」→ composer スコープのエディタ', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿先を選ぶ')); // アバタータップでタイル (D-091)
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿先のカスタマイズ'));
    await tester.pumpAndSettle();
    // 画面タイトル(コンポーザー FOW のリンクはオーバーレイ側に残る)。
    expect(find.descendant(of: find.byType(NodeEditorScreen), matching: find.text('投稿先のカスタマイズ')), findsOneWidget);
  });
}
