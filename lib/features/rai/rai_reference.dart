import 'dart:convert';
import 'dart:math' as math;

/// RAi のリファレンス関数 (D-179 → D-189)。
///
/// 端末側に持つ 2 種のリファレンス(どちらも jsonl、`assets/rai/`):
/// - **関数リファレンス** [RaiFunction]: 「何ができるか」(`does`)と引数。引数は
///   **事前に値を決められるもの**(`preset`: unixTime / hide / replyLimit など。ホストが埋める)と
///   **必ず入力しなければならないもの**(`input`: main / searchIndex など)に分かれる。小さいモデルに
///   定数を必要以上に触らせないため、LLM に渡すのは `input` だけ。
/// - **操作リファレンス** [RaiOperation]: ユーザーが短文で渡す「高度なインデックス」(`index`)から、
///   関数リファレンスの検索手順(`steps` = 関数 id の列 + 発言)を提案する。
///
/// 検索は **SigLIP のテキスト埋め込み**([RaiEmbedder]。ML ゲートウェイ未構成 / テストでは同じ契約の
/// 文字 n-gram ハッシュ埋め込み)+ キーワードのハイブリッド([RaiReferenceIndex])。問い合わせは
/// (a) 入力そのまま、(b) LLM が「シチュエーション」の一文を生成してから検索、の 2 通り
/// ([RaiSearchMode])。評価は `assets/rai/eval.jsonl` を `tool/rai_reference_eval.dart` で回す。
///
/// このファイルは flutter に依存しない(評価ツールを `dart run` で回すため)。

/// 引数の種類: 事前に値を決められる(ホストが埋める)/ 必ず入力する。
enum RaiParamKind { preset, input }

class RaiParam {
  const RaiParam({required this.name, required this.kind, this.label, this.value});
  final String name;
  final RaiParamKind kind;

  /// 表示名(input を聞くとき / preset を並べるとき)。
  final String? label;

  /// preset の値。`$unixTime` / `$unixTime-7d` / `$today` のマクロは [RaiPresets] が解決する。
  final Object? value;
  bool get isInput => kind == RaiParamKind.input;
  String get display => label ?? name;

  factory RaiParam.fromJson(Map<String, Object?> j) => RaiParam(
        name: '${j['name']}',
        kind: j['kind'] == 'input' ? RaiParamKind.input : RaiParamKind.preset,
        label: j['label'] as String?,
        value: j['value'],
      );
}

/// 指差す部品(ツールチップ / 表示テキスト)。
class RaiTarget {
  const RaiTarget({this.tooltip, this.label});
  final String? tooltip;
  final String? label;
  static RaiTarget? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = RaiTarget(tooltip: j['tooltip'] as String?, label: j['label'] as String?);
    return t.tooltip == null && t.label == null ? null : t;
  }
}

/// 関数リファレンスの 1 行。
class RaiFunction {
  const RaiFunction({required this.id, required this.does, this.tags = const [], this.params = const [], this.route, this.target});
  final String id;

  /// どんなことができるか(検索 / 提案の本文)。
  final String does;
  final List<String> tags;
  final List<RaiParam> params;

  /// 部品がある画面(ディープリンク)。
  final String? route;
  final RaiTarget? target;

  List<RaiParam> get inputs => [for (final p in params) if (p.isInput) p];
  List<RaiParam> get presets => [for (final p in params) if (!p.isInput) p];

  /// 埋め込む文(does + タグ)。
  String get text => [does, ...tags].join(' ');

  factory RaiFunction.fromJson(Map<String, Object?> j) => RaiFunction(
        id: '${j['id']}',
        does: '${j['does'] ?? ''}',
        tags: [for (final t in (j['tags'] as List? ?? const [])) '$t'],
        params: [for (final p in (j['params'] as List? ?? const [])) RaiParam.fromJson((p as Map).cast<String, Object?>())],
        route: j['route'] as String?,
        target: RaiTarget.fromJson(j['target']),
      );
}

