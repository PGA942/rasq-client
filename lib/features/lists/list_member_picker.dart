import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account_page_api.dart' hide RasqNotice;
import '../../backend/rasq_collections_api.dart';
import '../vc/astell_models.dart';

/// リストに人を足す (D-366): AsTell の作成 FOW の「フォロワーを招待」と同じ形。
/// - **SNS のフォロー中**(このアカウントがフォローしている人)と **RASQ のフォロー中**(RASQ アカウント)をアバターのチップで並べ、
///   タップで選ぶ。検索欄は SNS のユーザーと RASQ アカウントの両方を探す。
/// - RASQ ユーザーは、その人が公開ページに出している**同じ SNS のアカウント**でリストに入る(サーバーが違えばそのサーバーで引く)。
///   同じ SNS のアカウントを出していなければ選べない(理由を出す)。
/// - 足し先は [ListMemberTarget]: SNS のリスト(`addToList`)/ RASQ リスト(Central の項目)。

/// 足し先。[existing] はすでにいる人(SNS のユーザー id)。
abstract class ListMemberTarget {
  Set<String> get existing;

  /// まとめて足す。足せた人数。
  Future<int> addAll(List<UserSummary> users);
}

/// SNS のリスト。
class SnsListMemberTarget implements ListMemberTarget {
  SnsListMemberTarget(this.session, this.listId, this.existing);
  final SnsSession session;
  final String listId;
  @override
  final Set<String> existing;

  @override
  Future<int> addAll(List<UserSummary> users) async {
    var n = 0;
    for (final u in users) {
      await session.addToList(listId, u.id);
      n++;
    }
    return n;
  }
}

/// RASQ リスト(Central の項目)。[session] のアカウントから見た id で入れる。
class RasqListMemberTarget implements ListMemberTarget {
  RasqListMemberTarget(this.api, this.collectionId, this.session, List<RasqCollectionItem> items)
      : existing = {for (final i in items) if (i.kind == session.account.kind.name && i.instance == session.account.instance) i.refId};
  final RasqCollectionsApi api;
  final String collectionId;
  final SnsSession session;
  @override
  final Set<String> existing;

  @override
  Future<int> addAll(List<UserSummary> users) async {
    final detail = await api.get(collectionId, refresh: false);
    final keys = {for (final i in detail.items) i.key};
    final add = [
      for (final u in users)
        if (keys.add(RasqCollectionItem.member(u, via: session.account).key)) RasqCollectionItem.member(u, via: session.account),
    ];
    if (add.isEmpty) return 0;
    await api.putItems(collectionId, [for (final i in detail.items) i.toJson(), for (final i in add) i.toJson()]);
    return add.length;
  }
}

/// 候補の 1 人。SNS のユーザーならそのまま、RASQ アカウントなら選んだときに SNS のアカウントを引く。
@immutable
class MemberCandidate {
  MemberCandidate.sns(UserSummary this.user)
      : rasq = null,
        key = 'sns:${user.id}';
  MemberCandidate.rasq(AstellFollowEntry this.rasq)
      : user = null,
        key = 'rasq:${rasq.id}';

  final UserSummary? user;
  final AstellFollowEntry? rasq;
  final String key;

  String get displayName => user?.displayName ?? rasq!.displayName;
  Uri? get avatarUrl => user != null ? user!.avatarUrl : rasq!.avatarUrl;
  String get subtitle => user != null ? '@${user!.account.handle} ・ ${user!.account.instance}' : 'RASQ @${rasq!.handle}';
}

/// RASQ アカウント → そのセッションの SNS で見えるユーザー。同じ SNS のアカウントを公開していなければ null と理由。
Future<({UserSummary? user, String? reason})> resolveRasqMember(RasqAccountPageApi api, SnsSession session, AstellFollowEntry who) async {
  final profile = await api.profile(who.handle);
  final kind = session.account.kind.name;
  final links = [for (final l in profile.snsAccounts) if (l.kind == kind) l]
    // 同じサーバーのものを先に、確認済みを先に。
    ..sort((a, b) {
      final sa = a.instance == session.account.instance ? 0 : 1;
      final sb = b.instance == session.account.instance ? 0 : 1;
      return sa != sb ? sa - sb : (a.verified == b.verified ? 0 : (a.verified ? -1 : 1));
    });
  if (links.isEmpty) return (user: null, reason: '${who.displayName} さんは、この SNS のアカウントを公開していません');
  for (final l in links) {
    try {
      final p = await session.userByHandle(l.handle, host: l.instance == session.account.instance ? null : l.instance);
      if (p != null) return (user: p.summary, reason: null);
    } catch (_) {}
  }
  return (user: null, reason: '${who.displayName} さんの SNS アカウントが見つかりません');
}

