import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../app/navigation.dart';
import '../../l10n/l10n.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../compose/emoji_panel.dart';
import '../compose/emoji_picker_fow.dart';
import '../compose/compose_providers.dart';
import '../home/action_bar_config.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
import '../home/post_action_auto.dart';
import '../home/post_row.dart';
import '../plugins/slot_plugins.dart';
import '../post/share_fow.dart';
import '../vc/astell_post_share.dart';
import 'rasq_queue_prediction.dart';
import '../media/video_player.dart';
import '../../shell/third_column.dart';
import '../store/sticker_packs.dart';

/// RASQ の投稿のタイル (D-271 / S-022)。
///
/// 上: (リブロードの帯)/ アイコン / 表示名・@handle / 日付 / **…**(ほかの SNS と同じドロップダウン: リンクをコピー /
/// ブラウザで開く / 自分の投稿なら削除)。下のアクションバー: **返信 / リブロード (ReBroad、🔁) / キュー (Queue) / 共有**。
/// リブロードのボタンは、SNS のリノートと同じバンドル (D-276): 「リブロード / 引用」。リブロードは何度でもできる。
/// **自分のリブロードとして出ているタイル**では「リブロードを取り消す / 引用」になり、その 1 回だけを取り消す。
/// キュー = ストアでインストール(購入)した署名済みアセットパックの絵でのリアクション。付いているキューは、絵 + 件数のチップで出る
/// (絵はサーバーが配るので、そのパックを入れていなくても見える。チップを押すと、同じ絵を自分も付ける / 外す)。
class RasqPostTileView extends ConsumerWidget {
  const RasqPostTileView({super.key, required this.post, required this.onChanged, this.onOpen, this.focused = false, this.onReply, this.pinned = false, this.onTogglePin, this.onDelete});

  /// … の「削除」を呼び出し側で受ける(確かめも呼び出し側。Swing は Swing ごと消す、D-446)。null なら投稿を消す。
  final Future<void> Function()? onDelete;
  final RasqAccountPost post;

  /// 投稿が変わった / 消えた(呼び出し側が取り直す)。
  final VoidCallback onChanged;

  /// タイルのタップ(スレッドを開く)。null なら押せない。
  final VoidCallback? onOpen;

  /// スレッド画面の主役(本文を大きく)。
  final bool focused;

  /// 返信ボタンを、呼び出し側で受ける(投稿の詳細: 常駐の返信コンポーザーを呼び戻す。D-292)。null なら、返信のコンポーザーを開く。
  final VoidCallback? onReply;

  /// アカウントページで固定しているか (S-027)。
  final bool pinned;

  /// … のメニューの「固定する / 固定を外す」(D-423。自分のページの、固定できる投稿だけ)。null なら出さない。
  final Future<void> Function()? onTogglePin;

