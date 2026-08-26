import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

/// リレーショナルTL 設定 (D-022)。
///
/// [threshold] は **50〜100 に正規化した類似度しきい値**(高次元ベクトルの
/// cos 類似度は 0 に張り付かないため下限 50)。SigLIP 配線後は
/// `(cos + 1) / 2 * 100` を同じ尺度に写像する。初期値は実測で調整する前提
/// なのでユーザーがスライダーで変更できる。
@immutable
class RelationalSettings {
  const RelationalSettings({this.threshold = 75, this.staleMinutes = 10, this.maxOffTopicPosts = 4});

  /// 類似度しきい値(50〜100)。
  final int threshold;

  /// 浮上が無いままこの分数が経つとクラスタを外す。
  final int staleMinutes;

  /// メンバーがしきい値から離れた投稿をこの回数連続でしたら外す。
  final int maxOffTopicPosts;

  double get normalizedThreshold => threshold.clamp(50, 100) / 100.0;

  RelationalSettings copyWith({int? threshold, int? staleMinutes, int? maxOffTopicPosts}) => RelationalSettings(
        threshold: threshold ?? this.threshold,
        staleMinutes: staleMinutes ?? this.staleMinutes,
        maxOffTopicPosts: maxOffTopicPosts ?? this.maxOffTopicPosts,
      );
}

/// 2 投稿の類似度(0〜1、cos 相当)。SigLIP 配線後は
/// `(text_embeds コサイン + 1) / 2` を注入する(D-022)。
typedef PostSimilarity = double Function(Post a, Post b);

/// 1 クラスタ = 「関連」タブの 1 カード。
class RelationalCluster {
  RelationalCluster({required this.id, required this.seed, required this.posts, required this.tags, required this.lastActivityAt});

  final String id;

  /// クラスタを開始したフォロイー投稿(カードの代表)。
  final Post seed;
  final List<Post> posts;

  /// 束ねに使った特徴語(ハッシュタグ・固有名詞近似)。
  final Set<String> tags;

  /// 最後の「浮上」時刻: メンバーの投稿/リノート、または自分の関連投稿への
  /// アクション(markAction)。
  DateTime lastActivityAt;

  List<UserSummary> get members {
    final seen = <String>{};
    return [for (final p in posts) if (seen.add(p.author.key)) p.author];
  }
}

/// リレーショナルTL エンジン v0 (D-022)。
///
/// 3 段のうち **ルールベース段が実働**: 特徴抽出はハッシュタグ + メンション +
/// 固有名詞近似(カタカナ・英数・CJK の連続語 = GLiNER のゼロショット抽出が
/// 配線されるまでの代用)。類似度既定は特徴集合の Jaccard を 0.5〜1.0 に写像
/// した擬似 cos([RelationalEngine.ruleBasedSimilarity])。GLiNER / SigLIP は
/// [similarity] と特徴語の注入で差し替える。
class RelationalEngine {
  const RelationalEngine({this.settings = const RelationalSettings(), PostSimilarity? similarity}) : _similarity = similarity ?? ruleBasedSimilarity;

  final RelationalSettings settings;
  final PostSimilarity _similarity;

  double similarity(Post a, Post b) => _similarity(a, b);

  /// 特徴語: #タグ / @メンション / 固有名詞近似(2文字以上のカタカナ・英数語、
  /// 4文字以上の CJK 連続)。GLiNER 配線後はゼロショット抽出結果に置き換わる。
  static Set<String> features(Post p) {
    final out = <String>{};
    final text = '${p.body} ${p.quote?.body ?? ''}';
    for (final m in RegExp(r'#([^\s#＃]+)').allMatches(text)) {
      out.add(m.group(1)!.toLowerCase());
    }
    for (final m in RegExp(r'@([A-Za-z0-9_.-]+)').allMatches(text)) {
      out.add(m.group(1)!.toLowerCase());
    }
    for (final m in RegExp(r'([ァ-ヴー]{2,}|[A-Za-z0-9][A-Za-z0-9\-_.]{1,})').allMatches(text)) {
      out.add(m.group(1)!.toLowerCase());
    }
    for (final m in RegExp(r'([一-龠々]{4,})').allMatches(text)) {
      out.add(m.group(1)!);
    }
    return out;
  }

  /// 擬似 cos: Jaccard(0..1) → 0.5..1.0(高次元 cos が 0 に張り付かない性質に
  /// 合わせた床)。しきい値スライダー 50-100 と同じ尺度になる。
  static double ruleBasedSimilarity(Post a, Post b) {
    final fa = features(a);
    final fb = features(b);
    if (fa.isEmpty || fb.isEmpty) return 0.5;
    final inter = fa.intersection(fb).length;
    final union = fa.union(fb).length;
    return 0.5 + 0.5 * (inter / union);
  }

