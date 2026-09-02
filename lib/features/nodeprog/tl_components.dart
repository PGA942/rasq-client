import 'package:flutter/material.dart';

import 'node_graph.dart';

/// TL カスタマイズの簡略化 (D-121, 原典: ワイヤーフレーム「タイムラインの
/// カスタマイズ」+ ユーザー検討案)。自由形のノードキャンバスは TL スコープ
/// では**一旦無効化**し、TL は 2 種類のコンポーネントの積みで組む:
///
/// - **SNSタイムライン(TLコンポーネント)**: SNS プラグインのタイムライン
///   プロバイダ部。1 TL に複数共存でき、複数のときは合流 + 重複畳み込み
///   (D-115)。投稿加工プラグインはこのコンポーネント側で適用される
///   (D-118: 取得直前の post.transform)。
/// - **アルゴリズムコンポーネント**: 上から順に適用。選択肢は
///   「[キーワード/類似性] を [投稿内容/リアクション/会話内容] からサジェスト」
///   /「時系列順」/「カスタム(TLプラグイン)」。
///
/// 保存時は**正準形ノードグラフにコンパイル**して従来の `graph` キーに書く —
/// 実行系(runNodeGraph)・クロック・枝ページング(D-117)・重複畳み込みは
/// そのまま使われ、オート構成を壊す自由形はこの UI からは作れない。
@immutable
class TlSourceComponent {
  const TlSourceComponent({this.tl = 'home', this.account = '', this.enabled = true});

  /// TL 種別: home/social/local/global(基本 TL)、`list:<名前 or id>`
  /// (リスト系)、`trend`(現在のトレンド TL = 上位タグの検索結果合流)、
  /// `self`(この画面の基礎タイムライン — 検索結果/リスト/欄の投稿を
  /// そのまま取り込む, D-124)。
  final String tl;

  /// 一時的な無効化 (D-123): 外さずに実行だけ止める(コンパイルから除外)。
  final bool enabled;

  bool get isTrend => tl == 'trend';
  bool get isList => tl.startsWith('list:');
  bool get isSelf => tl == 'self';
  String get listName => isList ? tl.substring(5) : '';

  /// アカウント表記(空 = 現在のアカウント)。
  final String account;

  TlSourceComponent copyWith({String? tl, String? account, bool? enabled}) =>
      TlSourceComponent(tl: tl ?? this.tl, account: account ?? this.account, enabled: enabled ?? this.enabled);
  Map<String, Object?> toJson() => {'tl': tl, 'account': account, 'enabled': enabled};
  factory TlSourceComponent.fromJson(Map<String, Object?> j) =>
      TlSourceComponent(tl: j['tl'] as String? ?? 'home', account: j['account'] as String? ?? '', enabled: j['enabled'] != false);
}

/// サジェストの基準の選択肢 → 取得 kind(D-121 の対応):
/// 投稿内容 = 自分の投稿、リアクション = リアクション済み、会話内容 = 自分の
/// 返信(会話)。
const suggestWhatOptions = ['キーワード', '類似性'];
const suggestFromOptions = ['投稿内容', 'リアクション', '会話内容'];

String suggestFromKind(String from) => switch (from) {
      'リアクション' => 'myreactions',
      '会話内容' => 'myreplies',
      _ => 'myposts',
    };

@immutable
class TlAlgorithmComponent {
  const TlAlgorithmComponent({required this.type, this.what = 'キーワード', this.from = '投稿内容', this.pluginLabel = '', this.enabled = true});

  /// 'chrono'(時系列順)| 'suggest' | `plugin:<tlId>`(カスタム TL プラグイン)。
  final String type;

  /// suggest: なにを([キーワード/類似性])/なにから([投稿内容/リアクション/会話内容])。
  final String what;
  final String from;

  /// plugin: の表示名(「〇〇でソート」)。
  final String pluginLabel;

  /// 一時的な無効化 (D-123): 外さずに適用だけ止める(コンパイルから除外)。
  final bool enabled;

  bool get isSuggest => type == 'suggest';
  bool get isPlugin => type.startsWith('plugin:');

  String get title => switch (type) {
        'chrono' => '時系列順',
        'suggest' => '$whatを$fromからサジェスト',
        _ => pluginLabel.isEmpty ? 'カスタム(TLプラグイン)' : pluginLabel,
      };

  TlAlgorithmComponent copyWith({String? what, String? from, bool? enabled}) =>
      TlAlgorithmComponent(type: type, what: what ?? this.what, from: from ?? this.from, pluginLabel: pluginLabel, enabled: enabled ?? this.enabled);
  Map<String, Object?> toJson() => {'type': type, 'what': what, 'from': from, 'pluginLabel': pluginLabel, 'enabled': enabled};
  factory TlAlgorithmComponent.fromJson(Map<String, Object?> j) => TlAlgorithmComponent(
      type: j['type'] as String? ?? 'chrono',
      what: j['what'] as String? ?? 'キーワード',
      from: j['from'] as String? ?? '投稿内容',
      pluginLabel: j['pluginLabel'] as String? ?? '',
      enabled: j['enabled'] != false);
}

