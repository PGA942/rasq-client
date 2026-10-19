import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../relational/relational_engine.dart';

import '../../l10n/l10n.dart';

/// 例で決める (D-314、ユーザー決定 2026-09-24): id の許す / 止める一覧は規模が大きくなると追いつかないので、
/// **「こういうものは許す(好き)/ 止める(好きではない)」を例で選び**、新しいものは例との近さで分ける。
///
/// - 例 = 中身の要約([ContentExample.text]: 投稿の本文、プラグインの名前 + 説明 + スロット、クリップ / リストの名前 +
///   含まれる投稿の本文)。自分のトレンド(`TendencyProfile.examples`)とチャイルドセーフ(`allow.examples`)が同じ形を使う。
/// - 近さは端末の中で決まった計算(ネットワークなし): 文字 2〜3-gram のコサイン([charNgramProfile])/ 特徴語
///   ([extractFeaturesText])の重なり / 同じハッシュタグ(0.6)の、いちばん大きい値。話題のまとめ(`topicsOf`)と同じ道具。
///   特徴語の重なりは重みつきの Ochiai: Σ共通の重み / √((ΣAの重み + 2)(ΣBの重み + 2))。重み = 字数 − 1(2〜6 字に丸める。
///   「今日」のような短い語は軽く、「オンラインカジノ」のような長い語は重い。`composer.media` のような点つきの識別子は 1)。
///   `+ 2` は、特徴語が 1〜2 個しかない短い文どうしが、ありふれた語 1 つで「近い」にならないため。
///   点つきの識別子は文字 n-gram からも外す(同じスロットのプラグインどうしが、それだけで近くならないように)。
///   [exampleNearThreshold] 以上を「近い」とする。
/// - このファイルは画面に依存しない(純関数)。

/// 例の種類(Central `allow.examples` の `kind`)。
enum ExampleKind {
  plugin,
  clip,
  list,
  post,
  text;

  /// 画面に出す名前(表示の言語)。
  String get label => switch (this) {
        ExampleKind.plugin => appL10n.trendExamplesKindPlugin,
        ExampleKind.clip => appL10n.trendExamplesKindClip,
        ExampleKind.list => appL10n.trendExamplesKindList,
        ExampleKind.post => appL10n.trendExamplesKindPost,
        ExampleKind.text => appL10n.trendExamplesKindText,
      };
  static ExampleKind? fromWire(Object? w) => values.where((k) => k.name == w).firstOrNull;
}

/// 「近い」とみなす類似度(0〜1)。話題のまとめの辺の閾値(0.18)より高め: 関係の薄い日本語の文どうしは
/// 文字 n-gram のコサインが 0.05〜0.15 ほど、同じ話題の言い換えは 0.3 を超える(`test/example_match_test.dart`)。
const exampleNearThreshold = 0.3;

/// 例の中身の長さの上限(文字。Central と同じ)。
const maxExampleChars = 300;

/// 例の数の上限(許す例 / 止める例、それぞれ。Central と同じ)。
const maxExamplesPerSide = 50;

/// 例のもと(`ref`)の長さの上限(文字。Central と同じ)。
const maxExampleRefChars = 200;

/// 中身の要約: 空白の並びを 1 つにまとめて前後を取り、[maxExampleChars] 文字(コードポイント)で切る。
String exampleTextOf(Iterable<String> parts) {
  final squashed = parts.join(' ').split(RegExp(r'[\s\u0000-\u001f]+')).where((w) => w.isNotEmpty).join(' ');
  final runes = squashed.runes.toList();
  return runes.length <= maxExampleChars ? squashed : String.fromCharCodes(runes.take(maxExampleChars)).trimRight();
}

/// プラグインの中身(名前 + 説明 + スロット)。例の要約と、子の端末の判定(`ChildGate.pluginAllowed`)が同じ文を使う。
List<String> pluginExamplePieces({required String name, String description = '', List<String> slots = const []}) => [
      name,
      if (description.trim().isNotEmpty) description,
      if (slots.isNotEmpty) slots.join(' '),
    ];

/// 例 1 件。
@immutable
class ContentExample {
  const ContentExample({required this.kind, this.ref, required this.text});
  final ExampleKind kind;

  /// もとの id(プラグインの id、クリップ / リストの id、投稿のキー)。表示と重なりの判定だけ(近さには使わない)。
  final String? ref;

