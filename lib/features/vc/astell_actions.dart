import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import 'astell_bookmarks.dart';
import 'astell_fows.dart';
import 'astell_links.dart';
import 'astell_models.dart';
import 'astell_providers.dart';
import 'astell_tile.dart';

/// ルームのタイル/FOW から使う共通アクション (D-159/D-160): 投稿で共有、
/// ブックマーク、開始通知、… メニュー、TL 上のタイル。

/// 投稿コンポーザーへリンクを転送して共有する (D-159)。
Future<void> shareAstellRoom(BuildContext context, WidgetRef ref, AstellRoom room) async {
  await showComposer(ref, const ComposeNormal(), initialText: astellShareText(room, astellRoomLink(room)));
}

Future<void> copyAstellRoomLink(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: astellRoomLink(room)));
  messenger?.showSnackBar(const SnackBar(content: Text('リンクをコピーしました')));
}

/// ブックマークの切替 + スナックバー。タイルは切替で消えることがある(ブックマーク
/// 画面の帯)ので、メッセンジャーは先に取っておく。
Future<void> bookmarkAstellRoom(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final saved = await toggleAstellBookmark(ref, room);
  messenger?.showSnackBar(SnackBar(content: Text(saved ? 'ブックマークに保存しました' : 'ブックマークから削除しました')));
}

/// 開始通知の切替 + スナックバー。
Future<void> remindAstellRoom(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final res = await toggleAstellReminder(ref, room);
  final msg = switch (res) {
    AstellReminderResult.registered => '${formatAstellSchedule(room.scheduledAt!)} に通知します',
    AstellReminderResult.removed => '通知を解除しました',
    AstellReminderResult.unavailable => 'この端末では通知を登録できませんでした',
    AstellReminderResult.notScheduled => '開催予定のないルームです',
  };
  messenger?.showSnackBar(SnackBar(content: Text(msg)));
}

/// 「見てみる」/「戻る」(D-160): 参加中のルームならルーム FOW へ戻る、そうでなければ参加 FOW。
Future<void> openAstellRoomTile(BuildContext context, WidgetRef ref, AstellRoom room) async {
  if (ref.read(astellSessionProvider)?.room.id == room.id) {
    await openAstellRoomFow(context, ref);
  } else {
    await openAstellPreviewFow(context, ref, room);
  }
}

/// タイルの … メニュー(VC ホームと TL で共通)。自分がホストのルーム (D-164) は
/// 共有 / リンク / ブックマーク / 今すぐ開催(予約) / 参加(戻る) / 終了する。
Future<void> showAstellTileMenu(BuildContext context, WidgetRef ref, AstellRoom room, Rect anchor) async {
  final manager = ref.read(overlayManagerProvider);
  final following = ref.read(astellFollowingProvider).value?.contains(room.ownerId) ?? false;
  final bookmarked = ref.read(astellBookmarkedProvider(room.id));
  final reminded = ref.read(astellRemindedProvider(room.id));
  final mine = room.ownerId == ref.read(astellMyAccountIdProvider);
  final joined = ref.read(astellSessionProvider)?.room.id == room.id;
  final pick = await manager.showDropdown<String>(id: 'astell.tile.more', anchor: anchor, dense: true, items: [
    const RasqDropdownItem('投稿で共有', 'share'),
    const RasqDropdownItem('リンクをコピー', 'copy'),
    RasqDropdownItem(bookmarked ? 'ブックマークから削除' : 'ブックマークに保存', 'bookmark'),
    if (!mine && room.isScheduled) RasqDropdownItem(reminded ? '開始通知を解除' : '開始を通知', 'remind'),
    if (mine && room.isScheduled && !joined) const RasqDropdownItem('今すぐ開催する', 'start'),
    if (mine) RasqDropdownItem(joined ? 'ルームへ戻る' : '参加する', 'open'),
    if (mine) const RasqDropdownItem('終了する', 'close', destructive: true),
    if (!mine) RasqDropdownItem(following ? 'ホストのフォローを解除' : 'ホストをフォロー', 'follow'),
    if (!mine) const RasqDropdownItem('ミュート', 'mute'),
    if (!mine) const RasqDropdownItem('報告', 'report', destructive: true),
  ]);
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case 'share':
      await shareAstellRoom(context, ref, room);
    case 'copy':
      await copyAstellRoomLink(context, ref, room);
    case 'bookmark':
      await bookmarkAstellRoom(context, ref, room);
    case 'remind':
      await remindAstellRoom(context, ref, room);
    case 'start':
      // オーナーが接続した時点で開催になる (S-011)。
      await ref.read(astellSessionProvider.notifier).join(room);
      ref.invalidate(astellHomeProvider);
      if (context.mounted) await openAstellRoomFow(context, ref);
    case 'open':
      await openAstellRoomTile(context, ref, room);
    case 'close':
      await closeAstellRoom(context, ref, room);
    case 'follow':
      await ref.read(astellSessionProvider.notifier).follow(room.ownerId, !following);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(following ? '${room.ownerDisplayName} のフォローを解除しました' : '${room.ownerDisplayName} をフォローしました')));
    case 'report':
      await showAstellReportSheet(context, ref, targetAccountId: room.ownerId, roomId: room.id, what: 'ルーム「${room.title}」');
    default:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${room.title}」の操作($pick)は M5 後段で入ります')));
  }
}

