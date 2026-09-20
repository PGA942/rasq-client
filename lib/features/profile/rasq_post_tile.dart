import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../compose/emoji_panel.dart';
import '../compose/emoji_picker_fow.dart';
import '../store/sticker_packs.dart';

/// RASQ の投稿のタイル (D-271 / S-022)。
///
/// 上: (リブローの帯)/ アイコン / 表示名・@handle / 日付 / **…**(ほかの SNS と同じドロップダウン: リンクをコピー /
/// ブラウザで開く / 自分の投稿なら削除)。下のアクションバー: **返信 / リブロー (ReBroad、🔁) / キュー (Queue) / 共有**。
/// キュー = ストアでインストール(購入)した署名済みアセットパックの絵でのリアクション。付いているキューは、絵 + 件数のチップで出る
/// (絵はサーバーが配るので、そのパックを入れていなくても見える。チップを押すと、同じ絵を自分も付ける / 外す)。
class RasqPostTileView extends ConsumerWidget {
  const RasqPostTileView({super.key, required this.post, required this.onChanged, this.onOpen, this.focused = false});
  final RasqAccountPost post;

  /// 投稿が変わった / 消えた(呼び出し側が取り直す)。
  final VoidCallback onChanged;

  /// タイルのタップ(スレッドを開く)。null なら押せない。
  final VoidCallback? onOpen;