  /// 近さを測る中身。
  final String text;

  /// 重なりの判定の鍵(同じもとなら同じ例)。
  String get key => '${kind.name}:${ref ?? text}';

  /// チップに出す短い形。
  String get shortLabel {
    final runes = text.runes.toList();
    return runes.length <= 18 ? text : '${String.fromCharCodes(runes.take(18))}…';
  }

  Map<String, Object?> toJson() => {'kind': kind.name, if (ref != null && ref!.isNotEmpty) 'ref': ref, 'text': text};

  /// 読めないもの(知らない種類 / 空の中身)は null。
  static ContentExample? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = ExampleKind.fromWire(raw['kind']);
    final text = raw['text'];
    if (kind == null || text is! String || text.trim().isEmpty) return null;
    final ref = raw['ref'];
    return ContentExample(kind: kind, ref: ref is String && ref.trim().isNotEmpty ? ref.trim() : null, text: exampleTextOf([text]));
  }

  @override
  bool operator ==(Object other) => other is ContentExample && other.kind == kind && other.ref == ref && other.text == text;
  @override
  int get hashCode => Object.hash(kind, ref, text);
}

/// 許す例(好き)/ 止める例(好きではない)。
@immutable
class ContentExamples {
  const ContentExamples({this.allow = const [], this.deny = const []});
  final List<ContentExample> allow;
  final List<ContentExample> deny;

  static const none = ContentExamples();

  bool get isEmpty => allow.isEmpty && deny.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// [e] を片側に入れる(同じ鍵の例は両側から外してから。上限を超えたら古いものから落とす)。
  ContentExamples withExample(ContentExample e, {required bool allow}) {
    final a = [for (final x in this.allow) if (x.key != e.key) x];
    final d = [for (final x in deny) if (x.key != e.key) x];
    (allow ? a : d).add(e);
    List<ContentExample> cap(List<ContentExample> l) => l.length <= maxExamplesPerSide ? l : l.sublist(l.length - maxExamplesPerSide);
    return ContentExamples(allow: cap(a), deny: cap(d));
  }

  ContentExamples without(ContentExample e) => ContentExamples(allow: [for (final x in allow) if (x != e) x], deny: [for (final x in deny) if (x != e) x]);

  Map<String, Object?> toJson() => {'allow': [for (final e in allow) e.toJson()], 'deny': [for (final e in deny) e.toJson()]};

  /// 読めない例は飛ばす。両側にある同じ例は、止める側だけに残す(安全側)。
  factory ContentExamples.fromJson(Object? raw) {
    if (raw is! Map) return none;
    List<ContentExample> side(Object? v) {
      final out = <ContentExample>[];
      for (final r in v is List ? v : const []) {
        final e = ContentExample.tryParse(r);
        if (e != null && !out.contains(e)) out.add(e);
      }
      return out;
    }

    final deny = side(raw['deny']);
    return ContentExamples(allow: [for (final e in side(raw['allow'])) if (!deny.contains(e)) e], deny: deny);
  }

  @override
  bool operator ==(Object other) => other is ContentExamples && listEquals(other.allow, allow) && listEquals(other.deny, deny);
  @override
  int get hashCode => Object.hash(Object.hashAll(allow), Object.hashAll(deny));
}

/// 許す例 / 止める例への近さ(それぞれのいちばん近い例の類似度)。
@immutable
class ExampleScores {
  const ExampleScores(this.allow, this.deny);
  static const zero = ExampleScores(0, 0);
  final double allow;
  final double deny;
  bool get nearAllow => allow >= exampleNearThreshold;
  bool get nearDeny => deny >= exampleNearThreshold;

  /// 止める例のほうに寄っている(止める例に近く、許す例よりも近い)。自分のトレンドの「好きではない」に使う。
  bool get leansDeny => nearDeny && deny > allow;
}

// ── 類似度 ─────────────────────────────────────────────────────────────

@immutable
class _TextProfile {
  const _TextProfile(this.ngram, this.features, this.featureWeight, this.tags);
  final Map<String, double> ngram;

  /// 特徴語 → 重み。
  final Map<String, double> features;
  final double featureWeight;
  final Set<String> tags;
}

final _identifier = RegExp(r'^[a-z0-9_-]+(\.[a-z0-9_-]+)+$');

