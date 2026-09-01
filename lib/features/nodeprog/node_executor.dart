import 'dart:io';
import 'dart:math' as math;

import 'package:rasq_models/rasq_models.dart';

import '../relational/relational_engine.dart' show charNgramProfile, cosineOfProfiles, entityOverlap, extractFeatures, extractFeaturesText;
import 'node_graph.dart';

/// ノードグラフの実行 (D-094/D-097)。
///
/// 「取得ノード →(並べ替え/消去…)→ タイムライン」の**完成した鎖**が
/// あるときだけ実行し、なければ null(既定の TL のまま)。条件は縦方向の
/// 接続部で評価する: ある接続部の直下に複数ぶら下がれば **または**、条件
/// ノードの下に数珠繋ぎなら **かつ**、Not は直下の否定。
///
/// - [fetch]: 投稿リストの取得。`home` などの TL id のほか、リスト
///   `list:<名前>`・検索 `search:<ワード>`・DM `dm:<相手>` はアプリ側で解決。
/// - [fetchTrends]: トレンド取得ノード(タグの文字列配列)。
/// - [embedTexts]: SigLIP 埋め込み(ML ゲートウェイ)。null/失敗時は
///   n-gram 類似度に縮退する。
/// - [pluginSort]: TL プラグインのソートノード(`plugin:<id>`)の実体
///   (tl.sort/compose)。null なら素通し。
/// - [terminal]: 終端ノードの type。通常 TL は `timeline`、関連 TL の
///   前段絞り込み (D-102) は `timeline.relational`。
Future<List<Post>?> runNodeGraph(
  NodeGraph g, {
  required Future<List<Post>> Function(String kindId) fetch,
  Future<List<String>> Function()? fetchTrends,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<List<Post>> Function(String pluginTlId, List<Post> posts)? pluginSort,
  String terminal = 'timeline',
}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final timeline = g.nodes.where((n) => n.type == terminal).firstOrNull;
  if (timeline == null) return null;

  // タイムラインから上流(データ接続)へ遡って鎖を組む。
  final chain = <GraphNode>[];
  var current = timeline;
  final visited = <String>{timeline.id};
  while (true) {
    final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == current.id && e.toPort == 0).firstOrNull;
    if (edge == null) return null; // 鎖が途切れている → 実行しない
    final from = byId[edge.from];
    if (from == null || !visited.add(from.id)) return null; // 迷子/循環
    final sourceKind = _sourceKindOf(from);
    if (sourceKind != null) {
      final posts = await fetch(sourceKind);
      var out = posts;
      for (final step in chain.reversed) {
        out = await _applyStep(g, byId, step, out, fetchTrends: fetchTrends, embedTexts: embedTexts, pluginSort: pluginSort);
      }
      return out;
    }
    if (from.type != 'sort' && from.type != 'remove' && !from.type.startsWith('plugin:') && !from.type.startsWith('fn:')) {
      return null; // 投稿リストを繋げるのは加工ノードだけのはず
    }
    chain.add(from);
    current = from;
  }
}

/// 取得ノード (D-094/D-097) → fetch へ渡す kind id。取得ノードでなければ null。
String? _sourceKindOf(GraphNode n) {
  String value() => n.inputs.firstOrNull?.value?.trim() ?? '';
  return switch (n.type) {
    'tl.source' => value().isEmpty ? 'home' : value(),
    'tl.list' => 'list:${value()}',
    'tl.search' => 'search:${value()}',
    'tl.dm' => 'dm:${value()}',
    _ => null,
  };
}

