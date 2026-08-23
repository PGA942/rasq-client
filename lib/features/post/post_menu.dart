import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../home/timeline_providers.dart';

/// 投稿コンテキストメニュー(右上の `…` のみで出現 — ワイヤーフレーム注釈).
/// 自身: 詳細 / リンクをコピー / お気に入り / 削除. 他ユーザー: 詳細 / リンクをコピー /
/// お気に入り / フォロー(解除) / ミュート / ブロック / 報告. (プラグイン別項目は M3 で登録制に)
Future<void> showPostMenu(BuildContext context, WidgetRef ref, Post post, Rect anchor) async {
  final manager = ref.read(overlayManagerProvider);
  final s = ref.read(currentSnsSessionProvider);
  final viewer = ref.read(currentAccountProvider);
  final me = ref.read(currentUserProvider);
  if (s == null || viewer == null) return;
  final isMine = post.author.id == me.id || (post.author.handle == me.handle && post.author.account.instance == me.account.instance);
  final userKey = '${viewer.kind.name}:${viewer.instance}:${post.author.id}';
  final st = ref.read(followStateProvider.notifier).of(viewer.key, userKey);
  final fav = ref.read(actionStateProvider.notifier).of(post.key, 'favorite');

  final pick = await manager.showDropdown<String>(id: 'post.menu', anchor: anchor, items: [
    const RasqDropdownItem('詳細', 'detail'),
    const RasqDropdownItem('リンクをコピー', 'copy'),
    RasqDropdownItem(fav.done ? 'お気に入り解除' : 'お気に入り', 'favorite'),
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
    case 'copy':
      final url = post.url ?? Uri.https(post.author.account.instance, '/notes/${post.id}');
      await Clipboard.setData(ClipboardData(text: url.toString()));
    case 'favorite':
      final fa = s.actions.where((a) => a.id == 'favorite').firstOrNull;
      if (fa != null) await ref.read(timelineProvider(TimelineKind.home).notifier).perform(post, fa);
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
