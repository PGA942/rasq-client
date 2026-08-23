import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../compose/emoji_picker_fow.dart';
import '../post/post_menu.dart';

/// Interim post row (M1). The L2 composite `PostTile` with slot model
/// (avatar/content/media/action/完全置き換え) replaces this in M2; the action
/// bar already follows the registration model (plugin → ActionDescriptor →
/// state from Store).
/// Action handler: `args` carries e.g. `{'reaction': '🎉'}` from the picker.
typedef PostActionHandler = Future<void> Function(ActionDescriptor action, {Map<String, Object?> args});

class PostRow extends ConsumerStatefulWidget {
  const PostRow({super.key, required this.post, required this.actions, required this.onAction, this.onTap, this.dense = false});

  final Post post;
  final List<ActionDescriptor> actions;
  final PostActionHandler onAction;
  final VoidCallback? onTap;

  /// Embedded size (通知の投稿タイル系など): smaller avatar, no outer padding.
  final bool dense;

  static const Map<String, IconData> _icons = {
    'subdirectory_arrow_left': Icons.subdirectory_arrow_left,
    'repeat': Icons.repeat,
    'repeat_on': Icons.repeat_on,
    'add_reaction_outlined': Icons.add_reaction_outlined,
    'add_reaction': Icons.add_reaction,
    'star_border': Icons.star_border,
    'star': Icons.star,
    'favorite_border': Icons.favorite_border,
    'favorite': Icons.favorite,
    'ios_share': Icons.ios_share,
    'bookmark_border': Icons.bookmark_border,
    'bookmark': Icons.bookmark,
  };

  static IconData iconFor(String? name, IconData fallback) => _icons[name] ?? fallback;

  @override
  ConsumerState<PostRow> createState() => _PostRowState();
}

class _PostRowState extends ConsumerState<PostRow> {
  bool _expanded = false;

  Post get post => widget.post;
  List<ActionDescriptor> get actions => widget.actions;
  PostActionHandler get onAction => widget.onAction;
  VoidCallback? get onTap => widget.onTap;

  static const _collapseLines = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final emojis = ref.watch(emojiCacheProvider);
    // 省略表示: 既読かつ長文の投稿は先頭数行 + 「展開する」(タップ領域は全体).
    final isRead = ref.watch(isReadProvider(post.key));
    final lineCount = '\n'.allMatches(post.body).length + 1;
    final collapsible = isRead && !_expanded && (lineCount > _collapseLines || post.body.length > 140);
    final avatarSize = widget.dense ? RasqSizes.avatarMd : RasqSizes.avatarLg;
    final spans = InlineSpans.parse(post.body, emojis: emojis, onLink: (u) => launchUrl(u, mode: LaunchMode.externalApplication), onHashtag: (t) => context.pushTrend(t));
    final nameSpans = InlineSpans.parse(post.author.displayName, emojis: emojis);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: widget.dense ? const EdgeInsets.symmetric(vertical: RasqSpacing.xs) : const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.repostedBy != null)
            Padding(
              padding: EdgeInsets.only(left: avatarSize + RasqSpacing.md, bottom: 4),
              child: Row(children: [
                Icon(Icons.repeat, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text('${post.repostedBy!.displayName}がリノートしました', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqAvatar(imageUrl: post.author.avatarUrl, size: avatarSize, presence: post.author.presence, fallbackLabel: post.author.displayName, onTap: () => context.pushUser(post.author)),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.pushUser(post.author),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RasqRichText(nameSpans, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Flexible(child: Text('@${post.author.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 2),
                        Flexible(child: RasqSnsPill(account: post.author.account)),
                      ]),
                    ]),
                    ),
                  ),
                  RasqTimestamp(post.createdAt),
                  Builder(
                    builder: (ctx) => RasqIconButton(
                      icon: Icons.more_horiz,
                      size: 20,
                      tooltip: 'メニュー',
                      onPressed: () {
                        final box = ctx.findRenderObject() as RenderBox;
                        showPostMenu(context, ref, post, box.localToGlobal(Offset.zero) & box.size);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: RasqSpacing.xs),
                if (collapsible)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = true),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RasqRichText(spans, style: RasqTypography.body, maxLines: _collapseLines, overflow: TextOverflow.ellipsis),
                      Text('展開する', style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
                    ]),
                  )
                else if (post.contentWarning != null && post.contentWarning!.isNotEmpty)
                  _Cw(cw: post.contentWarning!, child: _Body(spans: spans, post: post, onMediaTap: (i) => context.openViewer(post, i)))
                else
                  _Body(spans: spans, post: post, onMediaTap: (i) => context.openViewer(post, i)),
                const SizedBox(height: RasqSpacing.xs),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final a in actions)
                    _ActionBtn(
                      post: post,
                      action: a,
                      onAction: onAction,
                      doneColor: a.genreTag == 'Reaction' ? tokens.live : null,
                      // リアクション: 長押しで絵文字ピッカー FOW → 選んだ絵文字で実行
                      onLongPress: a.genreTag == 'Reaction'
                          ? () => openEmojiPicker(ref, closeOnPick: true, title: 'リアクション', onPick: (e) => onAction(a, args: {'reaction': e}).catchError((_) {}))
                          : null,
                    ),
                  RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {}),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.spans, required this.post, this.onMediaTap});
  final List<RasqSpan> spans;
  final Post post;
  final ValueChanged<int>? onMediaTap;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (post.body.isNotEmpty) RasqRichText(spans, style: RasqTypography.body),
        if (post.media.isNotEmpty) ...[const SizedBox(height: RasqSpacing.sm), RasqMediaGrid(items: post.media, onTapTile: onMediaTap)],
        if (post.poll != null) ...[const SizedBox(height: RasqSpacing.sm), _PollView(poll: post.poll!)],
        if (post.quote != null) ...[const SizedBox(height: RasqSpacing.sm), _QuoteView(post: post.quote!)],
      ]);
}