Future<List<Post>> _applyStep(
  NodeGraph g,
  Map<String, GraphNode> byId,
  GraphNode step,
  List<Post> posts, {
  Future<List<String>> Function()? fetchTrends,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<List<Post>> Function(String pluginTlId, List<Post> posts)? pluginSort,
}) async {
  // TL プラグインのソートノード (D-102): tl.sort/compose の実体を呼ぶ。
  if (step.type.startsWith('plugin:') && pluginSort != null) {
    try {
      return await pluginSort(step.type.substring('plugin:'.length), posts);
    } catch (_) {
      return posts; // プラグイン不達は素通し
    }
  }
  switch (step.type) {
    case 'sort':
    case 'remove':
      // ML ノードのスコアは投稿一括で先に計算しておく(条件評価は同期)。
      final ctx = await _CondContext.prepare(g, byId, step.id, posts, fetchTrends: fetchTrends, embedTexts: embedTexts);
      if (step.type == 'sort') {
        // 条件に合う投稿を先頭へ(安定 — 各群の元の順序は保つ)。
        final hit = <Post>[];
        final miss = <Post>[];
        for (final p in posts) {
          (_evalCondPortAt(g, byId, step.id, p, 0, ctx) ? hit : miss).add(p);
        }
        return [...hit, ...miss];
      }
      return [for (final p in posts) if (!_evalCondPortAt(g, byId, step.id, p, 0, ctx)) p];
    default:
      // plugin:* 等はまだ実行系がない — 素通し(ストア統合/wasm 配線で実装)。
      return posts;
  }
}

/// [nodeId] の下辺の条件接続部を評価する(テスト用の公開口)。直下に何も
/// 無ければ true(制約なし)。複数ぶら下がっていれば **または**。
bool evalCondPort(NodeGraph g, Map<String, GraphNode> byId, String nodeId, Post p) => _evalCondPortAt(g, byId, nodeId, p, 0, const _CondContext.empty());

/// [branch] は下側分岐の番号 (D-099: カスタム関数は複数分岐を持てる。
/// 条件エッジの fromPort が分岐番号)。
bool _evalCondPortAt(NodeGraph g, Map<String, GraphNode> byId, String nodeId, Post p, int depth, _CondContext ctx, {int branch = 0}) {
  if (depth > 32) return true; // 深さ暴走の保険
  final children = [
    for (final e in g.edges)
      if (e.cond && e.from == nodeId && e.fromPort == branch)
        if (byId[e.to] != null) byId[e.to]!,
  ];
  if (children.isEmpty) return true;
  return children.any((c) => _nodeValue(g, byId, c, p, depth: depth + 1, ctx: ctx));
}

bool _nodeValue(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, Post p, {required int depth, required _CondContext ctx}) {
  if (depth > 32) return true;
  switch (n.type) {
    case 'cond':
      // 自分の述語 かつ 下の続き(数珠繋ぎ = かつ)。
      return _predicate(n, p) && _evalCondPortAt(g, byId, n.id, p, depth, ctx);
    case 'compare':
      // 演算子条件 (D-097): 値元(数値ノード)としきい値の比較。
      return _comparePredicate(g, byId, n, p, ctx) && _evalCondPortAt(g, byId, n.id, p, depth, ctx);
    case 'not':
      // 直下の否定。何も繋いでいない Not は「常に false」(空 = true の否定)。
      return !_evalCondPortAt(g, byId, n.id, p, depth, ctx);
    default:
      // カスタム関数 (D-099) v1: 各分岐(または)を全分岐で「かつ」。
      // 中身の実行はプラグイン/RAi 配線で置き換える。
      if (n.type.startsWith('fn:') && n.condOutCount > 0) {
        for (var b = 0; b < n.condOutCount; b++) {
          if (!_evalCondPortAt(g, byId, n.id, p, depth, ctx, branch: b)) return false;
        }
        return true;
      }
      return true;
  }
}

// ---- 数値ソース (D-097) -----------------------------------------------------

bool _comparePredicate(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, Post p, _CondContext ctx) {
  final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
  final source = edge == null ? null : byId[edge.from];
  if (source == null) return true; // 値元が未接続 → 制約なし
  final v = _numericOf(source, p, ctx);
  if (v == null) return true;
  String cfg(String label, String fallback) => n.inputs.where((i) => i.label == label).firstOrNull?.value ?? fallback;
  final t = num.tryParse(cfg('値', ''));
  if (t == null) return true;
  return switch (cfg('演算', '以上')) {
    '以下' => v <= t,
    '等しい' => (v - t).abs() < 1e-9,
    _ => v >= t,
  };
}

