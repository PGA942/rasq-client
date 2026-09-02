import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-121: TL カスタマイズの簡略化 — SNSタイムライン + アルゴリズムの
/// コンポーネント積みを正準形ノードグラフへコンパイルする。
void main() {
  test('コンパイル: 取得×1 + 時系列順 + クロック → 正準形フルチェーン', () {
    final g = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'chrono')]), scope: 'tl.home');
    expect({for (final n in g.nodes) n.type}, {'tl.source', 'timeline', 'clock'});
    expect(g.edges.where((e) => e.toIcon).length, 1); // クロック → 取得ノードのアイコン (D-095)
    expect(nodeGraphClockInterval(g), const Duration(seconds: 15));
  });

  test('コンパイル: 取得×2 はマージ、サジェスト/TLプラグインは鎖の段に', () {
    final g = compileTlConfig(
      const TlConfig(
        sources: [TlSourceComponent(tl: 'home'), TlSourceComponent(tl: 'local', account: '@sub@other.test')],
        algorithms: [
          TlAlgorithmComponent(type: 'suggest', what: 'キーワード', from: 'リアクション'),
          TlAlgorithmComponent(type: 'plugin:dict', pluginLabel: '辞書でソート'),
        ],
        clock: '',
      ),
      scope: 'tl.home',
    );
    final types = {for (final n in g.nodes) n.type};
    expect(types, containsAll(['merge', 'sort', 'ml.gliner', 'ml.keyword', 'compare', 'plugin:dict', 'timeline']));
    expect(types, isNot(contains('clock')));
    // サジェストの基準 = リアクション済み (myreactions を TL 値に持つ取得ノード)。
    expect(g.nodes.where((n) => n.type == 'tl.source' && n.inputs.first.value == 'myreactions'), hasLength(1));
    // 鎖: merge → sort → plugin → timeline(データエッジを辿って確認)。
    String? upstreamOf(String id) => g.edges.where((e) => !e.cond && !e.toIcon && e.to == id && e.toPort == 0).firstOrNull?.from;
    final t = g.nodes.firstWhere((n) => n.type == 'timeline');
    final plugin = upstreamOf(t.id)!;
    expect(g.nodes.firstWhere((n) => n.id == plugin).type, 'plugin:dict');
    final sort = upstreamOf(plugin)!;
    expect(g.nodes.firstWhere((n) => n.id == sort).type, 'sort');
    expect(g.nodes.firstWhere((n) => n.id == upstreamOf(sort)!).type, 'merge');
  });

  test('コンパイル: 関連スコープの終端は関連タイムライン (D-102)', () {
    final g = compileTlConfig(defaultTlConfig('tl.relational'), scope: 'tl.relational');
    expect(g.nodes.where((n) => n.type == 'timeline.relational'), hasLength(1));
  });

  test('コンパイル: リスト系 → tl.list、現在のトレンドTL → trend.posts (D-122)', () {
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'list:推しの人たち'), TlSourceComponent(tl: 'trend')], algorithms: [], clock: ''),
      scope: 'tl.home',
    );
    final list = g.nodes.firstWhere((n) => n.type == 'tl.list');
    expect(list.inputs.firstWhere((p) => p.label == 'リスト').value, '推しの人たち');
    expect(g.nodes.where((n) => n.type == 'trend.posts'), hasLength(1));
    expect(g.nodes.where((n) => n.type == 'merge'), hasLength(1));
  });

  test('実行: 類似性×投稿内容のサジェストが基準に近い投稿を先頭へ', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: body);

    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'suggest', what: '類似性', from: '投稿内容')], clock: ''),
      scope: 'tl.home',
    );
    final out = await runNodeGraph(
      g,
      fetch: (kid) async => switch (kid) {
        'myposts' => [post('ref', '猫がかわいい。猫の写真を撮った')],
        _ => [post('p1', '為替と株価の話題です'), post('p2', '猫がかわいいですね猫')],
      },
    );
    expect([for (final p in out!) p.id], ['p2', 'p1']); // 猫の投稿が先頭
  });

  Future<ProviderContainer> pumpConfig(WidgetTester tester) async {
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
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('歯車 → 簡略版カスタマイズ画面: コンポーネント追加でグラフが KV へコンパイルされる', (tester) async {
    final container = await pumpConfig(tester);

    // TL の歯車は簡略版カスタマイズ画面へ (D-121: キャンバスは一旦無効化)。
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    expect(inScreen(find.text('アルゴリズム')), findsOneWidget);
    expect(inScreen(find.text('SNSタイムライン')), findsOneWidget);

    // フォロー中タブへ(スコープ = tl.home)。既定は取得×1 + 時系列順。
    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('タイムラインを取得')), findsOneWidget);
    expect(inScreen(find.text('時系列順')), findsOneWidget);

    // アルゴリズムを追加 → ノード検索 FOW (D-122): プラグインタイルで
    // 入出力ではなくネイティブ対応の SNS プラグインを表示。
    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsOneWidget);
    expect(find.textContaining('対応: Fake'), findsWidgets);
    await tester.tap(find.text('サジェスト'));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsNothing); // 追加で閉じる
    expect(inScreen(find.text('キーワードを投稿内容からサジェスト')), findsOneWidget);

    // タイムラインを追加 → FOW の選択肢は [タイムライン, リスト系,
    // 現在のトレンドTL] に絞られている (D-122)。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsOneWidget);
    expect(find.text('リスト: Fediverse Banner'), findsOneWidget);
    expect(find.text('現在のトレンドTL'), findsOneWidget);
    await tester.tap(find.text('現在のトレンドTL'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('現在のトレンドTLを取得')), findsOneWidget);

    // KV: tlcfg(コンポーネント)+ graph(正準形コンパイル、トレンドは
    // trend.posts、2 本目でマージ段)。
    final area = await container.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future);
    expect(area['tlcfg'], isA<String>());
    final graph = NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>());
    final types = {for (final n in graph.nodes) n.type};
    expect(types, containsAll(['merge', 'trend.posts', 'sort', 'ml.gliner', 'ml.keyword', 'compare', 'timeline', 'clock']));

    // アルゴリズムの … → 削除でサジェストが外れる。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの操作')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('キーワードを投稿内容からサジェスト')), findsNothing);
  });

  testWidgets('D-123: パラメーターFOW(RRL)/一時的な無効化/並べ替えシート/ジャンルチップ', (tester) async {
    final container = await pumpConfig(tester);
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    final manager = container.read(overlayManagerProvider);
    final acc = fakeSession().account.key;

    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();

    // サジェストを追加してからタイルをタップ → パラメーター FOW(RRL の
    // ラジオ)。「類似性」を選ぶとタイトルが追従する。
    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サジェスト'));
    await tester.pumpAndSettle();
    await tester.tap(inScreen(find.text('キーワードを投稿内容からサジェスト')));
    await tester.pumpAndSettle();
    expect(find.text('なにをサジェストする?'), findsOneWidget); // RRL SectionHeader
    await tester.tap(find.text('類似性'));
    await tester.pumpAndSettle();
    expect(find.text('類似性を投稿内容からサジェスト'), findsWidgets); // タイル + FOW ヘッダー
    manager.close(tlConfigParamsFowId);
    await tester.pumpAndSettle();

    // … → 一時的な無効化: タイルがグレー表記になり、コンパイルから外れる。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの操作')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
    await tester.pumpAndSettle();
    expect(find.textContaining('無効化中'), findsOneWidget);
    var area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    var types = {for (final n in NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>()).nodes) n.type};
    expect(types, isNot(contains('sort'))); // 無効化された段は消える

    // 並べ替えシート(アクションバー編集と同じ UI): 目のトグルで解除。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの並べ替え')));
    await tester.pumpAndSettle();
    expect(find.text('アルゴリズムの並べ替え'), findsWidgets); // シートタイトル
    expect(find.byIcon(Icons.drag_handle), findsWidgets);
    await tester.tap(find.byTooltip('無効化の解除'));
    await tester.pumpAndSettle();
    area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    types = {for (final n in NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>()).nodes) n.type};
    expect(types, contains('sort')); // 解除で戻る
    manager.close('tlconfig.reorder');
    await tester.pumpAndSettle();

    // ジャンルチップ (D-123): タイムライン側パレットを「リスト系」に絞る。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsOneWidget);
    await tester.tap(find.text('プラグインノードを検索')); // 検索欄フォーカスでチップ表示
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ジャンル: すべて'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リスト系').last); // ドロップダウン項目
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsNothing);
    expect(find.text('リスト: Fediverse Banner'), findsOneWidget);
  });
}
