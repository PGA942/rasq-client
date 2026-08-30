import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../settings/settings_dsl.dart';
import '../users/user_list.dart';
import 'reactions_screen.dart';
import 'thread_section.dart';

/// スレッド展開画面: ancestors → 対象投稿 → 「∨ 返信 / リアクションを表示 >」→
/// replies (thread line) → さらに表示 → 返信バー(コンポーザーは次段階).
final threadProvider = FutureProvider.autoDispose.family<Thread, String>((ref, id) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) throw StateError('not logged in');
  final t = await s.thread(id);
  // Seed action states for every post in the thread so buttons show real counts.
  final all = [...t.ancestors, t.post, ...t.descendants];
  final states = await s.actionStates(all);
  final store = ref.read(actionStateProvider.notifier);
  store.applyAll({
    for (final p in all)
      for (final e in (states[p.id] ?? const <String, ActionResult>{}).entries) (postKey: p.key, actionId: e.key): ActionState(done: e.value.done, count: e.value.count),
  });
  return t;
});

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId, this.initial});
  final String postId;

  /// Post passed from the list for instant first paint.
  final Post? initial;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  /// 返信欄の並び順/表示種類 (D-070)。**キャッシュに残す** — KV
  /// `threadReplies.v1`(設定 DSL と同じ規約)に保存し、全スレッドで共有。
  static const _kvArea = 'threadReplies';
  String get postId => widget.postId;
  Post? get initial => widget.initial;

  /// 常駐返信 stick (D-050): 元の返信タイルの代わりに、ページを開いたら
  /// 縮小状態の stick コンポーザーを置く(ページ遷移で自動消滅 D-048)。
  /// このページへ**戻ってきた**ときも、コンポーザーが無ければ置き直す。
  bool _composerScheduled = false;
  bool _composerDismissed = false; // ✕ で閉じた(このページ滞在中は再表示しない)
  void _ensureReplyComposer(Post target) {
    if (_composerDismissed || _composerScheduled || ref.read(overlayManagerProvider).contains(composerFowId)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return; // 最前面のときだけ
    _composerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await showComposer(ref, ComposeReply(target), resident: true, column: fowColumnOf(context), onPosted: (_) => ref.invalidate(threadProvider(postId)));
        // ページが最前面のまま閉じた = ユーザーの ✕(遷移で消えた場合は除外)。
        // 遷移直後はナビゲーターが未反映のことがあるので 1 フレーム待つ。
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) _composerDismissed = true;
      } finally {
        _composerScheduled = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // 既読: 詳細を開いた投稿は既読扱い → TL では省略表示になる.
    final key = initial?.key;
    if (key != null) WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(readStateProvider.notifier).markRead(key));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final thread = ref.watch(threadProvider(postId));
    final manager = ref.watch(overlayManagerProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];

    Future<void> perform(Post p, ActionDescriptor a, {Map<String, Object?> args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args);

    final replyTarget = thread.value?.post ?? initial;
    if (replyTarget != null) _ensureReplyComposer(replyTarget);

    // 保存済みの並び順/表示種類 (D-070)。リアクション欄は Misskey のみ —
    // 他 SNS では返信に縮退する。
    final saved = ref.watch(settingsAreaProvider(_kvArea)).value ?? const <String, Object?>{};
    final order = ThreadSortOrder.values.asNameMap()[saved['order']] ?? ThreadSortOrder.none;
    final misskey = ref.watch(currentAccountProvider)?.kind == SnsKind.misskey;
    var mode = ThreadSectionMode.values.asNameMap()[saved['mode']] ?? ThreadSectionMode.replies;
    if (mode == ThreadSectionMode.reactions && !misskey) mode = ThreadSectionMode.replies;

    _ThreadBody body(Post post, List<Post> ancestors, List<Post> descendants, {bool loading = false}) => _ThreadBody(
          post: post,
          ancestors: ancestors,
          descendants: descendants,
          actions: actions,
          onAction: perform,
          loading: loading,
          order: order,
          mode: mode,
          onSortTap: (r) => _sort(manager, r, mode: mode, current: order),
          onModeTap: (r) => _switchMode(manager, r, current: mode, misskey: misskey),
          onShowReactions: () => context.pushReactions(post),
        );

    return Scaffold(
      appBar: RasqPageHeader(title: '投稿', leadingAvatar: me, actions: [RasqIconButton(icon: Icons.bookmark_border, onPressed: () {}, tooltip: 'ブックマーク')], onMore: () {}),
      body: thread.when(
        loading: () => initial == null ? const RasqLoading() : body(initial!, const [], const [], loading: true),
        error: (e, _) {
          final code = e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e');
          if (code.code == '404') {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('投稿はありません', style: RasqTypography.title)));
          }
          return RasqErrorView(code: code, onRetry: () => ref.invalidate(threadProvider(postId)), retryLabel: '再読み込み');
        },
        data: (t) => body(t.post, t.ancestors, t.descendants),
      ),
    );
  }

  /// 短押し: 並び順 (D-070)。関連順(SigLIP)/リアクション数/キーワード順
  /// (GLiNER)/デフォルト。リノート欄ではリアクション数を無効化(ユーザー
  /// リストに数が無い — 関連/キーワードはプロフィールからソート)。
  Future<void> _sort(OverlayManager manager, Rect rect, {required ThreadSectionMode mode, required ThreadSortOrder current}) async {
    final o = await manager.showDropdown<ThreadSortOrder>(id: 'sort.thread', anchor: rect, dense: true, items: [
      for (final s in ThreadSortOrder.values)
        RasqDropdownItem(s.label, s, checked: s == current, enabled: !(mode == ThreadSectionMode.renotes && s == ThreadSortOrder.reactions)),
    ]);
    if (o != null) await ref.read(settingsAreaProvider(_kvArea).notifier).set('order', o.name);
  }

  /// 長押し: 欄の切り替え (D-070)。引用(リノート)/返信/リアクション
  /// (Misskey のみ表示)/共有(引用ノート)。
  Future<void> _switchMode(OverlayManager manager, Rect rect, {required ThreadSectionMode current, required bool misskey}) async {
    final m = await manager.showDropdown<ThreadSectionMode>(id: 'thread.mode', anchor: rect, dense: true, items: [
      for (final x in ThreadSectionMode.values)
        if (x != ThreadSectionMode.reactions || misskey) RasqDropdownItem(x.label, x, checked: x == current),
    ]);
    if (m != null) await ref.read(settingsAreaProvider(_kvArea).notifier).set('mode', m.name);
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.post, required this.ancestors, required this.descendants, required this.actions, required this.onAction, this.loading = false, this.order = ThreadSortOrder.none, this.mode = ThreadSectionMode.replies, this.onSortTap, this.onModeTap, this.onShowReactions});
  final Post post;
  final List<Post> ancestors;
  final List<Post> descendants;
  final List<ActionDescriptor> actions;
  final Future<void> Function(Post, ActionDescriptor, {Map<String, Object?> args}) onAction;
  final bool loading;
  final ThreadSortOrder order;
  final ThreadSectionMode mode;
  final ValueChanged<Rect>? onSortTap;
  final ValueChanged<Rect>? onModeTap;
  final VoidCallback? onShowReactions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final replies = sortThreadPosts(descendants, order, post);
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      // 1 つ前の投稿(ancestors)は省略タイル (D-069: ワイヤーフレーム p.5
      // 「1件の添付リンク」の形)でスレッド線を繋ぐ。タップでそのスレッドへ。
      for (final a in ancestors) ReplyParentRow(post: a),
      PostRow(post: post, actions: actions, onAction: (d, {args = const {}}) => onAction(post, d, args: args), showReplyParent: ancestors.isEmpty),
      Container(
        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: scheme.onSurface, width: 1))),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        height: RasqSizes.minTap,
        child: Row(children: [
          Builder(
            // ∨: 短押し = 並び順、**長押し = 欄の切り替え** (D-070)。
            builder: (ctx) {
              Rect anchor() {
                final box = ctx.findRenderObject() as RenderBox;
                return box.localToGlobal(Offset.zero) & box.size;
              }

              return InkWell(
                onTap: onSortTap == null ? null : () => onSortTap!(anchor()),
                onLongPress: onModeTap == null ? null : () => onModeTap!(anchor()),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                  const SizedBox(width: 4),
                  Text(mode.shortLabel, style: RasqTypography.tab),
                  if (order != ThreadSortOrder.none) Padding(padding: const EdgeInsets.only(left: 6), child: Text(order.label, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
                ]),
              );
            },
          ),
          const Spacer(),
          TextButton(onPressed: onShowReactions, child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('リアクションを表示'), Icon(Icons.chevron_right, size: 18)])),
        ]),
      ),
      if (loading) const RasqLoading(),
      if (mode == ThreadSectionMode.replies) ...[
        for (final d in replies) ...[
          // 直接の返信は親(表示中の投稿)が見えているので省略タイルは出さない
          // (孫返信など別の親のものだけ出す、D-069)。
          _Threaded(child: PostRow(post: d, actions: actions, onAction: (x, {args = const {}}) => onAction(d, x, args: args), onTap: () => context.pushPost(d), showReplyParent: (d.replyToId ?? d.replyTo?.id) != post.id)),
          const Divider(),
        ],
        if (replies.isNotEmpty) Center(child: TextButton(onPressed: () {}, child: const Text('さらに表示'))),
      ] else
        _ModeSection(mode: mode, post: post, order: order, actions: actions),
    ]);
  }
}

