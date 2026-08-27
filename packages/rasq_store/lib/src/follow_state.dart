import 'package:riverpod/riverpod.dart';

/// Relationship between the viewing account and a user.
class FollowState {
  const FollowState({this.following = false, this.followedBy = false, this.requested = false, this.muted = false, this.blocked = false, this.blockedBy = false});
  final bool following;
  final bool followedBy;
  final bool requested;
  final bool muted;
  final bool blocked;
  final bool blockedBy;

  FollowState copyWith({bool? following, bool? followedBy, bool? requested, bool? muted, bool? blocked, bool? blockedBy}) => FollowState(
        following: following ?? this.following,
        followedBy: followedBy ?? this.followedBy,
        requested: requested ?? this.requested,
        muted: muted ?? this.muted,
        blocked: blocked ?? this.blocked,
        blockedBy: blockedBy ?? this.blockedBy,
      );

  @override
  bool operator ==(Object other) =>
      other is FollowState &&
      other.following == following &&
      other.followedBy == followedBy &&
      other.requested == requested &&
      other.muted == muted &&
      other.blocked == blocked &&
      other.blockedBy == blockedBy;
  @override
  int get hashCode => Object.hash(following, followedBy, requested, muted, blocked, blockedBy);
}

/// Key: `${viewerAccountKey}->${userKey}`.
String followKey(String viewerAccountKey, String userKey) => '$viewerAccountKey->$userKey';

class FollowStateStore extends Notifier<Map<String, FollowState>> {
  @override
  Map<String, FollowState> build() => const {};

  FollowState of(String viewerAccountKey, String userKey) => state[followKey(viewerAccountKey, userKey)] ?? const FollowState();

  void apply(String viewerAccountKey, String userKey, FollowState value) {
    state = {...state, followKey(viewerAccountKey, userKey): value};
  }

  void applyAll(Map<String, FollowState> byKey) {
    if (byKey.isEmpty) return;
    state = {...state, ...byKey};
  }
}

final followStateProvider = NotifierProvider<FollowStateStore, Map<String, FollowState>>(FollowStateStore.new);

final followStateOfProvider = Provider.family<FollowState, ({String viewer, String user})>((ref, k) {
  return ref.watch(followStateProvider.select((m) => m[followKey(k.viewer, k.user)])) ?? const FollowState();
});
