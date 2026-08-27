import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/providers.dart';

/// Helper that primes/sets follow state through the Store (状態はDSLの外).
class UserListHelper {
  UserListHelper(this.ref);
  final Ref ref;

  Future<void> primeRelationships(Iterable<String> ids) async {
    final s = ref.read(currentSnsSessionProvider);
    final viewer = ref.read(currentAccountProvider);
    if (s == null || viewer == null) return;
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return;
    try {
      final rel = await s.relationships(unique);
      ref.read(followStateProvider.notifier).applyAll({for (final e in rel.entries) followKey(viewer.key, _userKey(viewer, e.key)): e.value});
    } catch (_) {}
  }

  Future<void> toggleFollow(UserSummary u) async {
    final s = ref.read(currentSnsSessionProvider);
    final viewer = ref.read(currentAccountProvider);
    if (s == null || viewer == null) return;
    final store = ref.read(followStateProvider.notifier);
    final cur = store.of(viewer.key, u.key);
    store.apply(viewer.key, u.key, cur.copyWith(following: !cur.following));
    try {
      final next = await s.setFollowing(u.id, !cur.following);
      store.apply(viewer.key, u.key, next);
    } catch (_) {
      store.apply(viewer.key, u.key, cur);
    }
  }

  /// Store keys use `kind:instance:id`; relationships come back by bare id.
  static String _userKey(AccountId viewer, String id) => '${viewer.kind.name}:${viewer.instance}:$id';
}

final userListHelperProvider = Provider<UserListHelper>((ref) => UserListHelper(ref));

/// ユーザー欄 / リアクション欄の中身: RasqUserRow のリスト + フォロー状態.
class UserList extends ConsumerWidget {
  const UserList({super.key, required this.users, this.subtitles = const {}, this.shrinkWrap = false, this.leadingFor});
  final List<UserSummary> users;
  final Map<String, String> subtitles;
  final bool shrinkWrap;
  final Widget? Function(UserSummary u)? leadingFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(currentAccountProvider);
    final me = ref.watch(currentUserProvider);
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: users.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final u = users[i];
        final keyUser = viewer == null ? u.key : UserListHelper._userKey(viewer, u.id);
        final st = viewer == null ? const FollowState() : ref.watch(followStateOfProvider((viewer: viewer.key, user: keyUser)));
        final isMe = u.id == me.id || (u.handle == me.handle && u.account.instance == me.account.instance);
        return RasqUserRow(
          user: u,
          following: isMe ? null : st.following,
          followedBy: st.followedBy,
          subtitle: subtitles[u.id],
          leading: leadingFor?.call(u),
          onFollowTap: isMe ? null : () => ref.read(userListHelperProvider).toggleFollow(u),
          onMore: () {},
        );
      },
    );
  }
}
