import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:sns_misskey/sns_misskey.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';

@immutable
class TimelineState {
  const TimelineState({this.posts = const [], this.cursor, this.loadingMore = false, this.error});
  final List<Post> posts;
  final String? cursor;
  final bool loadingMore;
  final Object? error;
  bool get hasMore => cursor != null;

  TimelineState copyWith({List<Post>? posts, String? cursor, bool clearCursor = false, bool? loadingMore, Object? error, bool clearError = false}) => TimelineState(
        posts: posts ?? this.posts,
        cursor: clearCursor ? null : (cursor ?? this.cursor),
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// One timeline of the current account. Pages flow: plugin → posts + action
/// states → Store (状態はDSLの外) → rows receive props.
class TimelineNotifier extends AsyncNotifier<TimelineState> {
  TimelineNotifier(this.kind);
  final TimelineKind kind;

  SnsSession? get _session => ref.read(currentSnsSessionProvider);

  @override
  Future<TimelineState> build() async {
    ref.watch(currentAccountProvider); // rebuild per account
    final session = _session;
    if (session == null) return const TimelineState();
    final (page, states) = await _fetch(session, null);
    return TimelineState(posts: page.items, cursor: page.nextCursor);
  }

  Future<(Page<Post>, Map<String, Map<String, ActionResult>>)> _fetch(SnsSession session, String? cursor) async {
    Page<Post> page;
    Map<String, Map<String, ActionResult>> states;
    if (session is MisskeySession) {
      (page, states) = await session.timelineWithStates(kind, cursor: cursor);
    } else {
      page = await session.timeline(kind, cursor: cursor);
      states = await session.actionStates(page.items);
    }
    _applyStates(page.items, states);
    ref.read(emojiCacheProvider.notifier).request({for (final p in page.items) ...InlineSpans.emojiShortcodes(p.body), for (final p in page.items) ...InlineSpans.emojiShortcodes(p.author.displayName)});
    return (page, states);
  }

  void _applyStates(List<Post> posts, Map<String, Map<String, ActionResult>> states) {
    final store = ref.read(actionStateProvider.notifier);
    final batch = <ActionKey, ActionState>{};
    for (final p in posts) {
      final s = states[p.id];
      if (s == null) continue;
      for (final e in s.entries) {
        batch[(postKey: p.key, actionId: e.key)] = ActionState(done: e.value.done, count: e.value.count);
      }
    }
    store.applyAll(batch);
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) return;
    try {
      final (page, _) = await _fetch(session, null);
      state = AsyncData(TimelineState(posts: page.items, cursor: page.nextCursor));
    } catch (e, st) {
      if (state.value == null || state.value!.posts.isEmpty) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(state.value!.copyWith(error: e));
      }
    }
  }

  Future<void> loadMore() async {
    final cur = state.value;
    final session = _session;
    if (cur == null || session == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, clearError: true));
    try {
      final (page, _) = await _fetch(session, cur.cursor);
      final seen = {for (final p in cur.posts) p.id};
      final merged = [...cur.posts, ...page.items.where((p) => !seen.contains(p.id))];
      state = AsyncData(cur.copyWith(posts: merged, cursor: page.nextCursor, clearCursor: page.nextCursor == null, loadingMore: false));
    } catch (e) {
      state = AsyncData(cur.copyWith(loadingMore: false, error: e));
    }
  }

  /// Performs [actionId] with optimistic update, reconciles with the plugin result.
  Future<void> perform(Post post, ActionDescriptor action, {Map<String, Object?> args = const {}}) async {
    final session = _session;
    if (session == null) return;
    final store = ref.read(actionStateProvider.notifier);
    final before = store.of(post.key, action.id);
    final undo = before.done;
    store.applyOptimistic(post.key, action.id, done: !undo);
    try {
      final r = await session.performAction(action.id, post.id, args: {...args, 'undo': undo});
      store.apply(post.key, action.id, ActionState(done: r.done, count: r.count ?? before.count));
    } catch (e) {
      store.apply(post.key, action.id, before);
      debugPrint('action ${action.id} failed: $e');
      rethrow;
    }
  }
}

final timelineProvider = AsyncNotifierProvider.family<TimelineNotifier, TimelineState, TimelineKind>(TimelineNotifier.new);
