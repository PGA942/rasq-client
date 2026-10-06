import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:rasq_models/rasq_models.dart';

import '../home/post_duplicates.dart' show postDupKey;
import '../relational/relational_engine.dart' show charNgramProfile, cosineOfProfiles, entityOverlap, extractFeatures, extractFeaturesText;
import '../trend/tendency_profile.dart';
import 'node_graph.dart';
import 'tl_components.dart' show rasqListKindPrefix, rasqSearchKindPrefix;

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
/// - [embedTexts]: 文の埋め込み(ML ゲートウェイの SigLIP か、端末の RASQ MiniLM)。null/失敗時は
///   n-gram 類似度に縮退する。
/// - [embedPosts]: 投稿の埋め込み(端末の本文 + 画像、D-390)。あれば投稿側はこちら([embedTexts] と同じ空間)。
/// - [pluginSort]: TL プラグインのソートノード(`plugin:<id>`)の実体
///   (tl.sort/compose)。null なら素通し。
/// - [storageRead]/[storageWrite]: storage.safe (D-104) の読み書き。保存
///   ノードは**鎖の成立に関係なく**毎実行走る(プロファイル保存グラフ)。
/// - [terminal]: 終端ノードの type。通常 TL は `timeline`、関連 TL の
///   前段絞り込み (D-102) は `timeline.relational`。
/// - [onDuplicate]: マージ (D-115) が中身比較で畳んだコピーの通知
///   (残したコピー, 隠したコピー)。↓(アカウント選択)の選択肢に回す用。
/// - [loadFunction]: カスタム関数 (D-118) の中身グラフ(fn.input → … →
///   fn.output)の読み込み。null/中身なしの関数は素通し。
Future<List<Post>?> runNodeGraph(
  NodeGraph g, {
  required Future<List<Post>> Function(String kindId) fetch,
  Future<List<String>> Function()? fetchTrends,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<List<List<double>>> Function(List<Post> posts)? embedPosts,
  Future<List<Post>> Function(String pluginTlId, List<Post> posts, Map<String, Object?> params)? pluginSort,
  Future<Object?> Function(String slot)? storageRead,
  Future<void> Function(String slot, Object? value)? storageWrite,
  void Function(Post kept, Post dropped)? onDuplicate,
  Future<NodeGraph?> Function(String fnId)? loadFunction,
  String? selfQuery,
  String terminal = 'timeline',
}) async {
  final env = _ExecEnv(
      fetch: fetch, fetchTrends: fetchTrends, embedTexts: embedTexts, embedPosts: embedPosts, pluginSort: pluginSort, storageRead: storageRead, storageWrite: storageWrite, onDuplicate: onDuplicate, loadFunction: loadFunction, selfQuery: selfQuery);
  // 何か → 設定 (D-236): 設定ポートに繋がれたテキスト / テキスト配列を先に評価して値ボックスへ入れる。
  g = await _materializeSettings(g, env);
  final byId = {for (final n in g.nodes) n.id: n};

  // storage.safe 保存ノード (D-104/D-105): **終端評価より先に**書く — 同じ
  // グラフ内の「読み出し」が同一実行で新しいプロファイルを見られるように。
  if (storageWrite != null) {
    for (final n in g.nodes) {
      if (n.type != 'storage.save') continue;
      try {
        await _execSave(g, byId, n, env);
      } catch (_) {} // 保存失敗で TL は落とさない
    }
  }

  // 終端は複数置けることがある(組み替え中など) — **完成した鎖が最初に
  // 成立したもの**を採用する (D-105)。
  for (final timeline in g.nodes.where((n) => n.type == terminal)) {
    final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == timeline.id && e.toPort == 0).firstOrNull;
    final up = edge == null ? null : byId[edge.from];
    if (up == null) continue;
    final result = await _postsOutOf(g, byId, up, env, 0);
    if (result != null) return result;
  }
  return null;
}

/// 実行環境(コールバック束)。
class _ExecEnv {
  const _ExecEnv(
      {required this.fetch, this.fetchTrends, this.embedTexts, this.embedPosts, this.pluginSort, this.storageRead, this.storageWrite, this.onDuplicate, this.loadFunction, this.selfQuery, this.fnInput, this.fnStack = const {}});
  final Future<List<Post>> Function(String kindId) fetch;
  final Future<List<String>> Function()? fetchTrends;
  final Future<List<List<double>>> Function(List<String> texts)? embedTexts;
  final Future<List<List<double>>> Function(List<Post> posts)? embedPosts;
  final Future<List<Post>> Function(String pluginTlId, List<Post> posts, Map<String, Object?> params)? pluginSort;
  final Future<Object?> Function(String slot)? storageRead;
  final Future<void> Function(String slot, Object? value)? storageWrite;
  final void Function(Post kept, Post dropped)? onDuplicate;
  final Future<NodeGraph?> Function(String fnId)? loadFunction;

