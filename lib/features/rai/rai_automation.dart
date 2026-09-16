import 'package:flutter/foundation.dart';

import 'rai_functions.dart';
import 'rai_reference.dart';

/// 関数優先の自動化 (D-229): 「スキップ」→ 承認 → 手順を **UI を押さずに関数で** 進める。
///
/// - 操作リファレンスの手順が持つ関数 id(`fn`)に、呼べる RAi 関数と引数の埋め方を対応させる([raiAutoBindings])。
/// - 対応のある手順だけ実行し、その手前の UI 手順(歯車を押す、タイルを選ぶ …)は「関数で代替」として畳む。
///   最後の対応手順より後に部品を押す手順が残れば、そこからは通常の案内(指差し)に渡す。
/// - 引数(フィード名 / ワード / 本文 / 取り込み先)は ①これまでの答え ②質問文からの抽出 ③直前の取得結果の候補
///   の順で埋め、埋まらなければ**選択肢タイル**(入力タイルの上の FOW)で聞く。ただし質問に「任せる / 自動で」の
///   ような文言があれば([raiEntrusted])候補の先頭で進める。
/// - 取得系(fetch)の結果が空なら止まって別の語を聞く(条件分岐の「止まる / 進む / 聞く」)。
@immutable
class RaiAutoBinding {
  const RaiAutoBinding({required this.call, this.args = const {}, this.fetch = false, this.produces, this.destination = false});

  /// 呼ぶ RAi 関数名(`RaiFunctionRunner` の名前)。
  final String call;

  /// 引数の型: 値が `$ラベル` なら入力から埋める。
  final Map<String, String> args;

  /// 取得系(結果の候補を後の入力に使う)。
  final bool fetch;

  /// 取得結果が埋める入力のラベル(例: フィード)。
  final String? produces;

  /// 「取り込み先」(ホームのタイムライン / トレンドの指向性 / 両方)を選ばせる。
  final bool destination;

  /// 埋めるべき入力のラベル。
  List<String> get inputs => [
        for (final v in args.values)
          if (v.startsWith(r'$')) v.substring(1),
        if (destination) raiDestinationLabel,
      ];
}

const raiDestinationLabel = '取り込み先';
const raiDestinationHome = 'ホームのタイムライン';
const raiDestinationTendency = 'トレンドの指向性';
const raiDestinationBoth = '両方';
const raiDestinations = [raiDestinationHome, raiDestinationTendency, raiDestinationBoth];

/// 関数リファレンスの id → 呼べる関数 (D-229)。
const raiAutoBindings = <String, RaiAutoBinding>{
  // 保存済み一覧は「見る」だけ(候補にはしない: 後の検索の語を上書きしないように)。
  'feeds.open': RaiAutoBinding(call: 'feeds.list', fetch: true),
  'feeds.search': RaiAutoBinding(call: 'feeds.list', args: {'keyword': r'$フィード'}, fetch: true, produces: 'フィード'),
  'feeds.save': RaiAutoBinding(call: 'feed.save', args: {'feed': r'$フィード'}),
  'timeline.addFeed': RaiAutoBinding(call: 'timeline.addFeed', args: {'feed': r'$フィード'}, destination: true),
  'timeline.importFeed': RaiAutoBinding(call: 'timeline.addFeed', args: {'feed': r'$フィード'}, destination: true),
  'timeline.excludeWord': RaiAutoBinding(call: 'timeline.excludeWord', args: {'word': r'$ワード'}),
  'timeline.queryFilter': RaiAutoBinding(call: 'timeline.filterWord', args: {'word': r'$ワード', 'mode': 'include'}),
  'trend.seed': RaiAutoBinding(call: 'tendency.seed', args: {'source': r'$フィード'}),
  // コンポーザーを開く手順は post.create(本文つきで開く)に畳む。送信はしない(オートフィルだけ、D-225)。
  'post.create': RaiAutoBinding(call: 'post.compose', args: {'text': r'$本文'}),
};

