/// 送る前の判定の方針 (D-462 / Central S-102、ユーザー決定 2026-10-11): 見守り(チャイルドセーフ)と制限(アカウント処置)で、
/// コンポーザーから送る投稿を**端末で判定して止める**。
///
/// - Central は種類ごとの**閾値と動き**(`block` = 送らない / `warn` = 確かめてから送る)を配る(`GET /me/compose-policy`)。
///   端末は語彙 / 形のルール([measureText])で点数を出し、閾値**以上**なら当たり。
/// - **本文・画像・中身のハッシュはどこにも送らない。** 止めたときに Central へ届くのは、引っかかった種類とモードと面だけ
///   (`POST /me/compose-policy/trips`)。
/// - 判定できない種類(`image` = 端末に画像の判定のモデルが無い / 知らない測り方)は、**見守りの `block` なら止める側**
///   (添付・中身があれば送らない)、**それ以外(制限 / `warn`)は通す側**に倒す。
/// - 見守られている端末で、Central の方針が取れない(オフライン / まだ取っていない)/ 見守りのモードが入っていないときは、
///   署名つきの見守りの方針の「投稿」の強さで、組み込みの既定([childSafeFallbackRules]。Central の既定と同じ値)を当てる。
///   制限は Central の方針(控え)だけ(取れなければ当てない)。
library;

import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import 'compose_signals.dart';

/// 応答の形の名前。
const composePolicySchema = 'rasq.compose-policy/1';

/// 種類の名前(Central の `types` が無いときの表示。Central S-102 の TYPES と同じ。いまの表示の言語)。
Map<String, String> get composeTypeLabels => <String, String>{
  'sexual': appL10n.composePolicyTypeSexual,
  'violence': appL10n.composePolicyTypeViolence,
  'self-harm': appL10n.composePolicyTypeSelfHarm,
  'harassment': appL10n.composePolicyTypeHarassment,
  'personal-info': appL10n.composePolicyTypePersonalInfo,
  'link': appL10n.composePolicyTypeLink,
  'media': appL10n.composePolicyTypeMedia,
  'stimulus': appL10n.composePolicyTypeStimulus,
  'topic': appL10n.composePolicyTypeTopic,
};

/// 見守り / 制限。
const composeModeChildSafe = 'child-safe';
const composeModeSanction = 'sanction';

enum ComposeAction {
  block,
  warn;

  static ComposeAction? fromWire(Object? w) => switch (w) { 'block' => block, 'warn' => warn, _ => null };
}

/// 決まり 1 件。
@immutable
class ComposeRule {
  const ComposeRule({required this.type, required this.mode, required this.action, required this.threshold, required this.signal});
  final String type;
  final String mode;
  final ComposeAction action;
  final double threshold;

  /// `lexicon` / `pattern` / `image` / (知らないもの)。
  final String signal;

  static ComposeRule? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final action = ComposeAction.fromWire(raw['action']);
    final type = raw['type'], mode = raw['mode'], threshold = raw['threshold'], signal = raw['signal'];
    if (action == null || type is! String || mode is! String || threshold is! num || signal is! String) return null;
    return ComposeRule(type: type, mode: mode, action: action, threshold: threshold.toDouble().clamp(0.0, 1.0), signal: signal);
  }

  Map<String, Object?> toJson() => {'type': type, 'mode': mode, 'action': action.name, 'threshold': threshold, 'signal': signal};

  @override
  bool operator ==(Object other) => other is ComposeRule && other.type == type && other.mode == mode && other.action == action && other.threshold == threshold && other.signal == signal;
  @override
  int get hashCode => Object.hash(type, mode, action, threshold, signal);
  @override
  String toString() => '$mode:$type:${action.name}:$threshold';
}

/// Central が配る方針(控えにも同じ形で置く)。
@immutable
class ComposePolicy {
  const ComposePolicy({this.version = '', this.refreshSeconds = 21600, this.modes = const {}, this.rules = const [], this.labels = const {}});

  final String version;
  final int refreshSeconds;

  /// 効いているモード → レベル(`child-safe` → `strict` など)。
  final Map<String, String> modes;
  final List<ComposeRule> rules;

  /// 種類 → 名前(Central の `types`)。
  final Map<String, String> labels;

  static const none = ComposePolicy();

  bool hasMode(String mode) => modes.containsKey(mode);

