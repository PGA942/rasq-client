import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'user_list.dart';

final userProfileProvider = FutureProvider.autoDispose.family<UserProfile, String>((ref, id) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) throw StateError('not logged in');
  final p = await s.user(id);
  await ref.read(userListHelperProvider).primeRelationships([id]);
  return p;
});

final userPostsProvider = FutureProvider.autoDispose.family<Page<Post>, ({String id, UserPostsFilter filter})>((ref, k) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  return s.userPosts(k.id, filter: k.filter, limit: 30);
});

final followsProvider = FutureProvider.autoDispose.family<Page<UserSummary>, ({String id, bool followers})>((ref, k) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  final page = k.followers ? await s.followers(k.id, limit: 50) : await s.following(k.id, limit: 50);
  await ref.read(userListHelperProvider).primeRelationships(page.items.map((u) => u.id));
  return page;
});

final followRequestsProvider = FutureProvider.autoDispose<List<FollowRequest>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.followRequests();
});

final mutedUsersProvider = FutureProvider.autoDispose<Page<UserSummary>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  return s.mutedUsers(limit: 50);
});

final blockedUsersProvider = FutureProvider.autoDispose<Page<UserSummary>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  return s.blockedUsers(limit: 50);
});
