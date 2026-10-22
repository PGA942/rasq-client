import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/orgate_client.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_admission.dart';

/// 招待コード (D-548 / Central S-120): 通った利用者が出せる設定(`invite_user_issue`)のときだけ、設定のアカウントの画面から開く。
/// 出す・一覧・残りの数・共有。**平文のコードは出したときにしか返らない**(Central は SHA-256 だけを持つ)ので、コピーと
/// 共有はその場で出す。一覧はコードの末尾 ([RasqInvite.hint]) と使った数・期限だけ。
class RasqInvitesScreen extends ConsumerStatefulWidget {
  const RasqInvitesScreen({super.key});

  @override
  ConsumerState<RasqInvitesScreen> createState() => _RasqInvitesScreenState();
}

class _RasqInvitesScreenState extends ConsumerState<RasqInvitesScreen> {
  ({List<RasqInvite> items, int remaining})? _list;
  RasqIssuedInvite? _issued;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  RasqAdmissionApi? get _api => switch (ref.read(centralClientProvider)) { final c? => RasqAdmissionApi(c), _ => null };

  Future<void> _load() async {
    final api = _api;
    if (api == null) return;
    try {
      final list = await api.invites();
      if (mounted) setState(() => _list = list);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _issue() async {
    final api = _api;
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issued = await api.issue();
      if (!mounted) return;
      setState(() => _issued = issued);
      await _load();
      // 残りの数は設定の入口の出し分けにも使う。
      unawaited(ref.read(rasqAdmissionProvider.notifier).refresh());
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = context.l10n.settingsInvitesIssueFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text, String done) async {
    unawaited(Clipboard.setData(ClipboardData(text: text))); // 待たない(クリップボードの無い環境で止まらないように)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }

  String _date(DateTime? d) => d == null ? '' : MaterialLocalizations.of(context).formatMediumDate(d.toLocal());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = _list;
    final issued = _issued;
    final remaining = list?.remaining ?? 0;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsInvitesTitle),
      body: ListView(key: const ValueKey('invites.list'), children: [
        RasqCaption(l.settingsInvitesCaption, padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0)),
        if (list != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: Text(l.settingsInvitesRemaining(remaining), key: const ValueKey('invites.remaining')),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton(key: const ValueKey('invites.issue'), onPressed: _busy || list == null || remaining <= 0 ? null : _issue, child: Text(l.settingsInvitesIssueButton)),
        ),
        if (_error != null) RasqNotice.warning(key: const ValueKey('invites.error'), text: _error!),
        if (issued != null) ...[
          RasqNotice(
            key: const ValueKey('invites.issued'),
            title: l.settingsInvitesIssuedTitle,
            text: l.settingsInvitesIssuedText(issued.uses, _date(issued.expiresAt)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: SelectableText(issued.code, key: const ValueKey('invites.issued.code'), style: RasqTypography.title.copyWith(letterSpacing: 2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: Wrap(spacing: RasqSpacing.sm, children: [
              OutlinedButton.icon(key: const ValueKey('invites.issued.copy'), icon: const Icon(Icons.copy), label: Text(l.settingsInvitesCopyCode), onPressed: () => _copy(issued.code, l.settingsInvitesCopied)),
              OutlinedButton.icon(
                key: const ValueKey('invites.issued.share'),
                icon: const Icon(Icons.share),
                label: Text(l.settingsInvitesCopyMessage),
                onPressed: () => _copy(l.settingsInvitesShareMessage(issued.code), l.settingsInvitesMessageCopied),
              ),
            ]),
          ),
        ],
        if (list != null) ...[
          RasqSectionHeader(title: l.settingsInvitesIssuedHeader),
          if (list.items.isEmpty) RasqCaption(l.settingsInvitesNone, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page)),
          for (final i in list.items)
            RasqListTile(
              key: ValueKey('invites.item.${i.id}'),
              title: l.settingsInvitesItemTitle(i.hint),
              subtitle: i.revokedAt != null
                  ? l.settingsInvitesItemRevoked(i.used, i.uses)
                  : (i.expiresAt != null && i.expiresAt!.isBefore(DateTime.now()))
                      ? l.settingsInvitesItemExpired(i.used, i.uses)
                      : l.settingsInvitesItemActive(i.used, i.uses, _date(i.expiresAt)),
              chevron: false,
            ),
        ],
      ]),
    );
  }
}