@immutable
class TlConfig {
  const TlConfig({this.sources = const [], this.algorithms = const [], this.clock = '15秒'});

  final List<TlSourceComponent> sources;
  final List<TlAlgorithmComponent> algorithms;

  /// 自動更新の間隔('' = なし。クロックノードにコンパイルされる)。
  final String clock;

  TlConfig copyWith({List<TlSourceComponent>? sources, List<TlAlgorithmComponent>? algorithms, String? clock}) =>
      TlConfig(sources: sources ?? this.sources, algorithms: algorithms ?? this.algorithms, clock: clock ?? this.clock);

  Map<String, Object?> toJson() => {
        'sources': [for (final s in sources) s.toJson()],
        'algorithms': [for (final a in algorithms) a.toJson()],
        'clock': clock,
      };
  factory TlConfig.fromJson(Map<String, Object?> j) => TlConfig(
        sources: [for (final s in (j['sources'] as List? ?? const [])) TlSourceComponent.fromJson((s as Map).cast<String, Object?>())],
        algorithms: [for (final a in (j['algorithms'] as List? ?? const [])) TlAlgorithmComponent.fromJson((a as Map).cast<String, Object?>())],
        clock: j['clock'] as String? ?? '15秒',
      );
}

/// スコープの既定構成: 基礎 TL 1 本 + 時系列順(従来のデフォルトフルチェーン
/// D-107 と同じ意味)。総合は全アカウントの home(D-114 の自動構成と同形)。
/// TL 系は全部この UI (D-124): リスト TL はそのリストの取得、トレンド系は
/// 「このタイムライン」(self — 検索結果/欄の投稿)から始める。
TlConfig defaultTlConfig(String scope, {List<String> bundleAccounts = const []}) {
  if (scope == 'tl.bundle') {
    return TlConfig(sources: [for (final a in bundleAccounts) TlSourceComponent(tl: 'home', account: a)], algorithms: const [TlAlgorithmComponent(type: 'chrono')]);
  }
  if (scope == 'trend' || scope == 'trend.users') {
    return const TlConfig(sources: [TlSourceComponent(tl: 'self')], algorithms: [TlAlgorithmComponent(type: 'chrono')]);
  }
  if (scope == 'trend.following') {
    return const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'chrono')]);
  }
  final base = scope.startsWith('tl.') ? scope.substring(3) : 'home';
  if (base.startsWith('list:')) {
    return TlConfig(sources: [TlSourceComponent(tl: base)], algorithms: const [TlAlgorithmComponent(type: 'chrono')]);
  }
  final tl = ['home', 'social', 'local', 'global'].contains(base) ? base : 'home';
  return TlConfig(sources: [TlSourceComponent(tl: tl)], algorithms: const [TlAlgorithmComponent(type: 'chrono')]);
}

