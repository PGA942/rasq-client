import 'package:riverpod/riverpod.dart';

/// State of one action button on one post, as returned by the SNS plugin.
class ActionState {
  const ActionState({this.done = false, this.count, this.enabled = true});
  final bool done;

  /// `null` when the plugin does not return counts for this action.
  final int? count;
  final bool enabled;

  ActionState copyWith({bool? done, int? count, bool? enabled}) =>
      ActionState(done: done ?? this.done, count: count ?? this.count, enabled: enabled ?? this.enabled);

  @override
  bool operator ==(Object other) => other is ActionState && other.done == done && other.count == count && other.enabled == enabled;
  @override
  int get hashCode => Object.hash(done, count, enabled);
}

/// Key: `${postKey}#${actionId}` where postKey = `accountKey:postId`.
typedef ActionKey = ({String postKey, String actionId});

String actionKeyString(ActionKey k) => '${k.postKey}#${k.actionId}';

/// Holds アクション済み / アクション数 per (post, action).
/// Values come from SNS plugin return values; UI never mutates them directly
/// except through [applyOptimistic] which the host reconciles later.
class ActionStateStore extends Notifier<Map<String, ActionState>> {
  @override
  Map<String, ActionState> build() => const {};

  ActionState of(String postKey, String actionId) => state[actionKeyString((postKey: postKey, actionId: actionId))] ?? const ActionState();

  /// Bulk apply results returned by a plugin (e.g. after fetching a timeline).
  void applyAll(Map<ActionKey, ActionState> results) {
    if (results.isEmpty) return;
    state = {...state, for (final e in results.entries) actionKeyString(e.key): e.value};
  }

  void apply(String postKey, String actionId, ActionState value) {
    state = {...state, actionKeyString((postKey: postKey, actionId: actionId)): value};
  }

  /// Optimistic toggle used while the plugin call is in flight.
  void applyOptimistic(String postKey, String actionId, {required bool done}) {
    final cur = of(postKey, actionId);
    final delta = done == cur.done ? 0 : (done ? 1 : -1);
    apply(postKey, actionId, cur.copyWith(done: done, count: cur.count == null ? null : (cur.count! + delta).clamp(0, 1 << 31)));
  }

  /// Sum of counts across accounts for expand display (「expand時は複数アカウント分を合算」).
  int sumCounts(Iterable<String> postKeys, String actionId) =>
      postKeys.fold(0, (acc, k) => acc + (of(k, actionId).count ?? 0));

  void clearForAccount(String accountKey) {
    state = {for (final e in state.entries) if (!e.key.startsWith('$accountKey:')) e.key: e.value};
  }
}

final actionStateProvider = NotifierProvider<ActionStateStore, Map<String, ActionState>>(ActionStateStore.new);

/// Family selector for a single button — rebuilds only that button.
final actionStateOfProvider = Provider.family<ActionState, ActionKey>((ref, key) {
  return ref.watch(actionStateProvider.select((m) => m[actionKeyString(key)])) ?? const ActionState();
});