/// 足す人を選ぶ FOW。足したら人数を返す(やめたら null)。
Future<int?> showListMemberPicker(WidgetRef ref, {required SnsSession session, required ListMemberTarget target, String title = 'メンバーを追加'}) async {
  final manager = ref.read(overlayManagerProvider);
  final picked = ValueNotifier<Map<String, UserSummary>>({});
  final canAdd = ValueNotifier(false);
  picked.addListener(() => canAdd.value = picked.value.isNotEmpty);
  final ok = await manager.showBottomSheet<bool>(
    id: 'lists.members.add',
    title: title,
    confirmText: '追加',
    confirmEnabled: canAdd,
    builder: (_) => _PickerBody(session: session, target: target, picked: picked),
  );
  if (ok != true || picked.value.isEmpty) return null;
  final n = await target.addAll(picked.value.values.toList());
  return n;
}

class _PickerBody extends ConsumerStatefulWidget {
  const _PickerBody({required this.session, required this.target, required this.picked});
  final SnsSession session;
  final ListMemberTarget target;
  final ValueNotifier<Map<String, UserSummary>> picked;

  @override
  ConsumerState<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends ConsumerState<_PickerBody> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<UserSummary> _snsFollowing = const [];
  List<AstellFollowEntry> _rasqFollowing = const [];
  List<UserSummary> _snsHits = const [];
  List<AstellFollowEntry> _rasqHits = const [];
  bool _loading = true;

  /// RASQ の候補 → 引いた SNS のユーザー(選んだ印)/ 選べない理由。
  final _resolved = <String, UserSummary>{};
  final _unavailable = <String, String>{};
  final _resolving = <String>{};