  /// このページの検索ワード/タグ (D-125: 検索絞り込みノードの既定値)。
  final String? selfQuery;

  /// 関数の中身の実行中 (D-118): 「関数入力」ノードに束縛された投稿リストと、
  /// 実行中の関数 id の集合(自己再帰/循環の素通しガード)。
  final List<Post>? fnInput;
  final Set<String> fnStack;

  _ExecEnv enterFunction(String fnId, List<Post> input) => _ExecEnv(
      fetch: fetch,
      fetchTrends: fetchTrends,
      embedTexts: embedTexts,
      embedPosts: embedPosts,
      pluginSort: pluginSort,
      storageRead: storageRead,
      storageWrite: storageWrite,
      onDuplicate: onDuplicate,
      loadFunction: loadFunction,
      selfQuery: selfQuery,
      fnInput: input,
      fnStack: {...fnStack, fnId});
}

/// 取得ノード (D-094/D-097/D-103) → fetch へ渡す kind id。取得ノードで
/// なければ null。「アカウント」指定 (D-109) があると `acct:<表記>|<kind>` に
/// 包んで渡す(どのアカウントのセッションで取るかはアプリ側で解決)。
String? _sourceKindOf(GraphNode n) {
  String input(String label) => n.inputs.where((i) => i.label == label).firstOrNull?.value?.trim() ?? '';
  final base = switch (n.type) {
    'tl.source' => input('TL').isEmpty ? 'home' : input('TL'),
    'tl.list' => 'list:${input('リスト')}',
    'tl.feed' => 'feed:${input('フィード')}',
    'tl.rasqlist' => '$rasqListKindPrefix${input('リスト')}',
    'tl.search' => 'search:${input('検索ワード')}',
    'tl.dm' => 'dm:${input('相手')}',
    'tl.myreactions' => 'myreactions',
    _ => null,
  };
  if (base == null) return null;
  return _withAccount(n, base);
}

/// ワードの無い検索 (`search:`、D-440) を、このページの検索ワード / タグの検索にする(`acct:` で包まれていても)。
/// ページのワードが無ければそのまま(空の検索 = 何も取らない)。
String withPageQuery(String kind, String? pageQuery) {
  final q = pageQuery?.trim() ?? '';
  if (q.isEmpty || !kind.endsWith('search:')) return kind;
  final bare = kind.startsWith('acct:') ? kind.substring(kind.indexOf('|') + 1) : kind;
  // RASQ 検索 (D-449) もワードが空ならこのページのワードで。
  return bare == 'search:' || bare == rasqSearchKindPrefix ? '$kind$q' : kind;
}

/// 「アカウント」入力 (D-109) を kind id に包む。空/「現在のアカウント」は
/// そのまま(現在 or 持ち主のセッション)。
String _withAccount(GraphNode n, String kind) {
  final acct = n.inputs.where((i) => i.label == 'アカウント').firstOrNull?.value?.trim() ?? '';
  if (acct.isEmpty || acct == '現在のアカウント') return kind;
  return 'acct:$acct|$kind';
}

/// [n] の投稿リスト出力を再帰評価する(取得 → 加工の任意の形)。
Future<List<Post>?> _postsOutOf(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env, int depth) async {
  if (depth > 16) return null;
  final sourceKind = _sourceKindOf(n);
  if (sourceKind != null) return env.fetch(withPageQuery(sourceKind, env.selfQuery));
  // 関数入力 (D-118): 関数の中身の実行中は束縛された投稿リストを出す。
  if (n.type == 'fn.input') return env.fnInput;
  // マージ (D-106): 全入力の投稿リストを時刻順に 1 本へ(重複除外)。
  // 枝ごとに独立して評価し、失敗した枝(アカウント不達など)は捨てて
  // 残りだけで合流する (D-117: 1 枝の失敗で TL 全体を殺さない)。
  if (n.type == 'merge') {
    final lists = <List<Post>>[];
    for (final e in g.edges) {
      if (e.cond || e.toIcon || e.to != n.id) continue;
      final up = byId[e.from];
      if (up == null) continue;
      try {
        final posts = await _postsOutOf(g, byId, up, env, depth + 1);
        if (posts != null) lists.add(posts);
      } catch (_) {}
    }
    if (lists.isEmpty) return null;
    return mergePostLists(lists, onDuplicate: env.onDuplicate);
  }
  // トレンド検索結果取得 (D-106): 上位タグを検索して合流。
  if (n.type == 'trend.posts') {
    if (env.fetchTrends == null) return null;
    try {
      final count = int.tryParse(n.inputs.firstOrNull?.value?.trim() ?? '') ?? 3;
      final tags = (await env.fetchTrends!()).take(count.clamp(1, 10)).toList();
      if (tags.isEmpty) return const [];
      final lists = <List<Post>>[];
      for (final tag in tags) {
        try {
          lists.add(await env.fetch(_withAccount(n, 'search:$tag')));
        } catch (_) {}
      }
      return mergePostLists(lists, onDuplicate: env.onDuplicate);
    } catch (_) {
      return null;
    }
  }
  if (n.type == 'sort' || n.type == 'remove' || n.type == 'filter.query' || n.type.startsWith('plugin:') || n.type.startsWith('fn:')) {
    final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
    final up = edge == null ? null : byId[edge.from];
    if (up == null) return null;
    final posts = await _postsOutOf(g, byId, up, env, depth + 1);
    if (posts == null) return null;
    return _applyStep(g, byId, n, posts, env);
  }
  return null;
}

