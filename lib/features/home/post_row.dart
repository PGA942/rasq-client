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
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../compose/emoji_picker_fow.dart';
import 'reaction_history.dart';
import '../post/post_menu.dart';
import '../media/video_player.dart';
import '../post/share_fow.dart';
import '../plugins/slot_plugins.dart';
import '../vc/astell_post_share.dart';
import 'plugin_actions.dart';
import '../vc/astell_actions.dart';
import '../vc/astell_links.dart';
import '../settings/safety.dart';
import 'action_bar_config.dart';
import 'post_duplicates.dart';

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
  const PostRow({super.key, required this.post, required this.actions, required this.onAction, this.actionsFor, this.onTap, this.dense = false, this.showReplyParent = true, this.bannerIcon, this.bannerText, this.onActAs, this.compactQuote = false, this.showAllMedia = false, this.hideMedia = false});

  final Post post;
  final List<ActionDescriptor> actions;
  final PostActionHandler onAction;

  /// アカウント選択 (D-110): 重複コピーへ切り替えたとき、そのコピーで
  /// アクションを実行するためのハンドラ工場。null なら [onAction] のまま。
  final PostActionHandler Function(Post shown)? actionsFor;
  final VoidCallback? onTap;

  /// Embedded size (通知の投稿タイル系など): smaller avatar, no outer padding.
  final bool dense;

  /// リプライ元投稿の省略タイルを上に出す (D-069)。スレッド展開画面の
  /// ように文脈側が既に親を表示している場合は false。
  final bool showReplyParent;

  /// 上付きバナー行 (D-085): TL プラグインのバッジ(RT 行と同スタイル)。
  final IconData? bannerIcon;
  final String? bannerText;

  /// ↓ で別アカウントのコピーを選んだとき (D-155)。指定が無ければタイルの
  /// タップでそのコピー(= そのアカウント)のスレッドを開く。
  final ValueChanged<Post>? onActAs;

  /// インラインフレームモード (D-156): 引用を小表示(サムネイル最大 4 枚のカード)
  /// にする。TL では false(通常の埋め込みタイル)、スレッド展開/通知などでは true。
  final bool compactQuote;

  /// 添付を 4 枚で畳まず全部並べる(スレッド展開のメイン投稿、D-177)。
  final bool showAllMedia;

  /// 添付を出さない (D-202): ビューワーの FOW に投稿をインライン表示するとき(添付はビューワー本体)。
  final bool hideMedia;

  /// リプライ元の添付サマリー(「N件の添付ファイル」「1件の添付リンク」)。
  static String? attachmentSummaryOf(Post p) {
    if (p.media.isNotEmpty) return '${p.media.length}件の添付ファイル';
    if (p.linkUrl != null) return '1件の添付リンク';
    return null;
  }

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

  /// アカウント選択 (D-110): ↓ で選んだ別アカウントのコピー。表示と
  /// アクションがこのコピーに切り替わる。
  Post? _actAs;

  Post get post => _actAs ?? widget.post;

  /// [_actAs] 中はそのコピーでアクションを実行する。
  PostActionHandler get _onAction => (_actAs != null && widget.actionsFor != null) ? widget.actionsFor!(post) : widget.onAction;

  /// タップの実行: プラグインのボタン (D-176) はスロット登録簿へ、それ以外は SNS のアクションへ。
  Future<void> _run(ActionDescriptor a, {Map<String, Object?> args = const {}}) => isPluginActionId(a.id) ? _runPlugin(a) : _onAction(a, args: args);

  Future<void> _runPlugin(ActionDescriptor a) async {
    final pa = ref.read(pluginActionsProvider).where((x) => x.id == a.id).firstOrNull;
    if (pa == null) return;
    final acc = post.account;
    final column = fowColumnOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = await ref.read(slotPluginsProvider.notifier).postAction(
      pa.plugin,
      actionId: pa.decl.id,
      post: astellPostPayloadOf(post),
      account: {'sns': acc.kind.name, 'instance': acc.instance, 'handle': acc.handle},
      column: column,
      onComposerOpen: (text, media, mime, name) => showComposer(ref, const ComposeNormal(), initialText: text, column: column, initialFiles: media == null ? null : [ComposerInitialFile(bytes: media, name: name ?? 'plugin.png', mimeType: mime)]),
    );
    if (message != null && message.isNotEmpty) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static const _collapseLines = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final emojis = ref.watch(emojiCacheProvider);
    final isRead = ref.watch(isReadProvider(post.key));
    final safety = ref.watch(safetySettingsProvider);
    // 隠した重複コピー (D-110): あれば ↓(アカウント選択)を出す。
    final alternates = ref.watch(postAlternatesProvider)[widget.post.key] ?? const <Post>[];

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
      Widget body = post.body.isNotEmpty ? RasqRichText(spans, style: RasqTypography.body) : const SizedBox.shrink();
      // AsTell のリンクを含む投稿 (D-160): 本文の下にルームのタイル(ブックマーク/通知/見てみる)。
      final astellId = astellRoomIdIn(post.body);
      if (astellId != null) body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [body, AstellPostTile(roomId: astellId)]);
      final cw = post.contentWarning;
      content = (cw != null && cw.isNotEmpty) ? RasqContentWarning(cw: cw, initiallyOpen: safety.openCw, child: _CwBody(post: post, body: body, showAllMedia: widget.showAllMedia)) : body;
    }
    // When a CW is present, media/poll/quote live *inside* the CW reveal;
    // otherwise they fill the tile's own slots.
    final hasCw = !collapsible && (post.contentWarning?.isNotEmpty ?? false);
    // 閲覧注意メディアの表示設定 (D-044: sns.safety) を適用。
    final (mediaItems, mediaIndex) = safety.applyTo(post.media);

    // アクションバー編集(ホスト構成): リスト束ね・並び替え・非表示を適用して Props 化。
    // プラグインのボタン (D-176): このアカウントのスロット設定で有効なものを、タグの近い既存ボタンのバンドルへ。
    // 投稿が流れてきたアカウントの構成とアクションで出す (D-200): 複数サービスの合流 TL では、
    // 現在のアカウントのバーではなく、その投稿のアカウント(SNS)のボタン群と並びに上書きする。
    final ownSession = ref.watch(sessionForAccountProvider(post.account.key));
    final foreign = ownSession != null && ownSession.account != ref.watch(currentAccountProvider) && widget.actions.isNotEmpty;
    final snsActions = foreign ? ownSession.actions : widget.actions;
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(post.account.key)),
      snsActions: snsActions,
      plugins: ref.watch(pluginActionsProvider),
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
    );
    final entries = merged.config.apply(merged.actions);
    final actionItems = [
      for (final e in entries)
        switch (e) {
          SingleActionEntry() => _item(e.action, tokens),
          ActionListEntry() => _listItem(e),
        },
    ];

    final tile = RasqPostTile(
      author: post.author,
      createdAt: post.createdAt,
      nameSpans: nameSpans,
      repostedBy: post.repostedBy,
      bannerIcon: widget.bannerIcon,
      bannerText: widget.bannerText,
      dense: widget.dense,
      content: content,
      media: !collapsible && !hasCw && !widget.hideMedia && mediaItems.isNotEmpty ? RasqMediaGrid(items: mediaItems, maxVisible: widget.showAllMedia ? mediaItems.length : 4, onTapTile: (i) => context.openViewer(post, mediaIndex[i]), onPlayTile: (i) => showVideoFow(ref, mediaItems[i], post: post, column: fowColumnOf(context))) : null,
      poll: !collapsible && !hasCw && post.poll != null ? RasqPollWidget(poll: post.poll!) : null,
      quote: !collapsible && !hasCw && post.quote != null ? (widget.compactQuote ? InlinePostFrame(post: post.quote!) : quoteTile(context, post.quote!, emojis: emojis, safety: safety)) : null,
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
                      _onAction(a).catchError((_) {}); // 自分の → 解除
                    } else {
                      _onAction(a, args: {'reaction': r}).then((_) => ref.read(reactionHistoryProvider.notifier).record(r)).catchError((_) {});
                    }
                  },
                ),
              if (widget.actions.isNotEmpty) RasqActionBar(items: actionItems, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () => showPostShareFow(ref, post, column: fowColumnOf(context)))]),
            ]),
      // ↓ で別アカウントを選んでいる間は、そのコピーで以降の画面を開く (D-155)。
      onTap: _actAs != null && widget.onActAs == null ? () => context.pushPost(_actAs!) : widget.onTap,
      onAuthorTap: () => context.pushUser(post.author),
      onMore: (anchor) => showPostMenu(context, ref, post, anchor),
      // アカウント選択 (D-110/D-111): 複数アカウントに流れてきた同一投稿は
      // 1 枚に畳まれる — ヘッダー右上(… の左)の ↓ でどのアカウントとして
      // 見る/反応するかを選ぶ(アクションバーはずらさない)。
      headerAction: alternates.isEmpty
          ? null
          : Builder(builder: (ctx) {
              return RasqIconButton(
                icon: Icons.keyboard_arrow_down,
                size: 20,
                tooltip: 'アカウント選択',
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox;
                  final manager = ref.read(overlayManagerProvider);
                  final picked = await manager.showDropdown<Post>(
                    id: 'post.actAs.${widget.post.key}',
                    anchor: box.localToGlobal(Offset.zero) & box.size,
                    dense: true,
                    items: [
                      RasqDropdownItem('${widget.post.account}', widget.post, checked: post.key == widget.post.key),
                      for (final a in alternates) RasqDropdownItem('${a.account}', a, checked: post.key == a.key),
                    ],
                  );
                  if (picked != null && mounted) {
                    setState(() => _actAs = picked.key == widget.post.key ? null : picked);
                    // スレッド展開画面 (D-155): 選んだアカウントで開き直す。
                    if (_actAs != null) widget.onActAs?.call(_actAs!);
                  }
                },
              );
            }),
    );
    // リプライ元の省略タイル (D-069): TL に流れてきたリプライは、1 つ前の
    // 投稿をワイヤーフレーム p.5(DM ルームの「1件の添付リンク」)の形で
    // 上に出し、スレッド線で繋ぐ。タップで元投稿のスレッドへ。
    final parent = post.replyTo;
    if (parent == null || !widget.showReplyParent) return tile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ReplyParentRow(post: parent),
      tile,
    ]);
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
      // リアクション: 長押しで絵文字ピッカー FOW → 選んだ絵文字で実行。
      // ピッカーは**実物のリアクションボタンにアンカー**する (D-065:
      // 基本下付き・余白不足で上付き。D-055 の複製バーは置かない)。
      onAnchorLongPress: isReaction
          ? (anchor) => openEmojiPicker(ref, closeOnPick: true, title: 'リアクション', column: fowColumnOf(context), anchor: anchor,
                  predictionContext: '${post.contentWarning ?? ''} ${post.body} ${post.quote?.body ?? ''}',
                  existingReactions: post.reactions, onPick: (e) {
                _onAction(a, args: {'reaction': e}).then((_) => ref.read(reactionHistoryProvider.notifier).record(e)).catchError((_) {});
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
    _run(a).catchError((_) {});
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
        await _onAction(a).catchError((_) {});
      case 'quote':
        if (!mounted) return;
        await showComposer(ref, ComposeQuote(post), column: fowColumnOf(context));
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
          if (picked != null) await _run(picked).catchError((_) {});
        },
      );

  /// 引用: 投稿カード(埋め込みサイズ)を再利用.
  static Widget quoteTile(BuildContext context, Post q, {Map<String, Uri?> emojis = const {}, SafetySettings safety = const SafetySettings()}) {
    final (mediaItems, _) = safety.applyTo(q.media);
    return RasqPostTile(
      variant: RasqPostTileVariant.embedded,
      author: q.author,
      createdAt: q.createdAt,
      nameSpans: InlineSpans.parse(q.author.displayName, emojis: emojis),
      content: q.body.isNotEmpty ? RasqRichText(InlineSpans.parse(q.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis) : const SizedBox.shrink(),
      media: mediaItems.isNotEmpty ? RasqMediaGrid(items: mediaItems) : null,
      onTap: () => context.pushPost(q),
    );
  }
}