  String labelOf(String type) => labels[type] ?? composeTypeLabels[type] ?? type;

  factory ComposePolicy.fromJson(Map<String, Object?> j) => ComposePolicy(
        version: '${j['version'] ?? ''}',
        refreshSeconds: ((j['refreshSeconds'] as num?)?.toInt() ?? 21600).clamp(60, 7 * 86400),
        modes: {
          for (final m in j['modes'] as List? ?? const [])
            if (m is Map && m['mode'] is String) m['mode'] as String: '${m['level'] ?? ''}',
        },
        rules: [for (final r in j['rules'] as List? ?? const []) ?ComposeRule.tryParse(r)],
        labels: {
          for (final t in j['types'] as List? ?? const [])
            if (t is Map && t['id'] is String && t['label'] is String) t['id'] as String: t['label'] as String,
        },
      );

  Map<String, Object?> toJson() => {
        'schema': composePolicySchema,
        'version': version,
        'refreshSeconds': refreshSeconds,
        'modes': [for (final e in modes.entries) {'mode': e.key, 'level': e.value}],
        'rules': [for (final r in rules) r.toJson()],
        'types': [for (final e in labels.entries) {'id': e.key, 'label': e.value}],
      };

  ComposePolicy withRules(Map<String, String> moreModes, List<ComposeRule> more) =>
      ComposePolicy(version: version, refreshSeconds: refreshSeconds, modes: {...modes, ...moreModes}, rules: [...rules, ...more], labels: labels);
}

ComposeRule _cs(String type, ComposeAction action, double threshold, String signal) =>
    ComposeRule(type: type, mode: composeModeChildSafe, action: action, threshold: threshold, signal: signal);

/// 見守りの組み込みの既定(保護者の「投稿」の強さごと)。**Central S-102 の `child_safe_defaults` と同じ値**にしておく。
List<ComposeRule> childSafeFallbackRules(String level) {
  const b = ComposeAction.block, w = ComposeAction.warn;
  return switch (level) {
    'mild' => [
        _cs('sexual', b, 0.75, 'lexicon'),
        _cs('violence', w, 0.5, 'lexicon'),
        _cs('self-harm', b, 0.5, 'lexicon'),
        _cs('harassment', w, 0.5, 'lexicon'),
        _cs('personal-info', w, 1, 'pattern'),
      ],
    'standard' => [
        _cs('sexual', b, 0.5, 'lexicon'),
        _cs('violence', b, 0.5, 'lexicon'),
        _cs('self-harm', b, 0.5, 'lexicon'),
        _cs('harassment', b, 0.75, 'lexicon'),
        _cs('personal-info', b, 1, 'pattern'),
        _cs('link', w, 1, 'pattern'),
      ],
    _ => [
        _cs('sexual', b, 0.5, 'lexicon'),
        _cs('violence', b, 0.5, 'lexicon'),
        _cs('self-harm', b, 0.5, 'lexicon'),
        _cs('harassment', b, 0.5, 'lexicon'),
        _cs('personal-info', b, 1, 'pattern'),
        _cs('link', b, 1, 'pattern'),
        _cs('media', b, 0.5, 'image'),
      ],
  };
}

/// 当てる方針: Central の方針(控え)に、見守りの組み込みの既定を足す(見守られていて「投稿」の判定が有効なのに、
/// Central の方針に見守りのモードが無いとき = 取れない / 古い控え)。[childLevel] = 署名つきの見守りの方針の `composer.level`
/// (見守られていない / 判定が無効なら null)。
ComposePolicy effectiveComposePolicy(ComposePolicy? central, {String? childLevel}) {
  final base = central ?? ComposePolicy.none;
  if (childLevel == null || base.hasMode(composeModeChildSafe)) return base;
  return base.withRules({composeModeChildSafe: childLevel}, childSafeFallbackRules(childLevel));
}

/// 判定するもの。[texts] の先頭は入力欄の本文(当たった範囲はこれにだけ付ける)。注釈 / 投票の選択肢 / 送る前の加工のあとの本文も並べる。
@immutable
class ComposeInput {
  const ComposeInput({required this.texts, this.mediaCount = 0, this.imageScores});
  final List<String> texts;
  final int mediaCount;

  /// 端末の画像の判定の点数(種類 → 0〜1)。**null = 端末に画像の判定のモデルが無い**(いまはいつも null)。
  final Map<String, double>? imageScores;