/// 複数の投稿リストを時刻降順で 1 本に合流する。重複は 2 段階で畳む:
/// 同一アカウント内は著者キー+投稿 id、アカウント違いの同じ投稿は中身比較
/// ([postDupKey], D-115)。中身で畳んだコピーは [onDuplicate] へ渡す
/// (↓ のアカウント選択肢に回す — 同一アカウント内の重複は黙って捨てる)。
List<Post> mergePostLists(List<List<Post>> lists, {void Function(Post kept, Post dropped)? onDuplicate}) {
  final seen = <String>{};
  final byDup = <String, Post>{};
  final out = <Post>[];
  for (final list in lists) {
    for (final p in list) {
      if (!seen.add('${p.author.key}/${p.id}')) continue;
      final kept = byDup[postDupKey(p)];
      if (kept != null) {
        onDuplicate?.call(kept, p);
        continue;
      }
      byDup[postDupKey(p)] = p;
      out.add(p);
    }
  }
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

/// プラグインノードの「パラメーター」ポート (D-169) を Map に戻す。
Map<String, Object?> pluginParamsOf(GraphNode n) {
  final raw = n.inputs.where((p) => p.label == 'パラメーター').firstOrNull?.value;
  if (raw == null || raw.isEmpty) return const {};
  try {
    return (jsonDecode(raw) as Map).cast<String, Object?>();
  } catch (_) {
    return const {};
  }
}

Future<List<Post>> _applyStep(NodeGraph g, Map<String, GraphNode> byId, GraphNode step, List<Post> posts, _ExecEnv env) async {
  // TL プラグインのソートノード (D-102): tl.sort/compose の実体を呼ぶ。
  if (step.type.startsWith('plugin:') && env.pluginSort != null) {
    try {
      // パラメーター (D-169): 「パラメーター」ポートの値(JSON)。ノードを設定 FOW の RRL で編集したもの。
      return await env.pluginSort!(step.type.substring('plugin:'.length), posts, pluginParamsOf(step));
    } catch (_) {
      return posts; // プラグイン不達は素通し
    }
  }
  switch (step.type) {
    case 'filter.query':
      // 検索絞り込み (D-125): ワードが空ならこのページの検索ワード/タグ。
      final raw = step.inputs.where((i) => i.label == '検索ワード').firstOrNull?.value?.trim() ?? '';
      final word = (raw.isEmpty ? (env.selfQuery ?? '') : raw).replaceFirst(RegExp(r'^#'), '').toLowerCase();
      if (word.isEmpty) return posts;
      // 除外 (D-227): ワードを含む投稿を落とす(ワードミュート)。
      final exclude = step.inputs.where((i) => i.label == '除外').firstOrNull?.value?.trim() == 'true';
      bool hit(Post p) => p.body.toLowerCase().contains(word) || p.author.displayName.toLowerCase().contains(word) || (p.contentWarning ?? '').toLowerCase().contains(word);
      return [for (final p in posts) if (hit(p) != exclude) p];
    case 'sort':
    case 'remove':
      // ML ノードのスコアは投稿一括で先に計算しておく(条件評価は同期)。
      final ctx = await _CondContext.prepare(g, byId, step.id, posts, env);
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
      // データ型カスタム関数 (D-118): 中身のサブグラフ(fn.input → … →
      // fn.output)があれば実行する。中身なし/読めない/循環は素通し。
      if (step.type.startsWith('fn:') && env.loadFunction != null && !env.fnStack.contains(step.type)) {
        try {
          final body = await env.loadFunction!(step.type);
          if (body != null) {
            final result = await _runFunctionBody(body, step.type, posts, env);
            if (result != null) return result;
          }
        } catch (_) {}
      }
      return posts;
  }
}

/// カスタム関数の中身 (D-118): 「関数入力」に [input] を束縛して
/// 「関数出力」に繋がった鎖を評価する。成立した鎖が無ければ null(素通し)。
Future<List<Post>?> _runFunctionBody(NodeGraph body, String fnId, List<Post> input, _ExecEnv outer) async {
  final byId = {for (final n in body.nodes) n.id: n};
  final env = outer.enterFunction(fnId, input);
  for (final t in body.nodes.where((n) => n.type == 'fn.output')) {
    final edge = body.edges.where((e) => !e.cond && !e.toIcon && e.to == t.id && e.toPort == 0).firstOrNull;
    final up = edge == null ? null : byId[edge.from];
    if (up == null) continue;
    final result = await _postsOutOf(body, byId, up, env, 0);
    if (result != null) return result;
  }
  return null;
}

// ---- 結果ノード / storage.safe (D-104) --------------------------------------

/// [n] のテキスト配列出力を評価する(トレンド/GLiNER抽出/読み出し)。
Future<List<String>?> _textArrayOutOf(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  switch (n.type) {
    case 'trend.tags':
      if (env.fetchTrends == null) return null;
      try {
        return [for (final t in await env.fetchTrends!()) if (t.trim().isNotEmpty) t];
      } catch (_) {
        return null;
      }
    case 'ml.gliner':
      final posts = await _upstreamPosts(g, byId, n, env);
      if (posts == null) return null;
      return topFeaturesOf(posts);
    case 'storage.load':
      final payload = await _loadSlot(g, n, env);
      final texts = payload?['texts'];
      return texts is List ? texts.cast<String>() : null;
    case 'convert.split':
      // 変換 (D-235): 上流のテキストを区切りで配列に。
      final text = await _upstreamText(g, byId, n, env);
      if (text == null) return null;
      final sep = _separatorOf(n);
      return [for (final t in text.split(sep)) if (t.trim().isNotEmpty) t.trim()];
  }
  return null;
}

/// 設定ポートの駆動 (D-236): 設定ポートへの辺があれば、上流のテキスト(テキスト配列は改行で結合)で
/// 値を置き換えたグラフを返す。上流が評価できなければ元の値のまま。
Future<NodeGraph> _materializeSettings(NodeGraph g, _ExecEnv env) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final incoming = [for (final e in g.edges) if (!e.cond && !e.toIcon && (byId[e.to]?.inputs.elementAtOrNull(e.toPort)?.dataType == '設定')) e];
  if (incoming.isEmpty) return g;
  final nodes = <String, GraphNode>{...byId};
  for (final e in incoming) {
    final up = byId[e.from];
    final to = nodes[e.to];
    if (up == null || to == null) continue;
    String? value = await _textOutOf(g, byId, up, env);
    value ??= (await _textArrayOutOf(g, byId, up, env))?.join('\n');
    if (value == null) continue;
    nodes[e.to] = to.copyWith(inputs: [for (final (i, p) in to.inputs.indexed) i == e.toPort ? p.copyWith(value: value) : p]);
  }
  return NodeGraph(nodes: [for (final n in g.nodes) nodes[n.id] ?? n], edges: g.edges);
}