double? _numericOf(GraphNode s, Post p, _CondContext ctx) => switch (s.type) {
      'ml.similar' || 'ml.keyword' => ctx.scores[s.id]?[p.key],
      'random' => nodeRandomValue(s, p),
      _ => null,
    };

/// ランダムノード (D-097): 投稿ごとの決定的乱数。シード + 投稿キーのハッシュ
/// なので同じ TL では安定する。範囲「a-b」は整数なら両端含む整数、どちらかが
/// 小数点を含めば小数(桁は範囲表記に合わせる)。
double nodeRandomValue(GraphNode n, Post p) {
  String cfg(String label, String fallback) => n.inputs.where((i) => i.label == label).firstOrNull?.value ?? fallback;
  final seed = cfg('シード', 'randomseed');
  final range = cfg('範囲', '1-7');
  final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[-〜~]\s*(-?\d+(?:\.\d+)?)\s*$').firstMatch(range);
  var lo = 1.0, hi = 7.0;
  var decimals = 0;
  if (m != null) {
    lo = double.parse(m.group(1)!);
    hi = double.parse(m.group(2)!);
    if (lo > hi) (lo, hi) = (hi, lo);
    int places(String s) => s.contains('.') ? s.length - s.indexOf('.') - 1 : 0;
    decimals = math.max(places(m.group(1)!), places(m.group(2)!));
  }
  final h = Object.hash(seed, p.key) & 0xFFFFF;
  final frac = h / 0x100000; // [0, 1)
  if (decimals == 0) {
    final n0 = lo.round();
    final n1 = hi.round();
    return (n0 + (frac * (n1 - n0 + 1)).floor().clamp(0, n1 - n0)).toDouble();
  }
  final v = lo + frac * (hi - lo);
  final scale = math.pow(10, decimals).toDouble();
  return (v * scale).roundToDouble() / scale;
}

// ---- ML スコアの事前計算 (D-097) ---------------------------------------------

class _CondContext {
  const _CondContext(this.scores);
  const _CondContext.empty() : scores = const {};

  /// ML ノード id → 投稿キー → スコア。
  final Map<String, Map<String, double>> scores;

  /// [stepId] の条件木にぶら下がる比較ノードの値元(ML ノード)を集めて、
  /// 投稿一括でスコアを計算しておく。
  static Future<_CondContext> prepare(
    NodeGraph g,
    Map<String, GraphNode> byId,
    String stepId,
    List<Post> posts, {
    Future<List<String>> Function()? fetchTrends,
    Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  }) async {
    // 条件木を BFS で辿って比較ノードを集める。
    final queue = <String>[stepId];
    final seen = <String>{stepId};
    final mlNodes = <GraphNode>[];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      for (final e in g.edges) {
        if (!e.cond || e.from != id || !seen.add(e.to)) continue;
        final child = byId[e.to];
        if (child == null) continue;
        queue.add(child.id);
        if (child.type == 'compare') {
          final src = g.edges.where((x) => !x.cond && !x.toIcon && x.to == child.id && x.toPort == 0).firstOrNull;
          final ml = src == null ? null : byId[src.from];
          if (ml != null && (ml.type == 'ml.similar' || ml.type == 'ml.keyword')) mlNodes.add(ml);
        }
      }
    }
    if (mlNodes.isEmpty) return const _CondContext.empty();

    final scores = <String, Map<String, double>>{};
    for (final ml in mlNodes) {
      if (scores.containsKey(ml.id)) continue;
      final refs = await _textSources(g, byId, ml, fetchTrends: fetchTrends);
      if (refs.isEmpty) continue; // 基準なし → スコアなし(比較は制約なしに落ちる)
      scores[ml.id] = ml.type == 'ml.similar' ? await _similarScores(refs, posts, embedTexts) : _keywordScores(refs, posts);
    }
    return _CondContext(scores);
  }
}

