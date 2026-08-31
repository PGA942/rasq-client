import 'package:flutter/material.dart';

/// ノードプログラミング (D-090): タイムライン/投稿先のカスタマイズ画面の
/// GUI ノードグラフ。まだ実行系はなく(RAi 未実装)、グラフの編集と保存
/// (KV `nodeprog.<scope>.v1`)まで — 実行は RAi/プラグイン統合側で配線する。
@immutable
class NodePort {
  const NodePort({required this.label, this.value, this.dataType = 'any', this.format, this.options});

  final String label;

  /// 入力欄の値(ドロップダウン/テキスト設定)。null はラベルだけの
  /// 接続ポート(値を持たない)。
  final String? value;

  /// データ形式(大まかなジャンル)。**色分けと接続可否**の単位 —
  /// ジャンルが違うポート同士は接続できない(D-092)。
  final String dataType;

  /// プラグインが細かく指定する形式(例: テキストの `.dic`)。両端が
  /// 指定していて食い違うときは接続できない。
  final String? format;

  /// 値の選択肢 (D-094)。指定されると値ボックスのタップがドロップダウンになる。
  final List<String>? options;

  NodePort copyWith({String? value}) => NodePort(label: label, value: value ?? this.value, dataType: dataType, format: format, options: options);
  Map<String, Object?> toJson() => {
        'label': label,
        if (value != null) 'value': value,
        'dataType': dataType,
        if (format != null) 'format': format,
        if (options != null) 'options': options,
      };
  factory NodePort.fromJson(Map<String, Object?> j) => NodePort(
        label: j['label'] as String? ?? '',
        value: j['value'] as String?,
        dataType: j['dataType'] as String? ?? 'any',
        format: j['format'] as String?,
        options: (j['options'] as List?)?.cast<String>(),
      );

  /// 表示名: `テキスト(.dic)` のように形式を添える。
  String get typeLabel => format == null ? dataType : '$dataType($format)';
}

/// データ形式 → 色(ポートのドットと接続線の色分け)。
Color nodeTypeColor(String dataType) => switch (dataType) {
      'クロック' => const Color(0xFFE57368),
      '数値' => const Color(0xFF26A69A),
      'テキスト' => const Color(0xFFFFB74D),
      '投稿リスト' => const Color(0xFF42A5F5),
      // 条件接続部 (D-094): 上下方向の紫。設定はノード内の値ボックス専用
      // (接続相手が存在しないのでどこにも繋がらない)。
      '条件' => const Color(0xFFAB47BC),
      '設定' => const Color(0xFFBDBDBD),
      _ => const Color(0xFF9E9E9E),
    };

/// 2 ポートが接続可能か (D-092): ジャンル(dataType)一致が必須。
/// 両端が形式(format)を指定していて食い違う場合も不可。
bool portsCompatible(NodePort out, NodePort input) {
  if (out.dataType != input.dataType) return false;
  if (out.format != null && input.format != null && out.format != input.format) return false;
  return true;
}

@immutable
class GraphNode {
  const GraphNode({required this.id, required this.type, required this.title, required this.x, required this.y, this.inputs = const [], this.outputs = const [], this.hasCondIn = false, this.hasCondOut = false});

  final String id;

  /// カタログの type(`clock` / `plugin:<id>` …)。アイコン等はカタログから引く。
  final String type;
  final String title;
  final double x;
  final double y;
  final List<NodePort> inputs;
  final List<NodePort> outputs;

  /// 条件接続部 (D-094): 上辺(条件を受ける — 条件/Not ノード)と
  /// 下辺(条件をぶら下げる — 並べ替え/消去/条件/Not)。
  final bool hasCondIn;
  final bool hasCondOut;