/// コンポーネント構成 → 正準形ノードグラフ (D-121)。
/// 取得×N →(複数なら)マージ段組み → アルゴリズム段(上から順)→ 終端。
NodeGraph compileTlConfig(TlConfig cfg, {required String scope}) {
  GraphNode inst(String type, String id, Offset at, {Map<String, String> values = const {}}) {
    final e = builtinNodeCatalog.firstWhere((x) => x.type == type);
    final n = e.instantiate(id, at);
    return n.copyWith(inputs: [for (final p in n.inputs) values.containsKey(p.label) ? p.copyWith(value: values[p.label]) : p]);
  }

  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];

  // 一時的な無効化 (D-123): 無効のコンポーネントはコンパイルから除外。
  final sources = [for (final s in cfg.sources) if (s.enabled) s];
  final algorithms = [for (final a in cfg.algorithms) if (a.enabled) a];

  // 取得段。基準(サジェスト)には myposts / myreactions / myreplies も
  // tl.source の TL 値として通す(実行側の resolveNodeFetch が解決)。
  // リスト系 → tl.list、現在のトレンド TL → trend.posts (D-122)。
  for (var i = 0; i < sources.length; i++) {
    final s = sources[i];
    final at = Offset(24, 40.0 + i * 170);
    if (s.isTrend) {
      nodes.add(inst('trend.posts', 's$i', at, values: {'アカウント': s.account}));
    } else if (s.isSelf) {
      // この画面の基礎 TL (D-124): 実行側の resolveNodeFetch が selfItems を返す。
      nodes.add(inst('tl.source', 's$i', at, values: {'TL': 'self'}));
    } else if (s.isList) {
      nodes.add(inst('tl.list', 's$i', at, values: {'リスト': s.listName, 'アカウント': s.account}));
    } else {
      nodes.add(inst('tl.source', 's$i', at, values: {'TL': s.tl, 'アカウント': s.account}));
    }
  }
  if (sources.isEmpty) return const NodeGraph();

  // マージ段組み(D-114 と同形): 3 口、溢れたら前段 + 2 口で連鎖。
  String out;
  if (sources.length == 1) {
    out = 's0';
  } else {
    var mergeIndex = 0;
    String? current;
    var consumed = 0;
    while (consumed < sources.length) {
      final id = 'm$mergeIndex';
      nodes.add(inst('merge', id, Offset(260.0 + mergeIndex * 40, 120.0 + mergeIndex * 150)));
      var port = 0;
      if (current != null) edges.add(GraphEdge(from: current, fromPort: 0, to: id, toPort: port++));
      while (port < 3 && consumed < sources.length) {
        edges.add(GraphEdge(from: 's$consumed', fromPort: 0, to: id, toPort: port++));
        consumed++;
      }
      current = id;
      mergeIndex++;
    }
    out = current!;
  }

  // アルゴリズム段(上から順に適用 = 鎖の順)。
  var col = 0;
  for (var i = 0; i < algorithms.length; i++) {
    final a = algorithms[i];
    final x = 300.0 + col * 260;
    if (a.type == 'chrono') continue; // 時系列は取得/マージの既定順
    if (a.isPlugin) {
      final id = 'a$i';
      nodes.add(GraphNode(
          id: id,
          type: a.type,
          title: a.title,
          x: x,
          y: 60,
          inputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
          outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')]));
      edges.add(GraphEdge(from: out, fromPort: 0, to: id, toPort: 0));
      out = id;
      col++;
      continue;
    }
    // サジェスト: 基準取得 → 抽出(GLiNER/SigLIP)→ ML → 比較 → 並べ替え。
    final sortId = 'a$i';
    final refId = 'r$i';
    final exId = 'x$i';
    final mlId = 'l$i';
    final cmpId = 'c$i';
    nodes.add(inst('sort', sortId, Offset(x, 60)));
    nodes.add(inst('tl.source', refId, Offset(x - 40, 460), values: {'TL': suggestFromKind(a.from)}));
    edges.add(GraphEdge(from: out, fromPort: 0, to: sortId, toPort: 0));
    if (a.what == '類似性') {
      nodes.add(inst('ml.siglip', exId, Offset(x + 40, 380)));
      nodes.add(inst('ml.similar', mlId, Offset(x + 80, 300)));
      nodes.add(inst('compare', cmpId, Offset(x + 20, 180), values: {'演算': '以上', '値': '0.6'}));
      edges.add(GraphEdge(from: refId, fromPort: 0, to: exId, toPort: 0));
      // 基準ベクトル入力(ml.similar の 3 つ目)。
      edges.add(GraphEdge(from: exId, fromPort: 0, to: mlId, toPort: 2));
    } else {
      nodes.add(inst('ml.gliner', exId, Offset(x + 40, 380)));
      nodes.add(inst('ml.keyword', mlId, Offset(x + 80, 300)));
      nodes.add(inst('compare', cmpId, Offset(x + 20, 180), values: {'演算': '以上', '値': '1'}));
      edges.add(GraphEdge(from: refId, fromPort: 0, to: exId, toPort: 0));
      // キーワードリスト入力(ml.keyword の 2 つ目)。
      edges.add(GraphEdge(from: exId, fromPort: 0, to: mlId, toPort: 1));
    }
    edges.add(GraphEdge(from: mlId, fromPort: 0, to: cmpId, toPort: 0));
    edges.add(GraphEdge(from: sortId, fromPort: 0, to: cmpId, toPort: 0, cond: true));
    out = sortId;
    col++;
  }

  // 終端(関連スコープは前段絞り込みの終端 D-102)+ クロック (D-095)。
  final terminal = scope == 'tl.relational' ? 'timeline.relational' : 'timeline';
  nodes.add(inst(terminal, 't0', Offset(320.0 + col * 260, 160)));
  edges.add(GraphEdge(from: out, fromPort: 0, to: 't0', toPort: 0));
  if (cfg.clock.isNotEmpty) {
    nodes.add(inst('clock', 'c0', const Offset(24, -120), values: {'間隔': cfg.clock}));
    edges.add(const GraphEdge(from: 'c0', fromPort: 0, to: 's0', toPort: 0, toIcon: true));
  }
  // トレンドスコープ (D-113/D-124): トレンド枠の既定チェーンも添える —
  // グラフ編集(「グラフで編集」)でタグ一覧を置き換えられる口を残す。
  if (scope == 'trend') {
    nodes.add(inst('trend.tags', 'f0', const Offset(24, 640)));
    nodes.add(inst('trend.frame', 'f1', const Offset(300, 660)));
    edges.add(const GraphEdge(from: 'f0', fromPort: 0, to: 'f1', toPort: 0));
  }
  return NodeGraph(nodes: nodes, edges: edges);
}