  /// スレッド画面の主役(本文を大きく)。
  final bool focused;

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
      onChanged();
    } on OrgateException catch (e) {
      if (!context.mounted) return;
      _toast(context, switch (e.code.code) {
        '403' when e.message.contains('install') => 'このパックをストアからインストールすると、この絵でキューできます',
        '403' => 'この投稿には操作できません',
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
      if (isMine) const RasqDropdownItem('削除', 'delete', destructive: true),
    ]);
    if (!context.mounted || pick == null) return;
    final link = _permalink(ref);
    switch (pick) {
      case 'copy':
        if (link == null) return;
        await Clipboard.setData(ClipboardData(text: link.toString()));
        if (context.mounted) _toast(context, 'リンクをコピーしました');
      case 'open':
        if (link != null) await launchUrl(link, mode: LaunchMode.externalApplication);
      case 'delete':
        final ok = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.delete', title: '投稿を削除', message: 'この投稿と、付いている画像を削除します。元に戻せません。', confirmText: '削除する', cancelText: 'キャンセル', destructive: true);
        if (!ok || !context.mounted) return;
        await _run(context, ref, (api) => api.deletePost(post.id));
    }
  }

  Future<void> _reply(BuildContext context, WidgetRef ref) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインすると返信できます');
    final body = TextEditingController();
    final ok = await ref.read(overlayManagerProvider).showBottomSheet<bool>(
          id: 'rasq.post.reply',
          title: '@${post.author?.handle ?? ''} に返信',
          confirmText: '返信',
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqInput(key: const ValueKey('rasqReply.body'), controller: body, hintText: '返信を書く(文字だけ、500 文字まで)', maxLines: 4, autofocus: true),
              const SizedBox(height: RasqSpacing.xs),
              Text('返信は RASQ の公開ページに出ます。', style: RasqTypography.caption.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ]),
          ),
        );
    final text = body.text.trim();
    if (ok != true || text.isEmpty || !context.mounted) return;
    await _run(context, ref, (api) => api.reply(post.id, text));
  }

  /// キューのキー(絵文字ピッカー / リアクションのチップで使う 1 つの文字列)。
  static String queueKey(String packId, String stickerId) => '$packId|$stickerId';

  /// キュー: **絵文字ピッカーの使い回し**(履歴 / 予測 / パックごとの省略表示 / 検索。D-273)。リアクションと同じく、ボタンに張り付いて出る。
  Future<void> _queue(BuildContext context, WidgetRef ref, Rect? anchor) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインするとキューできます');
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
      existingReactions: {for (final q in post.queues) queueKey(q.packId, q.stickerId): q.count},
      stickers: [
        for (final pack in packs)
          for (final s in pack.stickers) EmojiPanelSticker(key: queueKey(pack.id, s.id), group: pack.name, label: s.label, tags: s.tags, file: s.file),
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
    UserSummary summary(RasqPostAuthor? a) => UserSummary(
          id: 'rasq:${a?.id ?? ''}',
          account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: a?.handle ?? ''),
          displayName: a?.label ?? '',
          avatarUrl: a?.avatarUrl,
        );
    Rect rectOf(BuildContext c) {
      final box = c.findRenderObject() as RenderBox?;
      return box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
    }

    // SNS の投稿と同じタイル(L2 の RasqPostTile)に載せる: ヘッダー / … / 本文 / メディア / リアクションのチップ / アクションバー。
    return KeyedSubtree(
      key: ValueKey('rasqPost.${post.id}'),
      child: RasqPostTile(
        author: summary(author),
        createdAt: post.createdAt ?? DateTime.now(),
        // 帯: リブロー(RASQ の言い方で出す。部品の既定は「リノート」)> 返信の印。
        bannerIcon: post.rebroadedBy != null ? Icons.repeat : (post.isReply && !focused ? Icons.reply : null),
        bannerText: post.rebroadedBy != null ? '${post.rebroadedBy!.label} がリブロー' : (post.isReply && !focused ? (post.replyTo == null ? '削除された投稿への返信' : '返信') : null),
        onTap: onOpen,
        onAuthorTap: author == null ? null : () => context.push(Routes.rasqAccount(author.handle)),
        // … = ほかの SNS の投稿と同じドロップダウン(削除はこの中)。
        onMore: (anchor) => _more(context, ref, anchor, isMine),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.body.isNotEmpty) Text(post.body, style: focused ? RasqTypography.body.copyWith(fontSize: 16) : RasqTypography.body),
          // 付いているキュー = リアクションのチップ(絵 + 件数。自分のものはハイライト)。押すと、同じ絵を自分も付ける / 外す。
          if (post.queues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.sm),
              child: RasqReactionChips(
                reactions: {for (final q in post.queues) ':${queueKey(q.packId, q.stickerId)}:': q.count},
                emojiUrls: {for (final q in post.queues) ':${queueKey(q.packId, q.stickerId)}:': q.url},
                myReaction: mine == null ? null : ':${queueKey(mine.packId, mine.stickerId)}:',
                onTap: (r) {
                  final parts = r.replaceAll(':', '').split('|');
                  if (parts.length != 2) return;
                  final isMineChip = mine != null && mine.packId == parts[0] && mine.stickerId == parts[1];
                  _run(context, ref, (api) => api.setQueue(post.id, isMineChip ? null : (packId: parts[0], stickerId: parts[1])));
                },
              ),
            ),
        ]),
        media: post.images.isEmpty ? null : RasqMediaGrid(items: [for (final i in post.images) MediaItem(id: i.id, type: MediaType.image, url: i.url, width: i.width == 0 ? null : i.width, height: i.height == 0 ? null : i.height)]),
        // アクションバー: 返信 / リブロー (ReBroad) / キュー (Queue) + 共有。キューは、付けていれば押すと外す、長押しでピッカー(Misskey のリアクションと同じ)。
        actionBar: Builder(
          builder: (bar) => RasqActionBar(
            items: [
              RasqActionBarItem(id: 'reply', label: '返信', icon: Icons.chat_bubble_outline, count: post.replyCount, onTap: () => _reply(context, ref)),
              RasqActionBarItem(id: 'rebroad', label: post.rebroaded ? 'リブローをやめる' : 'リブロー', icon: Icons.repeat, done: post.rebroaded, doneColor: tokens.link, count: post.rebroadCount, onTap: () => _run(context, ref, (api) => api.setRebroad(post.id, on: !post.rebroaded))),
              RasqActionBarItem(
                id: 'queue',
                label: 'キュー',
                icon: Icons.add_reaction_outlined,
                doneIcon: Icons.add_reaction,
                done: mine != null,
                doneColor: tokens.link,
                showCount: false,
                onTap: () => mine != null ? _run(context, ref, (api) => api.setQueue(post.id, null)) : _queue(context, ref, rectOf(bar)),
                onLongPress: () => _queue(context, ref, rectOf(bar)),
              ),
            ],
            trailing: [
              RasqActionButton.icon(
                key: ValueKey('rasqPost.${post.id}.share'),
                icon: Icons.ios_share,
                tooltip: '共有',
                onTap: () async {
                  final link = _permalink(ref);
                  if (link == null) return;
                  await Clipboard.setData(ClipboardData(text: link.toString()));
                  if (context.mounted) _toast(context, 'リンクをコピーしました');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