/// ML ノードのテキスト入力を解決する: 値ボックス + 接続元(ファイルリーダー
/// のファイル内容 / トレンド取得のタグ配列)。
Future<List<String>> _textSources(NodeGraph g, Map<String, GraphNode> byId, GraphNode ml, {Future<List<String>> Function()? fetchTrends}) async {
  final out = <String>[];
  final own = ml.inputs.firstOrNull?.value?.trim() ?? '';
  if (own.isNotEmpty) out.add(own);
  for (final e in g.edges) {
    if (e.cond || e.toIcon || e.to != ml.id) continue;
    final src = byId[e.from];
    if (src == null) continue;
    if (src.type == 'file') {
      final path = src.inputs.firstOrNull?.value?.trim() ?? '';
      if (path.isEmpty) continue;
      try {
        final resolved = path.startsWith('~') ? path.replaceFirst('~', Platform.environment['HOME'] ?? '') : path;
        final text = await File(resolved).readAsString();
        if (text.trim().isNotEmpty) out.add(text);
      } catch (_) {} // 読めないファイルは無視
    } else if (src.type == 'trend.tags' && fetchTrends != null) {
      try {
        out.addAll((await fetchTrends()).where((t) => t.trim().isNotEmpty));
      } catch (_) {}
    }
  }
  return out;
}

/// SigLIP cos 類似度(基準は複数なら最良値)。ゲートウェイ不達/失敗時は
/// n-gram 類似度に縮退する。
Future<Map<String, double>> _similarScores(List<String> refs, List<Post> posts, Future<List<List<double>>> Function(List<String>)? embedTexts) async {
  if (embedTexts != null) {
    try {
      final embs = await embedTexts([...refs, for (final p in posts) p.body]);
      double cos(List<double> a, List<double> b) {
        var dot = 0.0, na = 0.0, nb = 0.0;
        final len = math.min(a.length, b.length);
        for (var i = 0; i < len; i++) {
          dot += a[i] * b[i];
          na += a[i] * a[i];
          nb += b[i] * b[i];
        }
        return na == 0 || nb == 0 ? 0 : dot / (math.sqrt(na) * math.sqrt(nb));
      }

      return {
        for (var i = 0; i < posts.length; i++)
          posts[i].key: [for (var r = 0; r < refs.length; r++) cos(embs[r], embs[refs.length + i])].reduce(math.max),
      };
    } catch (_) {
      // 縮退へ
    }
  }
  final profiles = [for (final r in refs) charNgramProfile(r)];
  return {
    for (final p in posts) p.key: [for (final r in profiles) cosineOfProfiles(r, charNgramProfile(p.body))].reduce(math.max),
  };
}

/// キーワード一致 (GLiNER 系): 基準の特徴語と投稿の特徴語の重なり数。
Map<String, double> _keywordScores(List<String> refs, List<Post> posts) {
  final refFeatures = <String>{for (final r in refs) ...extractFeaturesText(r)};
  return {for (final p in posts) p.key: entityOverlap(refFeatures, extractFeatures(p)).toDouble()};
}

/// クロック接続 (D-095): クロックメーカーの出力が**どこかのノードの
/// アイコン**に繋がっていれば、その「間隔」を返す(TL の自動更新周期)。
/// 未接続なら null。間隔は `15秒` / `2分` / `30` などを解釈し、最短 10 秒。
Duration? nodeGraphClockInterval(NodeGraph g) {
  final byId = {for (final n in g.nodes) n.id: n};
  for (final e in g.edges) {
    if (!e.toIcon) continue;
    final clock = byId[e.from];
    if (clock == null || clock.type != 'clock') continue;
    return parseClockInterval(clock.inputs.firstOrNull?.value ?? '');
  }
  return null;
}

/// `15秒`/`2分`/`30s`/`1m`/`30` → Duration(最短 10 秒、既定 15 秒)。
Duration parseClockInterval(String raw) {
  final m = RegExp(r'(\d+)').firstMatch(raw);
  if (m == null) return const Duration(seconds: 15);
  final n = int.parse(m.group(1)!);
  final minutes = raw.contains('分') || raw.contains('m');
  final seconds = minutes ? n * 60 : n;
  return Duration(seconds: seconds < 10 ? 10 : seconds);
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