  GraphNode copyWith({double? x, double? y, List<NodePort>? inputs}) => GraphNode(
      id: id, type: type, title: title, x: x ?? this.x, y: y ?? this.y, inputs: inputs ?? this.inputs, outputs: outputs, hasCondIn: hasCondIn, hasCondOut: hasCondOut);

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'x': x,
        'y': y,
        'inputs': [for (final p in inputs) p.toJson()],
        'outputs': [for (final p in outputs) p.toJson()],
        if (hasCondIn) 'condIn': true,
        if (hasCondOut) 'condOut': true,
      };

  factory GraphNode.fromJson(Map<String, Object?> j) => GraphNode(
        id: j['id'] as String,
        type: j['type'] as String? ?? '',
        title: j['title'] as String? ?? '',
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        inputs: [for (final p in (j['inputs'] as List? ?? const [])) NodePort.fromJson((p as Map).cast<String, Object?>())],
        outputs: [for (final p in (j['outputs'] as List? ?? const [])) NodePort.fromJson((p as Map).cast<String, Object?>())],
        hasCondIn: j['condIn'] == true,
        hasCondOut: j['condOut'] == true,
      );
}

/// 出力ポート(from の outputs[fromPort])→ 入力ポート(to の inputs[toPort])。
/// [cond] のとき (D-094) は**縦方向の条件接続**: from の下辺 → to の上辺で、
/// fromPort/toPort は使わない(0 固定)。
@immutable
class GraphEdge {
  const GraphEdge({required this.from, required this.fromPort, required this.to, required this.toPort, this.cond = false});
  final String from;
  final int fromPort;
  final String to;
  final int toPort;
  final bool cond;

  Map<String, Object?> toJson() => {'from': from, 'fromPort': fromPort, 'to': to, 'toPort': toPort, if (cond) 'cond': true};
  factory GraphEdge.fromJson(Map<String, Object?> j) => GraphEdge(
      from: j['from'] as String, fromPort: (j['fromPort'] as num?)?.toInt() ?? 0, to: j['to'] as String, toPort: (j['toPort'] as num?)?.toInt() ?? 0, cond: j['cond'] == true);
}

@immutable
class NodeGraph {
  const NodeGraph({this.nodes = const [], this.edges = const []});
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  Map<String, Object?> toJson() => {'nodes': [for (final n in nodes) n.toJson()], 'edges': [for (final e in edges) e.toJson()]};

  factory NodeGraph.fromJson(Map<String, Object?> j) => NodeGraph(
        nodes: [for (final n in (j['nodes'] as List? ?? const [])) GraphNode.fromJson((n as Map).cast<String, Object?>())],
        edges: [for (final e in (j['edges'] as List? ?? const [])) GraphEdge.fromJson((e as Map).cast<String, Object?>())],
      );
}

/// パレット(プラグインノード検索)のカタログ項目。
@immutable
class NodeCatalogEntry {
  const NodeCatalogEntry({
    required this.type,
    required this.title,
    required this.icon,
    required this.genre,
    this.author,
    this.description,
    this.inputs = const [],
    this.outputs = const [],
    this.hasCondIn = false,
    this.hasCondOut = false,
  });

  final String type;
  final String title;
  final IconData icon;
  final String genre;

  /// 提供元(プラグイン名)。組み込みノードは null。
  final String? author;
  final String? description;
  final List<NodePort> inputs;
  final List<NodePort> outputs;
  final bool hasCondIn;
  final bool hasCondOut;

  GraphNode instantiate(String id, Offset at) =>
      GraphNode(id: id, type: type, title: title, x: at.dx, y: at.dy, inputs: inputs, outputs: outputs, hasCondIn: hasCondIn, hasCondOut: hasCondOut);

  /// パレットタイルの 1 行入出力表示(例: `入力: 間隔(数値) → 出力: クロック(クロック)`)。
  String get ioSummary {
    String side(List<NodePort> ps, {bool cond = false}) {
      final parts = [for (final p in ps) '${p.label}(${p.typeLabel})', if (cond) '条件'];
      return parts.isEmpty ? 'なし' : parts.join('・');
    }

    return '入力: ${side(inputs, cond: hasCondIn)} → 出力: ${side(outputs, cond: hasCondOut)}';
  }

  /// タイルの先頭に付ける形式色ドット(重複なし・登場順)。
  List<Color> get typeDots {
    final seen = <String>{};
    return [
      for (final p in [...inputs, ...outputs])
        if (p.dataType != '設定' && seen.add(p.dataType)) nodeTypeColor(p.dataType),
      if (hasCondIn || hasCondOut) if (seen.add('条件')) nodeTypeColor('条件'),
    ];
  }
}

