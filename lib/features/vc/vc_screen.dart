import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../shell/rasq_terms_gate.dart';
import '../settings/settings_dsl.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import 'astell_actions.dart';
import 'astell_fows.dart';
import 'astell_models.dart';
import 'astell_providers.dart';
import 'astell_tile.dart';

/// グローバル VC ホーム (D-139、ワイヤーフレーム p.3): おすすめ / トレンド /
/// フォロー中 の 3 節に VC タイルを横並び。「見てみる」→ 参加 FOW → 参加 →
/// ルーム FOW。右下の + で作成 FOW。データは RASQ Central `/astell/home`
/// (未接続ならモック)。
class VcScreen extends ConsumerWidget {
  const VcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final home = ref.watch(astellHomeProvider);
    final session = ref.watch(astellSessionProvider);

    void open(AstellRoom room) => openAstellPreviewFow(context, ref, room);

    Widget section(String title, List<AstellRoom> rooms, {String? emptyHint, VoidCallback? onSettings}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RasqSectionHeader(title: title, topMargin: 0, trailing: onSettings == null ? null : RasqIconButton(icon: Icons.settings, size: 20, onPressed: onSettings, tooltip: '$titleの設定')),
          // ブックマーク/開始通知/見てみる(戻る)を配線したタイル (D-160)。
          AstellTileStrip(rooms: rooms, tileBuilder: (r) => AstellRoomTile(room: r), emptyHint: emptyHint),
        ]);

    return Scaffold(
      appBar: RasqSearchHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
      body: home.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: 'VC を取得できませんでした', hint: '$e'),
        data: (h) => RefreshIndicator(
          onRefresh: () => ref.refresh(astellHomeProvider.future),
          child: ListView(children: [
            // 同意待ちなら AsTell は使えない (D-371)。
            const RasqTermsBanner(),
            // 参加中のルームがあれば先頭に戻り口(FOW を閉じても接続は続く)。
            if (session != null)
              RasqListTile(
                title: '参加中: ${session.room.title}',
                subtitle: session.connected ? '${session.peers.length}人 ・ タップで開く' : (session.error ?? '接続しています…'),
                leading: const Icon(Icons.headset_mic_outlined, color: RasqColors.accent),
                onTap: () => openAstellRoomFow(context, ref),
              ),
            // 招待 (D-150): 招待されているルームを行で(辞退できる)。
            if (h.invited.isNotEmpty) ...[
              const RasqSectionHeader(title: '招待', topMargin: 0),
              for (final r in h.invited)
                RasqListTile(
                  title: r.title,
                  subtitle: '${r.ownerDisplayName} から招待 ・ タップで見る',
                  leading: RasqAvatar(imageUrl: r.ownerAvatarUrl, size: RasqSizes.avatarMd, fallbackLabel: r.ownerDisplayName),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(astellClientProvider).declineInvite(r.id);
                      ref.invalidate(astellHomeProvider);
                    },
                    child: const Text('辞退'),
                  ),
                  chevron: false,
                  onTap: () => open(r),
                ),
            ],
            if (settingValue(ref, 'astell.trend', 'showRecommended', true) != false) section('おすすめ', h.recommended, emptyHint: 'おすすめの VC はまだありません'),
            // 近日開催 (D-159): 開催予約中のルーム(予約時刻の近い順)。
            if (h.upcoming.isNotEmpty) section('近日開催', h.upcoming),
            // 欄の歯車 (D-238): AsTell の設定ページへ。
            if (settingValue(ref, 'astell.trend', 'showTrending', true) != false) section('トレンド', h.trending, emptyHint: 'トレンドの VC はまだありません', onSettings: () => context.push('/settings/dsl/astell.trend')),
            section('フォロー中', h.following, emptyHint: 'フォロー中のユーザーの VC はありません', onSettings: () => context.push('/settings/dsl/astell.tiles')),
            const SizedBox(height: 80),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // 全画面ビューワー(ルートナビゲータへ push)の Hero と衝突しないよう固有タグ (D-145)。
        heroTag: 'astell.create',
        tooltip: 'VC を作成',
        onPressed: () => openAstellCreateFow(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
