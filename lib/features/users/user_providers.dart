import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import 'user_list.dart';

/// キーの `account` は表示するユーザーが属するアカウント (D-155: ↓ で選んだ
/// アカウントのセッションで以降の画面を展開する)。null = 現在。
typedef UserKey = ({String id, String? account});

final userProfileProvider = FutureProvider.autoDispose.family<UserProfile, UserKey>((ref, k) async {
  final s = ref.watch(sessionForAccountProvider(k.account));
  if (s == null) throw StateError('not logged in');
  final p = await s.user(k.id);
  await ref.read(userListHelperProvider).primeRelationships([k.id]);
  return p;
});

final userPostsProvider = FutureProvider.autoDispose.family<Page<Post>, ({String id, UserPostsFilter filter, String? account})>((ref, k) async {
  final s = ref.watch(sessionForAccountProvider(k.account));
  if (s == null) return Page.empty();
  // チャイルドセーフ (D-407、指摘 #26): プロフィールの投稿一覧にも、ホームと同じ保護者の表示制限を掛ける。
  final gate = ref.watch(childGateProvider);
  final page = await s.userPosts(k.id, filter: k.filter, limit: 30);
  return gate.supervised ? Page(items: gate.filterPosts(page.items), nextCursor: page.nextCursor) : page;
});

final followsProvider = FutureProvider.autoDispose.family<Page<UserSummary>, ({String id, bool followers, String? account})>((ref, k) async {
  final s = ref.watch(sessionForAccountProvider(k.account));
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
