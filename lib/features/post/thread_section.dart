import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../relational/relational_engine.dart';

/// 返信欄の並び順 (D-070、短押しドロップダウン)。
/// 関連順/キーワード順は SigLIP / GLiNER 配線までは関連TLと同じ
/// ルールベース近似(擬似 cos / 特徴語一致)で並べる。
enum ThreadSortOrder {
  relevance('関連順'),
  reactions('リアクション数'),
  keyword('キーワード順'),
  none('デフォルト');

  const ThreadSortOrder(this.label);
  final String label;
}

/// 返信欄に表示する種類 (D-070、長押しで切り替え)。
enum ThreadSectionMode {
  renotes('引用(リノート)', '引用'),
  replies('返信', '返信'),
  reactions('リアクション', 'リアクション'), // Misskey のみ表示
  quotes('共有(引用ノート)', '共有');

  const ThreadSectionMode(this.label, this.shortLabel);

  /// 長押しメニューの表記。
  final String label;

  /// 欄ヘッダーの表記。
  final String shortLabel;
}

List<T> _sortByScore<T>(List<T> items, double Function(T) score) {
  final copy = [...items];
  copy.sort((a, b) => score(b).compareTo(score(a)));
  return copy;
}

/// 投稿リスト(返信 / 引用ノート)への並び順の適用。
List<Post> sortThreadPosts(List<Post> items, ThreadSortOrder order, Post root) => switch (order) {
      ThreadSortOrder.none => items,
      ThreadSortOrder.reactions => _sortByScore(items, (p) => p.reactionTotal.toDouble()),
      ThreadSortOrder.relevance => _sortByScore(items, (p) => ruleBasedSimilarity(root, p)),
      ThreadSortOrder.keyword => _sortByScore(items, (p) => entityOverlap(extractFeatures(root), extractFeatures(p)).toDouble()),
    };

String _profileText(UserSummary u) => '${u.displayName} ${u.bio ?? ''}';

/// ユーザーリスト(リノートした人)への並び順の適用 (D-070:
/// 関連/キーワードは**プロフィールから**ソート。リアクション数は無効)。
List<UserSummary> sortThreadUsers(List<UserSummary> users, ThreadSortOrder order, Post root) => switch (order) {
      ThreadSortOrder.relevance => _sortByScore(users, (u) => cosineOfProfiles(charNgramProfile(root.body), charNgramProfile(_profileText(u)))),
      ThreadSortOrder.keyword => _sortByScore(users, (u) => entityOverlap(extractFeatures(root), extractFeaturesText(_profileText(u))).toDouble()),
      _ => users,
    };

/// 引用ノート一覧 (D-070「共有(引用ノート)」欄)。
final threadQuotesProvider = FutureProvider.autoDispose.family<List<Post>, ({String id, String? account})>((ref, k) async {
  final s = ref.watch(sessionForAccountProvider(k.account)); // 属するアカウントで (D-155)
  if (s == null) return const [];
  // チャイルドセーフ (D-407、指摘 #26): 引用ノートにも、ホームと同じ保護者の表示制限を掛ける(共有の口で掛ける)。
  final gate = ref.watch(childGateProvider);
  return gate.filterPosts((await s.quotes(k.id, limit: 30)).items);
});

/// 返信欄の設定の置き場(`threadReplies.v1`。全スレッドで共有。SNS / RASQ 共通)。
const threadRepliesKvArea = 'threadReplies';
