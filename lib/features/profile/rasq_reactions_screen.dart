import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/navigation.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../../l10n/l10n.dart';
import 'rasq_post_tile.dart';

/// RASQ の投稿の「リアクションを表示」(D-294 / S-030): SNS の同じページ (reactions_screen) と同じ作り。
///
/// 対象の投稿(小表示)+ タブ: 返信 / リブロード(した人)/ キュー(絵ごとの折りたたみ、中は付けた人)/ 引用(した投稿)。
/// 最初に開くのはキュー。
class RasqReactionsScreen extends ConsumerStatefulWidget {
  const RasqReactionsScreen({super.key, required this.postId});
  final String postId;
  @override
  ConsumerState<RasqReactionsScreen> createState() => _RasqReactionsScreenState();
}

class _RasqReactionsScreenState extends ConsumerState<RasqReactionsScreen> {
  final Set<String> _open = {};

  void _refresh() {
    ref.invalidate(rasqThreadProvider(widget.postId));
    ref.invalidate(rasqPostReactionsProvider(widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = ref.watch(rasqThreadProvider(widget.postId));
    final rx = ref.watch(rasqPostReactionsProvider(widget.postId));
    final central = ref.watch(centralBaseUrlProvider);
    final post = thread.value?.post;
    // チャイルドセーフ (D-454、[9]): 投稿の詳細と同じく、見せない投稿 / 見守りの時間に詳細を開かせない設定なら出さない。
    final childBlocked = rasqPostDetailBlockReason(ref.watch(childGateProvider), post);
    if (childBlocked != null) {
      return Scaffold(
        appBar: RasqPageHeader(title: l10n.profilePostReactionsTitle),
        body: RasqEmptyView(key: const ValueKey('childSafe.postHidden'), title: l10n.childSafePostHidden, hint: childBlocked == l10n.childSafePostHidden ? l10n.childSafeScreensBlockedHint : childBlocked),
      );
    }
    Widget tab(Widget Function(RasqPostReactions) of) => rx.when(
          loading: () => const RasqLoading(),
          error: (e, _) => _RasqLoadError(error: e),
          data: of,
        );
    final tabs = [RasqTabItem(l10n.profilePostReply), RasqTabItem(l10n.profilePostRebroad), RasqTabItem(l10n.profilePostQueue), RasqTabItem(l10n.profilePostQuote)];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: 2,
      child: Scaffold(
        appBar: RasqPageHeader(title: l10n.profilePostReactionsTitle),
        body: Column(children: [
          if (post != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, 0),
              child: InlinePostFrame(post: post.toPost(central: central), maxLines: 4, onTap: () => context.pushPost(post.toPost(central: central))),
            ),
          RasqTabs(items: tabs),
          Expanded(
            child: TabBarView(children: [
              thread.when(
                loading: () => const RasqLoading(),
                error: (e, _) => _RasqLoadError(error: e),
                data: (t) => RasqPostTileList(posts: t.replies, empty: l10n.profilePostNoReplies, onChanged: _refresh),
              ),
              tab((r) => RasqActorList(actors: r.rebroads, empty: l10n.profilePostNoRebroads)),
              tab((r) => RasqQueueSections(groups: r.queues, open: _open, onToggle: (k) => setState(() => _open.contains(k) ? _open.remove(k) : _open.add(k)))),
              tab((r) => RasqPostTileList(posts: r.quotes, empty: l10n.profilePostNoQuotes, onChanged: _refresh)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RasqLoadError extends StatelessWidget {
  const _RasqLoadError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    final e = error;
    return Padding(
      padding: const EdgeInsets.all(RasqSpacing.page),
      child: Text(e is OrgateException && e.code.code == '404' ? context.l10n.profilePostGone : context.l10n.profilePostLoadFailed('${e is OrgateException ? e.message : e}'),
          style: RasqTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

/// RASQ の投稿の並び(返信 / 引用)。スレッド画面の欄の切り替えにも埋め込むので、public + shrinkWrap。
class RasqPostTileList extends StatelessWidget {
  const RasqPostTileList({super.key, required this.posts, required this.empty, this.onChanged, this.shrinkWrap = false});
  final List<RasqAccountPost> posts;
  final String empty;
  final VoidCallback? onChanged;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return RasqEmptyView(title: empty);
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: posts.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, i) => RasqPostTileView(key: ValueKey('rasqRx.post.${posts[i].id}'), post: posts[i], onChanged: onChanged ?? () {}, onOpen: () => context.push(Routes.rasqPost(posts[i].id))),
    );
  }
}

/// RASQ アカウントの並び(リブロードした人 / キューした人)。押すと、その人のアカウントページへ。
class RasqActorList extends StatelessWidget {
  const RasqActorList({super.key, required this.actors, this.empty, this.shrinkWrap = false});
  final List<RasqReactionActor> actors;
  final String? empty;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (actors.isEmpty) return empty == null ? const SizedBox.shrink() : RasqEmptyView(title: empty!);
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: actors.length,
      itemBuilder: (_, i) {
        final a = actors[i];
        return InkWell(
          key: ValueKey('rasqRx.actor.${a.account.handle}.$i'),
          onTap: () => context.pushRasqAccount(a.account.handle),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
            child: Row(children: [
              RasqAvatar(imageUrl: a.account.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: a.account.label),
              const SizedBox(width: RasqSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.account.label, style: RasqTypography.title, overflow: TextOverflow.ellipsis),
                  Text('@${a.account.handle}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Text(RasqTimestamp.format(a.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        );
      },
    );
  }
}

/// キューの欄: 絵(いいねは ❤)+ 数 の行を押すと、付けた人が開く(SNS のリアクション欄と同じ折りたたみ)。
class RasqQueueSections extends StatelessWidget {
  const RasqQueueSections({super.key, required this.groups, required this.open, required this.onToggle, this.shrinkWrap = false});
  final List<({RasqQueueCount queue, List<RasqReactionActor> accounts})> groups;
  final Set<String> open;
  final ValueChanged<String> onToggle;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (groups.isEmpty) return RasqEmptyView(title: context.l10n.profilePostNoQueues);
    return ListView(shrinkWrap: shrinkWrap, physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null, children: [
      for (final g in groups) ...[
        InkWell(
          key: ValueKey('rasqRx.queue.${RasqPostTileView.queueKey(g.queue.packId, g.queue.stickerId)}'),
          onTap: () => onToggle(RasqPostTileView.queueKey(g.queue.packId, g.queue.stickerId)),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: g.queue.url != null
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '${g.queue.url}', height: 26, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, size: 22))
                    : const Text('❤', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: RasqSpacing.md),
              Text('${g.queue.count}', style: RasqTypography.title),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(child: Text(g.queue.like ? context.l10n.profilePostLike : g.queue.stickerId, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              if (g.queue.mine) RasqPill(label: context.l10n.profilePostYou),
              Icon(open.contains(RasqPostTileView.queueKey(g.queue.packId, g.queue.stickerId)) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            ]),
          ),
        ),
        if (open.contains(RasqPostTileView.queueKey(g.queue.packId, g.queue.stickerId))) RasqActorList(actors: g.accounts, shrinkWrap: true),
      ],
    ]);
  }
}