  void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function(RasqAccountPageApi api) action) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    final l10n = context.l10n;
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, l10n.profilePostLoginToUse);
    try {
      await action(api);
      // 自分のアカウントページも取り直す (D-277): スレッド画面からリブロード / 引用しても、投稿欄にすぐ出るように。
      final me = ref.read(orgateAccountProvider).value;
      if (me != null) ref.invalidate(rasqAccountPageProvider(me.handle));
      onChanged();
    } on OrgateException catch (e) {
      if (!context.mounted) return;
      _toast(context, switch (e.code.code) {
        '403' when e.message.contains('install') => l10n.profilePostErrorInstallPack,
        '403' => l10n.profilePostErrorForbidden,
        '409' when e.message.contains('rebroad') => l10n.profilePostErrorRebroadLimit,
        '409' => l10n.profilePostErrorReplyLimit,
        '404' => l10n.profilePostErrorGone,
        _ => l10n.profilePostErrorFailed(e.message),
      });
    }
  }

  Uri? _permalink(WidgetRef ref) {
    final central = ref.read(centralBaseUrlProvider);
    return central == null ? null : post.permalink(central);
  }

  Future<void> _more(BuildContext context, WidgetRef ref, Rect anchor, bool isMine) async {
    final l10n = context.l10n;
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'rasq.post.more', anchor: anchor, dense: true, items: [
      RasqDropdownItem(l10n.profilePostMenuReactions, 'reactions'),
      RasqDropdownItem(l10n.profilePostMenuCopyLink, 'copy'),
      RasqDropdownItem(l10n.profilePostMenuOpenBrowser, 'open'),
      RasqDropdownItem(l10n.profilePostMenuEditActions, 'editActions'),
      if (onTogglePin != null) RasqDropdownItem(pinned ? l10n.profilePostMenuUnpin : l10n.profilePostMenuPin, 'pin'),
      if (isMine) RasqDropdownItem(l10n.profilePostMenuDelete, 'delete', destructive: true),
    ]);
    if (!context.mounted || pick == null) return;
    final link = _permalink(ref);
    switch (pick) {
      case 'reactions':
        await context.push(Routes.rasqPostReactions(post.id));
      case 'copy':
        if (link == null) return;
        await Clipboard.setData(ClipboardData(text: link.toString()));
        if (context.mounted) _toast(context, l10n.profilePostLinkCopied);
      case 'editActions':
        // RASQ アカウントのバー(全画面 = Swing / 投稿)を編集する (D-446)。
        await showActionBarEditSheet(ref, column: fowColumnOf(context), rasq: true);
      case 'open':
        if (link != null) await launchUrl(link, mode: LaunchMode.externalApplication);
      case 'pin':
        await onTogglePin?.call();
      case 'delete':
        if (onDelete case final f?) return f();
        final ok = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.delete', title: l10n.profilePostDeleteTitle, message: l10n.profilePostDeleteMessage, confirmText: l10n.profilePostDeleteConfirm, cancelText: l10n.profilePostCancel, destructive: true);
        if (!ok || !context.mounted) return;
        await _run(context, ref, (api) => api.deletePost(post.id));
    }
  }

  /// 返信 (D-292): SNS の返信と同じコンポーザーで(投稿先は RASQ に固定。文字だけ、500 文字まで)。以前は、専用の簡易シートだった。
  Future<void> _reply(BuildContext context, WidgetRef ref) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, context.l10n.profilePostLoginToReply);
    if (onReply != null) return onReply!();
    final sent = await showComposer(ref, ComposeReply(post.toPost(central: ref.read(centralBaseUrlProvider))), column: fowColumnOf(context));
    if (sent != null) onChanged();
  }

  /// メディア: SNS の投稿と同じグリッド。タップで全画面表示、動画の再生ボタンで動画の FOW (D-276)。
  Widget? _media(BuildContext context, WidgetRef ref) {
    if (post.images.isEmpty) return null;
    final asPost = post.toPost(central: ref.read(centralBaseUrlProvider));
    return RasqMediaGrid(
      items: asPost.media,
      maxVisible: 6,
      onTapTile: (i) => context.openViewer(asPost, i),
      onPlayTile: (i) => showVideoFow(ref, asPost.media[i], post: asPost, column: fowColumnOf(context)),
    );
  }

  /// 本文 + 投票(+ 注釈つきのときはメディアも)。
  Widget _body(BuildContext context, WidgetRef ref) {
    final p = post.poll;
    final media = post.cw.isNotEmpty ? _media(context, ref) : null;
    final q = post.quote;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (post.body.isNotEmpty) _RasqBodyText(post: post, style: focused ? RasqTypography.body.copyWith(fontSize: 16) : RasqTypography.body),
      if (media != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: media),
      if (p != null)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.sm),
          child: RasqPollWidget(
            key: ValueKey('rasqPost.${post.id}.poll'),
            poll: Poll(
              options: [for (final c in p.choices) PollOption(text: c.text, votes: c.votes)],
              multiple: p.multiple,
              expiresAt: p.expiresAt,
              votedIndices: {for (var i = 0; i < p.choices.length; i++) if (p.choices[i].voted) i},
            ),
            // 選んだものを 1 つずつ送る(複数選択は選択肢ごとに 1 票)。
            onVote: p.expired
                ? null
                : (picked) => _run(context, ref, (api) async {
                      for (final i in picked) {
                        await api.vote(post.id, i);
                      }
                    }),
          ),
        ),
      if (q != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: _quote(context, q))
      else if (post.isQuote)
        Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(context.l10n.profilePostQuoteUnavailable, key: ValueKey('rasqPost.${post.id}.quoteGone'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
    ]);
  }

  /// キューのキー(絵文字ピッカー / リアクションのチップで使う 1 つの文字列)。
  static String queueKey(String? packId, String stickerId) => packId == null ? likeReaction : ':$packId|$stickerId:';

  /// いいね(パックを使わないキュー)のリアクション表記。
  static const likeReaction = '❤';

  /// リブロードのバンドル (D-276): ふつうのタイルでは「リブロード / 引用」(リブロードは何度でも)。
  /// 自分のリブロードとして出ているタイルでは「リブロードを取り消す / 引用」(その 1 回だけを取り消す)。
  Future<void> _rebroadBundle(BuildContext context, WidgetRef ref, Rect anchor, {required bool myRebroad}) async {
    final l10n = context.l10n;
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, l10n.profilePostLoginToRebroad);
    // SNS のリノートと同じく、ドロップダウンではなくバンドル FOW で出す (D-277)。
    final pick = await showBundleMenuFow<String>(
      ref.read(overlayManagerProvider),
      id: 'rasq.post.rebroad.${post.id}',
      title: l10n.profilePostRebroad,
      anchor: anchor,
      column: fowColumnOf(context),
      items: [
        if (myRebroad) BundleMenuItem(value: 'undo', label: l10n.profilePostRebroadUndo, icon: Icons.repeat, destructive: true) else BundleMenuItem(value: 'rebroad', label: l10n.profilePostRebroad, icon: Icons.repeat),
        BundleMenuItem(value: 'quote', label: l10n.profilePostQuote, icon: Icons.format_quote),
      ],
    );
    if (!context.mounted || pick == null) return;
    switch (pick) {
      case 'rebroad':
        await _run(context, ref, (api) => api.rebroad(post.id));
      case 'undo':
        final id = post.rebroadId;
        if (id != null) await _run(context, ref, (api) => api.deleteRebroad(id));
      case 'quote':
        if (post.visibility == 'followers') return _toast(context, l10n.profilePostQuoteFollowersOnly);
        // SNS の引用と同じコンポーザーを、RASQ 指定で開く(送ると、呼び出し側が取り直す)。
        await showComposer(ref, ComposeQuote(post.toPost()), rasqTarget: true, column: fowColumnOf(context));
        onChanged();
    }
  }

  /// プラグインのボタン (D-279): SNS の投稿と同じ `post.action`。投稿は SNS の投稿の形で渡し、アカウントは `rasq`。
  Future<void> _runPlugin(BuildContext context, WidgetRef ref, ActionDescriptor a) async {
    final pa = ref.read(pluginActionsProvider).where((x) => x.id == a.id).firstOrNull;
    if (pa == null) return;
    final asPost = post.toPost(central: ref.read(centralBaseUrlProvider));
    final column = fowColumnOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = await ref.read(slotPluginsProvider.notifier).postAction(
          pa.plugin,
          actionId: pa.decl.id,
          post: astellPostPayloadOf(asPost),
          account: _pluginAccount(ref),
          column: column,
          onComposerOpen: _composerOpenFor(ref, column),
        );
    if (message != null && message.isNotEmpty) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, Object?> _pluginAccount(WidgetRef ref) => {'sns': 'rasq', 'instance': rasqPostInstance, 'handle': ref.read(orgateAccountProvider).value?.handle ?? ''};

  /// プラグインが開くコンポーザーは、RASQ 指定で。
  void Function(String text, Uint8List? media, String? mime, String? name) _composerOpenFor(WidgetRef ref, int column) =>
      (text, media, mime, name) => showComposer(ref, const ComposeNormal(), initialText: text, column: column, rasqTarget: true, initialFiles: media == null ? null : [ComposerInitialFile(bytes: media, name: name ?? 'plugin.png', mimeType: mime)]);

  /// post.action の temp (契約 v0.14 §2.9、D-305): タイルが作られたら、自動実行できるボタンを投稿ごとに 1 回呼ぶ(RASQ の投稿も同じ)。
  void _scheduleAutoPluginActions(BuildContext context, WidgetRef ref, List<PluginAction> plugins) {
    if (!hasAutoPostActions(plugins)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final column = fowColumnOf(context);
      runAutoPostActions(
        ref,
        postKey: 'rasq:${post.id}',
        settingsKey: slotSettingsKeyFor(rasqPostConfigKey, ''),
        plugins: plugins,
        payload: astellPostPayloadOf(post.toPost(central: ref.read(centralBaseUrlProvider))),
        account: _pluginAccount(ref),
        column: column,
        onComposerOpen: _composerOpenFor(ref, column),
      );
    });
  }

  /// 引用の元: SNS の引用と同じ、埋め込みサイズのタイル。
  Widget _quote(BuildContext context, RasqAccountPost q) {
    final p = q.toPost();
    return RasqPostTile(
      key: ValueKey('rasqPost.${post.id}.quote'),
      variant: RasqPostTileVariant.embedded,
      author: p.author,
      createdAt: p.createdAt,
      content: Text(q.cw.isNotEmpty ? q.cw : q.body, style: RasqTypography.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis),
      media: q.cw.isEmpty && p.media.isNotEmpty ? RasqMediaGrid(items: p.media) : null,
      onTap: () => context.push(Routes.rasqPost(q.id)),
    );
  }

  /// キュー: **絵文字ピッカーの使い回し**(履歴 / 予測 / パックごとの省略表示 / 検索。D-273)。リアクションと同じく、ボタンに張り付いて出る。
  Future<void> _queue(BuildContext context, WidgetRef ref, Rect? anchor) => pickRasqQueue(context, ref, post, anchor: anchor, onRun: (f) => _run(context, ref, f));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RasqTokens.of(context);
    final l10n = context.l10n;
    final author = post.author;
    final me = ref.watch(orgateAccountProvider).value;
    final isMine = me != null && author != null && me.id == author.id;
    final mine = post.queues.where((q) => q.mine).firstOrNull;
    // 自分のリブロードとして出ているタイルか(ここでだけ、リブロードのボタンが「取り消す」になる。D-276)。
    final myRebroad = me != null && post.rebroadedBy?.id == me.id && post.rebroadId != null;
    UserSummary summary(RasqPostAuthor? a) => UserSummary(
          id: 'rasq:${a?.id ?? ''}',
          account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: a?.handle ?? ''),
          displayName: a?.label ?? '',
          avatarUrl: a?.avatarUrl,
        );

    // アクションバーの構成 (D-279): 内蔵の 返信 / リブロード / キュー + プラグインのボタン(`post.action`)。並びとバンドルは編集できる。
    final pluginActions = ref.watch(pluginActionsForProvider(rasqPostConfigKey));
    _scheduleAutoPluginActions(context, ref, pluginActions);
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(rasqPostConfigKey)),
      snsActions: rasqPostBuiltinActions,
      plugins: pluginActions,
      settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(rasqPostConfigKey, ''))),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);
    // キューの予測 (D-279): 付けていない投稿のボタンに、予測した絵を薄く出す。短押しでその絵を付ける(無ければピッカー)。
    final predicted = mine != null || post.likeOnly || me == null
        ? null
        : predictQueue(post, ownedPacks: {for (final p in ref.watch(stickerPacksProvider)) p.id}, recent: ref.watch(recentEmojiProvider), central: ref.watch(centralBaseUrlProvider));

    // いいねのみ (D-321): ❤ はチップに出さず、数をいいねのボタンに(絵のキューが残っていれば、それはチップのまま)。
    final chips = [for (final q in post.queues) if (!(post.likeOnly && q.like)) q];
    final likes = post.queues.where((q) => q.like).fold(0, (n, q) => n + q.count);

    Future<void> perform(ActionDescriptor a, Rect anchor) async {
      switch (a.id) {
        case rasqReplyActionId:
          return _reply(context, ref);
        case rasqRebroadActionId:
          return _rebroadBundle(context, ref, anchor, myRebroad: myRebroad);
        case rasqQueueActionId:
          if (mine != null) return _run(context, ref, (api) => api.setQueue(post.id, null));
          if (predicted != null) return _run(context, ref, (api) => api.setQueue(post.id, (packId: predicted.packId, stickerId: predicted.stickerId)));
          return _queue(context, ref, anchor);
        default:
          return _runPlugin(context, ref, a);
      }
    }

    RasqActionBarItem item(ActionDescriptor a) => switch (a.id) {
          rasqReplyActionId => RasqActionBarItem(id: 'reply', label: l10n.profilePostReply, icon: Icons.chat_bubble_outline, count: post.replyCount, onAnchorTap: (r) => perform(a, r)),
          // リブロード (D-276): SNS のリノートと同じバンドル(リブロード / 引用)。ふつうのタイルでは何度でもリブロードできる。
          // 自分のリブロードとして出ているタイルでは、済みの色になり、バンドルの 1 つ目が「リブロードを取り消す」になる。
          rasqRebroadActionId => RasqActionBarItem(
              id: 'rebroad',
              label: myRebroad ? l10n.profilePostRebroadUndo : l10n.profilePostRebroad,
              icon: Icons.repeat,
              doneIcon: Icons.repeat, // 完了アイコンが無いと、部品が済みのボタンを無効にする
              done: myRebroad,
              doneColor: tokens.link,
              count: post.rebroadCount + post.quoteCount,
              onAnchorTap: (r) => perform(a, r),
            ),
          rasqQueueActionId => RasqActionBarItem(
              id: 'queue',
              // いいねのみ (S-023) の投稿は、ボタンも ❤ に。いいねの数はチップではなくボタンに出す (D-321: SNS の「いいねのみ」と同じ)。
              label: post.likeOnly ? l10n.profilePostLike : l10n.profilePostQueue,
              icon: post.likeOnly ? Icons.favorite_border : Icons.add_reaction_outlined,
              doneIcon: post.likeOnly ? Icons.favorite : Icons.add_reaction,
              done: mine != null,
              doneColor: tokens.link,
              count: post.likeOnly ? likes : null,
              showCount: post.likeOnly,
              iconUrl: predicted?.url,
              mutedIcon: predicted != null,
              onAnchorTap: (r) => perform(a, r),
              onAnchorLongPress: (r) => _queue(context, ref, r),
            ),
          _ => RasqActionBarItem(id: a.id, label: a.label, icon: PostRow.iconFor(a.icon, Icons.extension_outlined), showCount: false, onAnchorTap: (r) => perform(a, r)),
        };

    // SNS の投稿と同じタイル(L2 の RasqPostTile)に載せる: ヘッダー / … / 本文 / メディア / リアクションのチップ / アクションバー。
    return KeyedSubtree(
      key: ValueKey('rasqPost.${post.id}'),
      child: RasqPostTile(
        author: summary(author),
        createdAt: post.createdAt ?? DateTime.now(),
        // 帯: リブロード(RASQ の言い方で出す。部品の既定は「リノート」)> 返信の印。
        bannerIcon: post.rebroadedBy != null ? Icons.repeat : (post.isReply && !focused ? Icons.reply : null),
        bannerText: post.rebroadedBy != null ? l10n.profilePostRebroadedBy(post.rebroadedBy!.label) : (post.isReply && !focused ? (post.replyTo == null ? l10n.profilePostReplyToDeleted : l10n.profilePostReply) : null),
        onTap: onOpen,
        onAuthorTap: author == null ? null : () => context.pushRasqAccount(author.handle),
        // … = ほかの SNS の投稿と同じドロップダウン(削除はこの中)。
        onMore: (anchor) => _more(context, ref, anchor, isMine),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 注釈 (CW) つきは、注釈だけ見せて、中身は押すまで畳む(SNS の投稿と同じ)。
          if (post.cw.isNotEmpty) _CwFold(cw: post.cw, child: _body(context, ref))
          else
            _body(context, ref),
          // 付いているキュー = リアクションのチップ(絵 + 件数。自分のものはハイライト)。押すと、同じ絵を自分も付ける / 外す。
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.sm),
              child: RasqReactionChips(
                reactions: {for (final q in chips) queueKey(q.packId, q.stickerId): q.count},
                emojiUrls: {for (final q in post.queues) if (q.url != null) queueKey(q.packId, q.stickerId): q.url!},
                myReaction: mine == null ? null : queueKey(mine.packId, mine.stickerId),
                onTap: (r) {
                  final isMineChip = mine != null && queueKey(mine.packId, mine.stickerId) == r;
                  final parts = r.replaceAll(':', '').split('|');
                  if (isMineChip) {
                    _run(context, ref, (api) => api.setQueue(post.id, null));
                  } else if (r == likeReaction) {
                    _run(context, ref, (api) => api.like(post.id));
                  } else if (parts.length == 2) {
                    _run(context, ref, (api) => api.setQueue(post.id, (packId: parts[0], stickerId: parts[1])));
                  }
                },
              ),
            ),
        ]),
        // 注釈つきのときは、メディアも畳みの中(_body)に入れる。
        media: post.cw.isNotEmpty ? null : _media(context, ref),
        // アクションバー: 返信 / リブロード (ReBroad) / キュー (Queue) + 共有。キューは、付けていれば押すと外す、長押しでピッカー(Misskey のリアクションと同じ)。
        actionBar: Builder(
          builder: (bar) => RasqActionBar(
            // 並び / バンドル / プラグインのボタンは、SNS の投稿バーと同じ仕組み (D-279。構成は `rasq:post`)。
            items: [
              for (final e in entries)
                switch (e) {
                  SingleActionEntry() => item(e.action),
                  ActionListEntry() => RasqActionBarItem(
                      id: 'list:${e.list.id}',
                      label: e.list.name,
                      icon: bundleIconOf(e.list, e.members),
                      iconUrl: bundleIconUrlOf(e.list),
                      showCount: false,
                      onAnchorTap: (anchor) => showActionBundleMenuFow(ref, anchor: anchor, entry: e, column: fowColumnOf(context), onPick: (a) => perform(a, anchor)),
                    ),
                },
            ],
            trailing: [
              RasqActionButton.icon(
                key: ValueKey('rasqPost.${post.id}.share'),
                icon: Icons.ios_share,
                tooltip: l10n.profilePostShare,
                // SNS の投稿と同じ共有 FOW (D-279。リンク / 内容のコピー、引用、DM、共有プラグイン)。
                onTap: () => showPostShareFow(ref, post.toPost(central: ref.read(centralBaseUrlProvider)), column: fowColumnOf(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 注釈 (CW) の畳み: 注釈と「もっと見る」→ 押すと中身。
class _CwFold extends StatefulWidget {
  const _CwFold({required this.cw, required this.child});
  final String cw;
  final Widget child;
  @override
  State<_CwFold> createState() => _CwFoldState();
}

class _CwFoldState extends State<_CwFold> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.cw, style: RasqTypography.body),
        TextButton(
          key: const ValueKey('rasqPost.cw.toggle'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => setState(() => _open = !_open),
          child: Text(_open ? context.l10n.profilePostCwHide : context.l10n.profilePostCwShow),
        ),
        if (_open) widget.child,
      ]);
}

/// 本文 (S-026): メンション(`@handle`。投稿した時点で実在したアカウントだけ)はリンクになり、押すとそのアカウントのページへ。
class _RasqBodyText extends StatefulWidget {
  const _RasqBodyText({required this.post, required this.style});
  final RasqAccountPost post;
  final TextStyle style;
  @override
  State<_RasqBodyText> createState() => _RasqBodyTextState();
}

class _RasqBodyTextState extends State<_RasqBodyText> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    if (post.mentions.isEmpty) return Text(post.body, style: widget.style);
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final link = RasqTokens.of(context).link;
    return Text.rich(
      key: ValueKey('rasqPost.${post.id}.body'),
      TextSpan(style: widget.style, children: [
        for (final (text, handle) in splitMentions(post.body, [for (final m in post.mentions) m.handle]))
          if (handle == null)
            TextSpan(text: text)
          else
            TextSpan(text: text, style: TextStyle(color: link), recognizer: (() {
              final t = TapGestureRecognizer()..onTap = () => context.pushRasqAccount(handle);
              _taps.add(t);
              return t;
            })()),
      ]),
    );
  }
}

/// RASQ の投稿へのキュー(ピッカーから絵を選ぶ、D-273)。投稿のタイルと Swing の返信の欄 (D-389) で共通。
/// [onRun] = API を呼んで結果を反映する(呼ぶ側の再読み込みつき)。
Future<void> pickRasqQueue(BuildContext context, WidgetRef ref, RasqAccountPost post, {Rect? anchor, required Future<void> Function(Future<RasqAccountPost> Function(RasqAccountPageApi api)) onRun}) async {
  void toast(String m) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m)));
  final l10n = context.l10n;
  if (ref.read(orgateAccountProvider).value == null) return toast(l10n.profilePostLoginToQueue);
  // いいねのみ (S-023): ピッカーは出さず、いいねを付ける。
  if (post.likeOnly) return onRun((api) => api.like(post.id));
  await ref.read(stickerPacksProvider.notifier).ready;
  if (!context.mounted) return;
  final packs = ref.read(stickerPacksProvider);
  if (packs.isEmpty) {
    final go = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.noPacks', title: l10n.profilePostNoPacksTitle, message: l10n.profilePostNoPacksMessage, confirmText: l10n.profilePostNoPacksStore, cancelText: l10n.profilePostClose);
    if (go && context.mounted) context.push(Routes.store);
    return;
  }
  await openEmojiPicker(
    ref,
    title: l10n.profilePostQueue,
    closeOnPick: true,
    anchor: anchor,
    predictionContext: post.body,
    existingReactions: {for (final q in post.queues) if (!q.like) '${q.packId}|${q.stickerId}': q.count},
    stickers: [
      for (final pack in packs)
        for (final s in pack.stickers) EmojiPanelSticker(key: '${pack.id}|${s.id}', group: pack.name, label: s.label, tags: s.tags, file: s.file),
    ],
    onPick: (key) {
      final parts = key.split('|');
      if (parts.length != 2 || !context.mounted) return;
      onRun((api) => api.setQueue(post.id, (packId: parts[0], stickerId: parts[1])));
    },
  );
}

