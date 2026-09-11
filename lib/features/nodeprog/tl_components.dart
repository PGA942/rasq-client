import 'dart:convert';
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
  bool get isDm => tl.startsWith('dm:');
  String get listName => isList ? tl.substring(5) : '';
  String get dmPeer => isDm ? tl.substring(3) : '';

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

/// コンポーザーの基準 (D-132): 学習ループの確定投稿プロファイル
/// (storage.safe スロット)も基準に選べる。
const composerSuggestFromOptions = [...suggestFromOptions, '学習プロファイル'];

/// 学習プロファイルの storage.safe スロット名 (D-132)。
String composerLearnSlot(String account) => 'learn:$account';

String suggestFromKind(String from) => switch (from) {
      'リアクション' => 'myreactions',
      '会話内容' => 'myreplies',
      _ => 'myposts',
    };

@immutable
class TlAlgorithmComponent {
  const TlAlgorithmComponent({required this.type, this.what = 'キーワード', this.from = '投稿内容', this.pluginLabel = '', this.enabled = true, this.query = '', this.params = const {}});

  /// plugin: のパラメーター (D-169): プラグインの RRL 設定ページ(`tl.params`)で編集した値。
  final Map<String, Object?> params;

  /// 'chrono'(時系列順)| 'suggest' | 'filter'(絞り込み — サジェストと
  /// 同じパラメーターで、合わない投稿を除外, D-125)| 'queryfilter'
  /// (検索絞り込み — このページの検索ワード/タグに合う投稿だけ, D-125)|
  /// 'tendency'(指向性/刺激性 — storage.safe のトレンドプロファイルで
  /// 絞り込み + 適合度順, D-153)| `plugin:<tlId>`(カスタム TL プラグイン)。
  final String type;

  /// suggest/filter: なにを([キーワード/類似性])/なにから([投稿内容/リアクション/会話内容])。
  final String what;
  final String from;

  /// plugin: の表示名(「〇〇でソート」)。
  final String pluginLabel;

  /// 一時的な無効化 (D-123): 外さずに適用だけ止める(コンパイルから除外)。
  final bool enabled;

  /// queryfilter: 検索ワード('' = このページの検索ワード/タグ, D-125)。
  final String query;

  bool get isSuggest => type == 'suggest';
  bool get isFilter => type == 'filter';
  bool get isQueryFilter => type == 'queryfilter';
  bool get isTendency => type == 'tendency';
  bool get isPlugin => type.startsWith('plugin:');

  /// パラメーター編集の対象(サジェスト/絞り込みは同じ 2 パラメーター)。
  bool get hasSuggestParams => isSuggest || isFilter;

  String get title => switch (type) {
        'chrono' => '時系列順',
        'suggest' => '$whatを$fromからサジェスト',
        'filter' => '$whatを$fromから絞り込み',
        'queryfilter' => '検索絞り込み',
        'tendency' => '指向性/刺激性(プロファイル)',
        _ => pluginLabel.isEmpty ? 'カスタム(TLプラグイン)' : pluginLabel,
      };

