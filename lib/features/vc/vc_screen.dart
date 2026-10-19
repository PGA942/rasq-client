import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../home/create_fow.dart' show RadialCreateFab;
import '../../shell/rasq_terms_gate.dart';
import '../settings/settings_dsl.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shell/rasq_shell.dart';
import 'astell_actions.dart';
import 'astell_fows.dart';
import 'astell_models.dart';
import 'astell_providers.dart';
import 'astell_tile.dart';
import '../swing/swing_banner.dart';
import '../swing/swing_providers.dart';

/// グローバル VC ホーム (D-139、ワイヤーフレーム p.3): おすすめ / トレンド /
/// フォロー中 の 3 節に VC タイルを横並び。「見てみる」→ 参加 FOW → 参加 →
/// ルーム FOW。右下の + で作成 FOW。データは RASQ Central `/astell/home`
/// (未接続ならモック)。
///
/// 上の検索欄 (D-385 → D-386): トレンドの検索と同じ形(アイコン + 角丸の欄 [RasqExpandableSearchBox])。
/// - **AsTell と Swing をまとめて探す**: ルームは名前 / 要約 / ジャンル / ホスト([searchAstellRooms])、Swing は作った人 /
///   文字 / 種類([searchSwingAuthors])。結果は **Swing の角丸バナー**([SwingBanner])→ **AsTell のタイル**の順に重ねる。
/// - **条件を重ねる**: Enter で入れた語を「語のチップ」にして残し、続けて入れた語と全部を満たすものだけにする(チップを押すと外す)。
///   欄を押すと下に伸び、節のチップ(Swing / 招待 / おすすめ …、複数可)でも絞れる。
class VcScreen extends ConsumerStatefulWidget {
  const VcScreen({super.key});

  @override
  ConsumerState<VcScreen> createState() => _VcScreenState();
}

/// 検索の節(チップ)。
Map<String, String> get astellSearchSections => astellSearchSectionsOf(appL10n);

