import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../../text/inline_spans.dart';
import 'dm_providers.dart';

/// DMホーム (全て / フォロー中): アイテム行コンポーネント(アイコン+右上テキスト+右下テキスト+`>`).
class DmScreen extends ConsumerWidget {
  const DmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final rooms = ref.watch(dmRoomsProvider);
    final tabs = [const RasqTabItem('全て'), const RasqTabItem('フォロー中')];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqNotificationHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Row(children: [
            Expanded(child: RasqTabs(items: tabs, showChevron: false)),
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'DM設定'),
          ]),
          const Padding(padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm), child: RasqSearchBar()),
          Expanded(
            child: TabBarView(children: [
              _RoomList(rooms: rooms, onRefresh: () => ref.refresh(dmRoomsProvider.future)),
              const RasqEmptyView(title: 'フォロー中のDMはありません', hint: 'フィルタは M2'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.rooms, required this.onRefresh});
  final AsyncValue<List<DmRoom>> rooms;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => rooms.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: onRefresh, retryLabel: '再読み込み'),
        data: (list) => RefreshIndicator(
          onRefresh: onRefresh,
          child: list.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), RasqEmptyView(title: 'DMはありません', hint: 'ダイレクト投稿(限定公開)がここに並びます')])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => _RoomRow(room: list[i], onTap: () => context.pushDmRoom(list[i])),
                ),
        ),
      );
}

/// アイテム行コンポーネント (DM・フォロワー一覧・ミュート一覧・通知で共用予定).
class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.onTap});
  final DmRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = room.lastPost;
    final mine = last != null && last.author.id != room.peer.id;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: room.unreadCount > 0 ? scheme.primaryContainer.withValues(alpha: 0.25) : null,
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
        child: Row(children: [
          RasqAvatar(imageUrl: room.peer.avatarUrl, size: RasqSizes.avatarLg, presence: room.peer.presence, fallbackLabel: room.peer.displayName),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(room.displayTitle, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (room.kind == DmRoomKind.chat) const Padding(padding: EdgeInsets.only(left: 6), child: RasqPill(label: 'Chat', outlined: true)),
              ]),
              const SizedBox(height: 2),
              if (last != null)
                RasqRichText(
                  [if (mine) const RasqTextSpan('あなた: ', bold: true), ...InlineSpans.parse(last.body.isEmpty ? (last.media.isNotEmpty ? '[メディア]' : '') : last.body)],
                  style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ]),
          ),
          const SizedBox(width: RasqSpacing.sm),
          if (last != null) RasqTimestamp(last.createdAt),
          Icon(Icons.chevron_right, color: scheme.onSurface),
        ]),
      ),
    );
  }
}