  TlAlgorithmComponent copyWith({String? what, String? from, bool? enabled, String? query, Map<String, Object?>? params}) => TlAlgorithmComponent(
      type: type, what: what ?? this.what, from: from ?? this.from, pluginLabel: pluginLabel, enabled: enabled ?? this.enabled, query: query ?? this.query, params: params ?? this.params);
  Map<String, Object?> toJson() => {'type': type, 'what': what, 'from': from, 'pluginLabel': pluginLabel, 'enabled': enabled, 'query': query, if (params.isNotEmpty) 'params': params};
  factory TlAlgorithmComponent.fromJson(Map<String, Object?> j) => TlAlgorithmComponent(
      type: j['type'] as String? ?? 'chrono',
      what: j['what'] as String? ?? 'キーワード',
      from: j['from'] as String? ?? '投稿内容',
      pluginLabel: j['pluginLabel'] as String? ?? '',
      enabled: j['enabled'] != false,
      query: j['query'] as String? ?? '',
      params: (j['params'] as Map?)?.cast<String, Object?>() ?? const {});
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
  if (scope == 'tl.dm' || scope.startsWith('tl.dm:') || scope.startsWith('tl.chat:')) {
    // DM (D-127): メイン(tl.dm)= カスタム未設定の全 DM ページの共通設定、
    // 各ページ(tl.dm:<peer>)= そのルームだけの設定。どちらも self から。
    return const TlConfig(sources: [TlSourceComponent(tl: 'self')], algorithms: [TlAlgorithmComponent(type: 'chrono')], clock: '');
  }
  if (scope == 'trend.following') {
    // フォロー中タブ (D-125): フォロイーの投稿を検索ワード/タグで絞り込む —
    // 「home 取得 → 時系列順」だけだと意味が見えないので絞り込みを明示する。
    return const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'queryfilter'), TlAlgorithmComponent(type: 'chrono')]);
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
    } else if (s.isDm) {
      // DM 取得 (D-127): 相手指定の DM ルーム。
      nodes.add(inst('tl.dm', 's$i', at, values: {'相手': s.dmPeer, 'アカウント': s.account}));
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
    if (a.isQueryFilter) {
      // 検索絞り込み (D-125): ワード空 = このページの検索ワード/タグ。
      final id = 'a$i';
      nodes.add(inst('filter.query', id, Offset(x, 60), values: {'検索ワード': a.query}));
      edges.add(GraphEdge(from: out, fromPort: 0, to: id, toPort: 0));
      out = id;
      col++;
      continue;
    }
    if (a.isTendency) {
      // 指向性/刺激性 (D-153): プロファイルの適合度で「消去(0 = 嫌い/しきい値未満)」→「並べ替え」。
      // id は取得(s*)/クロック(c*)/他段(a*,c*,n*)と被らない接頭辞で。
      final rmId = 'ta$i';
      final sortId = 'ts$i';
      final mlId = 'tl$i';
      final cmpRm = 'tc$i';
      final cmpSort = 'td$i';
      final notId = 'tn$i';
      nodes.add(inst('remove', rmId, Offset(x, 60)));
      nodes.add(inst('sort', sortId, Offset(x + 120, 60)));
      nodes.add(inst('ml.tendency', mlId, Offset(x + 40, 300)));
      nodes.add(inst('compare', cmpRm, Offset(x - 20, 180), values: {'演算': '以上', '値': '0.01'}));
      nodes.add(inst('compare', cmpSort, Offset(x + 140, 180), values: {'演算': '以上', '値': '0'}));
      nodes.add(inst('not', notId, Offset(x - 10, 120)));
      edges.add(GraphEdge(from: out, fromPort: 0, to: rmId, toPort: 0));
      edges.add(GraphEdge(from: rmId, fromPort: 0, to: sortId, toPort: 0));
      edges.add(GraphEdge(from: mlId, fromPort: 0, to: cmpRm, toPort: 0));
      edges.add(GraphEdge(from: mlId, fromPort: 0, to: cmpSort, toPort: 0));
      edges.add(GraphEdge(from: rmId, fromPort: 0, to: notId, toPort: 0, cond: true));
      edges.add(GraphEdge(from: notId, fromPort: 0, to: cmpRm, toPort: 0, cond: true));
      edges.add(GraphEdge(from: sortId, fromPort: 0, to: cmpSort, toPort: 0, cond: true));
      out = sortId;
      col += 2;
      continue;
    }
    if (a.isPlugin) {
      final id = 'a$i';
      nodes.add(GraphNode(
          id: id,
          type: a.type,
          title: a.title,
          x: x,
          y: 60,
          inputs: [
            const NodePort(label: '投稿リスト', dataType: '投稿リスト'),
            // パラメーター (D-169): ノードを設定 FOW で編集した値を JSON で持たせる。
            if (a.params.isNotEmpty) NodePort(label: 'パラメーター', value: jsonEncode(a.params), dataType: '設定'),
          ],
          outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')]));
      edges.add(GraphEdge(from: out, fromPort: 0, to: id, toPort: 0));
      out = id;
      col++;
      continue;
    }
    // サジェスト/絞り込み (D-125): 基準取得 → 抽出(GLiNER/SigLIP)→ ML →
    // 比較 → 並べ替え(suggest)/ 消去 + Not(filter = 合わない投稿を除外)。
    final stepId = 'a$i';
    final refId = 'r$i';
    final exId = 'x$i';
    final mlId = 'l$i';
    final cmpId = 'c$i';
    final notId = 'n$i';
    nodes.add(inst(a.isFilter ? 'remove' : 'sort', stepId, Offset(x, 60)));
    nodes.add(inst('tl.source', refId, Offset(x - 40, 460), values: {'TL': suggestFromKind(a.from)}));
    edges.add(GraphEdge(from: out, fromPort: 0, to: stepId, toPort: 0));
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
    if (a.isFilter) {
      // 絞り込み: 「条件に合わない投稿を消す」= remove → Not → 比較。
      nodes.add(inst('not', notId, Offset(x + 10, 120)));
      edges.add(GraphEdge(from: stepId, fromPort: 0, to: notId, toPort: 0, cond: true));
      edges.add(GraphEdge(from: notId, fromPort: 0, to: cmpId, toPort: 0, cond: true));
    } else {
      edges.add(GraphEdge(from: stepId, fromPort: 0, to: cmpId, toPort: 0, cond: true));
    }
    out = stepId;
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

/// 絞り込みの 1 ノードぶん (D-131: ノード追加ボタンで複数積める)。
@immutable
class ComposerFilterSpec {
  const ComposerFilterSpec({this.what = 'キーワード', this.from = '投稿内容'});
  final String what;
  final String from;

  String get title => '$whatを$fromから絞り込み';

  ComposerFilterSpec copyWith({String? what, String? from}) => ComposerFilterSpec(what: what ?? this.what, from: from ?? this.from);
  Map<String, Object?> toJson() => {'what': what, 'from': from};
  factory ComposerFilterSpec.fromJson(Map<String, Object?> j) =>
      ComposerFilterSpec(what: j['what'] as String? ?? 'キーワード', from: j['from'] as String? ?? '投稿内容');
}

/// 投稿加工(正規表現)の 1 ノードぶん (D-131)。
@immutable
class ComposerRegexSpec {
  const ComposerRegexSpec({this.pattern = '', this.replace = ''});
  final String pattern;
  final String replace;

  ComposerRegexSpec copyWith({String? pattern, String? replace}) => ComposerRegexSpec(pattern: pattern ?? this.pattern, replace: replace ?? this.replace);
  Map<String, Object?> toJson() => {'pattern': pattern, 'replace': replace};
  factory ComposerRegexSpec.fromJson(Map<String, Object?> j) => ComposerRegexSpec(pattern: j['pattern'] as String? ?? '', replace: j['replace'] as String? ?? '');
}

/// コンポーザーのポスト先絞り込み (D-125): **アカウントごとタブ選択形式**。
/// 各アカウントに 1 つ、サジェスト/絞り込みと同じ 2 パラメーター
/// ([キーワード/類似性] × [投稿内容/リアクション/会話内容])を持ち、
/// 下書きがそのアカウントの基準に合うときポスト先候補になる。
@immutable
class ComposerAccountFilter {
  const ComposerAccountFilter(
      {this.enabled = false,
      this.what = 'キーワード',
      this.from = '投稿内容',
      this.fallbackEnabled = false,
      this.fallbackFormat = '注釈を付ける',
      this.fallbackCw = '',
      this.delivery = 'auto',
      this.regexEnabled = false,
      this.regexPattern = '',
      this.regexReplace = '',
      this.extraFilters = const [],
      this.extraRegexes = const [],
      this.linkSources = const ['*'],
      this.linkFilters = const []});

  final bool enabled;
  final String what;
  final String from;

  /// 代わりのフォーマットで投稿 (D-126): 絞り込みで投稿先から外れた場合、
  /// 代替フォーマット(注釈/フォロワー限定/連合なし)で候補に残す。
  final bool fallbackEnabled;
  final String fallbackFormat;
  final String fallbackCw;

  /// 連動投稿の届け方 (D-129, 原典: 投稿コンポーザーの話.md):
  /// 'auto'(そのまま投稿)| 'confirm'(投稿前にチェック済み状態で確認)|
  /// 'draft'(そのアカウント宛の下書きだけ作る)。
  final String delivery;

  /// 投稿加工(正規表現, D-130): このアカウントへ送る本文にパターン置換。
  final bool regexEnabled;
  final String regexPattern;
  final String regexReplace;

  /// 追加ノード (D-131): 絞り込み/加工はノード追加ボタンで複数積める
  /// (絞り込みは「かつ」で連結、加工は上から順に適用)。
  final List<ComposerFilterSpec> extraFilters;
  final List<ComposerRegexSpec> extraRegexes;

  /// 連動元のアカウント選択 (D-131): このアカウントへ連動できる主投稿先。
  /// `['*']` = すべて許可(既定)。空 = どこからも連動しない。
  final List<String> linkSources;

  /// 連動の絞り込み (D-131: 検討メモの F_target): 連動投稿だけに掛かる
  /// 絞り込み(サジェストのポスト先判定には影響しない)。
  final List<ComposerFilterSpec> linkFilters;

  bool linkAllowedFrom(String source) => linkSources.contains('*') || linkSources.contains(source);

  String get title => '$whatを$fromから絞り込み';

  ComposerAccountFilter copyWith(
          {bool? enabled,
          String? what,
          String? from,
          bool? fallbackEnabled,
          String? fallbackFormat,
          String? fallbackCw,
          String? delivery,
          bool? regexEnabled,
          String? regexPattern,
          String? regexReplace,
          List<ComposerFilterSpec>? extraFilters,
          List<ComposerRegexSpec>? extraRegexes,
          List<String>? linkSources,
          List<ComposerFilterSpec>? linkFilters}) =>
      ComposerAccountFilter(
          enabled: enabled ?? this.enabled,
          what: what ?? this.what,
          from: from ?? this.from,
          fallbackEnabled: fallbackEnabled ?? this.fallbackEnabled,
          fallbackFormat: fallbackFormat ?? this.fallbackFormat,
          fallbackCw: fallbackCw ?? this.fallbackCw,
          delivery: delivery ?? this.delivery,
          regexEnabled: regexEnabled ?? this.regexEnabled,
          regexPattern: regexPattern ?? this.regexPattern,
          regexReplace: regexReplace ?? this.regexReplace,
          extraFilters: extraFilters ?? this.extraFilters,
          extraRegexes: extraRegexes ?? this.extraRegexes,
          linkSources: linkSources ?? this.linkSources,
          linkFilters: linkFilters ?? this.linkFilters);
  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'what': what,
        'from': from,
        'fallbackEnabled': fallbackEnabled,
        'fallbackFormat': fallbackFormat,
        'fallbackCw': fallbackCw,
        'delivery': delivery,
        'regexEnabled': regexEnabled,
        'regexPattern': regexPattern,
        'regexReplace': regexReplace,
        'extraFilters': [for (final f in extraFilters) f.toJson()],
        'extraRegexes': [for (final r in extraRegexes) r.toJson()],
        'linkSources': linkSources,
        'linkFilters': [for (final f in linkFilters) f.toJson()],
      };
  factory ComposerAccountFilter.fromJson(Map<String, Object?> j) => ComposerAccountFilter(
      enabled: j['enabled'] == true,
      what: j['what'] as String? ?? 'キーワード',
      from: j['from'] as String? ?? '投稿内容',
      fallbackEnabled: j['fallbackEnabled'] == true,
      fallbackFormat: j['fallbackFormat'] as String? ?? '注釈を付ける',
      fallbackCw: j['fallbackCw'] as String? ?? '',
      extraFilters: [for (final f in (j['extraFilters'] as List? ?? const [])) ComposerFilterSpec.fromJson((f as Map).cast<String, Object?>())],
      extraRegexes: [for (final r in (j['extraRegexes'] as List? ?? const [])) ComposerRegexSpec.fromJson((r as Map).cast<String, Object?>())],
      linkSources: (j['linkSources'] as List?)?.cast<String>() ?? const ['*'],
      linkFilters: [for (final f in (j['linkFilters'] as List? ?? const [])) ComposerFilterSpec.fromJson((f as Map).cast<String, Object?>())],
      delivery: j['delivery'] as String? ?? 'auto',
      regexEnabled: j['regexEnabled'] == true,
      regexPattern: j['regexPattern'] as String? ?? '',
      regexReplace: j['regexReplace'] as String? ?? '');
}

/// 連動投稿の届け方の表示 (D-129)。
const composerDeliveryOptions = ['auto', 'confirm', 'draft'];
String composerDeliveryLabel(String d) => switch (d) {
      'confirm' => '確認して投稿 (confirm)',
      'draft' => '下書きだけ作る (draft)',
      _ => 'そのまま投稿 (auto)',
    };

/// コンポーザーグラフの正規表現加工ルール (D-130):
/// (アカウント表記('' = すべて), パターン, 置換)。
List<(String, String, String)> composerRegexRules(NodeGraph g) => [
      for (final n in g.nodes)
        if (n.type == 'composer.regex')
          (
            n.inputs.where((i) => i.label == 'アカウント').firstOrNull?.value?.trim() ?? '',
            n.inputs.where((i) => i.label == 'パターン').firstOrNull?.value ?? '',
            n.inputs.where((i) => i.label == '置換').firstOrNull?.value ?? '',
          ),
    ];

/// [account](表記 or キー)へ送る本文に正規表現加工を適用する (D-130)。
/// パターンが不正なルールは無視(投稿は落とさない)。
String applyComposerRegex(String text, String account, List<(String, String, String)> rules) {
  var out = text;
  for (final (target, pattern, replace) in rules) {
    if (pattern.isEmpty) continue;
    if (target.isNotEmpty && target != account) continue;
    try {
      out = out.replaceAll(RegExp(pattern), replace);
    } catch (_) {} // 不正な正規表現はスキップ
  }
  return out;
}

/// アカウント表記 → 絞り込みの構成 → コンポーザーグラフ (D-125)。
/// 有効なアカウントだけ「ポスト先 + 比較 ← ML ← 抽出 ← 基準取得(その
/// アカウントの投稿/リアクション/返信)」の鎖になる。基準はアカウント指定
/// (`acct:<表記>|myposts` 等)で、そのアカウントのセッションから取る。
/// 類似度は下書き 1 件の生値比較(正規化なし)なので、しきい値は
/// キーワード = 1(特徴語の一致数)/類似性 = 0.2(n-gram cos の生値)。
NodeGraph compileComposerConfig(Map<String, ComposerAccountFilter> byAccount, List<String> accounts) {
  GraphNode inst(String type, String id, Offset at, {Map<String, String> values = const {}}) {
    final e = builtinNodeCatalog.firstWhere((x) => x.type == type);
    final n = e.instantiate(id, at);
    return n.copyWith(inputs: [for (final p in n.inputs) values.containsKey(p.label) ? p.copyWith(value: values[p.label]) : p]);
  }

  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  var seq = 0;

  /// 絞り込み 1 ノードぶんの ML チェーン(基準取得 → 抽出 → ML → 比較)を
  /// 置いて比較ノードの id を返す。
  String compareChain(String account, ComposerFilterSpec spec, double x, double y) {
    final id = seq++;
    final refId = 'r$id';
    final exId = 'x$id';
    final mlId = 'l$id';
    final cmpId = 'c$id';
    // 学習プロファイル (D-132): storage.safe の確定投稿プロファイルを基準に
    // (読み出しノード経由 — texts = キーワード基準、vector = 類似性基準)。
    if (spec.from == '学習プロファイル') {
      nodes.add(inst('storage.load', refId, Offset(x + 320, y + 130), values: {'スロット': composerLearnSlot(account)}));
      if (spec.what == '類似性') {
        nodes.add(inst('ml.similar', mlId, Offset(x + 280, y + 20)));
        nodes.add(inst('compare', cmpId, Offset(x + 20, y + 90), values: {'演算': '以上', '値': '0.2'}));
        edges.add(GraphEdge(from: refId, fromPort: 1, to: mlId, toPort: 2)); // ベクトル出力 → 基準ベクトル
      } else {
        nodes.add(inst('ml.keyword', mlId, Offset(x + 280, y + 20)));
        nodes.add(inst('compare', cmpId, Offset(x + 20, y + 90), values: {'演算': '以上', '値': '1'}));
        edges.add(GraphEdge(from: refId, fromPort: 0, to: mlId, toPort: 1)); // テキスト配列 → キーワードリスト
      }
      edges.add(GraphEdge(from: mlId, fromPort: 0, to: cmpId, toPort: 0));
      return cmpId;
    }
    nodes.add(inst('tl.source', refId, Offset(x + 320, y + 130), values: {'TL': suggestFromKind(spec.from), 'アカウント': account}));
    if (spec.what == '類似性') {
      nodes.add(inst('ml.siglip', exId, Offset(x + 300, y + 70)));
      nodes.add(inst('ml.similar', mlId, Offset(x + 280, y + 20)));
      nodes.add(inst('compare', cmpId, Offset(x + 20, y + 90), values: {'演算': '以上', '値': '0.2'}));
      edges.add(GraphEdge(from: refId, fromPort: 0, to: exId, toPort: 0));
      edges.add(GraphEdge(from: exId, fromPort: 0, to: mlId, toPort: 2));
    } else {
      nodes.add(inst('ml.gliner', exId, Offset(x + 300, y + 70)));
      nodes.add(inst('ml.keyword', mlId, Offset(x + 280, y + 20)));
      nodes.add(inst('compare', cmpId, Offset(x + 20, y + 90), values: {'演算': '以上', '値': '1'}));
      edges.add(GraphEdge(from: refId, fromPort: 0, to: exId, toPort: 0));
      edges.add(GraphEdge(from: exId, fromPort: 0, to: mlId, toPort: 1));
    }
    edges.add(GraphEdge(from: mlId, fromPort: 0, to: cmpId, toPort: 0));
    return cmpId;
  }

  /// 複数の絞り込みを「かつ」(数珠繋ぎ)で [ownerId] の条件接続部へ。
  /// 返り値 = 先頭の比較ノード id(フォールバックの Not のバイパス元)。
  String? andChain(String ownerId, String account, List<ComposerFilterSpec> specs, double x, double y) {
    String? head;
    String? prev;
    for (var k = 0; k < specs.length; k++) {
      final cmpId = compareChain(account, specs[k], x + k * 60, y + k * 160);
      if (prev == null) {
        edges.add(GraphEdge(from: ownerId, fromPort: 0, to: cmpId, toPort: 0, cond: true));
        head = cmpId;
      } else {
        edges.add(GraphEdge(from: prev, fromPort: 0, to: cmpId, toPort: 0, cond: true)); // かつ (D-094)
      }
      prev = cmpId;
    }
    return head;
  }

  var row = 0;
  // 投稿加工(正規表現, D-130/D-131): 絞り込みの有効/無効と独立に、
  // アカウント別の加工ノードを置く(ノード追加ボタンで複数、上から順)。
  for (var i = 0; i < accounts.length; i++) {
    final f = byAccount[accounts[i]];
    if (f == null) continue;
    final specs = [
      if (f.regexEnabled && f.regexPattern.isNotEmpty) ComposerRegexSpec(pattern: f.regexPattern, replace: f.regexReplace),
      ...f.extraRegexes.where((r) => r.pattern.isNotEmpty),
    ];
    for (var k = 0; k < specs.length; k++) {
      nodes.add(inst('composer.regex', 'rx${i}_$k', Offset(900.0 + k * 40, 40.0 + i * 120 + k * 30),
          values: {'アカウント': accounts[i], 'パターン': specs[k].pattern, '置換': specs[k].replace}));
    }
  }
  for (var i = 0; i < accounts.length; i++) {
    final account = accounts[i];
    final f = byAccount[account];
    if (f == null) continue;
    final y = 40.0 + row * 480;
    if (f.enabled) {
      final targetId = 't$i';
      nodes.add(inst('composer.target', targetId, Offset(100, y), values: {'アカウント': account}));
      // 絞り込み(主 + 追加ノード)を「かつ」で連結 (D-131)。
      final head = andChain(targetId, account, [ComposerFilterSpec(what: f.what, from: f.from), ...f.extraFilters], 100, y);
      // 代わりのフォーマットで投稿 (D-126): 絞り込みに合わなかったとき —
      // **無くなる直前のノード(比較の先頭)からバイパス**(Not で受ける)。
      if (f.fallbackEnabled && head != null) {
        final fbId = 'fb$i';
        final notId = 'nt$i';
        nodes.add(inst('composer.fallback', fbId, Offset(640, y), values: {'アカウント': account, 'フォーマット': f.fallbackFormat, '注釈': f.fallbackCw}));
        nodes.add(inst('not', notId, Offset(660, y + 60)));
        edges.add(GraphEdge(from: fbId, fromPort: 0, to: notId, toPort: 0, cond: true));
        edges.add(GraphEdge(from: notId, fromPort: 0, to: head, toPort: 0, cond: true));
      }
      row++;
    }
    // 連動の絞り込み (D-131: F_target): 連動投稿だけに掛かる関門ノード。
    if (f.linkFilters.isNotEmpty) {
      final gateId = 'lg$i';
      nodes.add(inst('composer.linkgate', gateId, Offset(1200, y), values: {'アカウント': account}));
      andChain(gateId, account, f.linkFilters, 1200, y);
      if (!f.enabled) row++;
    }
  }
  return NodeGraph(nodes: nodes, edges: edges);
}