/// 全画面の上に置く RASQ の投稿のアクション (D-445: Swing のビューワーの上)。全画面表示のアクションバー(D-212 / D-214)と同じ、
/// 暗い丸の 40px のボタンで、並び / バンドル / プラグインのボタンは投稿のバー(`rasq:post`)の構成のまま。
/// キューは押すと いいね(付けていれば外す)、長押しで絵を選ぶ。最後の「…」は投稿のメニュー(リアクションを表示 / リンクをコピー /
/// ブラウザで開く / アクションバーを編集 / 自分のものは削除。共有と保存は無し)。
class RasqPostOverlayActions extends ConsumerWidget {
  const RasqPostOverlayActions({super.key, required this.post, required this.onChanged, this.onReply, this.onDelete});
  final RasqAccountPost post;
  final VoidCallback onChanged;

  /// … の「削除」(D-446: Swing は Swing ごと消す)。null なら投稿を消す。
  final Future<void> Function()? onDelete;

  /// 返信のボタン。null なら返信のコンポーザーを開く。
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = RasqPostTileView(post: post, onChanged: onChanged, onReply: onReply, onDelete: onDelete);
    final me = ref.watch(orgateAccountProvider).value;
    final isMine = me != null && post.author != null && me.id == post.author!.id;
    final mine = post.queues.where((q) => q.mine).firstOrNull;
    // 構成は RASQ の全画面アクションバー (D-446: SNS の全画面アクションバーと同じ扱い。投稿のバーとは別に並べ替えられる)。
    final pluginActions = ref.watch(pluginActionsForProvider(rasqViewerConfigKey));
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(rasqViewerConfigKey)),
      snsActions: rasqPostBuiltinActions,
      plugins: pluginActions,
      settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(rasqViewerConfigKey, ''))),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);

    Future<void> perform(ActionDescriptor a, Rect anchor) async {
      switch (a.id) {
        case rasqReplyActionId:
          // 呼び出し側の返信(Swing は下の FOW のコンポーザー。ログインはそちらで見る)。
          if (onReply case final f?) return f();
          return view._reply(context, ref);
        case rasqRebroadActionId:
          return view._rebroadBundle(context, ref, anchor, myRebroad: false);
        case rasqQueueActionId:
          if (mine != null) return view._run(context, ref, (api) => api.setQueue(post.id, null));
          return view._run(context, ref, (api) => api.like(post.id));
        default:
          return view._runPlugin(context, ref, a);
      }
    }

    Rect anchorOf(BuildContext c) {
      final box = c.findRenderObject() as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    Widget circle(Widget child) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: child);

    Widget single(ActionDescriptor a) => Builder(builder: (bctx) {
          final queue = a.id == rasqQueueActionId;
          final icon = switch (a.id) {
            rasqReplyActionId => Icons.chat_bubble_outline,
            rasqRebroadActionId => Icons.repeat,
            rasqQueueActionId => mine != null ? Icons.favorite : (post.likeOnly ? Icons.favorite_border : Icons.add_reaction_outlined),
            _ => PostRow.iconFor(a.icon, Icons.extension_outlined),
          };
          return GestureDetector(
            onLongPress: queue ? () => view._queue(context, ref, anchorOf(bctx)) : null,
            child: circle(RasqIconButton(
              key: ValueKey('overlay.action.${a.id}'),
              icon: icon,
              color: queue && mine != null ? RasqTokens.of(context).link : Colors.white,
              tooltip: queue ? context.l10n.profilePostOverlayQueueTooltip(a.label) : a.label,
              onPressed: () => perform(a, anchorOf(bctx)),
            )),
          );
        });

    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final e in entries) ...[
        const SizedBox(width: 2),
        switch (e) {
          SingleActionEntry() => single(e.action),
          ActionListEntry() => Builder(
              builder: (bctx) => circle(Tooltip(
                message: e.list.name,
                child: InkResponse(
                  key: ValueKey('overlay.action.list:${e.list.id}'),
                  radius: 22,
                  onTap: () => showActionBundleMenuFow(ref, anchor: anchorOf(bctx), entry: e, column: fowColumnOf(context), onPick: (a) => perform(a, anchorOf(bctx))),
                  child: SizedBox(width: 40, height: 40, child: Center(child: bundleIconWidget(e.list, e.members, size: 22, color: Colors.white))),
                ),
              )),
            ),
        },
      ],
      const SizedBox(width: 2),
      Builder(
        builder: (bctx) => circle(RasqIconButton(
          key: const ValueKey('overlay.action.more'),
          icon: Icons.more_horiz,
          color: Colors.white,
          tooltip: context.l10n.profilePostMenu,
          onPressed: () => view._more(context, ref, anchorOf(bctx), isMine),
        )),
      ),
    ]);
  }
}
