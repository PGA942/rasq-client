import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:sns_misskey/sns_misskey.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../settings/settings_dsl.dart';

/// カスタム TL の宣言 (M5e / D-080): 現在のセッションが wasm 境界
/// ([WasmSnsSession])のとき、その TL レンダラー契約(`tl.timelines`)から
/// 読む。ホームのタブに `custom:<id>` として現れる。独立 TL プラグインの
/// 常設インストールはストア統合(M4)側で拡張する。
final customTimelinesProvider = FutureProvider<List<CustomTimelineSpec>>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  if (session is! WasmSnsSession) return const [];
  return session.timelinePlugin.timelines();
});

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
    // タイムライン設定 (D-044) を取得前に反映。watch なので変更 → 再取得。
    try {
      final tl = await ref.watch(snsSettingValuesProvider('timeline').future);
      if (tl.isNotEmpty) await session.applySettings('timeline', tl);
    } catch (e) {
      debugPrint('timeline settings: $e');
    }
    final (page, states) = await _fetch(session, null);
    return TimelineState(posts: page.items, cursor: page.nextCursor);
  }

  Future<(Page<Post>, Map<String, Map<String, ActionResult>>)> _fetch(SnsSession session, String? cursor) async {
    // カスタム TL (M5e / D-080): データ取得はホスト(基礎 TL)、TL プラグインは
    // ソートアルゴリズム(`tl.sort` — 表示順の id 列、未掲載は除外)。
    if (kind.id.startsWith('custom:') && session is WasmSnsSession) {
      final specs = await ref.read(customTimelinesProvider.future);
      final spec = specs.where((x) => 'custom:${x.id}' == kind.id).firstOrNull;
      if (spec != null) {
        final base = await session.timeline(TimelineKind(spec.base, spec.base), cursor: cursor);
        final states = await session.actionStates(base.items);
        final composed = await session.timelinePlugin.compose(spec.id, base.items);
        _applyStates(composed, states);
        ref.read(emojiCacheProvider.notifier).request({for (final p in composed) ...InlineSpans.emojiShortcodes(p.body)});
        return (Page(items: composed, nextCursor: base.nextCursor), states);
      }
    }
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
    final descriptors = {for (final a in _session?.actions ?? const <ActionDescriptor>[]) a.id: a};
    for (final p in posts) {
      final s = states[p.id];
      if (s == null) continue;
      for (final e in s.entries) {
        // Validation gate: per-post icons only for actions that declared iconPerPost.
        final allowIcon = descriptors[e.key]?.iconPerPost ?? false;
        batch[(postKey: p.key, actionId: e.key)] = ActionState(done: e.value.done, count: e.value.count, iconUrl: allowIcon ? e.value.icon?.url : null, iconText: allowIcon ? e.value.icon?.text : null);
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
    final undo = args.containsKey('reaction') ? false : before.done;
    store.applyOptimistic(post.key, action.id, done: !undo);
    try {
      final r = await session.performAction(action.id, post.id, args: {...args, 'undo': undo});
      store.apply(post.key, action.id, ActionState(done: r.done, count: r.count ?? before.count, iconUrl: action.iconPerPost ? (r.icon?.url ?? before.iconUrl) : null, iconText: action.iconPerPost ? (r.icon?.text ?? (r.icon?.url != null ? null : before.iconText)) : null));
    } catch (e) {
      store.apply(post.key, action.id, before);
      debugPrint('action ${action.id} failed: $e');
      rethrow;
    }
  }
}

final timelineProvider = AsyncNotifierProvider.family<TimelineNotifier, TimelineState, TimelineKind>(TimelineNotifier.new);
