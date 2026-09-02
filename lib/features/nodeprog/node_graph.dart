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
      'テキスト配列' => const Color(0xFF8D6E63),
      // ベクトル (D-104): SigLIP 埋め込み等のプロファイル(保存/類似度の基準)。
      'ベクトル' => const Color(0xFF5C6BC0),
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
  const GraphNode(
      {required this.id, required this.type, required this.title, required this.x, required this.y, this.inputs = const [], this.outputs = const [], this.hasCondIn = false, this.hasCondOut = false, this.condBranches = const []});

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

  /// 下側分岐のラベル (D-099: カスタム関数)。条件タグを複数選ぶと下側の
  /// 分岐が複数個になる。空なら従来どおり 1 個(hasCondOut のとき)。
  final List<String> condBranches;

  /// 下側の条件接続部の個数。
  int get condOutCount => condBranches.isNotEmpty ? condBranches.length : (hasCondOut ? 1 : 0);

  GraphNode copyWith({double? x, double? y, List<NodePort>? inputs}) => GraphNode(
      id: id,
      type: type,
      title: title,
      x: x ?? this.x,
      y: y ?? this.y,
      inputs: inputs ?? this.inputs,
      outputs: outputs,
      hasCondIn: hasCondIn,
      hasCondOut: hasCondOut,
      condBranches: condBranches);

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
        if (condBranches.isNotEmpty) 'condBranches': condBranches,
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
        condBranches: (j['condBranches'] as List?)?.cast<String>() ?? const [],
      );
}

/// 出力ポート(from の outputs[fromPort])→ 入力ポート(to の inputs[toPort])。
/// [cond] のとき (D-094) は**縦方向の条件接続**: from の下辺 → to の上辺で、
/// fromPort/toPort は使わない(0 固定)。
/// [toIcon] のとき (D-095) は**ノードのアイコンへの接続**(クロック):
/// from のクロック出力 → to のヘッダーアイコンで、toPort は使わない。
@immutable
class GraphEdge {
  const GraphEdge({required this.from, required this.fromPort, required this.to, required this.toPort, this.cond = false, this.toIcon = false});
  final String from;
  final int fromPort;
  final String to;
  final int toPort;
  final bool cond;
  final bool toIcon;

  Map<String, Object?> toJson() => {'from': from, 'fromPort': fromPort, 'to': to, 'toPort': toPort, if (cond) 'cond': true, if (toIcon) 'toIcon': true};
  factory GraphEdge.fromJson(Map<String, Object?> j) => GraphEdge(
      from: j['from'] as String,
      fromPort: (j['fromPort'] as num?)?.toInt() ?? 0,
      to: j['to'] as String,
      toPort: (j['toPort'] as num?)?.toInt() ?? 0,
      cond: j['cond'] == true,
      toIcon: j['toIcon'] == true);
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
    this.condBranches = const [],
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

  /// 下側分岐のラベル (D-099: カスタム関数の条件タグ)。
  final List<String> condBranches;

  GraphNode instantiate(String id, Offset at) => GraphNode(
      id: id, type: type, title: title, x: at.dx, y: at.dy, inputs: inputs, outputs: outputs, hasCondIn: hasCondIn, hasCondOut: hasCondOut, condBranches: condBranches);

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

/// カスタム関数ノードの定義 (D-099)。キャンバスの空白の長押しで作成し、
/// KV `nodeprog.functions.v1` に保存 → 全スコープのパレットに載る。
///
/// - 入力元が**条件以外(データ)**: 入出力のデータ形式をリストから選ぶ。
/// - 入力元が**条件**: 条件タグを選ぶ。**複数選ぶと下側の分岐が複数個**になる
///   (分岐 = 選んだタグ)。実行 v1 は「各分岐の評価(または)を全分岐で
///   かつ」— 関数の中身(タグ内容をどう使うか)はプラグイン/RAi 配線で
///   置き換える予定。
@immutable
class CustomFunctionDef {
  const CustomFunctionDef({required this.id, required this.name, required this.kind, this.tags = const [], this.inputs = const [], this.outputs = const []});

  /// ノード type(`fn:<連番>`)。
  final String id;
  final String name;

  /// 'cond'(入力元が条件)| 'data'(それ以外)。
  final String kind;
  final List<String> tags;
  final List<String> inputs;
  final List<String> outputs;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind, 'tags': tags, 'inputs': inputs, 'outputs': outputs};
  factory CustomFunctionDef.fromJson(Map<String, Object?> j) => CustomFunctionDef(
        id: j['id'] as String,
        name: j['name'] as String? ?? '関数',
        kind: j['kind'] as String? ?? 'data',
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        inputs: (j['inputs'] as List?)?.cast<String>() ?? const [],
        outputs: (j['outputs'] as List?)?.cast<String>() ?? const [],
      );

