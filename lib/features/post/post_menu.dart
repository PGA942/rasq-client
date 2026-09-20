import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../backend/rasq_account_page_api.dart';
import '../clips/clip_picker.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/timeline_providers.dart';
import '../media/image_saver.dart';
import '../plugins/slot_plugins.dart';
import '../../shell/third_column.dart';
import 'share_fow.dart';

/// 投稿コンテキストメニュー(右上の `…` のみで出現 — ワイヤーフレーム注釈).
/// 自身: 詳細 / リンクをコピー / お気に入り / 削除. 他ユーザー: 詳細 / リンクをコピー /
/// お気に入り / フォロー(解除) / ミュート / ブロック / 報告. (プラグイン別項目は M3 で登録制に)
/// 全画面表示 (D-213): [media] を渡すと投稿のメニューに準拠しつつ「詳細」を消して「画像を保存」を足す。
/// 「リンクをコピー」は画像のリンク、「共有」の FOW は「内容をコピー」が「画像を保存」になる。
Future<void> showPostMenu(BuildContext context, WidgetRef ref, Post post, Rect anchor, {MediaItem? media}) async {
  final manager = ref.read(overlayManagerProvider);
  // RASQ の投稿 (D-276。全画面表示の … から来る): SNS の操作は効かないので、保存とリンクだけ。
  if (isRasqPost(post)) {
    final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, items: [
      if (media != null && media.type == MediaType.image) const RasqDropdownItem('画像を保存', 'saveImage'),
      const RasqDropdownItem('リンクをコピー', 'copy'),
    ]);
    if (pick == 'saveImage' && media != null) await saveMediaImage(ref, media);
    if (pick == 'copy') await Clipboard.setData(ClipboardData(text: '${post.url ?? media?.url ?? ''}'));
    return;
  }
  final s = ref.read(currentSnsSessionProvider);
  final viewer = ref.read(currentAccountProvider);
  final me = ref.read(currentUserProvider);
  if (s == null || viewer == null) return;
  final isMine = post.author.id == me.id || (post.author.handle == me.handle && post.author.account.instance == me.account.instance);
  final userKey = '${viewer.kind.name}:${viewer.instance}:${post.author.id}';
  final st = ref.read(followStateProvider.notifier).of(viewer.key, userKey);
  final fav = ref.read(actionStateProvider.notifier).of(post.key, 'favorite');

  final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, items: [
    if (media == null) const RasqDropdownItem('詳細', 'detail') else const RasqDropdownItem('画像を保存', 'saveImage'),
    const RasqDropdownItem('リンクをコピー', 'copy'),
    const RasqDropdownItem('共有', 'share'),
    const RasqDropdownItem('アクションバーを編集', 'editActions'),
    RasqDropdownItem(fav.done ? 'お気に入り解除' : 'お気に入り', 'favorite'),
    const RasqDropdownItem('クリップに追加', 'clip'),
    if (!isMine) RasqDropdownItem(st.following ? 'フォロー解除' : 'フォロー', 'follow'),
    if (!isMine) RasqDropdownItem(st.muted ? 'ミュート解除' : 'ミュート', 'mute', accent: true),
    if (!isMine) RasqDropdownItem(st.blocked ? 'ブロック解除' : 'ブロック', 'block', destructive: true),
    if (!isMine) const RasqDropdownItem('報告', 'report', destructive: true),
    if (isMine) const RasqDropdownItem('削除', 'delete', destructive: true),
  ]);
  if (pick == null || !context.mounted) return;
  final store = ref.read(followStateProvider.notifier);
  switch (pick) {
    case 'detail':
      context.pushPost(post);
    case 'saveImage':
      if (media != null) await saveMediaImage(ref, media);
    case 'copy':
      final url = media?.url ?? post.url ?? Uri.https(post.author.account.instance, '/notes/${post.id}');
      await Clipboard.setData(ClipboardData(text: url.toString()));
    case 'share':
      await showPostShareFow(ref, post, column: fowColumnOf(context), media: media);
    case 'editActions':
      // その投稿が流れてきたアカウントのバーを編集する (D-284)。全画面表示から開いたときも同じ。
      await showActionBarEditSheet(ref, accountKey: post.account.key);
    case 'favorite':
      final fa = s.actions.where((a) => a.id == 'favorite').firstOrNull;
      if (fa != null) await ref.read(timelineProvider(TimelineKind.home).notifier).perform(post, fa);
    case 'clip':
      await showAddToClipSheet(ref, post);
    case 'follow':
      store.apply(viewer.key, userKey, await s.setFollowing(post.author.id, !st.following));
    case 'mute':
      store.apply(viewer.key, userKey, await s.setMuted(post.author.id, !st.muted));
    case 'block':
      final ok = st.blocked || await manager.showAlert(id: 'post.block', title: '${post.author.displayName} をブロックしますか？', confirmText: 'ブロック', cancelText: 'キャンセル', destructive: true);
      if (ok) store.apply(viewer.key, userKey, await s.setBlocked(post.author.id, !st.blocked));
    case 'report':
      final ok = await manager.showAlert(id: 'post.report', title: 'この投稿を報告しますか？', message: 'サーバー管理者に報告します。', confirmText: '報告', cancelText: 'キャンセル', destructive: true);
      if (ok) await s.reportUser(post.author.id, 'Note: ${post.url ?? post.id}');
    case 'delete':
      final ok = await manager.showAlert(id: 'post.delete', title: '投稿を削除しますか？', message: 'この操作は取り消せません。', confirmText: '削除', cancelText: 'キャンセル', destructive: true);
      if (ok) {
        await s.deletePost(post.id);
        await ref.read(timelineProvider(TimelineKind.home).notifier).refresh();
      }
  }
}

/// 画像を保存して結果をスナックバーに出す (D-213)。
Future<void> saveMediaImage(WidgetRef ref, MediaItem media) async {
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  try {
    final path = await ref.read(imageSaverProvider)(media);
    messenger?.showSnackBar(SnackBar(content: Text('画像を保存しました: $path')));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('画像を保存できませんでした: $e')));
  }
}
