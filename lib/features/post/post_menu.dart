import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../l10n/l10n.dart';
import '../clips/clip_picker.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/timeline_providers.dart';
import '../media/image_saver.dart';
import '../settings/settings_dsl.dart';
import '../plugins/slot_plugins.dart';
import '../../shell/third_column.dart';
import 'share_fow.dart';

/// 投稿コンテキストメニュー(右上の `…` のみで出現 — ワイヤーフレーム注釈).
/// 自身: 詳細 / リンクをコピー / お気に入り / 削除. 他ユーザー: 詳細 / リンクをコピー /
/// お気に入り / フォロー(解除) / ミュート / ブロック / 報告. (プラグイン別項目は M3 で登録制に)
/// 全画面表示 (D-213): [media] を渡すと投稿のメニューに準拠しつつ「詳細」を消して「画像を保存」を足す。
/// 「リンクをコピー」は画像のリンク、「共有」の FOW は「内容をコピー」が「画像を保存」になる。
/// [pin] (D-423) = アカウントページの固定 (S-027)。自分のページの、固定できる投稿にだけ渡す(「固定する / 固定を外す」が出る)。
///
/// [tetherIcon] (D-513) = 押した「…」のボタンのアイコン。渡すとメニューを**ボタンにつながった形**で出す(TL の投稿の右上の「…」)。
/// 全画面表示のボタンからは渡さない(暗いビューワーの上の、ボタンから離れたメニューのまま)。
Future<void> showPostMenu(BuildContext context, WidgetRef ref, Post post, Rect anchor, {MediaItem? media, PostMenuPin? pin, Widget? tetherIcon}) async {
  final manager = ref.read(overlayManagerProvider);
  final l10n = context.l10n;
  // RASQ の投稿 (D-276。全画面表示の … から来る): SNS の操作は効かないので、保存とリンクだけ。
  if (isRasqPost(post)) {
    final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, tetherAnchorChild: tetherIcon, items: [
      if (media != null && isSavableMedia(media)) RasqDropdownItem(saveMediaLabel(media), 'saveImage'),
      RasqDropdownItem(l10n.postMenuCopyLink, 'copy'),
    ]);
    if (pick == 'saveImage' && media != null) await saveMediaImage(ref, media);
    if (pick == 'copy') await Clipboard.setData(ClipboardData(text: '${post.url ?? media?.url ?? ''}'));
    return;
  }
  // 投稿が流れてきたアカウントで決める (D-155 / D-421)。総合表示(RASQ アカウントを選んでいる間)やアカウントページでは、
  // 現在のアカウントと違うアカウントの投稿が並ぶ。現在のアカウントで比べていたので、ほかのアカウントの自分の投稿に
  // 「フォロー / ミュート / ブロック / 報告」が出て、削除が出なかった(削除やフォローも現在のアカウントのセッションに飛んでいた)。
  final s = ref.read(sessionForAccountProvider(post.account.key));
  final viewer = ref.read(viewerForAccountProvider(post.account.key));
  final me = ref.read(currentUserProvider);
  // アカウントページの、この端末にログインの無い SNS の投稿 (D-423): SNS の操作は効かない(ほかのアカウントのセッションに
  // 縮退してしまう)ので、リンクと固定だけ。
  final loggedIn = (ref.read(sessionsProvider).value?.allSessions ?? const <AccountSession>[]).any((x) => accountServes(x.account, post.account.kind.name, post.account.instance));
  if (pin != null && (s == null || viewer == null || !loggedIn)) {
    final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, tetherAnchorChild: tetherIcon, items: [
      RasqDropdownItem(l10n.postMenuCopyLink, 'copy'),
      RasqDropdownItem(pin.pinned ? l10n.postMenuUnpin : l10n.postMenuPin, 'pin'),
    ]);
    if (pick == 'copy' && post.url != null) await Clipboard.setData(ClipboardData(text: '${post.url}'));
    if (pick == 'pin') await pin.toggle();
    return;
  }
  if (s == null || viewer == null) return;
  final isMine = isViewerSelf(post.author, viewer, me: me, viewerId: ref.read(viewerUserIdProvider(post.account.key)));
  final userKey = followUserKey(viewer, post.author.id);
  final st = ref.read(followStateProvider.notifier).of(viewer.key, userKey);
  final fav = ref.read(actionStateProvider.notifier).of(post.key, 'favorite');

  final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, tetherAnchorChild: tetherIcon, items: [
    if (media == null) RasqDropdownItem(l10n.postMenuDetail, 'detail') else if (isSavableMedia(media)) RasqDropdownItem(saveMediaLabel(media), 'saveImage'),
    RasqDropdownItem(l10n.postMenuCopyLink, 'copy'),
    RasqDropdownItem(l10n.postMenuShare, 'share'),
    RasqDropdownItem(l10n.postMenuEditActionBar, 'editActions'),
    RasqDropdownItem(fav.done ? l10n.postMenuUnfavorite : l10n.postMenuFavorite, 'favorite'),
    RasqDropdownItem(l10n.postMenuAddToClip, 'clip'),
    if (pin != null) RasqDropdownItem(pin.pinned ? l10n.postMenuUnpin : l10n.postMenuPin, 'pin'),
    if (!isMine) RasqDropdownItem(st.following ? l10n.postMenuUnfollow : l10n.postMenuFollow, 'follow'),
    if (!isMine) RasqDropdownItem(st.muted ? l10n.postMenuUnmute : l10n.postMenuMute, 'mute', accent: true),
    if (!isMine) RasqDropdownItem(st.blocked ? l10n.postMenuUnblock : l10n.postMenuBlock, 'block', destructive: true),
    if (!isMine) RasqDropdownItem(l10n.postMenuReport, 'report', destructive: true),
    if (isMine) RasqDropdownItem(l10n.postMenuDelete, 'delete', destructive: true),
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
    case 'pin':
      await pin?.toggle();
    case 'follow':
      store.apply(viewer.key, userKey, await s.setFollowing(post.author.id, !st.following));
    case 'mute':
      store.apply(viewer.key, userKey, await s.setMuted(post.author.id, !st.muted));
    case 'block':
      final ok = st.blocked || await manager.showAlert(id: 'post.block', title: l10n.postBlockConfirmTitle(post.author.displayName), confirmText: l10n.postMenuBlock, cancelText: l10n.postCancel, destructive: true);
      if (ok) store.apply(viewer.key, userKey, await s.setBlocked(post.author.id, !st.blocked));
    case 'report':
      final ok = await manager.showAlert(id: 'post.report', title: l10n.postReportConfirmTitle, message: l10n.postReportConfirmMessage, confirmText: l10n.postMenuReport, cancelText: l10n.postCancel, destructive: true);
      if (ok) await s.reportUser(post.author.id, 'Note: ${post.url ?? post.id}');
    case 'delete':
      final ok = await manager.showAlert(id: 'post.delete', title: l10n.postDeleteConfirmTitle, message: l10n.postDeleteConfirmMessage, confirmText: l10n.postMenuDelete, cancelText: l10n.postCancel, destructive: true);
      if (ok) {
        await s.deletePost(post.id);
        await ref.read(timelineProvider(TimelineKind.home).notifier).refresh();
      }
  }
}