  RasqAccountPageApi? get _api => ref.read(rasqAccountPageApiProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = widget.session;
    try {
      final me = await s.me();
      _snsFollowing = (await s.following(me.id, limit: 40)).items;
    } catch (_) {}
    try {
      final c = ref.read(centralClientProvider);
      if (c != null) _rasqFollowing = [for (final e in await c.getList('/me/following')) if (e is Map) AstellFollowEntry.fromJson(e.cast<String, Object?>())];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final text = q.trim();
      if (text.isEmpty) {
        if (mounted) {
          setState(() {
            _snsHits = const [];
            _rasqHits = const [];
          });
        }
        return;
      }
      List<UserSummary> sns = const [];
      List<AstellFollowEntry> rasq = const [];
      try {
        sns = (await widget.session.searchUsers(text, limit: 12)).items;
      } catch (_) {}
      try {
        final api = _api;
        if (api != null) rasq = [for (final a in await api.searchAccounts(text)) AstellFollowEntry(id: a.id, handle: a.handle, displayName: a.displayName, avatarUrl: a.avatarUrl)];
      } catch (_) {}
      if (mounted && _query.text.trim() == text) {
        setState(() {
          _snsHits = sns;
          _rasqHits = rasq;
        });
      }
    });
  }

  bool _selected(MemberCandidate c) => widget.picked.value.containsKey(c.key);

  Future<void> _toggle(MemberCandidate c) async {
    final picked = {...widget.picked.value};
    if (picked.containsKey(c.key)) {
      picked.remove(c.key);
      widget.picked.value = picked;
      setState(() {});
      return;
    }
    if (c.user != null) {
      picked[c.key] = c.user!;
      widget.picked.value = picked;
      setState(() {});
      return;
    }
    // RASQ アカウント: この SNS のアカウントを引いてから選ぶ。
    final who = c.rasq!;
    final done = _resolved[who.id];
    if (done != null) {
      widget.picked.value = {...widget.picked.value, c.key: done};
      setState(() {});
      return;
    }
    final api = _api;
    if (api == null || _unavailable.containsKey(who.id)) {
      _explain(_unavailable[who.id] ?? 'RASQ サーバーに繋がっていません');
      return;
    }
    setState(() => _resolving.add(who.id));
    final r = await resolveRasqMember(api, widget.session, who).catchError((Object e) => (user: null, reason: '調べられませんでした'));
    if (!mounted) return;
    setState(() {
      _resolving.remove(who.id);
      if (r.user != null) {
        _resolved[who.id] = r.user!;
        widget.picked.value = {...widget.picked.value, c.key: r.user!};
      } else {
        _unavailable[who.id] = r.reason ?? '選べません';
      }
    });
    if (r.user == null) _explain(r.reason ?? '選べません');
  }

  void _explain(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _row(String label, List<MemberCandidate> items, {Key? key}) {
    final visible = [for (final c in items) if (c.user == null || !widget.target.existing.contains(c.user!.id)) c];
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: Text(label, style: RasqTypography.caption)),
      if (visible.isEmpty)
        const RasqCaption('いません')
      else
        SizedBox(
          height: RasqSizes.avatarXl + 24,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            children: [
              for (final c in visible) ...[
                _MemberChip(
                  key: ValueKey('lists.members.chip.${c.key}'),
                  candidate: c,
                  selected: _selected(c),
                  busy: c.rasq != null && _resolving.contains(c.rasq!.id),
                  unavailable: c.rasq != null && _unavailable.containsKey(c.rasq!.id),
                  onTap: () => _toggle(c),
                ),
                const SizedBox(width: RasqSpacing.md),
              ],
            ],
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.text.trim().isNotEmpty;
    final count = widget.picked.value.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: RasqSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: RasqInput(key: const ValueKey('lists.members.search'), controller: _query, hintText: 'ユーザーを検索(SNS / RASQ)', onChanged: (v) {
            setState(() {});
            _search(v);
          }),
        ),
        if (_loading) const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading()),
        if (!_loading && searching) ...[
          _row('SNS のユーザー', [for (final u in _snsHits) MemberCandidate.sns(u)], key: const ValueKey('lists.members.snsHits')),
          _row('RASQ のユーザー', [for (final a in _rasqHits) MemberCandidate.rasq(a)], key: const ValueKey('lists.members.rasqHits')),
        ],
        if (!_loading && !searching) ...[
          _row('SNS のフォロー中', [for (final u in _snsFollowing) MemberCandidate.sns(u)], key: const ValueKey('lists.members.sns')),
          _row('RASQ のフォロー中', [for (final a in _rasqFollowing) MemberCandidate.rasq(a)], key: const ValueKey('lists.members.rasq')),
        ],
        const RasqNotice(
          text: 'RASQ のユーザーは、その人が公開している同じ SNS のアカウントで追加します。',
          detail: 'Central の公開ページ(GET /accounts/{handle})の snsAccounts から、このセッションと同じ SNS(同じサーバーを優先、確認済みを優先)を選び、userByHandle で引いた id を足す。',
        ),
        if (count > 0) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0), child: Text('$count 人を選んでいます', key: const ValueKey('lists.members.count'), style: RasqTypography.bodySmall)),
      ]),
    );
  }
}

/// アバター + 名前のチップ(AsTell の招待と同じ見た目)。RASQ アカウントには小さな印。
class _MemberChip extends StatelessWidget {
  const _MemberChip({super.key, required this.candidate, required this.selected, required this.onTap, this.busy = false, this.unavailable = false});
  final MemberCandidate candidate;
  final bool selected;
  final bool busy;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: '${c.displayName} ${c.subtitle}',
        child: Opacity(
          opacity: unavailable ? 0.4 : 1,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: RasqSizes.avatarXl,
                height: RasqSizes.avatarXl,
                foregroundDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? RasqColors.link : Colors.transparent, width: 2.5)),
                child: RasqAvatar(imageUrl: c.avatarUrl, size: RasqSizes.avatarXl, fallbackLabel: c.displayName),
              ),
              if (busy) const Positioned.fill(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))),
              if (selected)
                const Positioned(right: -2, bottom: -2, child: CircleAvatar(radius: 9, backgroundColor: RasqColors.link, child: Icon(Icons.check, size: 12, color: Colors.white))),
              // 左下にサービス / インスタンスのアイコン (D-369): SNS のユーザーはそのサーバーのアイコン、RASQ のユーザーは RASQ。
              Positioned(
                left: -3,
                bottom: -3,
                child: Container(
                  key: ValueKey('lists.members.badge.${c.key}'),
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle),
                  child: ClipOval(
                    child: c.user != null
                        ? RasqSnsPill(account: c.user!.account, showLabel: false, dotSize: 16)
                        : const RasqBrandIcon(size: 16, semanticsLabel: 'RASQ のユーザー'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            SizedBox(width: RasqSizes.avatarXl + 8, child: Text(c.displayName, style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          ]),
        ),
      ),
    );
  }
}