  NodeCatalogEntry toCatalogEntry() => kind == 'cond'
      ? NodeCatalogEntry(
          type: id,
          title: name,
          icon: Icons.auto_fix_high_outlined,
          genre: '関数',
          author: 'カスタム関数',
          description: '条件タグ ${tags.join('・')} を受けるカスタム関数です(中身の配線はプラグイン/RAi で)。',
          hasCondIn: true,
          hasCondOut: true,
          condBranches: tags.isEmpty ? const ['条件'] : tags,
        )
      : NodeCatalogEntry(
          type: id,
          title: name,
          icon: Icons.auto_fix_high_outlined,
          genre: '関数',
          author: 'カスタム関数',
          description: 'カスタム関数です(中身の配線はプラグイン/RAi で)。',
          inputs: [for (final t in inputs) NodePort(label: t, dataType: t)],
          outputs: [for (final t in outputs) NodePort(label: t, dataType: t)],
        );
}

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
    description: '投稿ごとに乱数を出します。範囲は「1-7」のように指定し、小数点を入れると小数点以下もカウントします。シードで再現できます。',
    inputs: [
      NodePort(label: 'シード', value: 'randomseed', dataType: '設定'),
      // 範囲 (D-097): ユーザー指定。整数なら両端含む整数、小数点を含む
      // 書き方(例: 0-1.5)なら小数も出す。
      NodePort(label: '範囲', value: '1-7', dataType: '設定'),
    ],
    outputs: [NodePort(label: '乱数', dataType: '数値')],
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
    inputs: [
      NodePort(label: 'TL', value: 'home', dataType: '設定', options: ['home', 'social', 'local', 'global']),
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
    ],
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
  // 関数の中身 (D-118): カスタム関数のサブグラフ専用の境界ノード。
  // 「関数入力」に呼び出し元の入力(v1 は投稿リスト)が束縛され、
  // 「関数出力」に繋いだ鎖の結果が関数ノードの出力になる。
  NodeCatalogEntry(
    type: 'fn.input',
    title: '関数入力',
    icon: Icons.login,
    genre: '関数',
    description: '関数の中身の入口。呼び出し元から渡された投稿リストがここから出ます(関数の中身の編集画面専用)。',
    outputs: [NodePort(label: '入力', dataType: '投稿リスト')],
  ),
  NodeCatalogEntry(
    type: 'fn.output',
    title: '関数出力',
    icon: Icons.logout,
    genre: '関数',
    description: '関数の中身の出口。ここに繋いだ投稿リストが関数ノードの出力になります(未接続なら素通し)。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // 検索絞り込み (D-125): このページの検索ワード/タグ(または指定ワード)に
  // 合う投稿だけ通す。検索/トレンド系 TL の既定チェーンに置かれる。
  NodeCatalogEntry(
    type: 'filter.query',
    title: '検索絞り込み',
    icon: Icons.manage_search,
    genre: '加工',
    description: '検索ワードに合う投稿だけ通します。ワードが空のときは、このページの検索ワード/タグを使います。',
    inputs: [
      NodePort(label: '投稿リスト', dataType: '投稿リスト'),
      NodePort(label: '検索ワード', value: '', dataType: '設定'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // マージ (D-106): 複数の投稿リストを 1 本のタイムラインへ合流。
  NodeCatalogEntry(
    type: 'merge',
    title: 'マージ',
    icon: Icons.merge_type,
    genre: '加工',
    description: '繋いだ投稿リストを時刻順に 1 本へ合流します。別アカウントに流れてきた同じ投稿は 1 枚に畳み、タイルの ↓ でアカウントを選べます。',
    inputs: [
      NodePort(label: '投稿リスト1', dataType: '投稿リスト'),
      NodePort(label: '投稿リスト2', dataType: '投稿リスト'),
      NodePort(label: '投稿リスト3', dataType: '投稿リスト'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // 関連プラグインノード (D-102): 関連 TL の**前段絞り込み**の終端。
  // 処理系(会話イベント構築)はそのまま — 繋いだ投稿リストがフォロイー
  // 入力の代わりになるだけ(通常 TL のタイムラインノードの置き換え)。
  NodeCatalogEntry(
    type: 'timeline.relational',
    title: '関連タイムライン',
    icon: Icons.hub_outlined,
    genre: 'タイムライン',
    description: '関連TLの前段絞り込みの最終出力。繋いだ投稿リストが会話イベント構築の入力になります(処理系は変わりません)。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // ---- 取得系 (D-097): リスト/検索/DM/トレンド。
  NodeCatalogEntry(
    type: 'tl.list',
    title: 'リストTL取得',
    icon: Icons.list_alt_outlined,
    genre: '取得',
    description: 'Misskey のリストのタイムラインを取得します(リスト名で指定)。',
    inputs: [
      NodePort(label: 'リスト', value: '', dataType: '設定'),
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  NodeCatalogEntry(
    type: 'tl.search',
    title: '検索TL取得',
    icon: Icons.search,
    genre: '取得',
    description: '検索ワードにヒットする投稿を取得します。',
    inputs: [
      NodePort(label: '検索ワード', value: '', dataType: '設定'),
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  NodeCatalogEntry(
    type: 'tl.dm',
    title: 'DM取得',
    icon: Icons.mail_outline,
    genre: '取得',
    description: '相手(ハンドル)との DM を取得します。',
    inputs: [
      NodePort(label: '相手', value: '', dataType: '設定'),
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  NodeCatalogEntry(
    type: 'trend.tags',
    title: 'トレンド取得',
    icon: Icons.trending_up,
    genre: '取得',
    description: 'いまのトレンドタグを文字列の配列として出します(類似度/キーワードの入力に)。',
    outputs: [NodePort(label: 'タグ', dataType: 'テキスト配列')],
  ),
  // トレンド検索結果取得 (D-106): トレンド上位タグを検索して投稿リストに。
  NodeCatalogEntry(
    type: 'trend.posts',
    title: 'トレンド検索結果取得',
    icon: Icons.travel_explore,
    genre: '取得',
    description: 'いまのトレンド上位タグを検索して、その投稿を 1 本に合流して出します。',
    inputs: [
      NodePort(label: 'タグ数', value: '3', dataType: '設定'),
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
    ],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // ポスト先 (D-106/D-116): 投稿コンポーザーのスコープ専用。下書き内容で
  // 条件を評価し、成立したポスト先が投稿先のサジェストになる。
  NodeCatalogEntry(
    type: 'composer.target',
    title: 'ポスト先',
    icon: Icons.send_outlined,
    genre: 'コンポーザー',
    description: '投稿先アカウントの候補。下に条件をぶら下げると、投稿内容がその条件に合うときこのアカウントが投稿先になります(上に置いたものほど優先。手動で選び直せます)。',
    inputs: [NodePort(label: 'アカウント', value: '', dataType: '設定')],
    hasCondOut: true,
  ),
  // 代わりのフォーマットで投稿 (D-126): 絞り込みで投稿が無くなった(下書きが
  // 条件に合わなかった)場合のバイパス — 直前の比較を Not で受けて、代替
  // フォーマットでこのアカウントに投稿する。
  NodeCatalogEntry(
    type: 'composer.fallback',
    title: '代わりのフォーマットで投稿',
    icon: Icons.alt_route,
    genre: 'コンポーザー',
    description: '絞り込みで投稿先から外れた場合のバイパス。下の条件(通常は直前の比較の Not)が成立したとき、代わりのフォーマットでこのアカウントに投稿します。',
    inputs: [
      NodePort(label: 'アカウント', value: '', dataType: '設定'),
      NodePort(label: 'フォーマット', value: '注釈を付ける', dataType: '設定', options: ['注釈を付ける', 'フォロワー限定', '連合なし']),
      NodePort(label: '注釈', value: '', dataType: '設定'),
    ],
    hasCondOut: true,
  ),
  NodeCatalogEntry(
    type: 'tl.myreactions',
    title: 'リアクション済み取得',
    icon: Icons.favorite_border,
    genre: '取得',
    description: 'TL で自分がリアクションした投稿を取得します(好みのプロファイル作りに)。',
    inputs: [NodePort(label: 'アカウント', value: '', dataType: '設定')],
    outputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
  ),
  // トレンド枠 (D-113): トレンドホームの「トレンド」一覧の終端。繋いだ
  // テキスト配列(トレンド取得/読み出し等)がそのまま一覧になる。
  NodeCatalogEntry(
    type: 'trend.frame',
    title: 'トレンド枠',
    icon: Icons.tag,
    genre: 'タイムライン',
    description: 'トレンドホームの「トレンド」一覧の最終出力。タグ(テキスト配列)を繋ぐとそのまま一覧に出ます。',
    inputs: [NodePort(label: 'タグ', dataType: 'テキスト配列')],
  ),
  // ---- 生成系 ML (D-097): 類似度/キーワード一致 + 演算子条件。
  NodeCatalogEntry(
    type: 'ml.similar',
    title: '類似度 (SigLIP)',
    icon: Icons.auto_awesome_outlined,
    genre: 'ML',
    description: '基準(テキスト/配列/ベクトル)と各投稿の類似度を、この TL 内での相対値 0〜1 で出します(0.8 ≒ 上位 2 割相当)。ML 不達時は n-gram 類似度に縮退します。',
    inputs: [
      NodePort(label: '基準', value: '', dataType: 'テキスト'),
      NodePort(label: '基準リスト', dataType: 'テキスト配列'),
      // 基準ベクトル (D-104): SigLIP 埋め込み/保存済みプロファイルを基準に。
      NodePort(label: '基準ベクトル', dataType: 'ベクトル'),
    ],
    outputs: [NodePort(label: '類似度', dataType: '数値')],
  ),
  // ---- 結果ノード + storage.safe (D-104)。
  NodeCatalogEntry(
    type: 'ml.gliner',
    title: 'GLiNER抽出',
    icon: Icons.sell_outlined,
    genre: 'ML',
    description: '投稿リストから特徴語(頻出順)を抽出して文字列の配列で出します。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    outputs: [NodePort(label: '特徴語', dataType: 'テキスト配列')],
  ),
  NodeCatalogEntry(
    type: 'ml.siglip',
    title: 'SigLIP埋め込み',
    icon: Icons.grain,
    genre: 'ML',
    description: '投稿リストの平均埋め込み(プロファイル)をベクトルで出します。ML 不達時は n-gram プロファイルに縮退します。',
    inputs: [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
    outputs: [NodePort(label: '埋め込み', dataType: 'ベクトル')],
  ),
  NodeCatalogEntry(
    type: 'storage.save',
    title: '保存 (storage.safe)',
    icon: Icons.save_outlined,
    genre: '保存',
    description: '繋いだデータをスロットに保存します。storage.safe は依存関係の子プラグインにも渡せる安全な置き場(プラグイン側の受け渡しは初回起動時に確認)。',
    inputs: [
      NodePort(label: 'スロット', value: '', dataType: '設定'),
      NodePort(label: 'テキスト配列', dataType: 'テキスト配列'),
      NodePort(label: 'ベクトル', dataType: 'ベクトル'),
    ],
  ),
  NodeCatalogEntry(
    type: 'storage.load',
    title: '読み出し (storage.safe)',
    icon: Icons.file_open_outlined,
    genre: '保存',
    description: 'スロットに保存したデータを読み出します。',
    inputs: [NodePort(label: 'スロット', value: '', dataType: '設定')],
    outputs: [
      NodePort(label: 'テキスト配列', dataType: 'テキスト配列'),
      NodePort(label: 'ベクトル', dataType: 'ベクトル'),
    ],
  ),
  NodeCatalogEntry(
    type: 'ml.keyword',
    title: 'キーワード一致 (GLiNER)',
    icon: Icons.label_important_outline,
    genre: 'ML',
    description: 'キーワード(または配列)と各投稿の特徴語の一致数を出します。',
    inputs: [
      NodePort(label: 'キーワード', value: '', dataType: 'テキスト'),
      NodePort(label: 'キーワードリスト', dataType: 'テキスト配列'),
    ],
    outputs: [NodePort(label: '一致度', dataType: '数値')],
  ),
  NodeCatalogEntry(
    type: 'compare',
    title: '比較',
    icon: Icons.functions,
    genre: '条件',
    description: '数値(類似度・乱数など)としきい値を比べて True/False を返す演算子条件です。値元が未接続・値が取れないとき(スロットが空など)は False になります。',
    inputs: [
      NodePort(label: '値元', dataType: '数値'),
      NodePort(label: '演算', value: '以上', dataType: '設定', options: ['以上', '以下', '等しい']),
      NodePort(label: '値', value: '0.5', dataType: '設定'),
    ],
    hasCondIn: true,
    hasCondOut: true,
  ),
];

/// 保存済みノードをカタログの最新形に追従させる (D-113)。追加された入力
/// (「アカウント」等)や選択肢(リスト名/アカウント一覧)を既存グラフにも
/// 反映する — 既存の設定値はラベルで引き継ぐ。カタログに無い type
/// (削除された関数など)はそのまま。入力はカタログ末尾追加が前提なので
/// エッジのポート番号は保たれる。
NodeGraph upgradeGraphNodes(NodeGraph g, Map<String, NodeCatalogEntry> catalog) {
  GraphNode upgrade(GraphNode n) {
    final e = catalog[n.type];
    if (e == null) return n;
    final inputs = [
      for (final ci in e.inputs)
        NodePort(
          label: ci.label,
          value: n.inputs.where((x) => x.label == ci.label).firstOrNull?.value ?? ci.value,
          dataType: ci.dataType,
          format: ci.format,
          options: ci.options,
        ),
    ];
    return GraphNode(
      id: n.id,
      type: n.type,
      title: e.title,
      x: n.x,
      y: n.y,
      inputs: inputs,
      outputs: e.outputs,
      hasCondIn: e.hasCondIn,
      hasCondOut: e.hasCondOut,
      condBranches: e.condBranches.isNotEmpty ? e.condBranches : n.condBranches,
    );
  }

  return NodeGraph(nodes: [for (final n in g.nodes) upgrade(n)], edges: g.edges);
}

/// 総合(バンドル)スコープの自動構成 (D-114): 各アカウントの
/// タイムライン取得 → マージ(3 口を段組み)→ タイムライン。
NodeGraph buildBundleGraph(List<String> accountLabels) {
  GraphNode inst(String type, String id, Offset at, {Map<String, String> values = const {}}) {
    final e = builtinNodeCatalog.firstWhere((x) => x.type == type);
    final n = e.instantiate(id, at);
    return n.copyWith(inputs: [
      for (final p in n.inputs) values.containsKey(p.label) ? p.copyWith(value: values[p.label]) : p,
    ]);
  }

  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  for (var i = 0; i < accountLabels.length; i++) {
    nodes.add(inst('tl.source', 's$i', Offset(24, 40 + i * 170), values: {'TL': 'home', 'アカウント': accountLabels[i]}));
  }
  // マージ段組み: 最初の段は取得×3、以降は前段のマージ + 取得×2。
  var mergeIndex = 0;
  String? currentOut; // 直近の出力ノード id
  var consumed = 0;
  if (accountLabels.length == 1) {
    currentOut = 's0';
    consumed = 1;
  }
  while (consumed < accountLabels.length) {
    final id = 'm$mergeIndex';
    nodes.add(inst('merge', id, Offset(260.0 + mergeIndex * 40, 120.0 + mergeIndex * 150)));
    var port = 0;
    if (currentOut != null) {
      edges.add(GraphEdge(from: currentOut, fromPort: 0, to: id, toPort: port++));
    }
    while (port < 3 && consumed < accountLabels.length) {
      edges.add(GraphEdge(from: 's$consumed', fromPort: 0, to: id, toPort: port++));
      consumed++;
    }
    currentOut = id;
    mergeIndex++;
  }
  nodes.add(builtinNodeCatalog.firstWhere((x) => x.type == 'timeline').instantiate('t0', Offset(520.0 + mergeIndex * 20, 160)));
  if (currentOut != null) edges.add(GraphEdge(from: currentOut, fromPort: 0, to: 't0', toPort: 0));
  return NodeGraph(nodes: nodes, edges: edges);
}

/// ユーザーが編集済みの総合グラフへ新アカウントの取得ノードを差し込む
/// (D-114)。終端タイムラインの 1 段前がマージで空き口があればそこへ。
/// 差し込めない形(マージ以外/満杯)は null — 手動に任せる。
NodeGraph? insertAccountIntoBundleGraph(NodeGraph g, String accountLabel) {
  final byId = {for (final n in g.nodes) n.id: n};
  for (final t in g.nodes.where((n) => n.type == 'timeline')) {
    final edge = g.edges.where((e) => !e.cond && !e.toIcon && e.to == t.id && e.toPort == 0).firstOrNull;
    final up = edge == null ? null : byId[edge.from];
    if (up == null || up.type != 'merge') continue;
    final used = {for (final e in g.edges) if (!e.cond && !e.toIcon && e.to == up.id) e.toPort};
    final free = [0, 1, 2].where((p) => !used.contains(p)).firstOrNull;
    if (free == null) continue;
    var seq = 0;
    for (final n in g.nodes) {
      final m = RegExp(r'^n?s?(\d+)$').firstMatch(n.id);
      if (m != null) seq = seq < int.parse(m.group(1)!) ? int.parse(m.group(1)!) : seq;
    }
    final src = builtinNodeCatalog.firstWhere((x) => x.type == 'tl.source').instantiate('s${seq + 1}', Offset(up.x - 230, up.y + 120));
    final withValues = src.copyWith(inputs: [
      for (final p in src.inputs)
        switch (p.label) {
          'TL' => p.copyWith(value: 'home'),
          'アカウント' => p.copyWith(value: accountLabel),
          _ => p,
        },
    ]);
    return NodeGraph(nodes: [...g.nodes, withValues], edges: [...g.edges, GraphEdge(from: withValues.id, fromPort: 0, to: up.id, toPort: free)]);
  }
  return null;
}
