import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/providers.dart';
import '../../mock/mock_data.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';

/// ホームTL (フォロー中/おすすめ/関連). M0: header + extensible tabs + mock rows.
/// The real `PostTile` (L2 composite) lands in M2; [_MockPostRow] only
/// exercises atomic components and the store wiring.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final account = ref.watch(currentAccountProvider);
    final posts = MockData.timeline(account);
    final tabs = [const RasqTabItem('おすすめ'), const RasqTabItem('フォロー中'), const RasqTabItem('関連')];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: 1,
      child: Scaffold(
        appBar: RasqHomeHeader(
          me: me,
          onAvatarTap: () => RasqShell.openSidebar(context, ref),
          vcWidget: _VcWidgetPlaceholder(users: [MockData.douglas, MockData.tivard], extra: 4),
        ),
        body: Column(children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(children: [
              Expanded(child: RasqTabs(items: tabs, showChevron: false)),
              RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'タイムライン設定'),
            ]),
          ),
          Expanded(
            child: TabBarView(children: [
              const RasqEmptyView(title: 'おすすめ', hint: 'M2でSNSプラグインから流入します'),
              _TimelineList(posts: posts),
              const RasqEmptyView(title: '関連', hint: 'リレーショナルTL (M5)'),
            ]),
          ),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          tooltip: '投稿',
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {},
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) => _MockPostRow(post: posts[i]),
        ),
      );
}

/// Temporary row for M0 — deliberately NOT the final PostTile.
class _MockPostRow extends ConsumerWidget {
  const _MockPostRow({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final like = ref.watch(actionStateOfProvider((postKey: post.key, actionId: 'like')));
    final repost = ref.watch(actionStateOfProvider((postKey: post.key, actionId: 'repost')));
    final store = ref.read(actionStateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RasqAvatar(imageUrl: post.author.avatarUrl, size: RasqSizes.avatarLg, presence: post.author.presence, fallbackLabel: post.author.displayName),
        const SizedBox(width: RasqSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.author.displayName, style: RasqTypography.displayName),
                  Row(children: [
                    Flexible(child: Text('@${post.author.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 2),
                    Flexible(child: RasqSnsPill(account: post.author.account)),
                  ]),
                ]),
              ),
              RasqIconButton(icon: Icons.bookmark_border, size: 20, onPressed: () {}, tooltip: 'ブックマーク'),
              RasqIconButton(icon: Icons.more_horiz, size: 20, onPressed: () {}, tooltip: 'メニュー'),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            RasqRichText.plain(post.body, style: RasqTypography.body),
            if (post.media.isNotEmpty) ...[const SizedBox(height: RasqSpacing.sm), RasqMediaGrid(items: post.media)],
            if (post.poll != null) ...[const SizedBox(height: RasqSpacing.sm), _MockPoll(poll: post.poll!)],
            const SizedBox(height: RasqSpacing.xs),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              RasqActionButton.iconCount(icon: Icons.subdirectory_arrow_left, count: post.counts['reply'] ?? 0, tooltip: '返信', onTap: () {}),
              RasqActionButton.icon(icon: Icons.navigation, tooltip: 'ブースト', onTap: () {}),
              RasqActionButton.iconCount(
                icon: Icons.repeat,
                doneIcon: Icons.repeat_on,
                count: repost.count ?? post.counts['repost'] ?? 0,
                done: repost.done,
                tooltip: 'リノート',
                onTap: () => store.apply(post.key, 'repost', ActionState(done: !repost.done, count: (repost.count ?? post.counts['repost'] ?? 0) + (repost.done ? -1 : 1))),
              ),
              RasqActionButton.iconCount(
                icon: Icons.favorite_border,
                doneIcon: Icons.favorite,
                doneColor: RasqTokens.of(context).live,
                count: like.count ?? post.counts['like'] ?? 0,
                done: like.done,
                tooltip: 'いいね',
                onTap: () => store.apply(post.key, 'like', ActionState(done: !like.done, count: (like.count ?? post.counts['like'] ?? 0) + (like.done ? -1 : 1))),
              ),
              RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {}),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _MockPoll extends StatelessWidget {
  const _MockPoll({required this.poll});
  final Poll poll;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = poll.totalVotes == 0 ? 1 : poll.totalVotes;
    return Column(children: [
      for (final o in poll.options)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: o.votes / total, child: ColoredBox(color: scheme.surfaceContainerHighest))),
            Center(child: Text(o.text, style: RasqTypography.listTile)),
            Positioned(right: 12, top: 0, bottom: 0, child: Center(child: Text('${o.votes}', style: RasqTypography.listTile))),
          ]),
        ),
    ]);
  }
}

class _VcWidgetPlaceholder extends StatelessWidget {
  const _VcWidgetPlaceholder({required this.users, required this.extra});
  final List<UserSummary> users;
  final int extra;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '参加中のVC',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: RasqColors.accent, borderRadius: BorderRadius.circular(999)),
          child: RasqGroupAvatar(users: users, size: 28, overflowCount: extra),
        ),
      );
}