/// インラインフレームの小表示 (D-156): 別の面に埋め込む投稿のコンパクトなカード
/// (小アバター + 名前 + 本文 3 行 + 左にサムネイル最大 4 枚)。タップでスレッドへ。
/// 使う面: スレッド展開の引用 / リアクション表示の対象投稿 / 通知の投稿の引用 /
/// アクションからのジャンル選択。TL の引用表示だけは通常の埋め込みタイル。
class InlinePostFrame extends ConsumerWidget {
  const InlinePostFrame({super.key, required this.post, this.onTap, this.maxLines = 3, this.badge});
  final Post post;
  final VoidCallback? onTap;
  final int maxLines;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ref.watch(emojiCacheProvider);
    final safety = ref.watch(safetySettingsProvider);
    final (mediaItems, _) = safety.applyTo(post.media);
    final cw = post.contentWarning;
    final body = (cw != null && cw.isNotEmpty) ? '【CW: $cw】' : post.body;
    final thumbs = <Uri>[for (final m in mediaItems) if (m.type == MediaType.image || m.type == MediaType.video || m.type == MediaType.gif) m.thumbnailUrl ?? m.url];
    return RasqInlinePostCard(
      author: post.author,
      nameSpans: InlineSpans.parse(post.author.displayName, emojis: emojis),
      content: body.isNotEmpty
          ? RasqRichText(InlineSpans.parse(body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: maxLines, overflow: TextOverflow.ellipsis)
          : Text(mediaItems.isNotEmpty ? '${mediaItems.length}件の添付' : '', style: RasqTypography.caption),
      thumbnails: thumbs,
      mediaCount: mediaItems.length,
      badge: badge,
      onTap: onTap ?? () => context.pushPost(post),
    );
  }
}