  bool get hasContent => mediaCount > 0 || texts.any((t) => t.trim().isNotEmpty);
}

/// 当たった 1 件。
@immutable
class ComposeTrip {
  const ComposeTrip({required this.rule, required this.label, this.unmeasured = false, this.start, this.end});
  final ComposeRule rule;
  final String label;

  /// 端末で判定できず、止める側に倒した(見守りの `block`)。
  final bool unmeasured;
  final int? start;
  final int? end;

  String get type => rule.type;
  String get mode => rule.mode;
  bool get blocks => rule.action == ComposeAction.block;
  bool get hasRange => start != null && end != null && end! > start!;

  /// 利用者に出す文(種類の名前だけ。点数や語の一覧は出さない)。
  String get message {
    final l = appL10n;
    final who = mode == composeModeChildSafe ? l.composePolicyWhoGuardian : l.composePolicyWhoSanction;
    if (unmeasured && type == 'media') return l.composePolicyBlockedMediaUnmeasured(who);
    if (unmeasured) return l.composePolicyBlockedUnmeasured(who, label);
    return blocks ? l.composePolicyBlocked(who, label) : l.composePolicyWarn(label, who);
  }
}

/// 判定の結果。
@immutable
class ComposeVerdict {
  const ComposeVerdict(this.trips);
  final List<ComposeTrip> trips;
  static const pass = ComposeVerdict([]);

  List<ComposeTrip> get blocks => [for (final t in trips) if (t.blocks) t];
  List<ComposeTrip> get warns => [for (final t in trips) if (!t.blocks) t];

  /// 出す 1 件: 止めるもの(見守りが先)、無ければ確かめるもの。
  ComposeTrip? get first => blocks.firstOrNull ?? warns.firstOrNull;
  bool get blocked => blocks.isNotEmpty;

  /// 止めた種類(モード × 種類で 1 つずつ)。Central へ送るのはこれだけ。
  List<({String type, String mode})> get blockedTypes {
    final seen = <String>{};
    return [
      for (final t in blocks)
        if (seen.add('${t.mode}|${t.type}')) (type: t.type, mode: t.mode),
    ];
  }
}

/// 端末で判定する(純関数)。決まりごとに、[ComposeInput.texts] のうち点数の最も高いものを閾値と比べる。
ComposeVerdict evaluateCompose(ComposePolicy policy, ComposeInput input) {
  final trips = <ComposeTrip>[];
  for (final rule in policy.rules) {
    final label = policy.labelOf(rule.type);
    final failClosed = rule.mode == composeModeChildSafe && rule.action == ComposeAction.block;
    if (rule.signal == 'image') {
      if (input.mediaCount == 0) continue;
      final score = input.imageScores?[rule.type];
      if (score == null) {
        if (failClosed) trips.add(ComposeTrip(rule: rule, label: label, unmeasured: true));
        continue;
      }
      if (score >= rule.threshold) trips.add(ComposeTrip(rule: rule, label: label));
      continue;
    }
    var best = 0.0;
    ComposeHit? hit;
    var measurable = true;
    for (final (i, text) in input.texts.indexed) {
      if (text.trim().isEmpty) continue;
      final m = measureText(rule.signal, rule.type, text);
      if (m == null) {
        measurable = false;
        break;
      }
      if (m.score > best) best = m.score;
      if (i == 0 && hit == null && m.hit != null) hit = m.hit;
    }
    if (!measurable) {
      // 知らない測り方: 見守りの block は、中身があれば止める側。ほかは通す。
      if (failClosed && input.hasContent) trips.add(ComposeTrip(rule: rule, label: label, unmeasured: true));
      continue;
    }
    if (best > 0 && best >= rule.threshold) trips.add(ComposeTrip(rule: rule, label: label, start: hit?.start, end: hit?.end));
  }
  // 止めるものが先、その中で見守りが先(決まりの並びは保つ)。
  int rank(ComposeTrip t) => (t.blocks ? 0 : 2) + (t.mode == composeModeChildSafe ? 0 : 1);
  final ordered = [...trips.indexed]..sort((a, b) => rank(a.$2) != rank(b.$2) ? rank(a.$2).compareTo(rank(b.$2)) : a.$1.compareTo(b.$1));
  return ComposeVerdict([for (final e in ordered) e.$2]);
}