/// [n] の投稿 1 件の出力 (D-236): `list.first`(投稿リストの何番目か)。
Future<Post?> _postOutOf(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  if (n.type != 'list.first') return null;
  final posts = await _upstreamPosts(g, byId, n, env);
  if (posts == null || posts.isEmpty) return null;
  final idx = (int.tryParse(n.inputs.where((i) => i.label == '番号').firstOrNull?.value?.trim() ?? '1') ?? 1).clamp(1, posts.length);
  return posts[idx - 1];
}

/// 区切りの設定(改行 / カンマ / 空白)→ 実際の区切り。
Pattern _separatorOf(GraphNode n) => switch (n.inputs.where((i) => i.label == '区切り').firstOrNull?.value?.trim()) {
      'カンマ' => RegExp(r'[,、，]'),
      '空白' => RegExp(r'\s+'),
      _ => RegExp(r'\r?\n'),
    };

String _joinerOf(GraphNode n) => switch (n.inputs.where((i) => i.label == '区切り').firstOrNull?.value?.trim()) { 'カンマ' => ',', '空白' => ' ', _ => '\n' };

/// [n] のテキスト出力 (D-235): テキスト定数 / ファイルリーダー / 結合。
Future<String?> _textOutOf(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  switch (n.type) {
    case 'text.const':
      final v = n.inputs.firstOrNull?.value?.trim() ?? '';
      return v.isEmpty ? null : v;
    case 'file':
      final path = n.inputs.firstOrNull?.value?.trim() ?? '';
      if (path.isEmpty) return null;
      try {
        final resolved = path.startsWith('~') ? path.replaceFirst('~', Platform.environment['HOME'] ?? '') : path;
        final text = await File(resolved).readAsString();
        return text.trim().isEmpty ? null : text;
      } catch (_) {
        return null; // 読めないファイルは無視
      }
    case 'convert.join':
      final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
      final up = edge == null ? null : byId[edge.from];
      if (up == null) return null;
      final texts = await _textArrayOutOf(g, byId, up, env);
      if (texts == null || texts.isEmpty) return null;
      return texts.join(_joinerOf(n));
    case 'post.text':
      // 投稿の本文 (D-236): 上流の投稿 1 件。
      final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
      final up = edge == null ? null : byId[edge.from];
      if (up == null) return null;
      final post = await _postOutOf(g, byId, up, env);
      final body = post?.body.trim() ?? '';
      return body.isEmpty ? null : body;
  }
  return null;
}