/// 投稿のメニューの「固定する / 固定を外す」(D-423。アカウントページの固定、S-027)。[pinned] = いま固定しているか。
typedef PostMenuPin = ({bool pinned, Future<void> Function() toggle});

/// 保存できる添付か(画像 / GIF / 動画)。
bool isSavableMedia(MediaItem m) => m.type == MediaType.image || m.type == MediaType.gif || m.type == MediaType.video;

/// メニューの文言(「画像を保存」/「動画を保存」)。
String saveMediaLabel(MediaItem m) => appL10n.postSaveMediaLabel(_mediaKind(m));

/// 文言の select に渡す添付の種類(`video` / `image`)。
String _mediaKind(MediaItem m) => m.type == MediaType.video ? 'video' : 'image';

/// 保存先を選ぶシートの id (D-334)。
const mediaSaveAskId = 'media.save.ask';

/// 画像 / 動画を保存して結果をスナックバーに出す (D-213 → D-334)。保存先は設定(`media.save`)、「保存するたびに選ぶ」なら
/// シートで選ぶ(「次からもこの保存先にする」で設定に残せる)。選べる先が 1 つだけの端末では聞かない。
Future<void> saveMediaImage(WidgetRef ref, MediaItem media) async {
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  final l10n = appL10n;
  final kind = _mediaKind(media);
  var dest = resolveMediaSaveDestination(ref.read(mediaSaveDestinationProvider), ref.read(mediaSaveDestinationsHereProvider));
  if (dest == null) {
    final manager = ref.read(overlayManagerProvider);
    var remember = false;
    dest = await manager.showBottomSheet<MediaSaveDestination>(
      id: mediaSaveAskId,
      title: l10n.postSaveDestinationTitle(kind),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (final d in ref.read(mediaSaveDestinationsHereProvider))
            RasqListTile(
              key: ValueKey('media.save.${d.name}'),
              title: d.label,
              subtitle: d == MediaSaveDestination.photos ? l10n.postSaveToPhotosSubtitle : (Theme.of(ctx).platform == TargetPlatform.iOS ? l10n.postSaveToFilesIosSubtitle : l10n.postSaveToFilesSubtitle),
              leading: Icon(d == MediaSaveDestination.photos ? Icons.photo_library_outlined : Icons.folder_outlined),
              onTap: () async {
                if (remember) await ref.read(settingsAreaProvider(mediaSaveSettingsArea).notifier).set('destination', d.name);
                manager.close(mediaSaveAskId, result: d);
              },
            ),
          RasqSwitchListTile(key: const ValueKey('media.save.remember'), title: l10n.postSaveRememberTitle, subtitle: l10n.postSaveRememberSubtitle, value: remember, onChanged: (v) => setState(() => remember = v)),
        ]),
      ),
    );
    if (dest == null) return;
  }
  try {
    final message = await ref.read(imageSaverProvider)(media, dest);
    if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.postSaveFailed(kind, e is StateError ? e.message : '$e'))));
  }
}
