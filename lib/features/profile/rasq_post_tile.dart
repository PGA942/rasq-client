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
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../compose/emoji_panel.dart';
import '../compose/emoji_picker_fow.dart';
import '../compose/compose_providers.dart';
import '../home/action_bar_config.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
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
  const RasqPostTileView({super.key, required this.post, required this.onChanged, this.onOpen, this.focused = false, this.onReply});
  final RasqAccountPost post;

  /// 投稿が変わった / 消えた(呼び出し側が取り直す)。
  final VoidCallback onChanged;

  /// タイルのタップ(スレッドを開く)。null なら押せない。
  final VoidCallback? onOpen;

  /// スレッド画面の主役(本文を大きく)。
  final bool focused;

  /// 返信ボタンを、呼び出し側で受ける(投稿の詳細: 常駐の返信コンポーザーを呼び戻す。D-292)。null なら、返信のコンポーザーを開く。
  final VoidCallback? onReply;

  void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function(RasqAccountPageApi api) action) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインすると使えます');
    try {
      await action(api);
      // 自分のアカウントページも取り直す (D-277): スレッド画面からリブロード / 引用しても、投稿欄にすぐ出るように。
      final me = ref.read(orgateAccountProvider).value;
      if (me != null) ref.invalidate(rasqAccountPageProvider(me.handle));
      onChanged();
    } on OrgateException catch (e) {
      if (!context.mounted) return;
      _toast(context, switch (e.code.code) {
        '403' when e.message.contains('install') => 'このパックをストアからインストールすると、この絵でキューできます',
        '403' => 'この投稿には操作できません',
        '409' when e.message.contains('rebroad') => 'この投稿は、これ以上リブロードできません',
        '409' => '返信は 100 件までです。古い返信を消してください',
        '404' => 'この投稿 / 絵は、もうありません',
        _ => '失敗しました: ${e.message}',
      });
    }
  }

  Uri? _permalink(WidgetRef ref) {
    final central = ref.read(centralBaseUrlProvider);
    return central == null ? null : post.permalink(central);
  }

  Future<void> _more(BuildContext context, WidgetRef ref, Rect anchor, bool isMine) async {
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'rasq.post.more', anchor: anchor, dense: true, items: [
      const RasqDropdownItem('リンクをコピー', 'copy'),
      const RasqDropdownItem('ブラウザで開く', 'open'),
      const RasqDropdownItem('アクションバーを編集', 'editActions'),
      if (isMine) const RasqDropdownItem('削除', 'delete', destructive: true),
    ]);
    if (!context.mounted || pick == null) return;
    final link = _permalink(ref);
    switch (pick) {
      case 'copy':
        if (link == null) return;
        await Clipboard.setData(ClipboardData(text: link.toString()));
        if (context.mounted) _toast(context, 'リンクをコピーしました');
      case 'editActions':
        await showActionBarEditSheet(ref, column: fowColumnOf(context), surfaces: const [ActionBarSurface.rasqPost]);
      case 'open':
        if (link != null) await launchUrl(link, mode: LaunchMode.externalApplication);
      case 'delete':
        final ok = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.delete', title: '投稿を削除', message: 'この投稿と、付いている画像を削除します。元に戻せません。', confirmText: '削除する', cancelText: 'キャンセル', destructive: true);
        if (!ok || !context.mounted) return;
        await _run(context, ref, (api) => api.deletePost(post.id));
    }
  }

  /// 返信 (D-292): SNS の返信と同じコンポーザーで(投稿先は RASQ に固定。文字だけ、500 文字まで)。以前は、専用の簡易シートだった。
  Future<void> _reply(BuildContext context, WidgetRef ref) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインすると返信できます');
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
        Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text('引用元の投稿は見られません', key: ValueKey('rasqPost.${post.id}.quoteGone'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
    ]);
  }

  /// キューのキー(絵文字ピッカー / リアクションのチップで使う 1 つの文字列)。
  static String queueKey(String? packId, String stickerId) => packId == null ? likeReaction : ':$packId|$stickerId:';

  /// いいね(パックを使わないキュー)のリアクション表記。
  static const likeReaction = '❤';

  /// リブロードのバンドル (D-276): ふつうのタイルでは「リブロード / 引用」(リブロードは何度でも)。
  /// 自分のリブロードとして出ているタイルでは「リブロードを取り消す / 引用」(その 1 回だけを取り消す)。
  Future<void> _rebroadBundle(BuildContext context, WidgetRef ref, Rect anchor, {required bool myRebroad}) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインするとリブロードできます');
    // SNS のリノートと同じく、ドロップダウンではなくバンドル FOW で出す (D-277)。
    final pick = await showBundleMenuFow<String>(
      ref.read(overlayManagerProvider),
      id: 'rasq.post.rebroad.${post.id}',
      title: 'リブロード',
      anchor: anchor,
      column: fowColumnOf(context),
      items: [
        if (myRebroad) const BundleMenuItem(value: 'undo', label: 'リブロードを取り消す', icon: Icons.repeat, destructive: true) else const BundleMenuItem(value: 'rebroad', label: 'リブロード', icon: Icons.repeat),
        const BundleMenuItem(value: 'quote', label: '引用', icon: Icons.format_quote),
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
        if (post.visibility == 'followers') return _toast(context, 'フォロワー限定の投稿は引用できません');
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
          account: {'sns': 'rasq', 'instance': rasqPostInstance, 'handle': ref.read(orgateAccountProvider).value?.handle ?? ''},
          column: column,
          // プラグインが開くコンポーザーは、RASQ 指定で。
          onComposerOpen: (text, media, mime, name) => showComposer(ref, const ComposeNormal(), initialText: text, column: column, rasqTarget: true, initialFiles: media == null ? null : [ComposerInitialFile(bytes: media, name: name ?? 'plugin.png', mimeType: mime)]),
        );
    if (message != null && message.isNotEmpty) messenger?.showSnackBar(SnackBar(content: Text(message)));
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
  Future<void> _queue(BuildContext context, WidgetRef ref, Rect? anchor) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインするとキューできます');
    // いいねのみ (S-023): ピッカーは出さず、いいねを付ける。
    if (post.likeOnly) return _run(context, ref, (api) => api.like(post.id));
    await ref.read(stickerPacksProvider.notifier).ready;
    if (!context.mounted) return;
    final packs = ref.read(stickerPacksProvider);
    if (packs.isEmpty) {
      final go = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.noPacks', title: 'アセットパックがありません', message: 'キューは、ストアでインストール(購入)したアセットパックの絵でのリアクションです。', confirmText: 'ストアで探す', cancelText: '閉じる');
      if (go && context.mounted) context.push(Routes.store);
      return;
    }
    await openEmojiPicker(
      ref,
      title: 'キュー',
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
        _run(context, ref, (api) => api.setQueue(post.id, (packId: parts[0], stickerId: parts[1])));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RasqTokens.of(context);
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
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(rasqPostConfigKey)),
      snsActions: rasqPostBuiltinActions,
      plugins: ref.watch(pluginActionsForProvider(rasqPostConfigKey)),
      settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(rasqPostConfigKey, ''))),
    );
    final entries = merged.config.apply(merged.actions);
    // キューの予測 (D-279): 付けていない投稿のボタンに、予測した絵を薄く出す。短押しでその絵を付ける(無ければピッカー)。
    final predicted = mine != null || post.likeOnly || me == null
        ? null
        : predictQueue(post, ownedPacks: {for (final p in ref.watch(stickerPacksProvider)) p.id}, recent: ref.watch(recentEmojiProvider), central: ref.watch(centralBaseUrlProvider));

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
          rasqReplyActionId => RasqActionBarItem(id: 'reply', label: '返信', icon: Icons.chat_bubble_outline, count: post.replyCount, onAnchorTap: (r) => perform(a, r)),
          // リブロード (D-276): SNS のリノートと同じバンドル(リブロード / 引用)。ふつうのタイルでは何度でもリブロードできる。
          // 自分のリブロードとして出ているタイルでは、済みの色になり、バンドルの 1 つ目が「リブロードを取り消す」になる。
          rasqRebroadActionId => RasqActionBarItem(
              id: 'rebroad',
              label: myRebroad ? 'リブロードを取り消す' : 'リブロード',
              icon: Icons.repeat,
              doneIcon: Icons.repeat, // 完了アイコンが無いと、部品が済みのボタンを無効にする
              done: myRebroad,
              doneColor: tokens.link,
              count: post.rebroadCount + post.quoteCount,
              onAnchorTap: (r) => perform(a, r),
            ),
          rasqQueueActionId => RasqActionBarItem(
              id: 'queue',
              // いいねのみ (S-023) の投稿は、ボタンも ❤ に。
              label: post.likeOnly ? 'いいね' : 'キュー',
              icon: post.likeOnly ? Icons.favorite_border : Icons.add_reaction_outlined,
              doneIcon: post.likeOnly ? Icons.favorite : Icons.add_reaction,
              done: mine != null,
              doneColor: tokens.link,
              showCount: false,
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
        bannerText: post.rebroadedBy != null ? '${post.rebroadedBy!.label} がリブロード' : (post.isReply && !focused ? (post.replyTo == null ? '削除された投稿への返信' : '返信') : null),
        onTap: onOpen,
        onAuthorTap: author == null ? null : () => context.push(Routes.rasqAccount(author.handle)),
        // … = ほかの SNS の投稿と同じドロップダウン(削除はこの中)。
        onMore: (anchor) => _more(context, ref, anchor, isMine),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 注釈 (CW) つきは、注釈だけ見せて、中身は押すまで畳む(SNS の投稿と同じ)。
          if (post.cw.isNotEmpty) _CwFold(cw: post.cw, child: _body(context, ref))
          else
            _body(context, ref),
          // 付いているキュー = リアクションのチップ(絵 + 件数。自分のものはハイライト)。押すと、同じ絵を自分も付ける / 外す。
          if (post.queues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.sm),
              child: RasqReactionChips(
                reactions: {for (final q in post.queues) queueKey(q.packId, q.stickerId): q.count},
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
                tooltip: '共有',
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
          child: Text(_open ? '隠す' : 'もっと見る'),
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
              final t = TapGestureRecognizer()..onTap = () => context.push(Routes.rasqAccount(handle));
              _taps.add(t);
              return t;
            })()),
      ]),
    );
  }
}