/// [astellSearchSections] を [l] の言語で。
Map<String, String> astellSearchSectionsOf(AppLocalizations l) => {'swing': 'Swing', 'invited': l.vcSectionInvited, 'recommended': l.vcSectionRecommended, 'upcoming': l.vcSectionUpcoming, 'trending': l.vcSectionTrending, 'following': l.vcSectionFollowing};

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

  /// 重ねた語 (D-386)。
  final List<String> _terms = [];

  /// いまの条件(重ねた語 + 入れている語)。
  String get _q => [..._terms, _query.text.trim()].where((t) => t.isNotEmpty).join(' ');

  void _stack(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_terms.contains(t)) _terms.add(t);
      _query.clear();
    });
    _focus.requestFocus();
  }

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

  bool get _searching => _q.isNotEmpty || _sections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final home = ref.watch(astellHomeProvider);
    final session = ref.watch(astellSessionProvider);

    void open(AstellRoom room) => openAstellPreviewFow(context, ref, room);

    Widget section(String title, List<AstellRoom> rooms, {String? emptyHint, VoidCallback? onSettings}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RasqSectionHeader(title: title, topMargin: 0, trailing: onSettings == null ? null : RasqIconButton(icon: Icons.settings, size: 20, onPressed: onSettings, tooltip: context.l10n.vcSectionSettingsTooltip(title))),
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
                  expanded: _toggled || _focus.hasFocus || _sections.isNotEmpty || _terms.isNotEmpty,
                  controller: _query,
                  focusNode: _focus,
                  hintText: _terms.isEmpty ? context.l10n.vcSearchHint : context.l10n.vcSearchRefineHint,
                  onSubmitted: _stack,
                  onDropdownTap: () => setState(() => _toggled = !_toggled),
                  onReset: _sections.isEmpty && _terms.isEmpty
                      ? null
                      : () => setState(() {
                            _sections.clear();
                            _terms.clear();
                          }),
                  // 重ねた語(押すと外す)。
                  filterChips: [
                    for (final t in _terms) RasqFilterChipItem(label: context.l10n.vcSearchTermChip(t), selected: true, onTap: () => setState(() => _terms.remove(t))),
                  ],
                  genreChips: [
                    for (final MapEntry(key: id, value: label) in astellSearchSectionsOf(context.l10n).entries)
                      RasqFilterChipItem(label: label, selected: _sections.contains(id), onTap: () => setState(() => _sections.contains(id) ? _sections.remove(id) : _sections.add(id))),
                  ],
                  barTrailing: _query.text.isEmpty ? null : RasqIconButton(key: const ValueKey('astell.search.clear'), icon: Icons.close, size: 18, tooltip: context.l10n.vcSearchClear, onPressed: _query.clear),
                ),
              ),
            ]),
          ),
          Expanded(child: _body(context, home, session, section, open)),
        ]),
      ),
      // ＋ (D-381): Swing / AsTell / RASQ に投稿(設定で出すものを選べる)。
      floatingActionButton: RadialCreateFab(scope: 'astell', heroTag: 'astell.create', tooltip: context.l10n.vcCreateTooltip),
    );
  }

  Widget _body(BuildContext context, AsyncValue<AstellHome> home, AstellSessionState? session, Widget Function(String, List<AstellRoom>, {String? emptyHint, VoidCallback? onSettings}) section, void Function(AstellRoom) open) {
    // 検索は、ルームを読めていなくても Swing を探せる(読めたルームだけ)。
    if (_searching) return _results(home.value ?? const AstellHome());
    return home.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: context.l10n.vcHomeLoadError, hint: '$e'),
        data: (h) => RefreshIndicator(
          onRefresh: () => ref.refresh(astellHomeProvider.future),
          child: ListView(key: const ValueKey('astell.home.list'), children: [
            // 同意待ちなら AsTell は使えない (D-371)。
            const RasqTermsBanner(),
            // 参加中のルームがあれば先頭に戻り口(FOW を閉じても接続は続く)。
            if (session != null)
              RasqListTile(
                title: context.l10n.vcJoinedRoom(session.room.title),
                subtitle: session.connected ? context.l10n.vcJoinedPeers(session.peers.length) : (session.error ?? context.l10n.vcConnecting),
                leading: const Icon(Icons.headset_mic_outlined, color: RasqColors.accent),
                onTap: () => openAstellRoomFow(context, ref),
              ),
            // 招待 (D-150): 招待されているルームを行で(辞退できる)。
            if (h.invited.isNotEmpty) ...[
              RasqSectionHeader(title: context.l10n.vcSectionInvited, topMargin: 0),
              for (final r in h.invited)
                RasqListTile(
                  title: r.title,
                  subtitle: context.l10n.vcInvitedBy(r.ownerDisplayName),
                  leading: RasqAvatar(imageUrl: r.ownerAvatarUrl, size: RasqSizes.avatarMd, fallbackLabel: r.ownerDisplayName),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(astellClientProvider).declineInvite(r.id);
                      ref.invalidate(astellHomeProvider);
                    },
                    child: Text(context.l10n.vcInviteDecline),
                  ),
                  chevron: false,
                  onTap: () => open(r),
                ),
            ],
            if (settingValue(ref, 'astell.trend', 'showRecommended', true) != false) section(context.l10n.vcSectionRecommended, h.recommended, emptyHint: context.l10n.vcRecommendedEmpty),
            // 近日開催 (D-159): 開催予約中のルーム(予約時刻の近い順)。
            if (h.upcoming.isNotEmpty) section(context.l10n.vcSectionUpcoming, h.upcoming),
            // 欄の歯車 (D-238): AsTell の設定ページへ。
            if (settingValue(ref, 'astell.trend', 'showTrending', true) != false) section(context.l10n.vcSectionTrending, h.trending, emptyHint: context.l10n.vcTrendingEmpty, onSettings: () => context.push('/settings/dsl/astell.trend')),
            section(context.l10n.vcSectionFollowing, h.following, emptyHint: context.l10n.vcFollowingEmpty, onSettings: () => context.push('/settings/dsl/astell.tiles')),
            const SizedBox(height: 80),
          ]),
        ),
      );
  }

  Widget _results(AstellHome h) {
    final q = _q;
    final wantSwing = _sections.isEmpty || _sections.contains('swing');
    final roomSections = {..._sections}..remove('swing');
    final wantRooms = _sections.isEmpty || roomSections.isNotEmpty;
    final swings = !wantSwing ? const <SwingAuthorEntry>[] : searchSwingAuthors(ref.watch(swingFeedProvider).value ?? const [], q);
    final rooms = !wantRooms ? const <AstellRoom>[] : searchAstellRooms(h, q, sections: roomSections);
    if (rooms.isEmpty && swings.isEmpty) return RasqEmptyView(title: context.l10n.vcSearchNoResults, hint: q.isEmpty ? context.l10n.vcSearchNoResultsInSection : context.l10n.vcSearchNoResultsFor(q));
    return ListView(key: const ValueKey('astell.search.results'), children: [
      if (swings.isNotEmpty) ...[
        RasqSectionHeader(title: 'Swing(${swings.length})', topMargin: 0),
        for (final e in swings)
          Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, RasqSpacing.xs), child: SwingBanner(entry: e)),
      ],
      if (rooms.isNotEmpty) ...[
        RasqSectionHeader(title: 'ASTell(${rooms.length})', topMargin: 0),
        AstellTileStrip(
          key: const ValueKey('astell.search.rooms'),
          rooms: rooms,
          tileBuilder: (r) => KeyedSubtree(key: ValueKey('astell.search.hit.${r.id}'), child: AstellRoomTile(room: r)),
        ),
      ],
      const SizedBox(height: 80),
    ]);
  }
}
