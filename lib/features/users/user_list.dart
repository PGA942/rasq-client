import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';

/// Helper that primes/sets follow state through the Store (状態はDSLの外).
///
/// [account] (D-421) = 一覧 / ページが属するアカウント(`AccountId.key`、D-155)。関係はそのアカウントのセッションで引き、
/// 鍵もそのアカウントで作る(null = 現在)。前は常に現在のアカウントで引いていたので、総合表示で別のアカウントの
/// フォロー中の一覧を開くと、よそのサーバーの id で関係を引いて全員「未フォロー」になっていた。
class UserListHelper {
  UserListHelper(this.ref);
  final Ref ref;

  Future<void> primeRelationships(Iterable<String> ids, {String? account}) async {
    final s = ref.read(sessionForAccountProvider(account));
    final viewer = ref.read(viewerForAccountProvider(account));
    if (s == null || viewer == null) return;
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return;
    try {
      final rel = await s.relationships(unique);
      ref.read(followStateProvider.notifier).applyAll({for (final e in rel.entries) followKey(viewer.key, followUserKey(viewer, e.key)): e.value});
    } catch (_) {}
  }

  Future<void> toggleFollow(UserSummary u, {String? account}) async {
    final s = ref.read(sessionForAccountProvider(account));
    final viewer = ref.read(viewerForAccountProvider(account));
    if (s == null || viewer == null) return;
    final store = ref.read(followStateProvider.notifier);
    // 一覧が読むのと同じ鍵(`u.key` は相手のサーバーで作るので、リモートの人では食い違っていた)。
    final key = followUserKey(viewer, u.id);
    final cur = store.of(viewer.key, key);
    store.apply(viewer.key, key, cur.copyWith(following: !cur.following));
    try {
      final next = await s.setFollowing(u.id, !cur.following);
      store.apply(viewer.key, key, next);
    } catch (_) {
      store.apply(viewer.key, key, cur);
    }
  }
}

final userListHelperProvider = Provider<UserListHelper>((ref) => UserListHelper(ref));

/// ユーザー欄 / リアクション欄の中身: RasqUserRow のリスト + フォロー状態.
class UserList extends ConsumerWidget {
  const UserList({super.key, required this.users, this.subtitles = const {}, this.shrinkWrap = false, this.leadingFor, this.account});
  final List<UserSummary> users;

  /// 一覧が属するアカウント(`AccountId.key`、D-155 / D-421)。null = 現在。
  final String? account;
  final Map<String, String> subtitles;
  final bool shrinkWrap;
  final Widget? Function(UserSummary u)? leadingFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerForAccountProvider(account));
    final me = ref.watch(currentUserProvider);
    final viewerId = ref.watch(viewerUserIdProvider(account));
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: users.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final u = users[i];
        final keyUser = viewer == null ? u.key : followUserKey(viewer, u.id);
        final st = viewer == null ? const FollowState() : ref.watch(followStateOfProvider((viewer: viewer.key, user: keyUser)));
        final isMe = isViewerSelf(u, viewer, me: me, viewerId: viewerId);
        return RasqUserRow(
          user: u,
          following: isMe ? null : st.following,
          followedBy: st.followedBy,
          subtitle: subtitles[u.id],
          leading: leadingFor?.call(u),
          onFollowTap: isMe ? null : () => ref.read(userListHelperProvider).toggleFollow(u, account: account),
          onTap: () => context.pushUser(u), // 行タップでプロフィールへ (D-177)
          onMore: () {},
        );
      },
    );
  }
}
