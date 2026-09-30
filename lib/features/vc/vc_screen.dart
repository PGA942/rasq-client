import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../home/create_fow.dart' show RadialCreateFab;
import '../../shell/rasq_terms_gate.dart';
import '../settings/settings_dsl.dart';
import '../../app/providers.dart';
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
///
/// 上の検索欄 (D-385): トレンドの検索と同じ形(アイコン + 角丸の欄 [RasqExpandableSearchBox])。入れるとホームに載っている
/// ルームから、名前 / 要約 / ジャンル / ホストで探す([searchAstellRooms])。欄を押すと下に伸び、節のチップで絞れる。
class VcScreen extends ConsumerStatefulWidget {
  const VcScreen({super.key});

  @override
  ConsumerState<VcScreen> createState() => _VcScreenState();
}

/// 検索の節(チップ)。
const astellSearchSections = {'invited': '招待', 'recommended': 'おすすめ', 'upcoming': '近日開催', 'trending': 'トレンド', 'following': 'フォロー中'};

/// ホームに載っているルームから探す (D-385)。[sections] を渡すとその節だけ。同じルームは 1 つに。語が無ければ節のルームを全部。
List<AstellRoom> searchAstellRooms(AstellHome h, String query, {Set<String> sections = const {}}) {
  final bySection = {'invited': h.invited, 'recommended': h.recommended, 'upcoming': h.upcoming, 'trending': h.trending, 'following': h.following};
  final q = query.trim().toLowerCase();
  final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final seen = <String>{};
  final out = <AstellRoom>[];
  for (final MapEntry(key: id, value: rooms) in bySection.entries) {
    if (sections.isNotEmpty && !sections.contains(id)) continue;
    for (final r in rooms) {
      final hay = [r.title, r.description, r.ownerDisplayName, r.ownerHandle, '@${r.ownerHandle}', ...r.genres].join(' ').toLowerCase();
      if (terms.every(hay.contains) && seen.add(r.id)) out.add(r);
    }
  }
  return out;
}

class _VcScreenState extends ConsumerState<VcScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _toggled = false;
  final Set<String> _sections = {};

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    _query.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _searching => _query.text.trim().isNotEmpty || _sections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // トレンドの検索と同じ並び(アイコン + 角丸の欄)。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: me.displayName, onTap: () => RasqShell.openSidebar(context, ref)),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: RasqExpandableSearchBox(
                  key: const ValueKey('astell.search'),
                  expanded: _toggled || _focus.hasFocus || _sections.isNotEmpty,
                  controller: _query,
                  focusNode: _focus,
                  hintText: 'AsTell を検索',
                  onDropdownTap: () => setState(() => _toggled = !_toggled),
                  onReset: _sections.isEmpty ? null : () => setState(_sections.clear),
                  genreChips: [
                    for (final MapEntry(key: id, value: label) in astellSearchSections.entries)
                      RasqFilterChipItem(label: label, selected: _sections.contains(id), onTap: () => setState(() => _sections.contains(id) ? _sections.remove(id) : _sections.add(id))),
                  ],
                  barTrailing: _query.text.isEmpty ? null : RasqIconButton(key: const ValueKey('astell.search.clear'), icon: Icons.close, size: 18, tooltip: '消す', onPressed: _query.clear),
                ),
              ),
            ]),
          ),
          Expanded(child: _body(context, home, session, section, open)),
        ]),
      ),
      // ＋ (D-381): Swing / AsTell / RASQ に投稿(設定で出すものを選べる)。
      floatingActionButton: const RadialCreateFab(scope: 'astell', heroTag: 'astell.create', tooltip: 'VC を作成'),
    );
  }

  Widget _body(BuildContext context, AsyncValue<AstellHome> home, AstellSessionState? session, Widget Function(String, List<AstellRoom>, {String? emptyHint, VoidCallback? onSettings}) section, void Function(AstellRoom) open) {
    return home.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: 'VC を取得できませんでした', hint: '$e'),
        data: (h) => _searching ? _results(h, open) : RefreshIndicator(
          onRefresh: () => ref.refresh(astellHomeProvider.future),
          child: ListView(key: const ValueKey('astell.home.list'), children: [
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
      );
  }

  Widget _results(AstellHome h, void Function(AstellRoom) open) {
    final rooms = searchAstellRooms(h, _query.text, sections: _sections);
    if (rooms.isEmpty) return RasqEmptyView(title: '見つかりませんでした', hint: _query.text.trim().isEmpty ? 'この節にルームはありません' : '「${_query.text.trim()}」に当たるルームはありません');
    return ListView(key: const ValueKey('astell.search.results'), children: [
      for (final r in rooms)
        RasqListTile(
          key: ValueKey('astell.search.hit.${r.id}'),
          title: r.title,
          subtitle: [
            r.ownerDisplayName,
            if (r.scheduledAt != null) '開催予約' else '${r.peerCount}人',
            if (r.genres.isNotEmpty) r.genres.take(3).join(' / '),
          ].join(' ・ '),
          leading: RasqAvatar(imageUrl: r.ownerAvatarUrl, size: RasqSizes.avatarMd, fallbackLabel: r.ownerDisplayName),
          onTap: () {
            _focus.unfocus();
            open(r);
          },
        ),
      const SizedBox(height: 80),
    ]);
  }
}