/// 入力 0 番に繋がるノードのテキスト。
Future<String?> _upstreamText(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
  final up = edge == null ? null : byId[edge.from];
  return up == null ? null : _textOutOf(g, byId, up, env);
}

/// [n] のベクトル出力を評価する(SigLIP埋め込み/読み出し)。
/// 形は `{kind: 'siglip', v: [...]}` か `{kind: 'ngram', p: {...}}`。
Future<Map<String, Object?>?> _vectorOutOf(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  switch (n.type) {
    case 'ml.siglip':
      final posts = await _upstreamPosts(g, byId, n, env);
      if (posts == null || posts.isEmpty) return null;
      return profileVectorOf(posts, env.embedTexts, embedPosts: env.embedPosts);
    case 'storage.load':
      final payload = await _loadSlot(g, n, env);
      final v = payload?['vector'];
      return v is Map ? v.cast<String, Object?>() : null;
  }
  return null;
}

Future<List<Post>?> _upstreamPosts(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == n.id && e.toPort == 0).firstOrNull;
  final up = edge == null ? null : byId[edge.from];
  if (up == null) return null;
  return _postsOutOf(g, byId, up, env, 0);
}

Future<Map<String, Object?>?> _loadSlot(NodeGraph g, GraphNode n, _ExecEnv env) async {
  final slot = n.inputs.where((i) => i.label == 'スロット').firstOrNull?.value?.trim() ?? '';
  if (slot.isEmpty || env.storageRead == null) return null;
  final raw = await env.storageRead!(slot);
  return raw is Map ? raw.cast<String, Object?>() : null;
}

Future<void> _execSave(NodeGraph g, Map<String, GraphNode> byId, GraphNode n, _ExecEnv env) async {
  final slot = n.inputs.where((i) => i.label == 'スロット').firstOrNull?.value?.trim() ?? '';
  if (slot.isEmpty) return;
  List<String>? texts;
  Map<String, Object?>? vector;
  for (final e in g.edges) {
    if (e.cond || e.toIcon || e.to != n.id) continue;
    final src = byId[e.from];
    if (src == null) continue;
    final port = n.inputs.elementAtOrNull(e.toPort);
    if (port?.label == 'テキスト配列') texts = await _textArrayOutOf(g, byId, src, env);
    if (port?.label == 'ベクトル') vector = await _vectorOutOf(g, byId, src, env);
  }
  if (texts == null && vector == null) return; // データ未接続 → 書かない
  await env.storageWrite!(slot, {'texts': ?texts, 'vector': ?vector});
}

/// GLiNER抽出 (D-104): 投稿群の特徴語を頻出順で返す。
List<String> topFeaturesOf(List<Post> posts, {int max = 24}) {
  final counts = <String, int>{};
  for (final p in posts) {
    for (final f in extractFeatures(p)) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(max)) e.key];
}

