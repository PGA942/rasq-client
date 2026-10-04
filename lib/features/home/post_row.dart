import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/rasq_account_page_api.dart';
import '../profile/rasq_post_tile.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../compose/emoji_picker_fow.dart';
import 'reaction_history.dart';
import 'reaction_mode.dart';
import '../post/post_menu.dart';
import '../media/video_player.dart';
import '../post/share_fow.dart';
import '../plugins/slot_plugins.dart';
import '../vc/astell_post_share.dart';
import 'plugin_actions.dart';
import 'post_action_auto.dart';
import '../vc/astell_actions.dart';
import '../vc/astell_links.dart';
import '../../backend/orgate_client.dart' show centralBaseUrlProvider;
import '../../backend/rasq_collections_api.dart' show rasqCollectionLinkIn;
import '../../backend/server_info_api.dart' show serverHostLinkIn;
import '../collections/rasq_collection_tile.dart';
import '../servers/server_info_tile.dart';
import '../settings/safety.dart';
import 'action_bar_config.dart';
import 'account_affinity.dart';
import 'action_bundle_fow.dart';
import 'material_icons.dart';
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
  const PostRow({super.key, required this.post, required this.actions, required this.onAction, this.actionsFor, this.onTap, this.dense = false, this.showReplyParent = true, this.bannerIcon, this.bannerText, this.onActAs, this.compactQuote = false, this.showAllMedia = false, this.hideMedia = false, this.menuPin});

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

  /// … のメニューの「固定する / 固定を外す」(D-423。アカウントページの自分の投稿だけ)。
  final PostMenuPin? menuPin;

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

  /// 投稿ボタンの小さい表 → Material の全アイコン表 (D-249: 宣言のアイコン名はどのバーでも同じように引く)。
  static IconData iconFor(String? name, IconData fallback) => _icons[name] ?? materialIconByName(name) ?? fallback;

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

  @override
  void didUpdateWidget(PostRow old) {
    super.didUpdateWidget(old);
    // 行が別の投稿に使い回されたら、↓ の切り替えは持ち越さない (D-282)。自動実行も新しい投稿について頼み直す。
    if (old.post.key != widget.post.key) {
      _actAs = null;
      _autoPlugins = null;
    }
  }

  /// 自動実行を頼んだときのプラグイン一覧。同じ一覧・同じ投稿なら二度頼まない(投稿ごとに 1 回は [PostActionAutoRuns] が守る)。
  /// プラグインが後から読み込まれる(起動直後の読み直し / ストアからの追加)と一覧が変わるので、build のたびに見る。
  List<PluginAction>? _autoPlugins;

  /// post.action の temp (契約 v0.14 §2.9、D-305): タイルが作られたら、自動実行できるボタンを投稿ごとに 1 回呼ぶ。
  void _scheduleAutoPluginActions(List<PluginAction> plugins) {
    if (identical(_autoPlugins, plugins)) return;
    _autoPlugins = plugins;
    if (isRasqPost(widget.post) || !hasAutoPostActions(plugins)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final acc = post.account;
      runAutoPostActions(
        ref,
        postKey: post.key,
        settingsKey: acc.key,
        plugins: plugins,
        payload: astellPostPayloadOf(post),
        account: _pluginAccount(acc),
        column: fowColumnOf(context),
        onComposerOpen: _composerOpenFor(acc, fowColumnOf(context)),
      );
    });
  }

  static Map<String, Object?> _pluginAccount(AccountId acc) => {'sns': acc.kind.name, 'instance': acc.instance, 'handle': acc.handle};

  /// プラグインが開くコンポーザーも、↓ で切り替えたアカウントで (D-278)。
  void Function(String text, Uint8List? media, String? mime, String? name) _composerOpenFor(AccountId acc, int column) =>
      (text, media, mime, name) => showComposer(ref, const ComposeNormal(), initialText: text, column: column, postAs: ref.read(sessionsProvider).value?.allSessions.where((s) => s.account.key == acc.key).firstOrNull, initialFiles: media == null ? null : [ComposerInitialFile(bytes: media, name: name ?? 'plugin.png', mimeType: mime)]);

  /// [_actAs] 中はそのコピーでアクションを実行する。
  PostActionHandler get _onAction => (_actAs != null && widget.actionsFor != null) ? widget.actionsFor!(post) : widget.onAction;

  /// いま自分が付けているリアクション (D-281)。投稿の `myReaction` は取得したときのものなので、この画面で付けた / 外したぶんは
  /// アクションの状態から読む: 外していれば null、付け直していれば、ボタンのアイコンと同じ絵文字のチップ。
  String? get _myReaction {
    final a = widget.actions.where((x) => x.genreTag == 'Reaction').firstOrNull;
    if (a == null) return post.myReaction;
    final st = ref.watch(actionStateOfProvider((postKey: post.key, actionId: a.id)));
    if (!st.done) return null;
    for (final r in post.reactions.keys) {
      if (st.iconText != null && r == st.iconText) return r;
      if (st.iconUrl != null && post.reactionEmojis[r] == st.iconUrl) return r;
    }
    return st.iconText == null && st.iconUrl == null ? post.myReaction : null;
  }

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
      account: _pluginAccount(acc),
      column: column,
      onComposerOpen: _composerOpenFor(acc, column),
    );
    if (message != null && message.isNotEmpty) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static const _collapseLines = 3;

  @override
  Widget build(BuildContext context) {
    // RASQ の投稿 (D-283。TL のソース「RASQ の投稿」)は、どの画面でも RASQ のタイルで描く(SNS のアクションは効かない)。
    if (isRasqPost(widget.post)) {
      final original = ref.watch(rasqFeedPostsProvider.select((m) => m[widget.post.id]));
      return original == null ? const SizedBox.shrink() : RasqPostTileView(post: original, onChanged: () {}, onOpen: widget.onTap ?? () => context.pushPost(widget.post));
    }
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
      // RASQ リスト / クリップの共有リンク (D-345): 本文の下にそのタイル。無ければ、サーバーそのものへのリンクにサーバー情報タイル
      // (インスタンスでなければ何も出ない)。タイルは 1 つだけ(AsTell → コレクション → サーバーの順)。
      final collection = astellId == null ? rasqCollectionLinkIn(post.body) : null;
      final serverHost = astellId == null && collection == null ? serverHostLinkIn(post.body, exclude: {?ref.watch(centralBaseUrlProvider)?.host}) : null;
      if (collection != null) body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [body, RasqCollectionPostTile(idOrCode: collection.ref)]);
      if (serverHost != null) body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [body, ServerInfoPostTile(host: serverHost)]);
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
    final plugins = ref.watch(pluginActionsProvider);
    _scheduleAutoPluginActions(plugins);
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(post.account.key)),
      snsActions: snsActions,
      plugins: plugins,
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);
    // リアクションの受け方 (D-321): 投稿の SNS の `Reaction` の宣言(絵文字でリアクションできるか)と、投稿の「いいねのみ」から決める。
    // 合流 TL では、表示中のアカウントではなく投稿のアカウントの宣言を先に見る(Misskey のバーで Bluesky の投稿を見ていても、いいねとして出す)。
    final reactionMode = reactionModeOf(post, [...?ownSession?.actions, ...widget.actions].where((a) => a.genreTag == 'Reaction').firstOrNull);
    // 角丸のチップ(絵文字 + 数)は、絵文字でリアクションできる投稿だけ。いいねだけの投稿は、数をいいねのボタンに出す。
    final showChips = reactionMode == PostReactionMode.emoji && post.reactions.isNotEmpty;
    final actionItems = [
      for (final e in entries)
        switch (e) {
          SingleActionEntry() => _item(e.action, tokens, reactionMode),
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
      actionBar: widget.actions.isEmpty && !showChips
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // 投稿内のリアクション数表示 (D-040): アクションバーの上に
              // 角丸タイル(絵文字+数、自分のはハイライト、タップで同調/解除)。
              if (showChips)
                RasqReactionChips(
                  reactions: post.reactions,
                  emojiUrls: post.reactionEmojis,
                  myReaction: _myReaction,
                  // チップにリアクションしたユーザー(アイコン+名前)を表示
                  // (D-042)。チップを開いたときだけ SNS API を叩く。
                  usersLoader: (r) async {
                    final s = ref.read(sessionForAccountProvider(post.account.key));
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
                    if (r == _myReaction) {
                      // 自分の → 確認なしで取り消す (D-281)。
                      _onAction(a, args: const {'forceUndo': true}).catchError((_) {});
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
      onMore: (anchor) => showPostMenu(context, ref, post, anchor, pin: widget.menuPin),
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
  RasqActionBarItem _item(ActionDescriptor a, RasqTokens tokens, PostReactionMode reactionMode) {
    final st = ref.watch(actionStateOfProvider((postKey: post.key, actionId: a.id)));
    final isReaction = a.genreTag == 'Reaction';
    final isRepost = a.genreTag == 'Repost';
    // いいねだけの投稿の SNS のリアクションボタン (D-321): 絵文字のアイコン / 予測 / ピッカーを使わない。数はここに出す。
    final likeButton = isReaction && reactionMode != PostReactionMode.emoji && !isPluginActionId(a.id);
    // 「いいねのみ」の Misskey のノートは、ボタンも ❤ に(RASQ の投稿の「いいねのみ」と同じ)。
    final likeOnly = likeButton && reactionMode == PostReactionMode.likeOnly;
    final icon = likeOnly ? Icons.favorite_border : PostRow.iconFor(a.icon, Icons.circle_outlined);
    final doneIcon = likeOnly ? Icons.favorite : (a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, icon));
    // 予測絵文字の表示 (D-041): リアクションしていない**全ての投稿**で、
    // 表示されたタイミングにパッシブ計算(純ローカル、ネットワーク/ML なし)。
    // Unicode はテキスト、カスタムは投稿の reactionEmojis から画像で表示。
    // 絵文字でリアクションできない投稿 (D-321) は、付けた絵文字(❤ / ⭐)にも予測にも差し替えない。
    String? iconText = likeButton ? null : st.iconText;
    Uri? iconUrl = likeButton ? null : st.iconUrl;
    var predictedIcon = false;
    if (iconText == null && iconUrl == null && isReaction && !st.done && reactionMode == PostReactionMode.emoji) {
      final predicted = ref.watch(reactionHistoryProvider).value == null ? null : ref.read(reactionHistoryProvider.notifier).predictFor(post);
      if (predicted != null) {
        final remote = remoteReactionName(predicted);
        if (remote != null) {
          // 他サーバーの絵文字 (D-278): 同じ名前の絵文字が自サーバーにあれば、それを予測として出す(押すとそれが付く)。
          // 無ければ何も出さない(押すとピッカーが開く)。
          // 引くのは、**投稿が流れてきたアカウント**のサーバー (D-284。総合 TL では、表示中のアカウントとは限らない)。
          iconUrl = ref.watch(accountEmojiUrlProvider((account: post.account.key, name: remote))).value;
        } else if (predicted.startsWith(':')) {
          iconUrl = post.reactionEmojis[predicted];
        } else {
          iconText = predicted;
        }
        predictedIcon = iconText != null || iconUrl != null;
      }
    }
    return RasqActionBarItem(
      id: a.id,
      label: likeOnly ? 'いいね' : a.label,
      icon: icon,
      // リノートのボタンは、済みでも無効にしない (D-274): 完了アイコンの宣言が無いと部品が無効化するので、同じアイコンを渡す
      // (何度でもリノート / 引用でき、取り消しはリノートの帯の … やドロップダウンから)。
      doneIcon: doneIcon ?? (isRepost ? icon : null),
      done: st.done,
      // いいねの数 (D-321): チップを出さないぶん、ボタンに。アクション id の数が無ければ、プラグインの規約の `reaction` 欄
      // (Mastodon / mixi2 はお気に入り数をここに載せる)→ リアクションの合計。
      count: st.count ?? post.counts[a.id] ?? (likeButton ? post.counts['reaction'] ?? (post.reactions.isEmpty ? null : post.reactionTotal) : null),
      showCount: likeButton || a.countSource != CountSource.none,
      enabled: st.enabled,
      doneColor: isReaction ? tokens.live : null,
      iconUrl: iconUrl,
      iconText: iconText,
      // 予測はグレースケール+70%減光で「未実行」を区別 (D-042)。
      mutedIcon: predictedIcon,
      // Repost はデフォルトの**アクションバンドル**(D-039): タップで
      // リノート / 引用ノートのドロップダウン(ユーザー編集のリスト化とは
      // 別で、(+) の編集導線には出ない組み込みバンドル)。
      onAnchorTap: isRepost ? (anchor) => _repostBundle(a, st, anchor) : (anchor) => _performReactionAware(a, st, anchor, reactionMode),
      // リアクション: 長押しで絵文字ピッカー FOW → 選んだ絵文字で実行。
      // ピッカーは**実物のリアクションボタンにアンカー**する (D-065:
      // 基本下付き・余白不足で上付き。D-055 の複製バーは置かない)。
      // 絵文字でリアクションできない投稿 (D-321: Mastodon / Bluesky / mixi2、Misskey の「いいねのみ」)では、長押ししてもピッカーを開かない。
      onAnchorLongPress: isReaction && reactionMode == PostReactionMode.emoji ? (anchor) => _openReactionPicker(a, anchor) : null,
    );
  }

  /// 短押し。リアクションは**予測絵文字**を添えて実行する (D-039:
  /// 事前学習なしのヒューリスティック — 自分の履歴 × 投稿に付いている
  /// リアクション。reaction-predictor モデル配線後は ml.infer に置換)。
  ///
  /// **付けられる予測が無いときは、ピッカーを開く** (D-278): だれもリアクションしていなくて履歴も無い / 予測が他サーバーの絵文字で、
  /// 同じ名前のものが自サーバーに無い。以前は絵文字を添えずに送っていて、SNS 側の既定(👍)が付いていた。
  /// [_actAs] で別のアカウントに切り替えているときは、そのアカウントで付ける(以前は元のアカウントで付けていた)。
  ///
  /// 絵文字でリアクションできない投稿 (D-321) では予測もピッカーも使わない: いいねだけの SNS はボタンの入り切り、
  /// Misskey の「いいねのみ」のノートは ❤ を付ける。
  Future<void> _performReactionAware(ActionDescriptor a, ActionState st, Rect anchor, PostReactionMode mode) async {
    // リアクション済みなら、確認なしで取り消す (D-281)。
    if (a.genreTag == 'Reaction' && st.done) return _onAction(a, args: const {'forceUndo': true}).catchError((_) {});
    if (a.genreTag == 'Reaction' && mode == PostReactionMode.likeOnly && !isPluginActionId(a.id)) return _onAction(a, args: const {'reaction': likeOnlyReaction}).catchError((_) {});
    if (a.genreTag != 'Reaction' || !a.iconPerPost || mode != PostReactionMode.emoji) return _run(a).catchError((_) {});
    // 待つ前に、実行先を掴む(待っている間に行が別の投稿に使い回されても、押した投稿に付ける。D-282)。
    final shown = post;
    final handler = _onAction;
    final predicted = ref.read(reactionHistoryProvider.notifier).predictFor(shown);
    final reaction = predicted == null ? null : await _sendable(predicted);
    if (!mounted) return;
    if (reaction == null) return post.key == shown.key ? _openReactionPicker(a, anchor) : null;
    await handler(a, args: {'reaction': reaction}).then((_) => ref.read(reactionHistoryProvider.notifier).record(reaction)).catchError((_) {});
  }

  /// 予測を、このアカウントのサーバーで付けられる形に。付けられなければ null。
  Future<String?> _sendable(String predicted) async {
    final remote = remoteReactionName(predicted);
    if (remote == null) return predicted;
    final session = ref.read(sessionForAccountProvider(post.account.key)) ?? ref.read(currentSnsSessionProvider);
    try {
      return await session?.emojiUrl(remote) == null ? null : ':$remote:';
    } catch (_) {
      return null;
    }
  }

  /// リアクションの絵文字ピッカー。**実物のリアクションボタンにアンカー**する (D-065: 基本下付き・余白不足で上付き)。
  ///
  /// **開いた時点の投稿と実行先を掴んでおく** (D-282): ピッカーを開いている間に TL へ投稿が足されると、この行の State が別の投稿に
  /// 使い回されることがあり、選んだ瞬間の `post` / `_onAction` を読むと、隣の投稿にリアクションしてしまっていた。
  void _openReactionPicker(ActionDescriptor a, Rect anchor) {
    final target = post;
    final handler = _onAction;
    // 行が作り直されて(TL の取り直しなど)この State が捨てられたあとに選ばれても動くよう、ref もここで読んでおく。
    final history = ref.read(reactionHistoryProvider.notifier);
    openEmojiPicker(ref, closeOnPick: true, title: 'リアクション', column: fowColumnOf(context), anchor: anchor, accountKey: target.account.key,
        predictionContext: '${target.contentWarning ?? ''} ${target.body} ${target.quote?.body ?? ''}',
        existingReactions: target.reactions, onPick: (e) {
      handler(a, args: {'reaction': e}).then((_) => history.record(e)).catchError((_) {});
    });
  }

  ActionDescriptor? get _repostAction => widget.actions.where((a) => a.genreTag == 'Repost').firstOrNull;

  /// この投稿が**自分のリノート**として流れてきているか (D-276)。ここでだけ、リノートのバンドルが「リノートを取り消す」になる。
  bool get _canUndoRepost {
    final by = post.repostedBy;
    if (by == null || _repostAction == null) return false;
    final sessions = ref.read(sessionsProvider).value?.allSessions ?? const <AccountSession>[];
    // 名前の形(大文字小文字・@host)の違いは見ない (D-421)。
    // Bluesky は DID でも (D-423。ハンドルを変えたあとでも自分)。
    return sessions.any((s) => sameAccountIdentity(s.account, by.account)) || isOwnBlueskyId(sessions, by.id);
  }

  /// リノート / 引用に使うコピー (D-280)。いまのコピーのままなら null(↓ で選んでいる / 見えているのが 1 アカウントだけ /
  /// 自分のリノートの取り消し / 予測がいまのアカウント)。
  Post? _predictedCopy() {
    if (_actAs != null || widget.actionsFor == null || _canUndoRepost) return null;
    final copies = [widget.post, ...ref.read(postAlternatesProvider)[widget.post.key] ?? const <Post>[]];
    if (copies.length < 2) return null;
    final key = pickActingAccount(ref, widget.post, [for (final c in copies) c.account.key]);
    final copy = copies.where((c) => c.account.key == key).firstOrNull;
    return copy == null || copy.key == widget.post.key ? null : copy;
  }

  /// リノート/引用ノートの組み込みバンドル (D-039)。
  Future<void> _repostBundle(ActionDescriptor a, ActionState st, Rect anchor) async {
    // ドロップダウンはやめて、バンドル FOW に統一 (D-277)。
    // ボタンは入り切りにしない (D-274 → D-276): ふつうの投稿では、いつ押しても「リノート」(何度でも)。
    // 自分のリノートとして流れてきたタイルでだけ、1 つ目が「リノートを取り消す」になる。
    // どのアカウントでリノートするか (D-280): 同じ投稿が複数のアカウントに見えていて、↓ で選んでいなければ、予測したアカウントで。
    // だまって切り替えない: 別のアカウントになるときは、行の名前に「(@… で)」と出す。
    final target = _predictedCopy();
    final handler = target == null ? _onAction : widget.actionsFor!(target);
    final via = target == null ? '' : '(@${target.account.handle}@${target.account.instance} で)';
    // 名前はリテラルのまま持つ(RAi の操作リファレンスが、この文字列でボタンを探す)。
    const renoteLabel = 'リノート';
    const quoteLabel = '引用ノート';
    final picked = await showBundleMenuFow<String>(
      ref.read(overlayManagerProvider),
      id: 'actionbar.repost.${post.key}',
      title: a.label,
      anchor: anchor,
      column: fowColumnOf(context),
      items: [
        if (_canUndoRepost) const BundleMenuItem(value: 'undo', label: 'リノートを取り消す', icon: Icons.repeat, destructive: true) else BundleMenuItem(value: 'renote', label: '$renoteLabel$via', icon: Icons.repeat),
        BundleMenuItem(value: 'quote', label: '$quoteLabel$via', icon: Icons.format_quote),
      ],
    );
    if (!mounted) return;
    switch (picked) {
      case 'renote':
        await handler(a, args: const {'forceUndo': false}).catchError((_) {});
      case 'undo':
        await _onAction(a, args: const {'forceUndo': true}).catchError((_) {});
      case 'quote':
        if (!mounted) return;
        await showComposer(ref, ComposeQuote(target ?? post), column: fowColumnOf(context));
    }
  }

  /// アクションリスト(束ね)ボタン: タップでアイコンから出るバンドル FOW (D-210)。
  RasqActionBarItem _listItem(ActionListEntry entry) => RasqActionBarItem(
        id: 'list:${entry.list.id}',
        label: entry.list.name,
        icon: bundleIconOf(entry.list, entry.members),
        iconUrl: bundleIconUrlOf(entry.list),
        showCount: false,
        onAnchorTap: (anchor) => showActionBundleMenuFow(ref, anchor: anchor, entry: entry, column: fowColumnOf(context), onPick: (a) => _run(a).catchError((_) {})),
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

/// バンドルのアイコン (D-210): `member:<id>` はそのメンバーのアイコン、`material:<name>` は Material Icon、
/// 無指定 / 不明は apps。
IconData bundleIconOf(ActionListDef list, List<ActionDescriptor> members) {
  final spec = list.icon;
  if (spec == null) return Icons.apps;
  if (spec.startsWith('member:')) {
    final id = spec.substring('member:'.length);
    final m = members.where((a) => a.id == id).firstOrNull;
    return m == null ? Icons.apps : PostRow.iconFor(m.icon, Icons.apps);
  }
  if (spec.startsWith('material:')) {
    final name = spec.substring('material:'.length);
    return materialIconByName(name) ?? PostRow.iconFor(name, Icons.apps);
  }
  return Icons.apps;
}

/// バンドルのアイコンの描画 (D-212): 写真(`file:`)は画像、それ以外はアイコン。
Widget bundleIconWidget(ActionListDef list, List<ActionDescriptor> members, {required double size, Color? color}) {
  final url = bundleIconUrlOf(list);
  if (url != null) return rasqIconImage(url, size: size, fallback: bundleIconOf(list, members));
  return Icon(bundleIconOf(list, members), size: size, color: color);
}

/// `file:<path>`(写真)のときの画像。
Uri? bundleIconUrlOf(ActionListDef list) {
  final spec = list.icon;
  if (spec == null || !spec.startsWith('file:')) return null;
  return Uri.file(spec.substring('file:'.length));
}