/// 返信以外の欄 (D-070): 引用(リノートした人)/ リアクション / 共有(引用
/// ノート)。外側の ListView に埋め込むため shrinkWrap 系で描く。
class _ModeSection extends ConsumerStatefulWidget {
  const _ModeSection({required this.mode, required this.post, required this.order, required this.actions});
  final ThreadSectionMode mode;
  final Post post;
  final ThreadSortOrder order;
  final List<ActionDescriptor> actions;

  @override
  ConsumerState<_ModeSection> createState() => _ModeSectionState();
}

class _ModeSectionState extends ConsumerState<_ModeSection> {
  final Set<String> _open = {}; // リアクション欄の展開状態

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    switch (widget.mode) {
      case ThreadSectionMode.renotes:
        final page = ref.watch(repostersProvider(post.id));
        return page.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
          data: (p) => p.items.isEmpty
              ? const RasqEmptyView(title: 'リノートはありません')
              : UserList(users: sortThreadUsers(p.items, widget.order, post), shrinkWrap: true),
        );
      case ThreadSectionMode.reactions:
        return ReactionSections(
          post: post,
          order: widget.order == ThreadSortOrder.reactions ? RasqSortOrder.reactionsDesc : RasqSortOrder.defaultOrder,
          open: _open,
          onToggle: (t) => setState(() => _open.contains(t) ? _open.remove(t) : _open.add(t)),
          shrinkWrap: true,
        );
      case ThreadSectionMode.quotes:
        final page = ref.watch(threadQuotesProvider(post.id));
        return page.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
          data: (list) {
            if (list.isEmpty) return const RasqEmptyView(title: '引用ノートはありません');
            final sorted = sortThreadPosts(list, widget.order, post);
            return Column(children: [
              for (final q in sorted) ...[
                PostRow(post: q, actions: widget.actions, onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(q, a, args: args), onTap: () => context.pushPost(q)),
                const Divider(),
              ],
            ]);
          },
        );
      case ThreadSectionMode.replies:
        return const SizedBox.shrink(); // 呼び出し側が処理
    }
  }
}

/// Draws the vertical thread line at the avatar column.
class _Threaded extends StatelessWidget {
  const _Threaded({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned(left: RasqSpacing.page + RasqSizes.avatarLg / 2 - 1, top: 0, bottom: 0, child: Container(width: 2, color: Theme.of(context).colorScheme.outlineVariant)),
        child,
      ]);
}

