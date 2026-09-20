import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
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

  Future<void> _queue(BuildContext context, WidgetRef ref) async {
    if (ref.read(orgateAccountProvider).value == null) return _toast(context, 'RASQ アカウントにログインするとキューできます');
    final mine = post.queues.where((q) => q.mine).firstOrNull;
    final pick = await showRasqQueuePicker(ref, current: mine == null ? null : (packId: mine.packId, stickerId: mine.stickerId));
    if (pick == null || !context.mounted) return;
    await _run(context, ref, (api) => api.setQueue(post.id, pick.remove ? null : (packId: pick.packId, stickerId: pick.stickerId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final author = post.author;
    final me = ref.watch(orgateAccountProvider).value;
    final isMine = me != null && author != null && me.id == author.id;
    final d = post.createdAt?.toLocal();
    return InkWell(
      key: ValueKey('rasqPost.${post.id}'),
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.sm, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.rebroadedBy != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 2),
              child: Row(children: [Icon(Icons.repeat, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Flexible(child: Text('${post.rebroadedBy!.label} がリブロー', style: caption, overflow: TextOverflow.ellipsis))]),
            ),
          if (post.isReply && !focused)
            Padding(padding: const EdgeInsets.only(left: 44, bottom: 2), child: Row(children: [Icon(Icons.reply, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text(post.replyTo == null ? '削除された投稿への返信' : '返信', style: caption)])),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: author == null ? null : () => context.push(Routes.rasqAccount(author.handle)),
              child: RasqAvatar(imageUrl: author?.avatarUrl, size: 36, fallbackLabel: author?.label ?? '?'),
            ),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(author?.label ?? '', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Flexible(child: Text('@${author?.handle ?? ''}', style: caption, overflow: TextOverflow.ellipsis)),
                  const Spacer(),
                  if (d != null) Text('${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}', style: caption),
                  // … = ほかの SNS の投稿と同じドロップダウン(削除はこの中)。
                  Builder(
                    builder: (b) => RasqIconButton(
                      icon: Icons.more_horiz,
                      size: 18,
                      tooltip: '投稿の操作',
                      onPressed: () {
                        final box = b.findRenderObject() as RenderBox;
                        _more(context, ref, box.localToGlobal(Offset.zero) & box.size, isMine);
                      },
                    ),
                  ),
                ]),
                if (post.body.isNotEmpty) Text(post.body, style: focused ? RasqTypography.body : RasqTypography.bodySmall),
                if (post.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.sm),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final i in post.images)
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(i.url.toString(), width: post.images.length == 1 ? 260 : 126, height: post.images.length == 1 ? 180 : 126, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 126, height: 126))),
                    ]),
                  ),
                // 付いているキュー(絵 + 件数)。押すと、同じ絵を自分も付ける / 外す。
                if (post.queues.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.sm),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final q in post.queues)
                        Material(
                          color: q.mine ? tokens.link.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: q.mine ? tokens.link : Colors.transparent)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('rasqPost.${post.id}.queue.${q.packId}.${q.stickerId}'),
                            onTap: () => _run(context, ref, (api) => api.setQueue(post.id, q.mine ? null : (packId: q.packId, stickerId: q.stickerId))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Image.network(q.url.toString(), width: 22, height: 22, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, size: 18)),
                                const SizedBox(width: 4),
                                Text('${q.count}', style: caption),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                // ── アクションバー: 返信 / リブロー / キュー / 共有 ──
                Row(children: [
                  RasqActionButton.iconCount(key: ValueKey('rasqPost.${post.id}.reply'), icon: Icons.chat_bubble_outline, count: post.replyCount, tooltip: '返信', onTap: () => _reply(context, ref)),
                  const SizedBox(width: RasqSpacing.md),
                  RasqActionButton.iconCount(
                    key: ValueKey('rasqPost.${post.id}.rebroad'),
                    icon: Icons.repeat,
                    count: post.rebroadCount,
                    done: post.rebroaded,
                    doneColor: tokens.link,
                    tooltip: post.rebroaded ? 'リブローをやめる' : 'リブロー',
                    onTap: () => _run(context, ref, (api) => api.setRebroad(post.id, on: !post.rebroaded)),
                  ),
                  const SizedBox(width: RasqSpacing.md),
                  RasqActionButton.icon(key: ValueKey('rasqPost.${post.id}.queue'), icon: Icons.add_reaction_outlined, doneIcon: Icons.add_reaction, done: post.queues.any((q) => q.mine), doneColor: tokens.link, tooltip: 'キュー', onTap: () => _queue(context, ref)),
                  const SizedBox(width: RasqSpacing.md),
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
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// キューの絵を選ぶ: インストール済みのアセットパックのステッカー。[current] = いま付けているもの(「外す」を出す)。
Future<({String packId, String stickerId, bool remove})?> showRasqQueuePicker(WidgetRef ref, {({String packId, String stickerId})? current}) async {
  await ref.read(stickerPacksProvider.notifier).ready;
  final packs = ref.read(stickerPacksProvider);
  final manager = ref.read(overlayManagerProvider);
  const id = 'rasq.post.queuePicker';
  return manager.showFow<({String packId, String stickerId, bool remove})>(
    id: id,
    spec: FowSpec(title: 'キュー', cancelText: '閉じる', initialHeightFactor: 0.5, minHeightFactor: 0.25, maxHeightFactor: 0.85, maxWidth: 560),
    semanticsLabel: 'キューの絵を選ぶ',
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.md), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('ストアでインストール(購入)したアセットパックの絵で、リアクションします。1 つの投稿に 1 つです。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        if (current != null)
          RasqListTile(key: const ValueKey('rasqQueue.remove'), title: 'いまのキューを外す', chevron: false, onTap: () => manager.close(id, result: (packId: current.packId, stickerId: current.stickerId, remove: true))),
        if (packs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('アセットパックが入っていません。', key: const ValueKey('rasqQueue.empty'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () {
                  manager.close(id);
                  ref.read(routerProvider).push(Routes.store);
                },
                child: const Text('ストアで探す'),
              ),
            ]),
          ),
        for (final pack in packs) ...[
          RasqSectionHeader(title: pack.name),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in pack.stickers)
                Tooltip(
                  message: s.label ?? s.id,
                  child: InkWell(
                    key: ValueKey('rasqQueue.${pack.id}.${s.id}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => manager.close(id, result: (packId: pack.id, stickerId: s.id, remove: false)),
                    child: Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: current != null && current.packId == pack.id && current.stickerId == s.id ? RasqTokens.of(context).link : scheme.outlineVariant),
                      ),
                      child: Image.file(File(s.file), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined)),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ]);
    },
  );
}