/// SigLIP埋め込み (D-104): 投稿群の平均埋め込み。ゲートウェイ不達時は
/// n-gram プロファイル(合算)に縮退する。
Future<Map<String, Object?>> profileVectorOf(List<Post> posts, Future<List<List<double>>> Function(List<String>)? embedTexts, {Future<List<List<double>>> Function(List<Post>)? embedPosts}) async {
  final bodies = [for (final p in posts.take(40)) p.body];
  if (embedTexts != null || embedPosts != null) {
    try {
      final embs = embedPosts != null ? await embedPosts(posts.take(40).toList()) : await embedTexts!(bodies);
      if (embs.isNotEmpty) {
        final mean = List<double>.filled(embs.first.length, 0);
        for (final e in embs) {
          for (var i = 0; i < mean.length && i < e.length; i++) {
            mean[i] += e[i];
          }
        }
        for (var i = 0; i < mean.length; i++) {
          mean[i] /= embs.length;
        }
        return {'kind': 'siglip', 'v': mean};
      }
    } catch (_) {
      // 縮退へ
    }
  }
  final merged = <String, double>{};
  for (final b in bodies) {
    for (final e in charNgramProfile(b).entries) {
      merged[e.key] = (merged[e.key] ?? 0) + e.value;
    }
  }
  return {'kind': 'ngram', 'p': merged};
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
  if (source == null) return false; // 値元が未接続 → 不成立 (D-105: 全消し事故防止)
  final v = _numericOf(source, p, ctx);
  if (v == null) return false; // 値が取れない(スロット空など)→ 不成立
  String cfg(String label, String fallback) => n.inputs.where((i) => i.label == label).firstOrNull?.value ?? fallback;
  final t = num.tryParse(cfg('値', ''));
  if (t == null) return false;
  return switch (cfg('演算', '以上')) {
    '以下' => v <= t,
    '等しい' => (v - t).abs() < 1e-9,
    _ => v >= t,
  };
}

double? _numericOf(GraphNode s, Post p, _CondContext ctx) => switch (s.type) {
      'ml.similar' || 'ml.keyword' || 'ml.tendency' => ctx.scores[s.id]?[p.key],
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
  static Future<_CondContext> prepare(NodeGraph g, Map<String, GraphNode> byId, String stepId, List<Post> posts, _ExecEnv env, {bool normalizeSimilar = true}) async {
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
          if (ml != null && (ml.type == 'ml.similar' || ml.type == 'ml.keyword' || ml.type == 'ml.tendency')) mlNodes.add(ml);
        }
      }
    }
    if (mlNodes.isEmpty) return const _CondContext.empty();

    final scores = <String, Map<String, double>>{};
    for (final ml in mlNodes) {
      if (scores.containsKey(ml.id)) continue;
      // 指向性/刺激性 (D-153): storage.safe のプロファイルへの適合度(生値 0〜1)。
      if (ml.type == 'ml.tendency') {
        final slot = ml.inputs.where((i) => i.label == 'プロファイル').firstOrNull?.value?.trim() ?? '';
        final raw = await env.storageRead?.call(slot.isEmpty ? TendencyProfile.slot : slot);
        final profile = TendencyProfile.tryParse(raw);
        if (profile == null) continue; // プロファイル無し → スコアなし(比較は不成立)
        scores[ml.id] = {for (final p in posts) p.key: tendencyScorer.score(p, profile).value};
        continue;
      }
      final refs = await _textSources(g, byId, ml, env);
      // 基準ベクトル (D-104): SigLIP埋め込み/読み出しからの接続。
      Map<String, Object?>? vecRef;
      if (ml.type == 'ml.similar') {
        final edge = g.edges.where((e) {
          if (e.cond || e.toIcon || e.to != ml.id) return false;
          return ml.inputs.elementAtOrNull(e.toPort)?.label == '基準ベクトル';
        }).firstOrNull;
        final src = edge == null ? null : byId[edge.from];
        if (src != null) vecRef = await _vectorOutOf(g, byId, src, env);
      }
      if (refs.isEmpty && vecRef == null) continue; // 基準なし → スコアなし(比較は不成立に落ちる)
      scores[ml.id] = ml.type == 'ml.similar' ? await _similarScores(refs, vecRef, posts, env.embedTexts, normalize: normalizeSimilar, embedPosts: env.embedPosts) : _keywordScores(refs, posts);
    }
    return _CondContext(scores);
  }
}

/// ML ノードのテキスト入力を解決する: 値ボックス + 接続元(ファイルリーダー
/// のファイル内容 / テキスト配列を出すノード — トレンド/GLiNER抽出/読み出し)。
Future<List<String>> _textSources(NodeGraph g, Map<String, GraphNode> byId, GraphNode ml, _ExecEnv env) async {
  final out = <String>[];
  final own = ml.inputs.firstOrNull?.value?.trim() ?? '';
  if (own.isNotEmpty) out.add(own);
  for (final e in g.edges) {
    if (e.cond || e.toIcon || e.to != ml.id) continue;
    final src = byId[e.from];
    if (src == null) continue;
    if (src.type == 'file' || src.type == 'text.const' || src.type == 'convert.join' || src.type == 'post.text') {
      // テキストを出すノード (D-235: 定数 / ファイル / 結合)。
      final text = await _textOutOf(g, byId, src, env);
      if (text != null) out.add(text);
    } else {
      final texts = await _textArrayOutOf(g, byId, src, env);
      if (texts != null) out.addAll(texts.where((t) => t.trim().isNotEmpty));
    }
  }
  return out;
}