/// 「任せる」系の文言 (D-229): あれば選択肢を聞かずに候補の先頭で進める。
final _entrustedRe = RegExp(r'任せ|おまかせ|お任せ|自動で|勝手に|よしなに|よろしく|進めて');
bool raiEntrusted(String question) => _entrustedRe.hasMatch(question);

/// 質問文から入力を抜く (D-229): 「…」 / 『…』 / "…" の引用、ラベルごとの言い回し。見つからなければ null。
String? raiExtractInput(String label, String question) {
  final q = question.trim();
  final quoted = [for (final m in RegExp(r'[「『"“]([^」』"”]{1,40})[」』"”]').allMatches(q)) m.group(1)!.trim()];
  switch (label) {
    case 'フィード':
      final m = RegExp(r'([\p{L}\p{N}ー・]{1,20}?)(?:の|について|という|に関する|系)?(?:カスタム)?フィード', unicode: true).firstMatch(q);
      if (m != null && m.group(1)!.isNotEmpty && !RegExp(r'^(カスタム|保存|した|この|その|人気|の)$').hasMatch(m.group(1)!)) return m.group(1);
      return quoted.firstOrNull;
    case 'ワード':
      final m = RegExp(r'([\p{L}\p{N}ー・]{1,20})(?:を|は|の)(?:除外|ミュート|消|落と|見たくない|隠|ブロック)', unicode: true).firstMatch(q);
      return quoted.firstOrNull ?? m?.group(1);
    case '本文':
      final m = RegExp(r'[「『"“]([^」』"”]{1,300})[」』"”]\s*(?:と|って)?\s*(?:投稿|書|送)').firstMatch(q);
      return m?.group(1)?.trim() ?? quoted.firstOrNull;
    case raiDestinationLabel:
      final tendency = RegExp(r'指向性|刺激性|トレンド').hasMatch(q);
      final home = RegExp(r'タイムライン|TL|ホーム').hasMatch(q);
      if (tendency && home) return raiDestinationBoth;
      if (tendency) return raiDestinationTendency;
      if (home) return raiDestinationHome;
      return null;
  }
  return quoted.firstOrNull;
}

/// 手順の状態(工程の表示、D-229)。
enum RaiAutoStatus { pending, running, done, skipped, failed, asking, guide }

@immutable
class RaiAutoStep {
  const RaiAutoStep({required this.index, required this.text, this.fn, this.binding, this.status = RaiAutoStatus.pending, this.detail = ''});
  final int index;
  final String text;
  final String? fn;
  final RaiAutoBinding? binding;
  final RaiAutoStatus status;
  final String detail;
  bool get bound => binding != null;
  RaiAutoStep with_({RaiAutoStatus? status, String? detail}) => RaiAutoStep(index: index, text: text, fn: fn, binding: binding, status: status ?? this.status, detail: detail ?? this.detail);
}

/// 承認前に組む計画 (D-229): 対応のある手順 / 畳む手順 / 案内に渡す手順。
@immutable
class RaiAutoPlan {
  const RaiAutoPlan({required this.opId, required this.title, required this.steps, required this.question, this.inputs = const {}, this.cursor = 0, this.candidates = const {}});
  final String opId;
  final String title;
  final List<RaiAutoStep> steps;
  final String question;

  /// 埋まった入力(ラベル → 値)。
  final Map<String, String> inputs;

  /// 次に実行する手順。
  final int cursor;

  /// 取得結果の候補(ラベル → 候補)。
  final Map<String, List<RaiFunctionItem>> candidates;

  bool get entrusted => raiEntrusted(question);

  /// 最後の対応手順(これより後の部品つき手順は案内へ)。
  int get lastBound => steps.lastIndexWhere((s) => s.bound);
  bool get hasBound => lastBound >= 0;

  /// 案内に渡す最初の手順(無ければ -1)。
  int get guideFrom {
    if (!hasBound) return 0;
    for (var i = lastBound + 1; i < steps.length; i++) {
      if (steps[i].status == RaiAutoStatus.guide) return i;
    }
    return -1;
  }

