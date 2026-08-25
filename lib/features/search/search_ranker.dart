import 'dart:math' as math;

import 'package:rasq_models/rasq_models.dart';

/// 「関連順」ランカー v0 (D-022)。
///
/// 3 段構成のうち、**ルールベース段が実働**。残り 2 段は `ml.infer` の
/// 接続点だけ切ってある(モデルは重いので最終版で構成が変わる前提):
///
/// 1. **ルールベース**(実装済み・同期): ハッシュタグ一致 / 本文一致 /
///    表示名・ハンドル一致 / ジャンル一致 / リアクション対数 / 新しさ減衰
/// 2. **GLiNER**(ゼロショット NER, onnx): クエリとユーザー表示名・一般固有名詞の
///    抽出一致でスコア加点 — manifest: `examples/gliner-ner.model.json`
/// 3. **SigLIP**(画像×テキスト類似, onnx): 候補が十分多いときだけ、クエリと
///    添付画像の類似で並びを補正 — manifest: `examples/siglip-similarity.model.json`
///
/// GLiNER/SigLIP は `MlScore` を注入したときだけ効く(ml.infer のバックエンドが
/// 配線されるまで null = ルールベースのみ)。リレーショナル TL も同じ 3 段を
/// 使う想定(D-022 の仕様メモ参照)。
class SearchRanker {
  const SearchRanker({this.mlScore});

  /// `ml.infer` 由来の追加スコア(postKey → score)。GLiNER/SigLIP の結果を
  /// 事前計算して渡す(同期ランキングを保つため、非同期推論は呼び出し側で)。
  final Map<String, double>? mlScore;

  /// モデルマニフェスト id(rasq-sdk-sample/examples)。
  static const glinerModelId = 'rasq.official.search/gliner-ner';
  static const siglipModelId = 'rasq.official.search/siglip-similarity';

  /// SigLIP を使い始める候補数のしきい値(仕様: 「ある程度多ければ」)。
  static const siglipCandidateThreshold = 24;

  List<Post> rank(List<Post> posts, {required String query, Set<String> genres = const {}, DateTime? now}) {
    final clock = now ?? DateTime.now();
    final scored = [for (final p in posts) (p, score(p, query: query, genres: genres, now: clock))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1];
  }

  double score(Post p, {required String query, Set<String> genres = const {}, DateTime? now}) {
    final clock = now ?? DateTime.now();
    final q = query.trim().toLowerCase();
    final body = p.body.toLowerCase();
    var s = 0.0;
    if (q.isNotEmpty) {
      if (body.contains('#$q')) s += 3;
      if (body.contains(q)) s += 2;
      final author = p.author;
      if (author.displayName.toLowerCase().contains(q) || author.handle.toLowerCase().contains(q)) s += 1.5;
    }
    for (final g in genres) {
      if (matchesGenre(p, g)) s += 2;
    }
    s += 0.5 * math.log(1 + p.reactionTotal) / math.ln10;
    // 新しさ: 24h で -0.5、以降なだらかに。
    final ageHours = clock.difference(p.createdAt).inMinutes / 60.0;
    s -= 0.5 * math.log(1 + math.max(0, ageHours) / 24) / math.ln2;
    s += mlScore?[p.key] ?? 0;
    return s;
  }

  /// ルールベースのジャンル一致(GLiNER 配線後は固有名詞抽出も加わる)。
  bool matchesGenre(Post p, String genre) {
    final g = genre.toLowerCase();
    final body = p.body.toLowerCase();
    return body.contains('#$g') || body.contains(g);
  }

  bool matchesAnyGenre(Post p, Set<String> genres) => genres.any((g) => matchesGenre(p, g));
}
