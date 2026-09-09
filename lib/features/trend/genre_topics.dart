import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';

import '../nodeprog/node_executor.dart';
import '../relational/relational_engine.dart';
import 'tendency_fows.dart';

/// アクションからジャンルを選択 (D-157): リアクション済みの投稿を**類似話題で
/// まとめ**、話題性の強い順に上位数件だけ出す。
///
/// ワイヤーの想定は UMAP + Louvain。端末側は投稿同士の類似度(SigLIP 埋め込みが
/// あれば cos、無ければ文字 n-gram cos + 特徴語の Jaccard)で近傍グラフを作り、
/// 同じ Louvain(`rasq_ml`)でコミュニティ分割する(UMAP の次元圧縮は埋め込みが
/// 入ってからの前段。n-gram はそのままグラフにできる)。
@immutable
class GenreTopic {
  const GenreTopic({required this.id, required this.posts, required this.representative, required this.genres, required this.hotness});
  final int id;

  /// この話題の投稿(話題性の高い順)。
  final List<Post> posts;

  /// 代表(リアクションが最も多い投稿)。
  final Post representative;

  /// 話題のジャンル候補(頻出の特徴語、最大 6)。
  final List<String> genres;

  /// 話題性: 件数 × log(1 + リアクション合計)。
  final double hotness;
}

/// 投稿の類似度 0〜1。
double _similarity(Post a, Post b, Map<String, double> pa, Map<String, double> pb, Set<String> fa, Set<String> fb, Map<String, List<double>>? emb) {
  if (emb != null && emb[a.key] != null && emb[b.key] != null) {
    final x = emb[a.key]!, y = emb[b.key]!;
    var dot = 0.0, nx = 0.0, ny = 0.0;
    for (var i = 0; i < math.min(x.length, y.length); i++) {
      dot += x[i] * y[i];
      nx += x[i] * x[i];
      ny += y[i] * y[i];
    }
    return nx == 0 || ny == 0 ? 0 : (dot / (math.sqrt(nx) * math.sqrt(ny))).clamp(0.0, 1.0);
  }
  final ng = cosineOfProfiles(pa, pb);
  final union = fa.union(fb).length;
  final jac = union == 0 ? 0.0 : fa.intersection(fb).length / union;
  return math.max(ng, jac);
}

/// [posts] を話題ごとにまとめて話題性の順に返す(最大 [top] 件)。
/// [embeddings] は post.key → ベクトル(SigLIP、あれば優先)。
List<GenreTopic> topicsOf(List<Post> posts, {int top = 3, double minSimilarity = 0.18, Map<String, List<double>>? embeddings}) {
  if (posts.isEmpty) return const [];
  final profiles = {for (final p in posts) p.key: charNgramProfile('${p.body} ${p.quote?.body ?? ''}')};
  final features = {for (final p in posts) p.key: extractFeatures(p)};
  final graph = <String, Map<String, double>>{for (final p in posts) p.key: {}};
  for (var i = 0; i < posts.length; i++) {
    for (var j = i + 1; j < posts.length; j++) {
      final a = posts[i], b = posts[j];
      final s = _similarity(a, b, profiles[a.key]!, profiles[b.key]!, features[a.key]!, features[b.key]!, embeddings);
      if (s >= minSimilarity) {
        graph[a.key]![b.key] = s;
        graph[b.key]![a.key] = s;
      }
    }
  }
  final community = louvain(graph);
  final byCommunity = <int, List<Post>>{};
  for (final p in posts) {
    byCommunity.putIfAbsent(community[p.key] ?? -1, () => []).add(p);
  }
  final topics = <GenreTopic>[];
  var id = 0;
  for (final members in byCommunity.values) {
    members.sort((a, b) => b.reactionTotal.compareTo(a.reactionTotal));
    final reactions = members.fold(0, (a, p) => a + p.reactionTotal);
    final hotness = members.length * (1 + math.log(1 + reactions));
    // ジャンル候補: 話題全体の頻出特徴語(+ 代表のハッシュタグを先頭に)。
    final genres = <String>[];
    for (final g in genreCandidatesOf(members.first, max: 3)) {
      if (!genres.contains(g)) genres.add(g);
    }
    for (final f in topFeaturesOf(members, max: 12)) {
      if (f.length >= 2 && !RegExp(r'^\d+$').hasMatch(f) && !f.startsWith('http') && !genres.contains(f)) genres.add(f);
      if (genres.length >= 6) break;
    }
    topics.add(GenreTopic(id: id++, posts: members, representative: members.first, genres: genres, hotness: hotness));
  }
  topics.sort((a, b) => b.hotness.compareTo(a.hotness));
  return topics.take(top).toList();
}