double _cosVec(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  final len = math.min(a.length, b.length);
  for (var i = 0; i < len; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : dot / (math.sqrt(na) * math.sqrt(nb));
}

/// SigLIP cos 類似度(基準は複数なら最良値、テキスト基準とベクトル基準は
/// max で併合)。ゲートウェイ不達/失敗時は n-gram 類似度に縮退する。
///
/// 返り値は **その投稿一括の中での相対値 0〜1**(min-max 正規化, D-105)。
/// 生 cos は縮退時 0.1〜0.3 程度と小さく「以上 0.8」等のしきい値が実質
/// 効かないため、比較で使いやすい相対スコアに揃える(0.8 ≒ 上位 2 割相当)。
Future<Map<String, double>> _similarScores(
    List<String> refs, Map<String, Object?>? vecRef, List<Post> posts, Future<List<List<double>>> Function(List<String>)? embedTexts, {bool normalize = true, Future<List<List<double>>> Function(List<Post>)? embedPosts}) async {
  // 投稿側のベクトル: 端末の投稿の埋め込み(本文 + 画像、D-390)があればそれ、無ければ本文だけ。
  Future<List<List<double>>> postVectors() => embedPosts != null ? embedPosts(posts) : embedTexts!([for (final p in posts) p.body]);
  final out = <String, double>{for (final p in posts) p.key: 0.0};
  void merge(Map<String, double> m) => m.forEach((k, v) => out[k] = math.max(out[k] ?? 0, v));

  if (refs.isNotEmpty) {
    var done = false;
    if (embedTexts != null) {
      try {
        final refVecs = await embedTexts(refs);
        final postVecs = await postVectors();
        merge({
          for (var i = 0; i < posts.length; i++)
            posts[i].key: [for (var r = 0; r < refs.length; r++) _cosVec(refVecs[r], postVecs[i])].reduce(math.max),
        });
        done = true;
      } catch (_) {
        // 縮退へ
      }
    }
    if (!done) {
      final profiles = [for (final r in refs) charNgramProfile(r)];
      merge({
        for (final p in posts) p.key: [for (final r in profiles) cosineOfProfiles(r, charNgramProfile(p.body))].reduce(math.max),
      });
    }
  }

  if (vecRef != null) {
    if (vecRef['kind'] == 'siglip' && vecRef['v'] is List && (embedTexts != null || embedPosts != null)) {
      try {
        final v = [for (final x in vecRef['v'] as List) (x as num).toDouble()];
        final embs = await postVectors();
        merge({for (var i = 0; i < posts.length; i++) posts[i].key: _cosVec(v, embs[i])});
      } catch (_) {}
    } else if (vecRef['kind'] == 'ngram' && vecRef['p'] is Map) {
      final profile = {for (final e in (vecRef['p'] as Map).entries) '${e.key}': ((e.value as num?) ?? 0).toDouble()};
      merge({for (final p in posts) p.key: cosineOfProfiles(profile, charNgramProfile(p.body))});
    }
  }

  // 相対値へ正規化 (D-105): 一括の最小→0、最大→1。全投稿が同点なら 0.5。
  // コンポーザー評価 (D-125) は 1 件なので生値のまま([normalize] = false)。
  if (normalize && out.isNotEmpty) {
    final values = out.values.toList();
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    if ((hi - lo).abs() < 1e-12) {
      out.updateAll((_, _) => 0.5);
    } else {
      out.updateAll((_, v) => (v - lo) / (hi - lo));
    }
  }
  return out;
}

/// キーワード一致 (GLiNER 系): 基準の特徴語と投稿の特徴語の重なり数。
Map<String, double> _keywordScores(List<String> refs, List<Post> posts) {
  final refFeatures = <String>{for (final r in refs) ...extractFeaturesText(r)};
  return {for (final p in posts) p.key: entityOverlap(refFeatures, extractFeatures(p)).toDouble()};
}

/// テキスト配列の終端 (D-113: トレンド枠ノード)。終端 [terminal] の入力に
/// 繋がったテキスト配列(トレンド取得/GLiNER抽出/読み出し)を評価して返す。
/// 鎖が無ければ null(既定のトレンド一覧のまま)。
Future<List<String>?> runNodeGraphTexts(
  NodeGraph g, {
  required String terminal,
  Future<List<Post>> Function(String kindId)? fetch,
  Future<List<String>> Function()? fetchTrends,
  Future<Object?> Function(String slot)? storageRead,
}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final env = _ExecEnv(fetch: fetch ?? (_) async => const [], fetchTrends: fetchTrends, storageRead: storageRead);
  for (final t in g.nodes.where((n) => n.type == terminal)) {
    final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == t.id && e.toPort == 0).firstOrNull;
    final up = edge == null ? null : byId[edge.from];
    if (up == null) continue;
    final texts = await _textArrayOutOf(g, byId, up, env);
    if (texts != null) return texts;
  }
  return null;
}