/// 条件ノードの設定候補 (D-094)。「タグ」は RRL の意味タグに合わせた
/// 投稿の見どころ、「演算」はその内容への述語。
const condTagOptions = ['本文', '名前', '注釈', 'リアクション', '画像'];
const condOpOptions = ['含む', '等しい', '以上', '以下'];

/// 組み込みノード(ワイヤーフレーム「GUIノードの例」より)。データ形式は
/// クロック/数値/テキスト/投稿リスト — 色分けと接続可否の単位 (D-092)。
const builtinNodeCatalog = <NodeCatalogEntry>[
  NodeCatalogEntry(
    type: 'clock',
    title: 'クロックメーカー',
    icon: Icons.schedule,
    genre: '生成',
    description: '一定間隔でクロックを出します。TL の自動更新などのトリガーに使います。',
    inputs: [NodePort(label: '間隔', value: '15秒', dataType: '数値')],
    outputs: [NodePort(label: 'クロック', dataType: 'クロック')],
  ),
  NodeCatalogEntry(
    type: 'random',
    title: 'ランダム',
    icon: Icons.casino_outlined,
    genre: '生成',
    description: '乱数を出します。シードを固定すると再現できます。',
    inputs: [NodePort(label: 'シード', value: 'randomseed', dataType: '数値')],
    outputs: [NodePort(label: '1-7', dataType: '数値')],
  ),
  NodeCatalogEntry(
    type: 'file',
    title: 'ファイルリーダー',
    icon: Icons.description_outlined,
    genre: '入力',
    description: 'ローカルファイルを読み込んでテキストとして出します。',
    inputs: [NodePort(label: 'パス', value: '~/Documents/sample.dic', dataType: 'テキスト')],
    outputs: [NodePort(label: 'テキスト', dataType: 'テキスト')],
  ),
  NodeCatalogEntry(
    type: 'timeline',
    title: 'タイムライン',
    icon: Icons.view_agenda_outlined,
    genre: 'タイムライン',
    description: '最終出力。投稿リストを繋ぐと、この画面のタイムラインに流れます。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // ---- 実行系 (D-094) — TL 取得 → 加工 → タイムライン、で実際に動く。
  NodeCatalogEntry(
    type: 'tl.source',
    title: 'タイムライン取得',
    icon: Icons.download_outlined,
    genre: 'タイムライン',
    description: '選んだタイムラインを取得して、投稿リスト(RRLタグ付き)として渡します。',
    inputs: [NodePort(label: 'TL', value: 'home', dataType: '設定', options: ['home', 'social', 'local', 'global'])],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  NodeCatalogEntry(
    type: 'sort',
    title: '並べ替え',
    icon: Icons.swap_vert,
    genre: '加工',
    description: '下に繋いだ条件に合う投稿を先頭に並べ替えます(元の順序は保たれます)。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    hasCondOut: true,
  ),
  NodeCatalogEntry(
    type: 'remove',
    title: '消去',
    icon: Icons.delete_sweep_outlined,
    genre: '加工',
    description: '下に繋いだ条件に合う投稿を取り除きます。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    hasCondOut: true,
  ),
  NodeCatalogEntry(
    type: 'cond',
    title: '条件',
    icon: Icons.filter_alt_outlined,
    genre: '条件',
    description: '指定したタグの内容を見て True/False を返します。下に数珠繋ぎで「かつ」、同じ接続部から並列で「または」。',
    inputs: [
      NodePort(label: 'タグ', value: '本文', dataType: '設定', options: condTagOptions),
      NodePort(label: '演算', value: '含む', dataType: '設定', options: condOpOptions),
      NodePort(label: '値', value: '', dataType: '設定'),
    ],
    hasCondIn: true,
    hasCondOut: true,
  ),
  NodeCatalogEntry(
    type: 'not',
    title: 'Not',
    icon: Icons.block_outlined,
    genre: '条件',
    description: '下に繋いだ条件の否定を返します。',
    hasCondIn: true,
    hasCondOut: true,
  ),
];
