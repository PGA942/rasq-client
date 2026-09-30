import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';

import 'relational_engine.dart';

/// SigLIP + EMA + Louvain の前段パイプライン (D-024 → D-027 で役割変更)。
///
/// 1. 投稿本文を SigLIP(多言語)で埋め込み(GPU はゲートウェイの配置解決先)
/// 2. **フォロイー毎に特徴量の指数移動平均**を更新([FolloweeEmbeddingStore])
/// 3. 著者類似グラフ → **Louvain** でコミュニティ分割
/// 4. コミュニティは [ConversationEngine] の**事前分布(リンク採点の加点)**と
///    適応しきい値の層別に使う。v0 のようなハードフィルタにはしない
///    (Louvain のコミュニティは「普段の関心圏」であって進行中の会話ではない)
class RelationalMlResult {
  const RelationalMlResult({required this.communityOf, required this.postSimilarity});

  /// authorKey → Louvain コミュニティ id。
  final Map<String, int> communityOf;

  /// 投稿間類似度(SigLIP cos を 0..1 に写像)。埋め込みが無いペアはルールベースへ。
  final PostSimilarity postSimilarity;
}

class RelationalMlPipeline {
  /// [gateway] = サーバーの SigLIP(本文だけ)。[embedPosts] = 端末の埋め込み(本文 + 画像、D-390)。どちらか。
  RelationalMlPipeline({this.gateway, this.embedPosts, FolloweeEmbeddingStore? store, this.communityEdgeMinSimilarity = 0.6})
      : assert(gateway != null || embedPosts != null),
        store = store ?? FolloweeEmbeddingStore();

  final MlGateway? gateway;
  final Future<List<List<double>>> Function(List<Post> posts)? embedPosts;

  /// EMA はセッションを通して持ち回る(直近の話題に追従する状態)。
  final FolloweeEmbeddingStore store;
  final double communityEdgeMinSimilarity;

  /// [followeePosts] を埋め込み → EMA 更新 → Louvain。[extraPosts]
  /// (LTL 候補など)は埋め込みだけ取り、EMA には入れない。
  Future<RelationalMlResult> analyze(List<Post> followeePosts, {List<Post> extraPosts = const []}) async {
    final all = [...followeePosts, ...extraPosts];
    final g = gateway;
    final List<List<double>> embeddings = g != null ? await g.embedTexts([for (final p in all) p.body]) : await embedPosts!(all);

    final byPostKey = <String, List<double>>{};
    for (var i = 0; i < all.length; i++) {
      byPostKey[all[i].key] = embeddings[i];
    }
    // 古い順に畳み込む(EMA が時系列を追うように)。
    final chronological = [...followeePosts]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final p in chronological) {
      final e = byPostKey[p.key];
      if (e != null) store.update(p.author.key, e);
    }

    final communityOf = louvain(store.graph(minSimilarity: communityEdgeMinSimilarity));

    double postSimilarity(Post a, Post b) {
      final ea = byPostKey[a.key];
      final eb = byPostKey[b.key];
      if (ea == null || eb == null || ea.length != eb.length) {
        return ruleBasedSimilarity(a, b);
      }
      var dot = 0.0;
      for (var i = 0; i < ea.length; i++) {
        dot += ea[i] * eb[i];
      }
      return (dot.clamp(-1.0, 1.0) + 1) / 2;
    }

    return RelationalMlResult(communityOf: communityOf, postSimilarity: postSimilarity);
  }
}
