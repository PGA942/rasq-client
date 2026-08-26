/// 重み付き無向グラフの Louvain 法によるコミュニティ分割 (D-024)。
///
/// 入力は隣接マップ `{node: {neighbor: weight}}`(対称)。標準の 2 段
/// (ローカル移動 → コミュニティの縮約)を改善が無くなるまで繰り返す。
/// フォロイー数は高々数百なので素朴な実装で十分。
Map<String, int> louvain(Map<String, Map<String, double>> graph) {
  if (graph.isEmpty) return const {};

  // 現在の「スーパーノード」グラフと、元ノード → スーパーノードの対応。
  var current = {for (final e in graph.entries) e.key: Map<String, double>.from(e.value)};
  var membership = {for (final k in graph.keys) k: k};

  for (var level = 0; level < 10; level++) {
    final community = _localMove(current);
    // 全ノードが自分のコミュニティのまま = 収束。
    final changed = community.entries.any((e) => e.value != e.key);
    // 元ノードの所属を更新。
    membership = {for (final e in membership.entries) e.key: community[e.value]!};
    if (!changed) break;
    current = _aggregate(current, community);
  }

  // コミュニティ id を 0..n-1 に正規化。
  final ids = <String, int>{};
  final out = <String, int>{};
  for (final e in membership.entries) {
    out[e.key] = ids.putIfAbsent(e.value, () => ids.length);
  }
  return out;
}

/// フェーズ1: 各ノードを、モジュラリティ利得が最大の隣接コミュニティへ動かす。
Map<String, String> _localMove(Map<String, Map<String, double>> graph) {
  final nodes = graph.keys.toList();
  final community = {for (final n in nodes) n: n};
  final degree = {for (final n in nodes) n: graph[n]!.values.fold(0.0, (a, b) => a + b)};
  final totalWeight = degree.values.fold(0.0, (a, b) => a + b) / 2;
  if (totalWeight == 0) return community;
  // コミュニティごとの次数和。
  final communityDegree = {for (final n in nodes) n: degree[n]!};

  var moved = true;
  for (var pass = 0; pass < 10 && moved; pass++) {
    moved = false;
    for (final node in nodes) {
      final home = community[node]!;
      final k = degree[node]!;
      // 隣接コミュニティごとの接続重み。
      final links = <String, double>{};
      graph[node]!.forEach((neighbor, w) {
        if (neighbor == node) return;
        final c = community[neighbor]!;
        links[c] = (links[c] ?? 0) + w;
      });
      // いったん自分のコミュニティから抜いて ΔQ を比べる(標準の局所移動)。
      communityDegree[home] = communityDegree[home]! - k;
      double gainOf(String c) => (links[c] ?? 0) - communityDegree[c]! * k / (2 * totalWeight);

      var bestCommunity = home;
      var bestGain = gainOf(home);
      for (final c in links.keys) {
        if (c == home) continue;
        final g = gainOf(c);
        if (g > bestGain + 1e-9) {
          bestGain = g;
          bestCommunity = c;
        }
      }

      communityDegree[bestCommunity] = communityDegree[bestCommunity]! + k;
      if (bestCommunity != home) {
        community[node] = bestCommunity;
        moved = true;
      }
    }
  }
  return community;
}

/// フェーズ2: コミュニティをスーパーノードに縮約したグラフを作る。
/// コミュニティ内部の重みは**自己ループとして保持**する(捨てると次レベルで
/// スーパーノードの次数が消え、弱い橋 1 本でも併合されてしまう)。
Map<String, Map<String, double>> _aggregate(Map<String, Map<String, double>> graph, Map<String, String> community) {
  final out = <String, Map<String, double>>{};
  graph.forEach((node, edges) {
    final cn = community[node]!;
    final row = out.putIfAbsent(cn, () => {});
    edges.forEach((neighbor, w) {
      final cm = community[neighbor]!;
      row[cm] = (row[cm] ?? 0) + w; // cn == cm は自己ループに積む(双方向で 2w)
    });
  });
  return out;
}