/// 1 手順: 発言と、指差す部品、必要なら先に開く画面、対応する関数 id。
class RaiStep {
  const RaiStep(this.text, {this.tooltip, this.label, this.route, this.fn, this.inputs = const [], this.presets = const {}});
  final String text;
  final String? tooltip;
  final String? label;
  final String? route;

  /// 関数リファレンスの id(手順が関数に対応するとき)。
  final String? fn;

  /// 関数の「必ず入力する」引数の表示名。
  final List<String> inputs;

  /// 関数の「事前に決まる」引数(表示名 → 解決済みの値)。
  final Map<String, Object?> presets;
  bool get hasTarget => tooltip != null || label != null;

  RaiStep withTarget(RaiTarget? t, {String? route}) => RaiStep(text, tooltip: tooltip ?? t?.tooltip, label: label ?? t?.label, route: this.route ?? route, fn: fn, inputs: inputs, presets: presets);
}

/// 操作リファレンスの 1 行(index = 短文の高度なインデックス)。
class RaiOperation {
  const RaiOperation({required this.id, required this.index, this.tags = const [], this.steps = const []});
  final String id;
  final String index;
  final List<String> tags;
  final List<RaiOperationStep> steps;
  String get title => index;
  String get text => [index, ...tags].join(' ');

  factory RaiOperation.fromJson(Map<String, Object?> j) => RaiOperation(
        id: '${j['id']}',
        index: '${j['index'] ?? j['title'] ?? ''}',
        tags: [for (final t in (j['tags'] as List? ?? const [])) '$t'],
        steps: [for (final s in (j['steps'] as List? ?? const [])) RaiOperationStep.fromJson((s as Map).cast<String, Object?>())],
      );
}

class RaiOperationStep {
  const RaiOperationStep({required this.say, this.fn, this.route, this.target});
  final String say;
  final String? fn;
  final String? route;
  final RaiTarget? target;
  factory RaiOperationStep.fromJson(Map<String, Object?> j) => RaiOperationStep(say: '${j['say'] ?? ''}', fn: j['fn'] as String?, route: j['route'] as String?, target: RaiTarget.fromJson(j['target']));
}

/// 互換: 旧 `RaiInstruction`(操作リファレンス + 展開済みの手順)。
class RaiInstruction {
  const RaiInstruction({required this.id, required this.title, required this.keywords, required this.steps});
  final String id;
  final String title;
  final List<String> keywords;
  final List<RaiStep> steps;
}

/// jsonl(1 行 1 オブジェクト。空行 / `#` 行は無視)。
List<Map<String, Object?>> parseJsonl(String text) => [
      for (final line in const LineSplitter().convert(text))
        if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) (jsonDecode(line) as Map).cast<String, Object?>(),
    ];

/// preset 値のマクロ解決(`$unixTime`, `$unixTime-7d`, `$today`)。それ以外はそのまま。
class RaiPresets {
  const RaiPresets({this.now});
  final DateTime? now;

  Object? resolve(Object? v) {
    if (v is! String || !v.startsWith(r'$')) return v;
    final t = now ?? DateTime.now();
    if (v == r'$today') return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final m = RegExp(r'^\$unixTime(?:([+-])(\d+)([smhd]))?$').firstMatch(v);
    if (m != null) {
      var secs = t.millisecondsSinceEpoch ~/ 1000;
      if (m.group(1) != null) {
        const unit = {'s': 1, 'm': 60, 'h': 3600, 'd': 86400};
        final delta = int.parse(m.group(2)!) * unit[m.group(3)]!;
        secs += m.group(1) == '-' ? -delta : delta;
      }
      return secs;
    }
    return v;
  }

  Map<String, Object?> resolveAll(RaiFunction f) => {for (final p in f.presets) p.display: resolve(p.value)};
}

/// テキスト埋め込みの契約(SigLIP テキスト塔 / 代替)。返りは L2 正規化済み。
abstract class RaiEmbedder {
  String get name;
  Future<List<List<double>>> embed(List<String> texts);
}

/// 文字 2〜3-gram のハッシュ埋め込み(SigLIP が使えない環境 / テスト用。同じ契約)。
class NgramRaiEmbedder implements RaiEmbedder {
  const NgramRaiEmbedder({this.dims = 256});
  final int dims;
  @override
  String get name => 'ngram-$dims';