class _Cw extends StatefulWidget {
  const _Cw({required this.cw, required this.child});
  final String cw;
  final Widget child;
  @override
  State<_Cw> createState() => _CwState();
}

class _CwState extends State<_Cw> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.cw, style: RasqTypography.body),
      const SizedBox(height: 4),
      OutlinedButton(
        onPressed: () => setState(() => _open = !_open),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12), side: BorderSide(color: scheme.outline), foregroundColor: scheme.onSurface),
        child: Text(_open ? '隠す' : 'もっと見る'),
      ),
      if (_open) ...[const SizedBox(height: RasqSpacing.sm), widget.child],
    ]);
  }
}

class _ActionBtn extends ConsumerWidget {
  const _ActionBtn({required this.post, required this.action, required this.onAction, this.doneColor, this.onLongPress});
  final Post post;
  final ActionDescriptor action;
  final PostActionHandler onAction;
  final Color? doneColor;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(actionStateOfProvider((postKey: post.key, actionId: action.id)));
    final icon = PostRow.iconFor(action.icon, Icons.circle_outlined);
    final doneIcon = action.doneIcon == null ? null : PostRow.iconFor(action.doneIcon, icon);
    final showCount = action.countSource != CountSource.none;
    final count = st.count ?? post.counts[action.id] ?? 0;
    void tap() => onAction(action).catchError((_) {});
    return showCount
        ? RasqActionButton.iconCount(icon: icon, doneIcon: doneIcon, done: st.done, doneColor: doneColor, count: count, tooltip: action.label, onTap: tap, onLongPress: onLongPress, enabled: st.enabled)
        : RasqActionButton.icon(icon: icon, doneIcon: doneIcon, done: st.done, doneColor: doneColor, tooltip: action.label, onTap: tap, onLongPress: onLongPress, enabled: st.enabled);
  }
}

class _PollView extends StatelessWidget {
  const _PollView({required this.poll});
  final Poll poll;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = poll.totalVotes == 0 ? 1 : poll.totalVotes;
    final now = DateTime.now();
    final results = poll.showsResults(now);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < poll.options.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: poll.votedIndices.contains(i) ? scheme.primary : scheme.onSurface, width: poll.votedIndices.contains(i) ? 2 : 1), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            if (results) Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: poll.options[i].votes / total, child: ColoredBox(color: scheme.surfaceContainerHighest))),
            Center(child: Text(poll.options[i].text, style: RasqTypography.listTile)),
            if (results) Positioned(right: 12, top: 0, bottom: 0, child: Center(child: Text('${poll.options[i].votes}', style: RasqTypography.listTile))),
          ]),
        ),
      if (poll.expiresAt != null) RasqTimestamp(poll.expiresAt!, mode: RasqTimestampMode.remaining),
    ]);
  }
}

class _QuoteView extends StatelessWidget {
  const _QuoteView({required this.post});
  final Post post;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RasqAvatar(imageUrl: post.author.avatarUrl, size: RasqSizes.avatarXs, fallbackLabel: post.author.displayName),
          const SizedBox(width: 6),
          Flexible(child: Text(post.author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Flexible(child: Text('@${post.author.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
        ]),
        if (post.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: RasqRichText(InlineSpans.parse(post.body), style: RasqTypography.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis)),
        if (post.media.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: RasqMediaGrid(items: post.media)),
      ]),
    );
  }
}
