import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/sort_menu.dart';
import '../../shell/headers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../users/user_list.dart';
import 'post_detail_screen.dart';

/// リアクションを表示: 対象投稿 + tabs 返信 / ∨引用 / リアクション / 共有.
/// リアクション欄: 絵文字画像 + リアクション数 + 名前(折りたたみ、中身はユーザー欄).
final reactionUsersProvider = FutureProvider.autoDispose.family<Page<ReactionEntry>, ({String postId, String type})>((ref, k) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  final page = await s.reactions(k.postId, type: k.type, limit: 50);
  await ref.read(userListHelperProvider).primeRelationships(page.items.map((e) => e.user.id));
  return page;
});

final repostersProvider = FutureProvider.autoDispose.family<Page<UserSummary>, String>((ref, postId) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return Page.empty();
  final page = await s.reposters(postId, limit: 50);
  await ref.read(userListHelperProvider).primeRelationships(page.items.map((e) => e.id));
  return page;
});

class ReactionsScreen extends ConsumerStatefulWidget {
  const ReactionsScreen({super.key, required this.postId, this.initial});
  final String postId;
  final Post? initial;
  @override
  ConsumerState<ReactionsScreen> createState() => _ReactionsScreenState();
}

class _ReactionsScreenState extends ConsumerState<ReactionsScreen> {
  RasqSortOrder _order = RasqSortOrder.defaultOrder;
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final thread = ref.watch(threadProvider(widget.postId));
    final post = thread.value?.post ?? widget.initial;
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final manager = ref.watch(overlayManagerProvider);
    final tabs = [const RasqTabItem('返信'), const RasqTabItem('引用'), const RasqTabItem('リアクション'), const RasqTabItem('共有')];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: 2,
      child: Scaffold(
        appBar: RasqPageHeader(title: 'リアクション', leadingAvatar: me, actions: [RasqIconButton(icon: Icons.bookmark_border, onPressed: () {}, tooltip: 'ブックマーク')], onMore: () {}),
        body: Column(children: [
          if (post != null)
            Container(
              margin: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, 0),
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
              clipBehavior: Clip.antiAlias,
              child: PostRow(post: post, actions: const [], onAction: (_, {args = const {}}) async {}, onTap: () => context.pushPost(post)),
            ),
          RasqTabs(
            items: tabs,
            onSelectedTabTap: (i, rect) async {
              final o = await showSortMenu(manager, rect, _order, id: 'reactions');
              if (o != null) setState(() => _order = o);
            },
          ),
          Expanded(
            child: TabBarView(children: [
              _Replies(postId: widget.postId, actions: actions, order: _order),
              _Reposters(postId: widget.postId),
              post == null ? const RasqLoading() : _ReactionSections(post: post, order: _order, open: _open, onToggle: (t) => setState(() => _open.contains(t) ? _open.remove(t) : _open.add(t))),
              const RasqEmptyView(title: '共有', hint: '共有の記録は M2'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Replies extends ConsumerWidget {
  const _Replies({required this.postId, required this.actions, required this.order});
  final String postId;
  final List<ActionDescriptor> actions;
  final RasqSortOrder order;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(threadProvider(postId));
    return thread.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
      data: (t) {
        final list = sortByReactions(t.descendants, order, (p) => p.reactionTotal);
        if (list.isEmpty) return const RasqEmptyView(title: '返信はありません');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) => PostRow(post: list[i], actions: actions, onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(list[i], a, args: args), onTap: () => context.pushPost(list[i])),
        );
      },
    );
  }
}

class _Reposters extends ConsumerWidget {
  const _Reposters({required this.postId});
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(repostersProvider(postId));
    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e')),
      data: (p) => p.items.isEmpty ? const RasqEmptyView(title: 'リノート・引用はありません') : UserList(users: p.items),
    );
  }
}

class _ReactionSections extends ConsumerWidget {
  const _ReactionSections({required this.post, required this.order, required this.open, required this.onToggle});
  final Post post;
  final RasqSortOrder order;
  final Set<String> open;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final emojis = ref.watch(emojiCacheProvider);
    final entries = sortByReactions(post.reactions.entries.toList(), order, (e) => e.value);
    if (entries.isEmpty) return const RasqEmptyView(title: 'リアクションはありません');
    // prefetch custom emoji urls for :name: reactions not carried by the note
    ref.read(emojiCacheProvider.notifier).request([for (final e in entries) if (e.key.startsWith(':') && !post.reactionEmojis.containsKey(e.key)) e.key.substring(1, e.key.length - 1).replaceAll('@.', '')]);
    return ListView(children: [
      for (final e in entries) ...[
        InkWell(
          onTap: () => onToggle(e.key),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
            child: Row(children: [
              _ReactionGlyph(reaction: e.key, url: post.reactionEmojis[e.key] ?? (e.key.startsWith(':') ? emojis[e.key.substring(1, e.key.length - 1).replaceAll('@.', '')] : null), size: 26),
              const SizedBox(width: RasqSpacing.md),
              Text('${e.value}', style: RasqTypography.title),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(child: Text(e.key.startsWith(':') ? e.key : '', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              if (post.myReaction == e.key) const RasqPill(label: 'あなた'),
              Icon(open.contains(e.key) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            ]),
          ),
        ),
        if (open.contains(e.key)) _ReactionUsers(postId: post.id, type: e.key),
      ],
    ]);
  }
}

class _ReactionUsers extends ConsumerWidget {
  const _ReactionUsers({required this.postId, required this.type});
  final String postId;
  final String type;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(reactionUsersProvider((postId: postId, type: type)));
    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text('$e', style: RasqTypography.caption)),
      data: (p) => UserList(users: [for (final r in p.items) r.user], subtitles: {for (final r in p.items) r.user.id: RasqTimestamp.format(r.createdAt)}, shrinkWrap: true),
    );
  }
}

/// Emoji image (custom) or unicode text.
class _ReactionGlyph extends StatelessWidget {
  const _ReactionGlyph({required this.reaction, this.url, this.size = 22});
  final String reaction;
  final Uri? url;
  final double size;
  @override
  Widget build(BuildContext context) => url != null
      ? Image.network(url.toString(), height: size, errorBuilder: (_, _, _) => Text(reaction, style: TextStyle(fontSize: size * 0.5)))
      : Text(reaction.startsWith(':') ? reaction : reaction, style: TextStyle(fontSize: reaction.startsWith(':') ? size * 0.45 : size * 0.85));
}