  /// フォロイーの投稿からクラスタを作り、候補(LTL・トレンド)の類似投稿を
  /// 取り込む。しきい値未満は束ねない。
  ///
  /// [communityOf] は D-024 の計算量削減: SigLIP EMA の著者類似グラフを
  /// Louvain で分割した所属(authorKey → community id)。渡すと、**異なる
  /// コミュニティの著者同士は類似度計算すら行わず束ねない**(候補=非フォロイー
  /// など所属が無い著者は制限なし)。
  List<RelationalCluster> build({
    required List<Post> followeePosts,
    List<Post> candidatePosts = const [],
    Map<String, int>? communityOf,
    DateTime? now,
  }) {
    final t = settings.normalizedThreshold;
    final clusters = <RelationalCluster>[];

    bool sameCommunity(RelationalCluster c, Post p) {
      if (communityOf == null) return true;
      final a = communityOf[c.seed.author.key];
      final b = communityOf[p.author.key];
      return a == null || b == null || a == b;
    }

    for (final p in followeePosts) {
      RelationalCluster? best;
      var bestScore = 0.0;
      for (final c in clusters) {
        if (!sameCommunity(c, p)) continue;
        final s = _clusterSimilarity(c, p);
        if (s >= t && s > bestScore) {
          best = c;
          bestScore = s;
        }
      }
      if (best != null) {
        best.posts.add(p);
        best.tags.addAll(features(p));
        if (p.createdAt.isAfter(best.lastActivityAt)) best.lastActivityAt = p.createdAt;
      } else {
        clusters.add(RelationalCluster(id: p.key, seed: p, posts: [p], tags: features(p), lastActivityAt: p.createdAt));
      }
    }

    // 1 投稿だけのクラスタは「関連」ではないので、候補取り込み前に見る。
    for (final candidate in candidatePosts) {
      for (final c in clusters) {
        if (!sameCommunity(c, candidate)) continue;
        final s = _clusterSimilarity(c, candidate);
        if (s >= t && !c.posts.any((p) => p.key == candidate.key)) {
          c.posts.add(candidate);
          if (candidate.createdAt.isAfter(c.lastActivityAt)) c.lastActivityAt = candidate.createdAt;
          break;
        }
      }
    }

    // 関連が成立しているクラスタ(2投稿以上)だけ、活動が新しい順に。
    final out = [for (final c in clusters) if (c.posts.length >= 2) c];
    out.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return pruneStale(out, now: now);
  }

  double _clusterSimilarity(RelationalCluster c, Post p) {
    var maxScore = 0.0;
    for (final member in c.posts) {
      final s = similarity(member, p);
      if (s > maxScore) maxScore = s;
    }
    return maxScore;
  }

  /// 浮上ルール: [RelationalCluster.lastActivityAt] から staleMinutes 超なら外す。
  /// 浮上 = メンバーの投稿/リノート(build で反映)+ 自分の関連投稿への
  /// アクション([markAction] で反映)。
  List<RelationalCluster> pruneStale(List<RelationalCluster> clusters, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final limit = Duration(minutes: settings.staleMinutes);
    return [for (final c in clusters) if (clock.difference(c.lastActivityAt) <= limit) c];
  }

  /// 自分の関連投稿にアクション(リアクション・返信等)が付いた → 浮上。
  void markAction(List<RelationalCluster> clusters, {required String postKey, required DateTime at}) {
    for (final c in clusters) {
      if (c.posts.any((p) => p.key == postKey) && at.isAfter(c.lastActivityAt)) c.lastActivityAt = at;
    }
  }

  /// 除外ルール: 著者の直近投稿のうち、しきい値から離れた投稿が
  /// [RelationalSettings.maxOffTopicPosts] 連続したらそのメンバーの投稿を外す。
  List<RelationalCluster> dropOffTopicMembers(List<RelationalCluster> clusters, {required Map<String, List<Post>> recentByAuthor}) {
    final t = settings.normalizedThreshold;
    final out = <RelationalCluster>[];
    for (final c in clusters) {
      final dropAuthors = <String>{};
      for (final author in c.members) {
        final recent = recentByAuthor[author.key];
        if (recent == null || recent.length < settings.maxOffTopicPosts) continue;
        final latest = recent.take(settings.maxOffTopicPosts);
        final allOff = latest.every((p) => _clusterSimilarity(c, p) < t);
        if (allOff) dropAuthors.add(author.key);
      }
      final kept = [for (final p in c.posts) if (!dropAuthors.contains(p.author.key)) p];
      if (kept.length >= 2 && !dropAuthors.contains(c.seed.author.key)) {
        out.add(RelationalCluster(id: c.id, seed: c.seed, posts: kept, tags: c.tags, lastActivityAt: c.lastActivityAt));
      }
    }
    return out;
  }
}
