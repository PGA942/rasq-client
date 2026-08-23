import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../users/user_list.dart';

@immutable
class TrendAnalysis {
  const TrendAnalysis({required this.posts, required this.followingPosts, required this.users});
  final List<Post> posts;

  /// Posts by users the viewer follows (フォロー中の反応 / フォロー中タブ).
  final List<Post> followingPosts;

  /// Users ranked by total reactions on their tag posts (ユーザー欄).
  final List<(UserProfile, int)> users;
}

/// Fetches up to ~60 tag posts, checks which authors are followed
/// (`users/relation`), and ranks authors by reactions (`users/show` for tiles).
final trendAnalysisProvider = FutureProvider.autoDispose.family<TrendAnalysis, String>((ref, tag) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const TrendAnalysis(posts: [], followingPosts: [], users: []);
  final posts = <Post>[];
  String? cursor;
  for (var i = 0; i < 3; i++) {
    final page = await s.timeline(DynamicTimelines.tag(tag), cursor: cursor, limit: 20);
    posts.addAll(page.items);
    cursor = page.nextCursor;
    if (cursor == null || page.items.isEmpty) break;
  }
  final score = <String, int>{};
  for (final p in posts) {
    score.update(p.author.id, (v) => v + p.reactionTotal, ifAbsent: () => p.reactionTotal);
  }
  final ids = score.keys.toList();
  final rel = ids.isEmpty ? const <String, dynamic>{} : await s.relationships(ids);
  await ref.read(userListHelperProvider).primeRelationships(ids);
  final following = {for (final e in rel.entries) if (e.value.following == true) e.key};
  final rankedIds = ids..sort((a, b) => score[b]!.compareTo(score[a]!));
  final profiles = rankedIds.isEmpty ? const <UserProfile>[] : await s.users(rankedIds.take(30).toList());
  final byId = {for (final p in profiles) p.summary.id: p};
  return TrendAnalysis(
    posts: posts,
    followingPosts: [for (final p in posts) if (following.contains(p.author.id)) p]..sort((a, b) => b.reactionTotal.compareTo(a.reactionTotal)),
    users: [for (final id in rankedIds) if (byId[id] != null) (byId[id]!, score[id]!)],
  );
});
