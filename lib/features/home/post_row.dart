import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../compose/emoji_picker_fow.dart';
import 'reaction_history.dart';
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

    // アクションバー編集(ホスト構成): リスト束ね・並び替え・非表示を適用して Props 化。
    final entries = ref.watch(actionBarConfigProvider).apply(widget.actions);
    final actionItems = [
      for (final e in entries)
        switch (e) {
          SingleActionEntry() => _item(e.action, tokens),
          ActionListEntry() => _listItem(e),
        },
    ];

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
      actionBar: widget.actions.isEmpty && post.reactions.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // 投稿内のリアクション数表示 (D-040): アクションバーの上に
              // 角丸タイル(絵文字+数、自分のはハイライト、タップで同調/解除)。
              if (post.reactions.isNotEmpty)
                RasqReactionChips(
                  reactions: post.reactions,
                  emojiUrls: post.reactionEmojis,
                  myReaction: post.myReaction,
                  // チップにリアクションしたユーザー(アイコン+名前)を表示
                  // (D-042)。チップを開いたときだけ SNS API を叩く。
                  usersLoader: (r) async {
                    final s = ref.read(currentSnsSessionProvider);
                    if (s == null) return const [];
                    try {
                      return [for (final e in (await s.reactions(post.id, type: r, limit: 10)).items) e.user];
                    } catch (_) {
                      return const [];
                    }
                  },
                  onTap: (r) {
                    final a = widget.actions.where((x) => x.genreTag == 'Reaction').firstOrNull;
                    if (a == null) return;
                    if (r == post.myReaction) {
                      widget.onAction(a).catchError((_) {}); // 自分の → 解除
                    } else {
                      widget.onAction(a, args: {'reaction': r}).then((_) => ref.read(reactionHistoryProvider.notifier).record(r)).catchError((_) {});
                    }
                  },
                ),
              if (widget.actions.isNotEmpty) RasqActionBar(items: actionItems, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})]),
            ]),
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
    final isRepost = a.genreTag == 'Repost';
    // 予測絵文字の表示 (D-041): リアクションしていない**全ての投稿**で、
    // 表示されたタイミングにパッシブ計算(純ローカル、ネットワーク/ML なし)。
    // Unicode はテキスト、カスタムは投稿の reactionEmojis から画像で表示。
    String? iconText = st.iconText;
    Uri? iconUrl = st.iconUrl;
    var predictedIcon = false;
    if (iconText == null && iconUrl == null && isReaction && !st.done) {
      final predicted = ref.watch(reactionHistoryProvider).value == null ? null : ref.read(reactionHistoryProvider.notifier).predictFor(post);
      if (predicted != null) {
        if (predicted.startsWith(':')) {
          iconUrl = post.reactionEmojis[predicted];
        } else {
          iconText = predicted;
        }
        predictedIcon = iconText != null || iconUrl != null;
      }
    }
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
      iconUrl: iconUrl,
      iconText: iconText,
      // 予測はグレースケール+70%減光で「未実行」を区別 (D-042)。
      mutedIcon: predictedIcon,
      // Repost はデフォルトの**アクションバンドル**(D-039): タップで
      // リノート / 引用ノートのドロップダウン(ユーザー編集のリスト化とは
      // 別で、(+) の編集導線には出ない組み込みバンドル)。
      onTap: isRepost ? null : () => _performReactionAware(a, st),
      onAnchorTap: isRepost ? (anchor) => _repostBundle(a, st, anchor) : null,
      // リアクション: 長押しで絵文字ピッカー FOW → 選んだ絵文字で実行
      onLongPress: isReaction
          ? () => openEmojiPicker(ref, closeOnPick: true, title: 'リアクション',
                  predictionContext: '${post.contentWarning ?? ''} ${post.body} ${post.quote?.body ?? ''}',
                  existingReactions: post.reactions, onPick: (e) {
                widget.onAction(a, args: {'reaction': e}).then((_) => ref.read(reactionHistoryProvider.notifier).record(e)).catchError((_) {});
              })
          : null,
    );
  }

  /// 短押し。リアクションは**予測絵文字**を添えて実行する (D-039:
  /// 事前学習なしのヒューリスティック — 自分の履歴 × 投稿に付いている
  /// リアクション。reaction-predictor モデル配線後は ml.infer に置換)。
  void _performReactionAware(ActionDescriptor a, ActionState st) {
    if (a.genreTag == 'Reaction' && !st.done) {
      final predicted = ref.read(reactionHistoryProvider.notifier).predictFor(post);
      widget
          .onAction(a, args: predicted == null ? const {} : {'reaction': predicted})
          .then((_) => predicted == null ? null : ref.read(reactionHistoryProvider.notifier).record(predicted))
          .catchError((_) {});
      return;
    }
    widget.onAction(a).catchError((_) {});
  }

  /// リノート/引用ノートの組み込みバンドル (D-039)。
  Future<void> _repostBundle(ActionDescriptor a, ActionState st, Rect anchor) async {
    final manager = ref.read(overlayManagerProvider);
    final picked = await manager.showDropdown<String>(
      id: 'actionbar.repost.${post.key}',
      anchor: anchor,
      dense: true,
      items: [
        RasqDropdownItem(st.done ? 'リノート解除' : 'リノート', 'renote'),
        const RasqDropdownItem('引用ノート', 'quote'),
      ],
    );
    switch (picked) {
      case 'renote':
        await widget.onAction(a).catchError((_) {});
      case 'quote':
        await showComposer(ref, ComposeQuote(post));
    }
  }

  /// アクションリスト(束ね)ボタン: タップでメンバーのドロップダウン。
  RasqActionBarItem _listItem(ActionListEntry entry) => RasqActionBarItem(
        id: 'list:${entry.list.id}',
        label: entry.list.name,
        icon: Icons.apps,
        showCount: false,
        onAnchorTap: (anchor) async {
          final manager = ref.read(overlayManagerProvider);
          final picked = await manager.showDropdown<ActionDescriptor>(
            id: 'actionbar.list.${entry.list.id}',
            anchor: anchor,
            dense: true,
            items: [for (final a in entry.members) RasqDropdownItem(a.label, a)],
          );
          if (picked != null) await widget.onAction(picked).catchError((_) {});
        },
      );

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
