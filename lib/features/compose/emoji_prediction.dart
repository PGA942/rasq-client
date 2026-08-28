import 'package:rasq_models/rasq_models.dart';

/// 絵文字予測 (D-040)。絵文字予測.md の初期統合スコアの**縮退版** —
/// SigLIP(意味検索)/ GLiNER(エンティティ共起)の配線前は、実装順 1〜4 の
/// ルールベース 3 系統だけで動かす:
///
/// score = 0.4 × name/alias の語句一致(BM25 の代用)
///       + 0.3 × 自分の利用履歴
///       + 0.2 × 既に付いているリアクション(強くしすぎない — 原文どおり低め)
///       + 0.1 × 最近使った
///
/// SigLIP/GLiNER が MlGateway 経由で使えるようになったら、この関数の前段に
/// 候補 50 件の意味検索と共起表の再順位付けを足す(表示は近傍検索+再順位のみ)。
List<String> predictEmojis({
  required String context,
  Map<String, int> existingReactions = const {},
  Map<String, int> history = const {},
  List<String> recent = const [],
  List<EmojiInfo> custom = const [],
  int max = 8,
}) {
  final text = context.toLowerCase();
  final maxHistory = history.values.fold<int>(1, (a, b) => a > b ? a : b);
  final maxExisting = existingReactions.values.fold<int>(1, (a, b) => a > b ? a : b);

  String normalize(String r) {
    // リアクション形式 `:name@.:` → 挿入形式 `:name:`。
    if (!r.startsWith(':')) return r;
    final name = r.substring(1, r.length - 1).split('@').first;
    return ':$name:';
  }

  double historyOf(String e) {
    for (final entry in history.entries) {
      if (normalize(entry.key) == e || entry.key == e) return entry.value / maxHistory;
    }
    return 0;
  }

  double existingOf(String e) {
    for (final entry in existingReactions.entries) {
      if (normalize(entry.key) == e || entry.key == e) return entry.value / maxExisting;
    }
    return 0;
  }

  final scores = <String, double>{};
  void add(String emoji, double score) {
    if (score <= 0) return;
    scores[emoji] = (scores[emoji] ?? 0) + score;
  }

  // 語句一致: カスタム絵文字の name / alias が文脈に現れる(2 文字以上)。
  for (final e in custom) {
    var match = 0.0;
    for (final key in [e.name, ...e.aliases]) {
      final k = key.toLowerCase();
      if (k.length >= 2 && text.contains(k)) {
        match = k.length >= 4 ? 1.0 : 0.7; // 長い一致ほど強い
        break;
      }
    }
    if (match > 0) add(':${e.name}:', 0.4 * match);
  }
  // 履歴・既存リアクション・最近。
  for (final r in history.keys) {
    add(normalize(r), 0.3 * historyOf(normalize(r)));
  }
  for (final r in existingReactions.keys) {
    add(normalize(r), 0.2 * existingOf(normalize(r)));
  }
  for (var i = 0; i < recent.length; i++) {
    add(normalize(recent[i]), 0.1 * (1.0 - i / (recent.length + 1)));
  }

  final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(max)) e.key];
}