  /// 実行に要る入力(順序つき、重複なし)。
  List<String> get inputsNeeded {
    final out = <String>[];
    for (final s in steps) {
      for (final l in s.binding?.inputs ?? const <String>[]) {
        if (!inputs.containsKey(l) && !out.contains(l)) out.add(l);
      }
    }
    return out;
  }

  RaiAutoPlan copyWith({List<RaiAutoStep>? steps, Map<String, String>? inputs, int? cursor, Map<String, List<RaiFunctionItem>>? candidates}) =>
      RaiAutoPlan(opId: opId, title: title, steps: steps ?? this.steps, question: question, inputs: inputs ?? this.inputs, cursor: cursor ?? this.cursor, candidates: candidates ?? this.candidates);

  RaiAutoPlan withStep(int i, RaiAutoStep s) => copyWith(steps: [for (final (k, x) in steps.indexed) k == i ? s : x]);

  /// 操作の手順から組む: `fn` に対応があれば bound、最後の対応手順より前の未対応は skipped、後ろは部品があれば guide。
  static RaiAutoPlan build(RaiOperation op, List<RaiStep> steps, String question, {Map<String, RaiAutoBinding> bindings = raiAutoBindings}) {
    final raw = [for (final (i, s) in steps.indexed) RaiAutoStep(index: i, text: s.text, fn: s.fn, binding: s.fn == null ? null : bindings[s.fn!])];
    final last = raw.lastIndexWhere((s) => s.bound);
    final out = <RaiAutoStep>[];
    for (final s in raw) {
      if (s.bound) {
        out.add(s);
      } else if (s.index < last) {
        out.add(s.with_(status: RaiAutoStatus.skipped, detail: '関数で代替'));
      } else if (steps[s.index].hasTarget || steps[s.index].inputs.isNotEmpty) {
        out.add(s.with_(status: RaiAutoStatus.guide, detail: last < 0 ? '関数の対応が無い' : '押す部品は案内で'));
      } else {
        out.add(s.with_(status: RaiAutoStatus.skipped, detail: '説明だけ'));
      }
    }
    return RaiAutoPlan(opId: op.id, title: op.index, steps: out, question: question);
  }

  /// 承認タイルの説明文。
  String describe() {
    final b = StringBuffer();
    if (!hasBound) {
      b.write('「$title」は関数で代わりにできる手順が無いので、案内(指差し)で進めます。');
      return b.toString();
    }
    b.write('「$title」は案内を出さずに私が関数でやります:');
    for (final s in steps) {
      final mark = switch (s.status) {
        RaiAutoStatus.skipped => '(${s.detail})',
        RaiAutoStatus.guide => '(ここからは案内: ${s.detail})',
        _ => s.binding == null ? '' : ' → ${s.binding!.call}',
      };
      b.write('\n${s.index + 1}. ${s.text}$mark');
    }
    final need = inputsNeeded;
    if (need.isNotEmpty) {
      final found = [for (final l in need) if (raiExtractInput(l, question) != null) '$l=${raiExtractInput(l, question)}'];
      final ask = [for (final l in need) if (raiExtractInput(l, question) == null) l];
      if (found.isNotEmpty) b.write('\n質問から: ${found.join('、')}');
      if (ask.isNotEmpty) b.write(entrusted ? '\n${ask.join('、')} は候補の先頭で進めます(任されているので)' : '\n${ask.join('、')} は実行の途中で選んでもらいます');
    }
    b.write('\nよければ「実行する」を押してください。');
    return b.toString();
  }
}

/// 選択肢タイル (D-229): 入力タイルの上の FOW で聞く内容。
@immutable
class RaiAutoAsk {
  const RaiAutoAsk({required this.label, required this.question, this.options = const [], this.allowFree = true, this.hint});
  final String label;
  final String question;
  final List<RaiFunctionItem> options;
  final bool allowFree;
  final String? hint;
}