/// 文の中の点つきの識別子(スロットの名前など)。文字 n-gram からは外す(英字の n-gram が多く、同じスロットの
/// プラグインどうしが中身と関係なく近くなるため)。特徴語としては重み 1 で残る。
final _identifierInText = RegExp(r'[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+');

/// 特徴語の重み(字数 − 1、2〜6 字に丸める。点つきの識別子は 1)。
double _featureWeight(String f) => _identifier.hasMatch(f) ? 1 : (f.runes.length.clamp(2, 6) - 1).toDouble();

/// 例の中身は何度も比べるので、作ったプロファイルを覚えておく(上限を超えたら捨て直す)。
final _profiles = <String, _TextProfile>{};

_TextProfile _profileOf(String text) {
  final hit = _profiles[text];
  if (hit != null) return hit;
  if (_profiles.length > 1024) _profiles.clear();
  final tags = {for (final m in RegExp(r'[#＃]([^\s#＃]+)').allMatches(text)) m.group(1)!.toLowerCase()}; // l10n-ignore: ハッシュタグの照合(全角の＃)
  final features = {for (final f in extractFeaturesText(text)) f: _featureWeight(f)};
  return _profiles[text] = _TextProfile(charNgramProfile(text.replaceAll(_identifierInText, ' ')), features, features.values.fold(0.0, (a, b) => a + b), tags);
}

double _similarity(_TextProfile a, _TextProfile b) {
  var s = cosineOfProfiles(a.ngram, b.ngram);
  if (a.features.isNotEmpty && b.features.isNotEmpty) {
    var shared = 0.0;
    for (final e in a.features.entries) {
      if (b.features.containsKey(e.key)) shared += e.value;
    }
    s = math.max(s, shared / math.sqrt((a.featureWeight + 2) * (b.featureWeight + 2)));
  }
  if (a.tags.any(b.tags.contains)) s = math.max(s, 0.6);
  return s.clamp(0.0, 1.0);
}

/// 2 つの文の類似度(0〜1)。
double exampleSimilarity(String a, String b) => a.trim().isEmpty || b.trim().isEmpty ? 0 : _similarity(_profileOf(a), _profileOf(b));

/// もの(1 つ以上の文 [pieces]。例: 名前 / 説明 / 本文)の、例ごとのいちばん近い値。文が 2 つ以上なら、つないだ全体も比べる。
ExampleScores exampleScoresOf(List<String> pieces, ContentExamples examples) {
  if (examples.isEmpty) return ExampleScores.zero;
  final texts = [for (final p in pieces) if (p.trim().isNotEmpty) p, if (pieces.where((p) => p.trim().isNotEmpty).length > 1) pieces.join(' ')];
  if (texts.isEmpty) return ExampleScores.zero;
  final profiles = [for (final t in texts) _profileOf(t)];
  double best(List<ContentExample> side) {
    var b = 0.0;
    for (final e in side) {
      final pe = _profileOf(e.text);
      for (final p in profiles) {
        b = math.max(b, _similarity(p, pe));
        if (b >= 1) return 1;
      }
    }
    return b;
  }

  return ExampleScores(best(examples.allow), best(examples.deny));
}

/// 束(クリップ / リスト)の近さ: 名前 + 説明([meta])と、投稿ごと。投稿ごとの値は、**近い投稿が 3 割以上**に
/// なる値(上から数えて 3 割目の投稿の値)を使う(1 件だけ外れた投稿があるだけでは、束ごと寄せない。中身をつないだ
/// 全体とも比べない: 強い投稿 1 件が全体を引っぱるため)。
ExampleScores collectionScoresOf({required String meta, required List<String> posts, required ContentExamples examples}) {
  if (examples.isEmpty) return ExampleScores.zero;
  final head = exampleScoresOf([meta], examples);
  final bodies = [for (final p in posts) if (p.trim().isNotEmpty) p];
  if (bodies.isEmpty) return head;
  final each = [for (final b in bodies) exampleScoresOf([b], examples)];
  final k = (bodies.length * 0.3).ceil().clamp(1, bodies.length);
  double kth(Iterable<double> v) => (v.toList()..sort((a, b) => b.compareTo(a)))[k - 1];
  return ExampleScores(math.max(head.allow, kth(each.map((s) => s.allow))), math.max(head.deny, kth(each.map((s) => s.deny))));
}
