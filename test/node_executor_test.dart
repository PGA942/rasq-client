import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-094: ノードグラフの実行 — タイムライン取得 → 並べ替え/消去(条件は
/// 縦接続: 数珠繋ぎ = かつ、並列 = または、Not = 否定)→ タイムライン。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body, {int reactions = 0, int media = 0}) => Post(
      id: id,
      account: acc,
      author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: DateTime(2026, 8, 31),
      body: body,
      reactions: reactions == 0 ? const {} : {'👍': reactions},
      media: [for (var i = 0; i < media; i++) MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://x.invalid/$i.png'))]);

  GraphNode source(String id) => builtinNodeCatalog.firstWhere((e) => e.type == 'tl.source').instantiate(id, Offset.zero);
  GraphNode step(String type, String id) => builtinNodeCatalog.firstWhere((e) => e.type == type).instantiate(id, Offset.zero);
  GraphNode timelineNode(String id) => builtinNodeCatalog.firstWhere((e) => e.type == 'timeline').instantiate(id, Offset.zero);
  GraphNode cond(String id, {String tag = '本文', String op = '含む', String value = ''}) {
    final base = builtinNodeCatalog.firstWhere((e) => e.type == 'cond').instantiate(id, Offset.zero);
    return base.copyWith(inputs: [
      base.inputs[0].copyWith(value: tag),
      base.inputs[1].copyWith(value: op),
      base.inputs[2].copyWith(value: value),
    ]);
  }

  GraphEdge data(String from, String to) => GraphEdge(from: from, fromPort: 0, to: to, toPort: 0);
  GraphEdge condEdge(String from, String to) => GraphEdge(from: from, fromPort: 0, to: to, toPort: 0, cond: true);

  final posts = [post('p1', '広告です', reactions: 1), post('p2', 'ふつうの投稿', reactions: 5), post('p3', '広告とセール', media: 2), post('p4', '猫')];
  Future<List<Post>> fetch(String kid) async => posts;

  test('消去: 条件(本文 含む)に合う投稿が消える', () async {
    final g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), cond('c1', value: '広告')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    final out = await runNodeGraph(g, fetch: fetch);
    expect([for (final p in out!) p.id], ['p2', 'p4']);
  });

  test('並べ替え: 条件に合う投稿が先頭(安定)', () async {
    final g = NodeGraph(
      nodes: [source('n1'), step('sort', 'n2'), timelineNode('n3'), cond('c1', tag: 'リアクション', op: '以上', value: '1')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    final out = await runNodeGraph(g, fetch: fetch);
    expect([for (final p in out!) p.id], ['p1', 'p2', 'p3', 'p4']); // 反応あり(p1,p2)が先頭・各群は元順
  });

  test('数珠繋ぎ = かつ / 並列 = または / Not = 否定', () async {
    // かつ: 「広告」かつ「セール」→ p3 だけ消える。
    var g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), cond('c1', value: '広告'), cond('c2', value: 'セール')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1'), condEdge('c1', 'c2')],
    );
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2', 'p4']);

    // または: 「セール」または「猫」→ p3, p4 が消える。
    g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), cond('c1', value: 'セール'), cond('c2', value: '猫')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1'), condEdge('n2', 'c2')],
    );
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2']);

    // Not: 「広告を含まない」→ p2, p4 が消える(残るのは広告)。
    final not = step('not', 'x1');
    g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), not, cond('c1', value: '広告')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'x1'), condEdge('x1', 'c1')],
    );
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p3']);

    // 画像タグ: 画像 1 枚以上を消す → p3 が消える。
    g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), cond('c1', tag: '画像', op: '以上', value: '1')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2', 'p4']);
  });

  test('クロック → アイコン接続 (D-095): 間隔の解釈、鎖はそのまま動く', () async {
    final clockBase = builtinNodeCatalog.firstWhere((e) => e.type == 'clock').instantiate('k1', Offset.zero);
    final clock30 = clockBase.copyWith(inputs: [clockBase.inputs[0].copyWith(value: '30秒')]);
    final g = NodeGraph(
      nodes: [source('n1'), step('sort', 'n2'), timelineNode('n3'), clock30],
      edges: [
        data('n1', 'n2'),
        data('n2', 'n3'),
        const GraphEdge(from: 'k1', fromPort: 0, to: 'n1', toPort: 0, toIcon: true), // クロック → 取得ノードのアイコン
      ],
    );
    expect(nodeGraphClockInterval(g), const Duration(seconds: 30));
    // toIcon エッジは鎖の遡りに混ざらない — 実行結果は素通し(条件なし sort)。
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2', 'p3', 'p4']);

    // 間隔の解釈: 分/既定/最短クランプ。
    expect(parseClockInterval('15秒'), const Duration(seconds: 15));
    expect(parseClockInterval('2分'), const Duration(minutes: 2));
    expect(parseClockInterval('5'), const Duration(seconds: 10)); // 最短 10 秒
    expect(parseClockInterval(''), const Duration(seconds: 15)); // 既定
    // クロック未接続なら null。
    expect(nodeGraphClockInterval(NodeGraph(nodes: [clock30], edges: const [])), isNull);
  });

  test('鎖が未完成なら null(実行しない)', () async {
    // タイムラインノードに何も繋がっていない。
    final g = NodeGraph(nodes: [source('n1'), timelineNode('n3')], edges: const []);
    expect(await runNodeGraph(g, fetch: fetch), isNull);
    // 取得ノードがない。
    final g2 = NodeGraph(nodes: [step('remove', 'n2'), timelineNode('n3')], edges: [data('n2', 'n3')]);
    expect(await runNodeGraph(g2, fetch: fetch), isNull);
  });

  test('取得系 (D-097): リスト/検索/DM ノードは kind を組み立てて fetch へ渡す', () async {
    final asked = <String>[];
    Future<List<Post>> capture(String kid) async {
      asked.add(kid);
      return posts;
    }

    GraphNode withValue(String type, String id, String value) {
      final base = step(type, id);
      return base.copyWith(inputs: [base.inputs[0].copyWith(value: value), ...base.inputs.skip(1)]);
    }

    for (final (type, value, expected) in [('tl.search', 'わんこ', 'search:わんこ'), ('tl.list', '推し', 'list:推し'), ('tl.dm', 'yamada', 'dm:yamada')]) {
      asked.clear();
      final g = NodeGraph(nodes: [withValue(type, 'n1', value), timelineNode('n3')], edges: [data('n1', 'n3')]);
      expect(await runNodeGraph(g, fetch: capture), posts);
      expect(asked, [expected]);
    }
  });

  test('ランダム範囲 (D-097): 整数レンジは整数、小数点入りは小数、決定的', () {
    final base = builtinNodeCatalog.firstWhere((e) => e.type == 'random').instantiate('r1', Offset.zero);
    GraphNode withRange(String range) => base.copyWith(inputs: [base.inputs[0], base.inputs[1].copyWith(value: range)]);

    for (final p in posts) {
      final v = nodeRandomValue(withRange('1-7'), p);
      expect(v, inInclusiveRange(1, 7));
      expect(v, v.roundToDouble()); // 整数
      expect(nodeRandomValue(withRange('1-7'), p), v); // 決定的
      final d = nodeRandomValue(withRange('0-1.5'), p);
      expect(d, inInclusiveRange(0, 1.5));
      expect((d * 10).roundToDouble() / 10, d); // 小数第 1 位まで
    }
    // シードを変えると系列が変わる(全投稿一致はまず起きない)。
    final other = base.copyWith(inputs: [base.inputs[0].copyWith(value: 'べつのシード'), base.inputs[1]]);
    expect([for (final p in posts) nodeRandomValue(other, p)], isNot([for (final p in posts) nodeRandomValue(base, p)]));
  });

  test('比較 + ML (D-097): キーワード一致(トレンド供給)とn-gram類似度で条件ソート', () async {
    final mlPosts = [post('m1', 'ラーメン食べたい'), post('m2', '猫がかわいい'), post('m3', '今日のラーメンは最高'), post('m4', 'ねむい')];
    Future<List<Post>> fetchMl(String kid) async => mlPosts;

    // トレンド(['ラーメン'])→ キーワード一致 → 比較(以上 1)→ 消去。
    var g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), step('compare', 'x1'), step('ml.keyword', 'k1'), step('trend.tags', 't1')],
      edges: [
        data('n1', 'n2'), data('n2', 'n3'),
        condEdge('n2', 'x1'),
        const GraphEdge(from: 'k1', fromPort: 0, to: 'x1', toPort: 0), // 一致度 → 値元
        const GraphEdge(from: 't1', fromPort: 0, to: 'k1', toPort: 1), // タグ → キーワードリスト
      ],
    );
    var out = await runNodeGraph(g, fetch: fetchMl, fetchTrends: () async => ['ラーメン']);
    expect([for (final p in out!) p.id], ['m2', 'm4']); // ラーメン投稿が消える

    // 類似度(基準 'ラーメン大好き')→ 比較(以上 0.2)→ 並べ替え(ヒットが先頭)。
    final simBase = step('ml.similar', 's1');
    final sim = simBase.copyWith(inputs: [simBase.inputs[0].copyWith(value: 'ラーメン大好き'), ...simBase.inputs.skip(1)]);
    final cmpBase = step('compare', 'x2');
    final cmp = cmpBase.copyWith(inputs: [cmpBase.inputs[0], cmpBase.inputs[1], cmpBase.inputs[2].copyWith(value: '0.2')]);
    g = NodeGraph(
      nodes: [source('n1'), step('sort', 'n2'), timelineNode('n3'), cmp, sim],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'x2'), const GraphEdge(from: 's1', fromPort: 0, to: 'x2', toPort: 0)],
    );
    out = await runNodeGraph(g, fetch: fetchMl);
    expect(out!.first.body, contains('ラーメン')); // 類似の高い投稿が先頭
    expect([for (final p in out) p.id]..sort(), ['m1', 'm2', 'm3', 'm4']..sort()); // 消えてはいない

    // 比較の値元が未接続なら制約なし(何も消えない)。
    g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), step('compare', 'x3')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'x3')],
    );
    // 制約なし = 全部 true = remove は全消し(条件なしの remove と同じ挙動)。
    expect((await runNodeGraph(g, fetch: fetchMl))!, isEmpty);
  });

  test('カスタム関数 (D-099): 条件型は分岐ごとに「または」を取り、全分岐で「かつ」', () async {
    final fnEntry = const CustomFunctionDef(id: 'fn:1', name: 'テスト関数', kind: 'cond', tags: ['本文', '画像']).toCatalogEntry();
    expect(fnEntry.condBranches, ['本文', '画像']);
    final fn = fnEntry.instantiate('f1', Offset.zero);
    expect(fn.condOutCount, 2);

    // remove ← fn(分岐0: 本文含む「広告」/ 分岐1: 画像 1 枚以上)
    // → 「広告」かつ「画像あり」の p3 だけ消える。
    final g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), fn, cond('c1', value: '広告'), cond('c2', tag: '画像', op: '以上', value: '1')],
      edges: [
        data('n1', 'n2'), data('n2', 'n3'),
        condEdge('n2', 'f1'),
        const GraphEdge(from: 'f1', fromPort: 0, to: 'c1', toPort: 0, cond: true),
        const GraphEdge(from: 'f1', fromPort: 1, to: 'c2', toPort: 0, cond: true),
      ],
    );
    final out = await runNodeGraph(g, fetch: fetch);
    expect([for (final p in out!) p.id], ['p1', 'p2', 'p4']); // p3(広告 + 画像2枚)だけ消える

    // 空の分岐は「制約なし」: 分岐1 を外すと本文「広告」だけで消える。
    final g2 = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), fn, cond('c1', value: '広告')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'f1'), const GraphEdge(from: 'f1', fromPort: 0, to: 'c1', toPort: 0, cond: true)],
    );
    expect([for (final p in (await runNodeGraph(g2, fetch: fetch))!) p.id], ['p2', 'p4']);
  });

  test('カスタム関数 (D-099): データ型(投稿リスト入出力)は鎖に挟めて素通し', () async {
    final fn = const CustomFunctionDef(id: 'fn:2', name: '素通し', kind: 'data', inputs: ['投稿リスト'], outputs: ['投稿リスト']).toCatalogEntry().instantiate('f2', Offset.zero);
    final g = NodeGraph(
      nodes: [source('n1'), fn, timelineNode('n3')],
      edges: [data('n1', 'f2'), data('f2', 'n3')],
    );
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2', 'p3', 'p4']);
  });

  testWidgets('TL 反映: tl.home のグラフ(消去)がフォロー中タブに効く', (tester) async {
    final graph = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), cond('c1', value: '消して')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
      // ノードグラフは KV `nodeprog.<scope>.v1` (D-090)。
      'nodeprog.tl.home.v1': jsonEncode({'graph': jsonEncode(graph.toJson())}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: (v) => [post('a1', '残る投稿'), post('a2', '消しての投稿'), post('a3', 'これも残る')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('フォロー中'));
    await tester.pumpAndSettle();
    expect(find.text('残る投稿'), findsOneWidget);
    expect(find.text('これも残る'), findsOneWidget);
    expect(find.text('消しての投稿'), findsNothing);
  });
}