/// ポスト先ノードの実行 (D-116): 下書き [draft] で各「ポスト先」の条件木を
/// 評価し、成立したノードの「アカウント」を**上から順**(y → x)に返す。
/// 条件を何もぶら下げていないポスト先は常に成立(デフォルト候補として
/// 一番下に置く想定)。空文字は「現在のアカウント」の意味。
Future<List<String>> composerTargetAccounts(
  NodeGraph g,
  Post draft, {
  Future<List<Post>> Function(String kindId)? fetch,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<Object?> Function(String slot)? storageRead,
}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final env = _ExecEnv(fetch: fetch ?? (_) async => const [], embedTexts: embedTexts, storageRead: storageRead);
  final targets = g.nodes.where((n) => n.type == 'composer.target').toList()
    ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  final out = <String>[];
  for (final t in targets) {
    // 下書きは 1 件なので類似度は生値で比較する (D-125: 正規化は縮退する)。
    final ctx = await _CondContext.prepare(g, byId, t.id, [draft], env, normalizeSimilar: false);
    if (_evalCondPortAt(g, byId, t.id, draft, 0, ctx)) {
      out.add(t.inputs.where((i) => i.label == 'アカウント').firstOrNull?.value?.trim() ?? '');
    }
  }
  return out;
}

/// 連動の絞り込み (D-131): `composer.linkgate` を下書きで評価し、
/// アカウント表記 → 通過したか、を返す(関門が無いアカウントは載らない =
/// 制限なし)。同一アカウントに複数の関門があれば**すべて**通過が必要。
Future<Map<String, bool>> composerLinkGates(
  NodeGraph g,
  Post draft, {
  Future<List<Post>> Function(String kindId)? fetch,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<Object?> Function(String slot)? storageRead,
}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final env = _ExecEnv(fetch: fetch ?? (_) async => const [], embedTexts: embedTexts, storageRead: storageRead);
  final out = <String, bool>{};
  for (final n in g.nodes.where((n) => n.type == 'composer.linkgate')) {
    final account = n.inputs.where((i) => i.label == 'アカウント').firstOrNull?.value?.trim() ?? '';
    if (account.isEmpty) continue;
    final ctx = await _CondContext.prepare(g, byId, n.id, [draft], env, normalizeSimilar: false);
    final passed = _evalCondPortAt(g, byId, n.id, draft, 0, ctx);
    out[account] = (out[account] ?? true) && passed;
  }
  return out;
}

/// ポスト先の選択(フォールバック込み, D-126)。成立したポスト先を上から順に
/// 返し、続けて**代わりのフォーマットで投稿**(composer.fallback)の成立分を
/// 返す(既に通常候補になったアカウントは除く)。フォールバックの
/// `format` は `{'format': 'cw'|'followers'|'localOnly', 'cw': <注釈>}`。
Future<List<(String, Map<String, String>?)>> composerTargetChoices(
  NodeGraph g,
  Post draft, {
  Future<List<Post>> Function(String kindId)? fetch,
  Future<List<List<double>>> Function(List<String> texts)? embedTexts,
  Future<Object?> Function(String slot)? storageRead,
}) async {
  final byId = {for (final n in g.nodes) n.id: n};
  final env = _ExecEnv(fetch: fetch ?? (_) async => const [], embedTexts: embedTexts, storageRead: storageRead);
  final out = <(String, Map<String, String>?)>[];
  final chosen = <String>{};
  final matched = await composerTargetAccounts(g, draft, fetch: fetch, embedTexts: embedTexts, storageRead: storageRead);
  for (final a in matched) {
    if (chosen.add(a)) out.add((a, null));
  }
  final fallbacks = g.nodes.where((n) => n.type == 'composer.fallback').toList()
    ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  for (final f in fallbacks) {
    String input(String label) => f.inputs.where((i) => i.label == label).firstOrNull?.value?.trim() ?? '';
    final account = input('アカウント');
    if (chosen.contains(account)) continue;
    final ctx = await _CondContext.prepare(g, byId, f.id, [draft], env, normalizeSimilar: false);
    if (!_evalCondPortAt(g, byId, f.id, draft, 0, ctx)) continue;
    chosen.add(account);
    final format = switch (input('フォーマット')) {
      'フォロワー限定' => 'followers',
      '連合なし' => 'localOnly',
      _ => 'cw',
    };
    out.add((account, {'format': format, 'cw': input('注釈')}));
  }
  return out;
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