/// リプライ元投稿の省略タイル(ホスト接着、D-069): RSL の 1 行抜粋・
/// 添付サマリー・タップ遷移を [RasqReplyParentTile] の Props に写す。
/// TL のリプライ(PostRow が上に積む)とスレッド展開画面の ancestors で共用。
class ReplyParentRow extends ConsumerWidget {
  const ReplyParentRow({super.key, required this.post, this.onTap});

  /// リプライ元(親)の投稿。
  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ref.watch(emojiCacheProvider);
    final cw = post.contentWarning;
    final spans = InlineSpans.parse(cw != null && cw.isNotEmpty ? '【CW: $cw】' : post.body, emojis: emojis);
    return RasqReplyParentTile(
      author: post.author,
      attachmentSummary: PostRow.attachmentSummaryOf(post),
      content: RasqRichText(spans, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap ?? () => context.pushPost(post),
    );
  }
}

/// Body shown under an opened CW: text + media + poll + quote together.
class _CwBody extends ConsumerWidget {
  const _CwBody({required this.post, required this.body, this.showAllMedia = false});
  final Post post;
  final Widget body;
  final bool showAllMedia;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ref.watch(emojiCacheProvider);
    final safety = ref.watch(safetySettingsProvider);
    final (mediaItems, mediaIndex) = safety.applyTo(post.media);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      body,
      if (mediaItems.isNotEmpty) ...[const SizedBox(height: RasqSpacing.sm), RasqMediaGrid(items: mediaItems, maxVisible: showAllMedia ? mediaItems.length : 4, onTapTile: (i) => context.openViewer(post, mediaIndex[i]))],
      if (post.poll != null) ...[const SizedBox(height: RasqSpacing.sm), RasqPollWidget(poll: post.poll!)],
      if (post.quote != null) ...[const SizedBox(height: RasqSpacing.sm), _PostRowState.quoteTile(context, post.quote!, emojis: emojis, safety: safety)],
    ]);
  }
}