  @override
  Future<List<List<double>>> embed(List<String> texts) async => [for (final t in texts) embedOne(t)];

  List<double> embedOne(String text) {
    final v = List<double>.filled(dims, 0);
    final s = ' ${text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
    for (var n = 2; n <= 3; n++) {
      for (var i = 0; i + n <= s.length; i++) {
        final g = s.substring(i, i + n);
        if (g.trim().length < 2) continue; // 1 文字だけの gram は捨てる(漢字 1 字が支配しないように)
        final h = g.hashCode;
        final idx = (h & 0x7fffffff) % dims;
        v[idx] += (h & 0x80000000) == 0 ? 1.0 : -1.0; // 符号付きで衝突を薄める
      }
    }
    return normalize(v);
  }

  static List<double> normalize(List<double> v) {
    var n = 0.0;
    for (final x in v) {
      n += x * x;
    }
    n = n == 0 ? 1 : math.sqrt(n);
    return [for (final x in v) x / n];
  }
}

double cosine(List<double> a, List<double> b) {
  var s = 0.0;
  final n = math.min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// 文字 2-gram の Dice 係数(`plugin_actions.tagSimilarity` と同じ式。flutter 非依存のためここに持つ)。
double diceSimilarity(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  Map<String, int> grams(String s) {
    final t = ' $s ';
    final out = <String, int>{};
    for (var i = 0; i + 2 <= t.length; i++) {
      out[t.substring(i, i + 2)] = (out[t.substring(i, i + 2)] ?? 0) + 1;
    }
    return out;
  }
  final ga = grams(x), gb = grams(y);
  var common = 0;
  for (final e in ga.entries) {
    final c = gb[e.key];
    if (c != null) common += e.value < c ? e.value : c;
  }
  final total = ga.values.fold(0, (s, v) => s + v) + gb.values.fold(0, (s, v) => s + v);
  return total == 0 ? 0 : 2 * common / total;
}

/// 問い合わせの語尾(〜したい / 〜するには / 〜はどこ …)と、タグの動詞の終止形の末尾(探す → 探、書く → 書)を
/// 落として、活用の違いで外さないようにする(SigLIP 側は不要だがキーワード側は素の文字一致なので)。
String stemJa(String s) {
  var t = s.trim().toLowerCase();
  const tails = ['したいです', 'したいんだけど', 'したい', 'するには', 'する方法', 'の方法', 'のやり方', 'はどこ', 'ですか', 'ますか', 'には', 'たい', 'して', 'する', 'できる', '方法', 'やり方', '？', '?', '。'];
  var changed = true;
  while (changed) {
    changed = false;
    for (final tail in tails) {
      if (t.length > tail.length + 1 && t.endsWith(tail)) {
        t = t.substring(0, t.length - tail.length);
        changed = true;
      }
    }
  }
  return t;
}

/// タグの語幹と、それが動詞(終止形)だったか。動詞は「何をしたいか」を担うので、当たったときの覆いに下限を置く。
({String stem, bool verb}) _stemKey(String k) {
  final t = k.trim().toLowerCase();
  if (t.length >= 2 && RegExp(r'[うくぐすつぬぶむる]$').hasMatch(t)) return (stem: t.substring(0, t.length - 1), verb: true);
  return (stem: t, verb: false);
}

/// キーワード側のスコア: タイトル / タグが問い合わせに含まれる(含む)ときは、その語が問い合わせを
/// どれだけ覆うか(短い語 1 つの一致で満点にしない: 「投稿のリンクをコピー」の「投稿」)、それ以外は
/// 2-gram Dice の最大。当たったタグが複数なら覆いを足し合わせる(「投稿」+「リンク」)。
double keywordScore(String query, List<String> keys) {
  final q = stemJa(query);
  if (q.isEmpty) return 0;
  var best = 0.0;
  var covered = 0.0;
  var hits = 0;
  for (final k in keys) {
    final (stem: kk, verb: verb) = _stemKey(k);
    if (kk.isEmpty) continue;
    double s;
    if (kk.contains(q)) {
      // 問い合わせがタグの一部(「投稿」⊂「画像を付けて投稿」)なら、タグをどれだけ覆うかで下げる。
      final c = math.min(1.0, q.length / kk.length);
      s = 0.5 + 0.5 * c;
      hits++;
      covered += c;
    } else if (q.contains(kk)) {
      final c = math.max(verb ? 0.6 : 0.0, math.min(1.0, kk.length / q.length));
      s = 0.5 + 0.5 * c;
      hits++;
      covered += c;
    } else {
      s = diceSimilarity(q, kk);
    }
    if (s > best) best = s;
  }
  if (hits > 1) best = math.max(best, 0.5 + 0.5 * math.min(1.0, covered));
  return best + math.max(0, hits - 1) * 0.05;
}

/// 問い合わせの作り方: 入力そのまま / LLM がシチュエーションの一文を作ってから。
enum RaiSearchMode { raw, situation }

class RaiHit<T> {
  const RaiHit({required this.item, required this.score, required this.vector, required this.keyword});
  final T item;

  /// ハイブリッドのスコア(`weight` × ベクトル + (1 − weight) × キーワード)。
  final double score;
  final double vector;
  final double keyword;
}

/// 検索 1 回の記録(評価用ログ)。
class RaiSearchTrace {
  const RaiSearchTrace({required this.query, required this.mode, required this.situation, required this.kind, required this.hits, required this.at});
  final String query;
  final RaiSearchMode mode;
  final String? situation;
  final String kind; // operations / functions
  final List<({String id, double score})> hits;
  final DateTime at;
  @override
  String toString() => '[$kind/${mode.name}] "$query"${situation == null ? '' : ' → "$situation"'} → ${hits.map((h) => '${h.id}:${h.score.toStringAsFixed(2)}').join(', ')}';
}

/// ハイブリッド索引(ベクトル + キーワード)。
class RaiReferenceIndex {
  RaiReferenceIndex._(this.functions, this.operations, this.embedder, this._fnVectors, this._opVectors);
  final List<RaiFunction> functions;
  final List<RaiOperation> operations;
  final RaiEmbedder embedder;
  final List<List<double>> _fnVectors;
  final List<List<double>> _opVectors;

  /// 直近の検索の記録(新しい順、100 件まで)。
  final List<RaiSearchTrace> traces = [];

  /// ベクトルの重み(残りはキーワード)。
  static const weight = 0.5;
  static const threshold = 0.42;

  static Future<RaiReferenceIndex> build({required List<RaiFunction> functions, required List<RaiOperation> operations, required RaiEmbedder embedder}) async {
    final fv = await embedder.embed([for (final f in functions) f.text]);
    final ov = await embedder.embed([for (final o in operations) o.text]);
    return RaiReferenceIndex._(functions, operations, embedder, fv, ov);
  }

  static Future<RaiReferenceIndex> fromJsonl({required String functionsJsonl, required String operationsJsonl, required RaiEmbedder embedder}) => build(
        functions: [for (final j in parseJsonl(functionsJsonl)) RaiFunction.fromJson(j)],
        operations: [for (final j in parseJsonl(operationsJsonl)) RaiOperation.fromJson(j)],
        embedder: embedder,
      );

  RaiFunction? function(String id) {
    for (final f in functions) {
      if (f.id == id) return f;
    }
    return null;
  }

  RaiOperation? operation(String id) {
    for (final o in operations) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// 操作リファレンスを引く(閾値未満は返さない)。[situation] を渡すとそれも問い合わせに足す。
  Future<List<RaiHit<RaiOperation>>> searchOperations(String query, {int k = 3, String? situation, double? threshold}) async {
    final hits = await _search<RaiOperation>(query, situation, operations, _opVectors, (o) => [o.index, ...o.tags], k, threshold ?? RaiReferenceIndex.threshold);
    _trace(query, situation, 'operations', [for (final h in hits) (id: h.item.id, score: h.score)]);
    return hits;
  }

  Future<List<RaiHit<RaiFunction>>> searchFunctions(String query, {int k = 3, String? situation, double? threshold}) async {
    final hits = await _search<RaiFunction>(query, situation, functions, _fnVectors, (f) => [f.does, ...f.tags], k, threshold ?? RaiReferenceIndex.threshold);
    _trace(query, situation, 'functions', [for (final h in hits) (id: h.item.id, score: h.score)]);
    return hits;
  }

  Future<List<RaiHit<T>>> _search<T>(String query, String? situation, List<T> items, List<List<double>> vectors, List<String> Function(T) keys, int k, double threshold) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final text = situation == null || situation.trim().isEmpty ? q : '$q $situation';
    final qv = (await embedder.embed([text])).single;
    final scored = <RaiHit<T>>[];
    for (var i = 0; i < items.length; i++) {
      final vec = math.max(0.0, cosine(qv, vectors[i]));
      final kw = math.max(keywordScore(q, keys(items[i])), situation == null ? 0.0 : keywordScore(situation, keys(items[i])) * 0.8);
      scored.add(RaiHit(item: items[i], score: weight * vec + (1 - weight) * math.min(1.0, kw), vector: vec, keyword: kw));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final h in scored.take(k)) if (h.score >= threshold) h];
  }

  void _trace(String query, String? situation, String kind, List<({String id, double score})> hits) {
    traces.insert(0, RaiSearchTrace(query: query, mode: situation == null ? RaiSearchMode.raw : RaiSearchMode.situation, situation: situation, kind: kind, hits: hits, at: DateTime.now()));
    if (traces.length > 100) traces.removeLast();
  }

  /// 操作リファレンスの手順を、関数リファレンスで肉付けした [RaiStep] に展開する
  /// (関数の部品 / 画面を引き継ぎ、preset は解決、input は表示名の列)。
  List<RaiStep> expand(RaiOperation op, {RaiPresets presets = const RaiPresets()}) => [
        for (final s in op.steps)
          () {
            final f = s.fn == null ? null : function(s.fn!);
            return RaiStep(
              s.say,
              tooltip: s.target?.tooltip,
              label: s.target?.label,
              route: s.route,
              fn: s.fn,
              inputs: [for (final p in f?.inputs ?? const <RaiParam>[]) p.display],
              presets: f == null ? const {} : presets.resolveAll(f),
            ).withTarget(f?.target, route: f?.route);
          }(),
      ];

  /// 旧契約 (D-179): キーワードだけで一番近い操作(閾値未満は null)。
  ({RaiInstruction instruction, double score})? matchInstruction(String query, {double threshold = 0.45}) {
    ({RaiOperation op, double score})? best;
    for (final op in operations) {
      final s = keywordScore(query, [op.index, ...op.tags]);
      if (best == null || s > best.score) best = (op: op, score: s);
    }
    if (best == null || best.score < threshold) return null;
    final op = best.op;
    return (instruction: RaiInstruction(id: op.id, title: op.index, keywords: op.tags, steps: expand(op)), score: best.score);
  }
}

/// アシスタント向けの提案文: 操作リファレンスの手順を「関数の検索手順」として並べる
/// (関数 / できること / 入力するもの / 決まっているもの)。1 行 = 1 発言 (D-182 の行割りに合わせて `\n`)。
List<String> proposalLines(RaiOperation op, List<RaiStep> steps) {
  final lines = <String>['「${op.index}」なら、この順で進めます(${steps.length} 手順)'];
  for (var i = 0; i < steps.length; i++) {
    final s = steps[i];
    final b = StringBuffer('${i + 1}. ${s.text}');
    if (s.fn != null) {
      b.write('〔${s.fn}〕');
      if (s.inputs.isNotEmpty) b.write(' 入力: ${s.inputs.join('、')}');
      if (s.presets.isNotEmpty) b.write(' 固定: ${s.presets.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    }
    lines.add(b.toString());
  }
  return lines;
}

/// LLM に「シチュエーション」の一文を作らせるときの指示(入力そのままでは引けない言い回しを補う)。
const raiSituationSystem = 'ユーザーの発言を、SNS ブラウザ RASQ で何をしたい状況かを表す日本語の一文に言い換えてください。一文だけ、20 文字程度で。';
