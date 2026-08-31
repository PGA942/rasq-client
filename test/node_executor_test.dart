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

  test('鎖が未完成なら null(実行しない)', () async {
    // タイムラインノードに何も繋がっていない。
    final g = NodeGraph(nodes: [source('n1'), timelineNode('n3')], edges: const []);
    expect(await runNodeGraph(g, fetch: fetch), isNull);
    // 取得ノードがない。
    final g2 = NodeGraph(nodes: [step('remove', 'n2'), timelineNode('n3')], edges: [data('n2', 'n3')]);
    expect(await runNodeGraph(g2, fetch: fetch), isNull);
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