/// 自分のルームを終了する (D-164): 確認シート → 参加中なら退出 → close → ホーム更新。
Future<void> closeAstellRoom(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final manager = ref.read(overlayManagerProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await manager.showBottomSheet<bool>(
    id: 'astell.tile.close',
    title: 'ルームを終了',
    confirmText: '終了する',
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.page),
      child: Text(room.isScheduled ? '「${room.title}」の予約を取り消します。ブックマークや開始通知を登録した人には届きません。' : '「${room.title}」を終了します。参加中のメンバーは退出になります。', style: RasqTypography.body),
    ),
  );
  if (ok != true) return;
  try {
    if (ref.read(astellSessionProvider)?.room.id == room.id) await ref.read(astellSessionProvider.notifier).leave();
    await ref.read(astellClientProvider).closeRoom(room.id);
    ref.invalidate(astellHomeProvider);
    ref.invalidate(astellRoomProvider(room.id));
    messenger?.showSnackBar(SnackBar(content: Text(room.isScheduled ? '「${room.title}」の予約を取り消しました' : '「${room.title}」を終了しました')));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('終了できませんでした: $e')));
  }
}

/// ブックマーク/通知/見てみる(戻る)を配線したタイル (D-160)。VC ホームの帯、
/// TL の投稿内、ブックマーク画面で共通。
class AstellRoomTile extends ConsumerWidget {
  const AstellRoomTile({super.key, required this.room});
  final AstellRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(astellSessionProvider.select((s) => s?.room.id == room.id));
    return AstellTile(
      room: room,
      openLabel: joined ? '戻る' : '見てみる',
      onOpen: () => openAstellRoomTile(context, ref, room),
      onMore: (rect) => showAstellTileMenu(context, ref, room, rect),
      bookmarked: ref.watch(astellBookmarkedProvider(room.id)),
      onBookmark: () => bookmarkAstellRoom(context, ref, room),
      reminded: ref.watch(astellRemindedProvider(room.id)),
      onRemind: room.isScheduled ? () => remindAstellRoom(context, ref, room) : null,
    );
  }
}

/// TL に流れてきた投稿の AsTell リンク → タイル (D-160)。本文の下に固定高で描く。
/// ルームが取れない(消えた/未接続)ときは何も出さない。
class AstellPostTile extends ConsumerWidget {
  const AstellPostTile({super.key, required this.roomId, this.height = 216});
  final String roomId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(astellRoomProvider(roomId));
    return room.when(
      loading: () => const SizedBox(height: 48, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, _) => const SizedBox.shrink(),
      data: (r) => r == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: SizedBox(height: height, child: AstellRoomTile(key: ValueKey('astell.post.tile.$roomId'), room: r)),
            ),
    );
  }
}

/// ホームヘッダーの AsTell 帯 (D-163): 参加中 / フォロー中のホストのルーム / 招待されているルームのバンドルを横に並べ、
/// タップで参加 FOW(参加中ならルーム FOW)。何も無ければ何も出さない。
/// D-377: 帯を囲んでいた大きな角丸四角形は無くし、バンドルを少し大きく(28 → [size] 34)。前後に [leading] / [trailing]
/// (Swing を作るボタン / Swing を出している人)を並べられる。
class AstellHeaderStrip extends ConsumerWidget {
  const AstellHeaderStrip({super.key, this.max = 4, this.size = 34, this.leading = const [], this.trailing = const [], this.showTitles = false});
  final int max;

  /// バンドルの下辺にルーム名(D-379: ヘッダーを畳んでいないとき。D-388: 下に並べるのをやめ、アイコンの下辺に地の色の角丸で載せる)。
  final bool showTitles;
  final double size;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(astellHomeProvider).value;
    final session = ref.watch(astellSessionProvider);
    final rooms = <AstellRoom>[];
    final seen = <String>{};
    void add(AstellRoom r) {
      if (seen.add(r.id) && r.isOpen) rooms.add(r);
    }
    if (session != null) add(session.room);
    for (final r in home?.following ?? const <AstellRoom>[]) {
      add(r);
    }
    for (final r in home?.invited ?? const <AstellRoom>[]) {
      add(r);
    }
    if (rooms.isEmpty && leading.isEmpty && trailing.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      key: const ValueKey('astell.header.strip'),
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final w in leading) ...[w, const SizedBox(width: 8)],
        // D-379: 並べきれない数の「+N」は出さない(横にスクロールすると続きがある)。
        for (final r in rooms.take(max)) ...[
          Tooltip(
            message: '${r.ownerDisplayName}: ${r.title}',
            child: RasqAvatarBundle(
              user: r.owner,
              count: r.peerCount,
              faces: r.bundleFaces,
              live: r.live,
              size: size,
              onTap: () => openAstellRoomTile(context, ref, r),
              // D-388: ヘッダーを畳んでいないときは、アイコンの下辺に名前を載せる(LIVE は赤地)。
              caption: showTitles ? r.title : null,
              captionKey: ValueKey('astell.header.title.${r.id}'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        for (final w in trailing) ...[w, const SizedBox(width: 8)],
      ]),
    );
  }
}
