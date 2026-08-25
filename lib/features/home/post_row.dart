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
import 'action_bar_config.dart';

/// Action handler: `args` carries e.g. `{'reaction': '🎉'}` from the picker.
typedef PostActionHandler = Future<void> Function(ActionDescriptor action, {Map<String, Object?> args});

/// Host adapter around the L2 composite [RasqPostTile]: reads the Store
/// (既読 / アクション状態 / 絵文字キャッシュ), parses RSL into spans, maps the
/// plugin's `ActionDescriptor`s to [RasqActionBarItem]s and fills the tile's
/// slots. The tile itself is props-only (D-002: L2 はホスト実装、状態は DSL の外).
///
/// This is exactly the work the RRL renderer will do for a WASM plugin's
/// `PostTile` node later (M3): descriptor + Store → props.
class PostRow extends ConsumerStatefulWidget {
  const PostRow({super.key, required this.post, required this.actions, required this.onAction, this.onTap, this.dense = false});

  final Post post;
  final List<ActionDescriptor> actions;
  final PostActionHandler onAction;
  final VoidCallback? onTap;

  /// Embedded size (通知の投稿タイル系など): smaller avatar, no outer padding.
  final bool dense;

  /// Host icon registry: plugin icon names → Material glyphs (until the RASQ
  /// icon font lands).
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
  /// Ephemeral: user expanded a collapsed (既読) post in this session.
  bool _expanded = false;

  Post get post => widget.post;

  static const _collapseLines = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final emojis = ref.watch(emojiCacheProvider);
    final isRead = ref.watch(isReadProvider(post.key));

    // 省略表示: 既読かつ長文の投稿は先頭数行 + 「展開する」(Store 状態 → props).
    final lineCount = '\n'.allMatches(post.body).length + 1;
    final collapsible = isRead && !_expanded && (lineCount > _collapseLines || post.body.length > 140);

    final spans = InlineSpans.parse(post.body, emojis: emojis, onLink: (u) => launchUrl(u, mode: LaunchMode.externalApplication), onHashtag: (t) => context.pushTrend(t));
    final nameSpans = InlineSpans.parse(post.author.displayName, emojis: emojis);

    // content slot
    final Widget content;
    if (collapsible) {
      content = RasqCollapsedPost(spans: spans, maxLines: _collapseLines, onExpand: () => setState(() => _expanded = true));
    } else {
      final body = post.body.isNotEmpty ? RasqRichText(spans, style: RasqTypography.body) : const SizedBox.shrink();
      final cw = post.contentWarning;
      content = (cw != null && cw.isNotEmpty) ? RasqContentWarning(cw: cw, child: _CwBody(post: post, body: body)) : body;
    }
    // When a CW is present, media/poll/quote live *inside* the CW reveal;
    // otherwise they fill the tile's own slots.
    final hasCw = !collapsible && (post.contentWarning?.isNotEmpty ?? false);

    // アクションバー編集(ホスト構成): 並び替え・非表示を適用してから Props 化。
    final configured = ref.watch(actionBarConfigProvider).apply(widget.actions);
    final actionItems = [for (final a in configured) _item(a, tokens)];

    return RasqPostTile(
      author: post.author,
      createdAt: post.createdAt,
      nameSpans: nameSpans,
      repostedBy: post.repostedBy,
      dense: widget.dense,
      content: content,
      media: !collapsible && !hasCw && post.media.isNotEmpty ? RasqMediaGrid(items: post.media, onTapTile: (i) => context.openViewer(post, i)) : null,
      poll: !collapsible && !hasCw && post.poll != null ? RasqPollWidget(poll: post.poll!) : null,
      quote: !collapsible && !hasCw && post.quote != null ? quoteTile(context, post.quote!, emojis: emojis) : null,
      actionBar: widget.actions.isEmpty
          ? null
          : RasqActionBar(items: actionItems, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})]),
      onTap: widget.onTap,
      onAuthorTap: () => context.pushUser(post.author),
      onMore: (anchor) => showPostMenu(context, ref, post, anchor),
    );
  }

  /// ActionDescriptor + ActionState (Store) → ActionBar props.
  RasqActionBarItem _item(ActionDescriptor a, RasqTokens tokens) {
    final st = ref.watch(actionStateOfProvider((postKey: post.key, actionId: a.id)));
    final icon = PostRow.iconFor(a.icon, Icons.circle_outlined);
    final doneIcon = a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, icon);
    final isReaction = a.genreTag == 'Reaction';
    return RasqActionBarItem(
      id: a.id,
      label: a.label,
      icon: icon,
      doneIcon: doneIcon,
      done: st.done,
      count: st.count ?? post.counts[a.id],
      showCount: a.countSource != CountSource.none,
      enabled: st.enabled,
      doneColor: isReaction ? tokens.live : null,
      iconUrl: st.iconUrl,
      onTap: () => widget.onAction(a).catchError((_) {}),
      // リアクション: 長押しで絵文字ピッカー FOW → 選んだ絵文字で実行
      onLongPress: isReaction ? () => openEmojiPicker(ref, closeOnPick: true, title: 'リアクション', onPick: (e) => widget.onAction(a, args: {'reaction': e}).catchError((_) {})) : null,
    );
  }

  /// 引用: 投稿カード(埋め込みサイズ)を再利用.
  static Widget quoteTile(BuildContext context, Post q, {Map<String, Uri?> emojis = const {}}) => RasqPostTile(
        variant: RasqPostTileVariant.embedded,
        author: q.author,
        createdAt: q.createdAt,
        nameSpans: InlineSpans.parse(q.author.displayName, emojis: emojis),
        content: q.body.isNotEmpty ? RasqRichText(InlineSpans.parse(q.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis) : const SizedBox.shrink(),
        media: q.media.isNotEmpty ? RasqMediaGrid(items: q.media) : null,
        onTap: () => context.pushPost(q),
      );
}

/// Body shown under an opened CW: text + media + poll + quote together.
class _CwBody extends ConsumerWidget {
  const _CwBody({required this.post, required this.body});
  final Post post;
  final Widget body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ref.watch(emojiCacheProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      body,
      if (post.media.isNotEmpty) ...[const SizedBox(height: RasqSpacing.sm), RasqMediaGrid(items: post.media, onTapTile: (i) => context.openViewer(post, i))],
      if (post.poll != null) ...[const SizedBox(height: RasqSpacing.sm), RasqPollWidget(poll: post.poll!)],
      if (post.quote != null) ...[const SizedBox(height: RasqSpacing.sm), _PostRowState.quoteTile(context, post.quote!, emojis: emojis)],
    ]);
  }
}
