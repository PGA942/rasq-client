import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../../shell/scroll_memory.dart';
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
            // DM のカスタマイズ (D-127): メインページの設定 = カスタム未設定の
            // 全 DM ページに適用される共通設定(tl.dm)。
            RasqIconButton(icon: Icons.settings, size: 20, onPressed: () => context.push(Routes.tlConfig('tl.dm')), tooltip: 'DM設定'),
          ]),
          const Padding(padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm), child: RasqSearchBar()),
          Expanded(
            child: TabBarView(children: [
              _RoomList(rooms: rooms, onRefresh: () => ref.refresh(dmRoomsProvider.future)),
              const RasqEmptyView(title: 'フォロー中のDMはありません', hint: 'フィルタは M2'),
            ]),
          ),
        ]),
        // 新規メッセージ (D-045/D-046): 投稿と同じ + ボタン。ユーザーを選んで
        // コンポーザー付きのルームを開く(既存ルームが無くても始められる)。
        floatingActionButton: FloatingActionButton(
        // 画面ごとに違う Hero のタグ (D-374): 既定のタグは、タブの画面が同じルームに並ぶと重なる。
        heroTag: 'fab.dm',
          onPressed: () => _startNewDm(context, ref),
          tooltip: '新規メッセージ',
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

Future<void> _startNewDm(BuildContext context, WidgetRef ref) =>
    startNewDm(manager: ref.read(overlayManagerProvider), router: GoRouter.of(context), rooms: () => ref.read(dmRoomsProvider).value ?? const <DmRoom>[]);

/// 新規メッセージ: 相手を選ぶシート → ルーム(コンポーザー付き)。DM の + と、ホーム画面のショートカット「メッセージを作成」(D-483)
/// から。Widget の外からも開けるよう [OverlayManager] と [GoRouter] を直接受ける。[rooms] は相手を選んでから読む
/// (起動直後のショートカットでは、シートを出した時点でまだ読み終えていないことがある)。
Future<void> startNewDm({required OverlayManager manager, required GoRouter router, required List<DmRoom> Function() rooms}) async {
  final picked = await manager.showBottomSheet<UserSummary>(id: dmNewSheetId, title: '新規メッセージ', builder: (_) => const _UserPickSheet());
  if (picked == null) return;
  // 既存ルームがあればそれを開く(重複ルームを作らない)。
  final existing = rooms().where((r) => r.peer.id == picked.id).firstOrNull;
  final room = existing ?? DmRoom(id: 'dm:${picked.id}', peer: picked);
  unawaited(router.push(Routes.dmRoom(room.peer.id), extra: room));
}

/// 新規メッセージのシートの id。
const dmNewSheetId = 'dm.new';

/// 相手を選ぶシート: 検索欄 + 結果リスト。選択で ルーム画面(コンポーザー付き)へ。
class _UserPickSheet extends ConsumerStatefulWidget {
  const _UserPickSheet();
  @override
  ConsumerState<_UserPickSheet> createState() => _UserPickSheetState();
}

class _UserPickSheetState extends ConsumerState<_UserPickSheet> {
  String _q = '';
  Future<List<UserSummary>>? _results;

  void _search(String q) {
    final session = ref.read(currentSnsSessionProvider);
    setState(() {
      _q = q.trim();
      _results = _q.isEmpty || session == null ? null : session.searchUsers(_q, limit: 20).then((p) => p.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
        child: RasqSearchBar(hintText: 'ユーザー名で検索..', onChanged: _search),
      ),
      Flexible(
        child: _results == null
            ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('DM を送る相手を検索します。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)))
            : FutureBuilder(
                future: _results,
                builder: (context, snap) {
                  if (!snap.hasData && snap.error == null) return const RasqLoading();
                  final users = snap.data ?? const <UserSummary>[];
                  if (users.isEmpty) return const RasqEmptyView(title: '見つかりませんでした');
                  return ListView(shrinkWrap: true, children: [
                    for (final u in users)
                      RasqListTile(
                        leading: RasqAvatar(imageUrl: u.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: u.displayName),
                        title: u.displayName,
                        subtitle: '@${u.handle}',
                        onTap: () => ref.read(overlayManagerProvider).close(dmNewSheetId, result: u),
                      ),
                  ]);
                },
              ),
      ),
    ]);
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
              // 位置を覚える (D-504): タブを切り替えて戻っても前の位置から。
              : RememberScroll(
                  id: 'dm.rooms',
                  builder: (context, controller) => ListView.separated(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => _RoomRow(room: list[i], onTap: () => context.pushDmRoom(list[i])),
                  ),
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
