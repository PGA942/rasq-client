import 'package:riverpod/riverpod.dart';

/// 既読/未読 — drives 省略表示 (collapsed post) in TL and notifications.
/// Keyed by post key (`accountKey:postId`).
class ReadStateStore extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool isRead(String postKey) => state.contains(postKey);

  void markRead(String postKey) {
    if (state.contains(postKey)) return;
    state = {...state, postKey};
  }

  void markAllRead(Iterable<String> postKeys) {
    final next = {...state, ...postKeys};
    if (next.length == state.length) return;
    state = next;
  }

  void markUnread(String postKey) {
    if (!state.contains(postKey)) return;
    state = {...state}..remove(postKey);
  }

  void clear() => state = const {};
}

final readStateProvider = NotifierProvider<ReadStateStore, Set<String>>(ReadStateStore.new);

final isReadProvider = Provider.family<bool, String>((ref, postKey) => ref.watch(readStateProvider.select((s) => s.contains(postKey))));
