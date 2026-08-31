import 'package:rasq_models/rasq_models.dart';

import 'node_graph.dart';

/// ノードグラフの実行 (D-094)。
///
/// 「タイムライン取得 →(並べ替え/消去…)→ タイムライン」の**完成した鎖**が
/// あるときだけ実行し、なければ null(既定の TL のまま)。条件は縦方向の
/// 接続部で評価する: ある接続部の直下に複数ぶら下がれば **または**、条件
/// ノードの下に数珠繋ぎなら **かつ**、Not は直下の否定。
Future<List<Post>?> runNodeGraph(NodeGraph g, {required Future<List<Post>> Function(String kindId) fetch}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final timeline = g.nodes.where((n) => n.type == 'timeline').firstOrNull;
  if (timeline == null) return null;

  // タイムラインから上流(データ接続)へ遡って鎖を組む。
  final chain = <GraphNode>[];
  var current = timeline;
  final visited = <String>{timeline.id};
  while (true) {
    final edge = g.edges.where((e) => !e.cond && e.to == current.id && e.toPort == 0).firstOrNull;
    if (edge == null) return null; // 鎖が途切れている → 実行しない
    final from = byId[edge.from];
    if (from == null || !visited.add(from.id)) return null; // 迷子/循環
    if (from.type == 'tl.source') {
      final posts = await fetch(from.inputs.firstOrNull?.value ?? 'home');
      var out = posts;
      for (final step in chain.reversed) {
        out = _applyStep(g, byId, step, out);
      }
      return out;
    }
    if (from.type != 'sort' && from.type != 'remove' && !from.type.startsWith('plugin:')) {
      return null; // 投稿リストを繋げるのは加工ノードだけのはず
    }
    chain.add(from);
    current = from;
  }
}

List<Post> _applyStep(NodeGraph g, Map<String, GraphNode> byId, GraphNode step, List<Post> posts) {
  switch (step.type) {
    case 'sort':
      // 条件に合う投稿を先頭へ(安定 — 各群の元の順序は保つ)。
      final hit = <Post>[];
      final miss = <Post>[];
      for (final p in posts) {
        (evalCondPort(g, byId, step.id, p) ? hit : miss).add(p);
      }
      return [...hit, ...miss];
    case 'remove':
      return [for (final p in posts) if (!evalCondPort(g, byId, step.id, p)) p];
    default:
      // plugin:* 等はまだ実行系がない — 素通し(ストア統合/wasm 配線で実装)。
      return posts;
  }
}

/// [nodeId] の下辺の条件接続部を評価する。直下に何も無ければ true
/// (制約なし)。複数ぶら下がっていれば **または**。
bool evalCondPort(NodeGraph g, Map<String, GraphNode> byId, String nodeId, Post p) => _evalCondPortAt(g, byId, nodeId, p, 0);

bool _evalCondPortAt(NodeGraph g, Map<String, GraphNode> byId, String nodeId, Post p, int depth) {
  if (depth > 32) return true; // 深さ暴走の保険
  final children = [
    for (final e in g.edges)
      if (e.cond && e.from == nodeId)
        if (byId[e.to] != null) byId[e.to]!,
  ];
  if (children.isEmpty) return true;
  return children.any((c) => _nodeValue(g, byId, c, p, depth: depth + 1));
}

bool _nodeValue(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, Post p, {required int depth}) {
  if (depth > 32) return true;
  switch (n.type) {
    case 'cond':
      // 自分の述語 かつ 下の続き(数珠繋ぎ = かつ)。
      return _predicate(n, p) && _evalCondPortAt(g, byId, n.id, p, depth);
    case 'not':
      // 直下の否定。何も繋いでいない Not は「常に false」(空 = true の否定)。
      return !_evalCondPortAt(g, byId, n.id, p, depth);
    default:
      return true;
  }
}

/// 条件ノードの述語: 指定タグの内容 × 演算 × 値。
bool _predicate(GraphNode n, Post p) {
  String cfg(String label, String fallback) => n.inputs.where((i) => i.label == label).firstOrNull?.value ?? fallback;
  final tag = cfg('タグ', '本文');
  final op = cfg('演算', '含む');
  final value = cfg('値', '');

  final (text, number) = switch (tag) {
    '本文' => (p.body, null),
    '名前' => ('${p.author.displayName} @${p.author.handle}', null),
    '注釈' => (p.contentWarning ?? '', null),
    'リアクション' => ('', p.reactions.values.fold<int>(0, (a, b) => a + b)),
    '画像' => ('', p.media.length),
    _ => (p.body, null),
  };
  final numValue = num.tryParse(value);
  switch (op) {
    case '含む':
      return number == null ? value.isNotEmpty && text.contains(value) : '$number'.contains(value);
    case '等しい':
      return number == null ? text == value : (numValue != null && number == numValue);
    case '以上':
      final left = number ?? num.tryParse(text);
      return left != null && numValue != null && left >= numValue;
    case '以下':
      final left = number ?? num.tryParse(text);
      return left != null && numValue != null && left <= numValue;
  }
  return false;
}
