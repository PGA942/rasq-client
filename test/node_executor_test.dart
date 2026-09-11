import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-094: ノードグラフの実行 — タイムライン取得 → 並べ替え/消去(条件は
/// 縦接続: 数珠繋ぎ = かつ、並列 = または、Not = 否定)→ タイムライン。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body, {int reactions = 0, int media = 0, DateTime? at}) => Post(
      id: id,
      account: acc,
      author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: at ?? DateTime(2026, 8, 31),
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

  test('指向性/刺激性 (D-153): プロファイルの適合度で 消去 → 並べ替え(簡略 UI のコンパイル)', () async {
    final profile = const TendencyProfile(genres: ['広告'], directionality: 0.0, disliked: ['猫']).toJson();
    final g = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'tendency')]), scope: 'tl.social');
    expect(g.nodes.where((n) => n.type == 'ml.tendency').length, 1);
    final out = await runNodeGraph(g, fetch: fetch, storageRead: (slot) async => slot == TendencyProfile.slot ? profile : null);
    // 広告に合う p1/p3 だけ残り(狭い)、猫は嫌いなジャンルで消える。
    expect([for (final p in out!) p.id], ['p1', 'p3']);
    // プロファイルが無ければ比較が不成立 = 全部消える側に倒れず、鎖は動く(消去は not(不成立)= 全消去を避けるため素通し)。
    final none = await runNodeGraph(g, fetch: fetch, storageRead: (_) async => null);
    expect(none, isNotNull);
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

    // 比較の値元が未接続/値が取れないときは False (D-105: 全消し事故防止)。
    g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), timelineNode('n3'), step('compare', 'x3')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'x3')],
    );
    expect((await runNodeGraph(g, fetch: fetchMl))!, hasLength(mlPosts.length)); // 何も消えない
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

  test('マージ (D-106): 複数の投稿リストを時刻降順で 1 本へ(重複除外)', () async {
    final listA = [post('a1', 'A新しい', at: DateTime(2026, 9, 1, 12)), post('dup', '共通', at: DateTime(2026, 9, 1, 10))];
    final listB = [post('b1', 'B最新', at: DateTime(2026, 9, 1, 13)), post('dup', '共通', at: DateTime(2026, 9, 1, 10)), post('b2', 'B古い', at: DateTime(2026, 9, 1, 9))];
    GraphNode src(String id, String tl) {
      final base = step('tl.source', id);
      return base.copyWith(inputs: [base.inputs[0].copyWith(value: tl)]);
    }

    final g = NodeGraph(
      nodes: [src('n1', 'home'), src('n2', 'local'), step('merge', 'm1'), timelineNode('n3')],
      edges: [
        const GraphEdge(from: 'n1', fromPort: 0, to: 'm1', toPort: 0),
        const GraphEdge(from: 'n2', fromPort: 0, to: 'm1', toPort: 1),
        data('m1', 'n3'),
      ],
    );
    final out = await runNodeGraph(g, fetch: (kid) async => kid == 'home' ? listA : listB);
    expect([for (final p in out!) p.id], ['b1', 'a1', 'dup', 'b2']); // 時刻降順・重複 1 回
  });

  test('トレンド検索結果取得 (D-106): 上位タグを検索して合流', () async {
    final asked = <String>[];
    final base = step('trend.posts', 't1');
    final t = base.copyWith(inputs: [base.inputs[0].copyWith(value: '2')]);
    final g = NodeGraph(nodes: [t, timelineNode('n3')], edges: [data('t1', 'n3')]);
    final out = await runNodeGraph(
      g,
      fetch: (kid) async {
        asked.add(kid);
        return kid == 'search:x' ? [post('x1', 'xの投稿', at: DateTime(2026, 9, 1, 10))] : [post('y1', 'yの投稿', at: DateTime(2026, 9, 1, 11))];
      },
      fetchTrends: () async => ['x', 'y', 'z'],
    );
    expect(asked, ['search:x', 'search:y']); // タグ数 2 で打ち切り
    expect([for (final p in out!) p.id], ['y1', 'x1']);
  });

  test('アカウント指定 (D-109): 取得ノードのアカウントが kind に包まれて渡る', () async {
    final asked = <String>[];
    Future<List<Post>> capture(String kid) async {
      asked.add(kid);
      return posts;
    }

    final base = step('tl.source', 'n1');
    GraphNode withAccount(String acct) => base.copyWith(inputs: [
          base.inputs.firstWhere((i) => i.label == 'TL').copyWith(value: 'home'),
          base.inputs.firstWhere((i) => i.label == 'アカウント').copyWith(value: acct),
        ]);

    // アカウント指定あり → `acct:<表記>|home`。
    var g = NodeGraph(nodes: [withAccount('@second@example.test'), timelineNode('n3')], edges: [data('n1', 'n3')]);
    await runNodeGraph(g, fetch: capture);
    expect(asked, ['acct:@second@example.test|home']);

    // 「現在のアカウント」/空はそのまま。
    asked.clear();
    g = NodeGraph(nodes: [withAccount('現在のアカウント'), timelineNode('n3')], edges: [data('n1', 'n3')]);
    await runNodeGraph(g, fetch: capture);
    expect(asked, ['home']);
  });

  test('リアクション済み取得 (D-103): fetch へ myreactions を渡す', () async {
    final asked = <String>[];
    final g = NodeGraph(nodes: [step('tl.myreactions', 'n1'), timelineNode('n3')], edges: [data('n1', 'n3')]);
    final out = await runNodeGraph(g, fetch: (kid) async {
      asked.add(kid);
      return posts;
    });
    expect(asked, ['myreactions']);
    expect(out, posts);
  });

  test('storage.safe (D-104): GLiNER/SigLIP の結果を保存 → 読み出してローカルTLを絞り込む(おすすめレシピ)', () async {
    final mlPosts = [post('m1', 'ラーメン食べたい'), post('m2', '猫がかわいい'), post('m3', '今日のラーメンは最高'), post('m4', 'ねむい')];
    Future<List<Post>> fetchMl(String kid) async => mlPosts;
    final store = <String, Object?>{};

    // ① 保存グラフ: リアクション済み(の代わりに固定 posts)→ GLiNER抽出/
    //   SigLIP埋め込み → 保存(slot: profile)。終端の鎖が無くても保存は走る。
    GraphNode slotted(String type, String id, String slot) {
      final base = step(type, id);
      return base.copyWith(inputs: [base.inputs[0].copyWith(value: slot), ...base.inputs.skip(1)]);
    }

    final saveGraph = NodeGraph(
      nodes: [step('tl.myreactions', 'n1'), step('ml.gliner', 'k1'), step('ml.siglip', 's1'), slotted('storage.save', 'w1', 'profile')],
      edges: [
        data('n1', 'k1'), data('n1', 's1'),
        const GraphEdge(from: 'k1', fromPort: 0, to: 'w1', toPort: 1), // 特徴語 → テキスト配列
        const GraphEdge(from: 's1', fromPort: 0, to: 'w1', toPort: 2), // 埋め込み → ベクトル
      ],
    );
    final saved = await runNodeGraph(saveGraph, fetch: fetchMl, storageWrite: (slot, value) async => store[slot] = value, storageRead: (s) async => store[s]);
    expect(saved, isNull); // TL 終端はない
    final payload = (store['profile'] as Map).cast<String, Object?>();
    expect((payload['texts'] as List).cast<String>(), contains('ラーメン'));
    expect((payload['vector'] as Map)['kind'], 'ngram'); // ゲートウェイなし → n-gram 縮退

    // ② 絞り込みグラフ: 読み出し → キーワード一致 → 比較(以上 1)→ 並べ替え。
    final filterGraph = NodeGraph(
      nodes: [source('n1'), step('sort', 'n2'), timelineNode('n3'), step('compare', 'x1'), step('ml.keyword', 'k2'), slotted('storage.load', 'r1', 'profile')],
      edges: [
        data('n1', 'n2'), data('n2', 'n3'),
        condEdge('n2', 'x1'),
        const GraphEdge(from: 'k2', fromPort: 0, to: 'x1', toPort: 0),
        const GraphEdge(from: 'r1', fromPort: 0, to: 'k2', toPort: 1), // 読み出したテキスト配列 → キーワードリスト
      ],
    );
    final sorted = await runNodeGraph(filterGraph, fetch: fetchMl, storageRead: (s) async => store[s], storageWrite: (s, v) async => store[s] = v);
    expect(sorted!.first.body, contains('ラーメン')); // プロファイルに合う投稿が先頭

    // ③ ベクトル基準: 読み出し → 類似度(基準ベクトル、相対値 0〜1) →
    //   比較(以上 0.5)→ 並べ替え: プロファイルに似た投稿が先頭へ。
    final vecGraph = NodeGraph(
      nodes: [source('n1'), step('sort', 'n2'), timelineNode('n3'), step('compare', 'x2'), step('ml.similar', 'sim'), slotted('storage.load', 'r2', 'profile')],
      edges: [
        data('n1', 'n2'), data('n2', 'n3'),
        condEdge('n2', 'x2'),
        const GraphEdge(from: 'sim', fromPort: 0, to: 'x2', toPort: 0),
        const GraphEdge(from: 'r2', fromPort: 1, to: 'sim', toPort: 2), // ベクトル → 基準ベクトル
      ],
    );
    final byVec = await runNodeGraph(vecGraph, fetch: fetchMl, storageRead: (s) async => store[s], storageWrite: (s, v) async => store[s] = v);
    expect(byVec!.first.body, contains('ラーメン')); // 相対値の最大 = ラーメン系が先頭

    // ④ 保存は終端評価より先 (D-105): 同じグラフの保存 → 読み出しが 1 回の
    //   実行で繋がる(空ストアから 1 発でソートが効く)。
    final store2 = <String, Object?>{};
    final oneShot = NodeGraph(
      nodes: [
        step('tl.myreactions', 'r0'), step('ml.gliner', 'k0'), slotted('storage.save', 'w0', 'p2'),
        source('n1'), step('sort', 'n2'), timelineNode('n3'), step('compare', 'x0'), step('ml.keyword', 'k9'), slotted('storage.load', 'l0', 'p2'),
      ],
      edges: [
        data('r0', 'k0'),
        const GraphEdge(from: 'k0', fromPort: 0, to: 'w0', toPort: 1),
        data('n1', 'n2'), data('n2', 'n3'),
        condEdge('n2', 'x0'),
        const GraphEdge(from: 'k9', fromPort: 0, to: 'x0', toPort: 0),
        const GraphEdge(from: 'l0', fromPort: 0, to: 'k9', toPort: 1),
      ],
    );
    final oneShotOut = await runNodeGraph(oneShot, fetch: fetchMl, storageRead: (s) async => store2[s], storageWrite: (s, v) async => store2[s] = v);
    expect(store2['p2'], isNotNull); // 保存が走っている
    expect(oneShotOut!.first.body, contains('ラーメン')); // 同一実行で読めている
  });

  test('終端タイプ (D-102): 関連タイムラインノードは terminal 指定でだけ実行される', () async {
    final relTerminal = builtinNodeCatalog.firstWhere((e) => e.type == 'timeline.relational').instantiate('n3', Offset.zero);
    final g = NodeGraph(
      nodes: [source('n1'), step('remove', 'n2'), relTerminal, cond('c1', value: '広告')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    expect(await runNodeGraph(g, fetch: fetch), isNull); // 通常 TL 終端では実行しない
    final out = await runNodeGraph(g, fetch: fetch, terminal: 'timeline.relational');
    expect([for (final p in out!) p.id], ['p2', 'p4']); // 前段絞り込みとして動く
  });

  test('plugin ソートノード (D-102): tl.sort の実体(コールバック)が呼ばれる', () async {
    const pluginNode = GraphNode(id: 'g1', type: 'plugin:rank', title: 'ランキング順でソート', x: 0, y: 0, inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')], outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')]);
    final g = NodeGraph(
      nodes: [source('n1'), pluginNode, timelineNode('n3')],
      edges: [data('n1', 'g1'), data('g1', 'n3')],
    );
    final asked = <String>[];
    final out = await runNodeGraph(g, fetch: fetch, pluginSort: (id, posts, params) async {
      asked.add(id);
      return posts.reversed.toList();
    });
    expect(asked, ['rank']);
    expect([for (final p in out!) p.id], ['p4', 'p3', 'p2', 'p1']);
    // コールバック無しは素通し。
    expect([for (final p in (await runNodeGraph(g, fetch: fetch))!) p.id], ['p1', 'p2', 'p3', 'p4']);
  });

  test('カタログ追従 (D-113): 旧ノードに追加入力(アカウント等)と選択肢が入る', () {
    // D-109 以前の保存形: tl.source は TL 入力しか持っていない。
    const old = NodeGraph(nodes: [
      GraphNode(id: 'n1', type: 'tl.source', title: 'タイムライン取得', x: 0, y: 0, inputs: [NodePort(label: 'TL', value: 'social', dataType: '設定')], outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')]),
    ]);
    final catalog = {for (final e in builtinNodeCatalog) e.type: e};
    final up = upgradeGraphNodes(old, catalog).nodes.single;
    expect(up.inputs.map((i) => i.label), ['TL', 'アカウント']); // 追加入力が末尾に付く
    expect(up.inputs.first.value, 'social'); // 既存の設定値は保持
    expect(up.inputs.first.options, isNotNull); // 選択肢もカタログから
  });

  test('トレンド枠 (D-113): テキスト配列の終端 runNodeGraphTexts', () async {
    GraphNode inst(String type, String id) => builtinNodeCatalog.firstWhere((e) => e.type == type).instantiate(id, Offset.zero);
    final g = NodeGraph(
      nodes: [inst('trend.tags', 't1'), inst('trend.frame', 'f1')],
      edges: [const GraphEdge(from: 't1', fromPort: 0, to: 'f1', toPort: 0)],
    );
    final tags = await runNodeGraphTexts(g, terminal: 'trend.frame', fetchTrends: () async => ['猫', 'ラーメン']);
    expect(tags, ['猫', 'ラーメン']);
    // 鎖なし → null(既定のトレンドのまま)。
    expect(await runNodeGraphTexts(const NodeGraph(), terminal: 'trend.frame', fetchTrends: () async => ['x']), isNull);
  });

  test('バンドル自動構成 (D-114): アカウント列 → 取得×N + マージ段 + タイムライン', () async {
    // 2 アカウント: マージ 1 段。
    final g2 = buildBundleGraph(['@a@x.test', '@b@x.test']);
    expect(g2.nodes.where((n) => n.type == 'tl.source'), hasLength(2));
    expect(g2.nodes.where((n) => n.type == 'merge'), hasLength(1));
    expect(g2.nodes.where((n) => n.type == 'timeline'), hasLength(1));
    final asked = <String>[];
    final out = await runNodeGraph(g2, fetch: (kid) async {
      asked.add(kid);
      return [post(kid.hashCode.toString(), kid, at: DateTime(2026, 9, 1, asked.length))];
    });
    expect(asked.toSet(), {'acct:@a@x.test|home', 'acct:@b@x.test|home'});
    expect(out, hasLength(2));

    // 5 アカウント: マージ段組み(3 口 → 前段 + 2)で全部合流する。
    final g5 = buildBundleGraph([for (var i = 0; i < 5; i++) '@u$i@x.test']);
    expect(g5.nodes.where((n) => n.type == 'merge').length, greaterThanOrEqualTo(2));
    final asked5 = <String>[];
    final out5 = await runNodeGraph(g5, fetch: (kid) async {
      asked5.add(kid);
      return [post('p${asked5.length}', kid, at: DateTime(2026, 9, 1, asked5.length))];
    });
    expect(out5, hasLength(5));

    // ユーザー編集後の差し込み: マージに空き口があれば新アカウントを接続。
    final inserted = insertAccountIntoBundleGraph(g2, '@c@x.test');
    expect(inserted, isNotNull);
    final askedIns = <String>[];
    final outIns = await runNodeGraph(inserted!, fetch: (kid) async {
      askedIns.add(kid);
      return [post('q${askedIns.length}', kid, at: DateTime(2026, 9, 1, askedIns.length))];
    });
    expect(askedIns.toSet(), contains('acct:@c@x.test|home'));
    expect(outIns, hasLength(3));
    // 満杯(3 口使用済み)なら null。
    expect(insertAccountIntoBundleGraph(inserted, '@d@x.test'), isNull);
  });

  testWidgets('ノードTLタブ (D-101): node: タブの中身はグラフ実行結果', (tester) async {
    final srcBase = builtinNodeCatalog.firstWhere((e) => e.type == 'tl.source').instantiate('n1', Offset.zero);
    final src = srcBase.copyWith(inputs: [srcBase.inputs[0].copyWith(value: 'home')]);
    final graph = NodeGraph(
      nodes: [src, step('remove', 'n2'), timelineNode('n3'), cond('c1', value: '消して')],
      edges: [data('n1', 'n2'), data('n2', 'n3'), condEdge('n2', 'c1')],
    );
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
      'nodeprog.tabs.v1': jsonEncode({'list': jsonEncode([{'id': 'node:1', 'label': 'マイTL'}])}),
      'nodeprog.tl.node:1.v1': jsonEncode({'graph': jsonEncode(graph.toJson())}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: (v) => [post('a1', '残る投稿'), post('a2', '消しての投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('マイTL'));
    await tester.pumpAndSettle();
    expect(find.text('残る投稿'), findsOneWidget);
    expect(find.text('消しての投稿'), findsNothing);
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

  test('マージ: 別アカウントに流れてきた同じ投稿は 1 枚に畳んで ↓ の選択肢へ (D-115)', () async {
    const accB = AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'tester2');
    const someone = UserSummary(id: 'u9', account: AccountId(kind: SnsKind.misskey, instance: 'origin.test', handle: 'someone'), displayName: '同一人物');
    final at = DateTime(2026, 9, 1);
    final copyA = Post(id: 'a1', account: acc, author: someone, createdAt: at, body: '同じ投稿');
    final copyB = Post(id: 'b1', account: accB, author: someone, createdAt: at, body: '同じ投稿');
    final onlyB = Post(id: 'b2', account: accB, author: someone, createdAt: at, body: 'こっちだけ');

    final srcA = source('n1');
    final rawB = source('n2');
    final srcB = rawB.copyWith(inputs: [rawB.inputs[0].copyWith(value: 'local'), rawB.inputs[1]]);
    final g = NodeGraph(
      nodes: [srcA, srcB, step('merge', 'm1'), timelineNode('n3')],
      edges: [data('n1', 'm1'), const GraphEdge(from: 'n2', fromPort: 0, to: 'm1', toPort: 1), data('m1', 'n3')],
    );

    Post? kept;
    final dropped = <Post>[];
    final out = await runNodeGraph(
      g,
      fetch: (kid) async => kid == 'local' ? [copyB, onlyB] : [copyA],
      onDuplicate: (k, d) {
        kept = k;
        dropped.add(d);
      },
    );
    expect({for (final p in out!) p.id}, {'a1', 'b2'}); // 中身が同じ b1 は畳まれる
    expect(kept!.id, 'a1');
    expect([for (final p in dropped) p.id], ['b1']);
  });

  test('カスタム関数の中身: 関数入力 → 消去 → 関数出力 が実行される (D-118)', () async {
    const fnType = 'fn:test1';
    final fnNode = GraphNode(
        id: 'f1',
        type: fnType,
        title: '広告おとし',
        x: 0,
        y: 0,
        inputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
        outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')]);
    final g = NodeGraph(nodes: [source('n1'), fnNode, timelineNode('n3')], edges: [data('n1', 'f1'), data('f1', 'n3')]);
    final body = NodeGraph(
      nodes: [step('fn.input', 'b1'), step('remove', 'b2'), step('fn.output', 'b3'), cond('c1', value: '広告')],
      edges: [data('b1', 'b2'), data('b2', 'b3'), condEdge('b2', 'c1')],
    );
    final out = await runNodeGraph(g, fetch: fetch, loadFunction: (id) async => id == fnType ? body : null);
    expect([for (final p in out!) p.id], ['p2', 'p4']);

    // 中身なし(未編集)の関数は素通し。
    final plain = await runNodeGraph(g, fetch: fetch, loadFunction: (_) async => null);
    expect(plain!.length, posts.length);
  });

  test('カスタム関数の自己再帰は素通しになる(無限ループしない) (D-118)', () async {
    const fnType = 'fn:test2';
    GraphNode fnAt(String id) => GraphNode(
        id: id,
        type: fnType,
        title: '再帰',
        x: 0,
        y: 0,
        inputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
        outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')]);
    final g = NodeGraph(nodes: [source('n1'), fnAt('f1'), timelineNode('n3')], edges: [data('n1', 'f1'), data('f1', 'n3')]);
    // 中身に自分自身が置かれている → 内側の自分は素通し(ガード)。
    final body = NodeGraph(nodes: [step('fn.input', 'b1'), fnAt('b2'), step('fn.output', 'b3')], edges: [data('b1', 'b2'), data('b2', 'b3')]);
    final out = await runNodeGraph(g, fetch: fetch, loadFunction: (_) async => body);
    expect(out!.length, posts.length);
  });

  test('マージ: 失敗した枝は捨てて残りの枝だけで合流する (D-117)', () async {
    final rawB = source('n2');
    final srcB = rawB.copyWith(inputs: [rawB.inputs[0].copyWith(value: 'local'), rawB.inputs[1]]);
    final g = NodeGraph(
      nodes: [source('n1'), srcB, step('merge', 'm1'), timelineNode('n3')],
      edges: [data('n1', 'm1'), const GraphEdge(from: 'n2', fromPort: 0, to: 'm1', toPort: 1), data('m1', 'n3')],
    );
    final out = await runNodeGraph(g, fetch: (kid) async => kid == 'local' ? throw StateError('接続不可') : posts);
    expect(out!.length, posts.length); // local 枝の失敗で TL 全体は死なない
  });

  test('ポスト先ノード: 下書き内容の条件で投稿先が上から順に選ばれる (D-116)', () async {
    GraphNode target(String id, String account, Offset at) {
      final base = builtinNodeCatalog.firstWhere((e) => e.type == 'composer.target').instantiate(id, at);
      return base.copyWith(inputs: [base.inputs[0].copyWith(value: account)]);
    }

    // 上: 条件付き(本文に「ネタバレ」)→ サブ垢。下: 条件なし = デフォルト。
    final g = NodeGraph(
      nodes: [target('t1', '@sub@other.test', const Offset(0, 0)), target('t2', '@main@example.test', const Offset(0, 120)), cond('c1', value: 'ネタバレ')],
      edges: [condEdge('t1', 'c1')],
    );
    expect(await composerTargetAccounts(g, post('d1', 'ネタバレ注意です')), ['@sub@other.test', '@main@example.test']);
    expect(await composerTargetAccounts(g, post('d2', 'ただのあいさつ')), ['@main@example.test']);
  });
}
