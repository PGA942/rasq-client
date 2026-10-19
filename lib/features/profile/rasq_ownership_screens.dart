import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'rasq_account_page_screen.dart' show RasqSnsTileChip;

/// 持ち主の確認ができる SNS(Central が公開のプロフィールを読める種類。D-313)。
const rasqVerifiableKinds = {'misskey', 'mastodon', 'bluesky'};

/// 確認の文を「どこに貼るか」を、その SNS の呼び名で。
String rasqVerifyWhere(String kind, List<String> where) {
  final fields = where.contains('fields');
  return switch (kind) {
    'misskey' when fields => appL10n.profileOwnershipWhereMisskey,
    'mastodon' when fields => appL10n.profileOwnershipWhereMastodon,
    'bluesky' => appL10n.profileOwnershipWhereBluesky,
    _ when fields => appL10n.profileOwnershipWhereFields,
    _ => appL10n.profileOwnershipWhereBio,
  };
}

/// 持ち主の確認のエラーを、画面に出す 1 行へ。
/// D-503: Central の持ち主の確認 / Keybase の誤りには名前つきの理由(`error.code`)がまだ無く、文は英語の固定の文なので、
/// HTTP の番号と文の一部で見ている。Central が名前を返すようになったら [OrgateException.isReason] に替える。
String rasqVerifyMessage(OrgateException e) => switch (e.code.code) {
      '404' => appL10n.profileOwnershipErrorNotLinked,
      '400' when e.message.contains('not supported') => appL10n.profileOwnershipErrorUnsupported,
      '429' => appL10n.profileOwnershipErrorTooMany,
      '409' when e.message.contains('verify/start') => appL10n.profileOwnershipErrorNotStarted,
      '409' when e.message.contains('code was not found') => appL10n.profileOwnershipErrorCodeNotFound,
      '409' when e.message.contains('was not found') => appL10n.profileOwnershipErrorProfileNotFound,
      '409' => appL10n.profileOwnershipErrorReadFailed,
      _ => appL10n.profileOwnershipErrorFailed(e.message),
    };

/// Keybase のエラーを、画面に出す 1 行へ。
String rasqKeybaseMessage(OrgateException e) => switch (e.code.code) {
      '400' when e.message.contains('username') => appL10n.profileOwnershipKeybaseErrorUsername,
      '400' when e.message.contains('signature:') => appL10n.profileOwnershipKeybaseErrorSignature,
      '400' when e.message.contains('not the statement') => appL10n.profileOwnershipKeybaseErrorStatement,
      '400' when e.message.contains('current key') => appL10n.profileOwnershipKeybaseErrorKey,
      '400' when e.message.contains('no such keybase user') => appL10n.profileOwnershipKeybaseErrorNoUser,
      '409' when e.message.contains('another rasq account') => appL10n.profileOwnershipKeybaseErrorOtherAccount,
      '409' => appL10n.profileOwnershipKeybaseErrorExpired,
      '429' => appL10n.profileOwnershipErrorTooMany,
      'B03' => appL10n.profileOwnershipKeybaseErrorUnreachable,
      _ => appL10n.profileOwnershipKeybaseErrorFailed(e.message),
    };

String _date(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

void _copy(BuildContext context, String text, String done) {
  unawaited(Clipboard.setData(ClipboardData(text: text))); // 待たない(クリップボードの無い環境で止まらないように)
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(done)));
}

/// 貼る文 / コマンドを見せる枠(選んでコピーもできる)。
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.valueKey, required this.text, this.mono = false});
  final Key valueKey;
  final String text;
  final bool mono;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: SelectableText(text, key: valueKey, style: mono ? RasqTypography.bodySmall.copyWith(fontFamily: 'monospace') : RasqTypography.body),
    );
  }
}

/// SNS アカウントの持ち主の確認 (D-313)。
///
/// 1. 「確認の文を作る」→ Central が一度きりのコード入りの文をくれる(24 時間)。
/// 2. その SNS で、自分で自己紹介(かプロフィールの項目)に貼って保存する。**アプリからは書き換えない**
///    (プロフィールを編集できるプラグインでログインしていても、手で貼ってもらう。自動で書くのは今後の課題)。
/// 3. 「確認する」→ Central が公開のプロフィールを読んで、コードがあれば確認済み。確認できたら文は消してよい。
class RasqSnsVerifyScreen extends ConsumerStatefulWidget {
  const RasqSnsVerifyScreen({super.key, required this.accountKey});
  final String accountKey;
  @override
  ConsumerState<RasqSnsVerifyScreen> createState() => _RasqSnsVerifyScreenState();
}

class _RasqSnsVerifyScreenState extends ConsumerState<RasqSnsVerifyScreen> {
  RasqSnsLink? _link;
  bool _loaded = false;
  RasqSnsVerifyStart? _start;
  bool _busy = false;
  String? _error;

  /// 確認できた直後の案内(文を消してよい)。
  bool _justVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(rasqAccountPageApiProvider);
    try {
      final links = await api?.mySnsLinks() ?? const <RasqSnsLink>[];
      if (mounted) setState(() => _link = links.where((l) => l.accountKey == widget.accountKey).firstOrNull);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqVerifyMessage(e));
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _run(Future<void> Function(RasqAccountPageApi api) body) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body(api);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqVerifyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin() => _run((api) async {
        final s = await api.startSnsVerification(widget.accountKey);
        if (mounted) setState(() => _start = s);
      });

  Future<void> _check() => _run((api) async {
        final l = await api.checkSnsVerification(widget.accountKey);
        if (mounted) {
          setState(() {
            _link = l;
            _start = null;
            _justVerified = l.tile.verified;
          });
        }
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final l10n = context.l10n;
    final link = _link;
    final kind = link?.tile.kind ?? widget.accountKey.split(':').first;
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.profileOwnershipVerifyTitle),
      body: !_loaded
          ? const RasqLoading()
          : ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
              if (link == null)
                Text(l10n.profileOwnershipNotLinked, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
              else ...[
                Align(alignment: Alignment.centerLeft, child: SizedBox(height: 40, child: RasqSnsTileChip(tile: link.tile))),
                const SizedBox(height: RasqSpacing.md),
                if (link.tile.verified) ...[
                  Row(key: const ValueKey('snsVerify.done'), children: [
                    Icon(Icons.verified, size: 20, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l10n.profileOwnershipVerified(link.tile.verifiedLabel), style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: RasqSpacing.sm),
                  if (_justVerified) Text(l10n.profileOwnershipJustVerified, key: const ValueKey('snsVerify.removeHint'), style: RasqTypography.bodySmall),
                  const SizedBox(height: RasqSpacing.xs),
                  Text(rasqDetail(context, l10n.profileOwnershipVerifiedCaption, l10n.profileOwnershipVerifiedCaptionDetail), style: caption),
                ] else if (!rasqVerifiableKinds.contains(kind))
                  Text(l10n.profileOwnershipUnsupportedKind, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
                else ...[
                  Text(rasqDetail(context, l10n.profileOwnershipIntro, l10n.profileOwnershipIntroDetail), style: RasqTypography.bodySmall),
                  const SizedBox(height: RasqSpacing.xs),
                  Text(rasqDetail(context, l10n.profileOwnershipEffect, l10n.profileOwnershipEffectDetail), style: caption),
                  const SizedBox(height: RasqSpacing.md),
                  if (_start == null)
                    FilledButton(key: const ValueKey('snsVerify.start'), onPressed: _busy ? null : _begin, child: Text(l10n.profileOwnershipStart))
                  else ...[
                    Text(l10n.profileOwnershipStep1, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: RasqSpacing.xs),
                    _CodeBox(valueKey: const ValueKey('snsVerify.text'), text: _start!.text),
                    Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      TextButton.icon(key: const ValueKey('snsVerify.copy'), onPressed: () => _copy(context, _start!.text, l10n.profileOwnershipCopied), icon: const Icon(Icons.copy, size: 16), label: Text(l10n.profileOwnershipCopy)),
                      if (_start!.expiresAt != null) Text(l10n.profileOwnershipValidUntil(_date(_start!.expiresAt)), style: caption),
                    ]),
                    const SizedBox(height: RasqSpacing.sm),
                    Text(l10n.profileOwnershipStep2, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: RasqSpacing.xs),
                    Text(rasqVerifyWhere(kind, _start!.where), key: const ValueKey('snsVerify.where'), style: RasqTypography.bodySmall),
                    Text(l10n.profileOwnershipNoRewrite, style: caption),
                    const SizedBox(height: RasqSpacing.sm),
                    Text(l10n.profileOwnershipStep3, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: RasqSpacing.sm),
                  Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
                    // 前に作った文を貼ってあれば、作り直さずに確かめられる。
                    FilledButton.tonal(key: const ValueKey('snsVerify.check'), onPressed: _busy ? null : _check, child: Text(l10n.profileOwnershipCheck)),
                    if (_start != null) TextButton(key: const ValueKey('snsVerify.restart'), onPressed: _busy ? null : _begin, child: Text(l10n.profileOwnershipRestart)),
                  ]),
                ],
              ],
              // 失敗は、押したボタンのすぐ下に出す(画面の一番下 = いま見ているところ)。
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, key: const ValueKey('snsVerify.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
              if (_busy) const Padding(padding: EdgeInsets.only(top: RasqSpacing.md), child: RasqLoading()),
            ]),
    );
  }
}

/// RASQ アカウントの Keybase (D-313)。
///
/// Keybase のユーザー名を入れる → 署名してもらう文と `keybase sign -m '…'` のコマンド(コピー)→ 出てきた署名を貼る →
/// Central が Keybase の公開の鍵で確かめる。確かめた Keybase は公開ページに「Keybase: @user」で出る。
/// Keybase の証明(Mastodon など)に、つないでいる SNS アカウントがあれば、それも確認済みになる。
class RasqKeybaseScreen extends ConsumerStatefulWidget {
  const RasqKeybaseScreen({super.key});
  @override
  ConsumerState<RasqKeybaseScreen> createState() => _RasqKeybaseScreenState();
}

class _RasqKeybaseScreenState extends ConsumerState<RasqKeybaseScreen> {
  final _username = TextEditingController();
  final _signature = TextEditingController();
  RasqKeybaseStart? _start;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(RasqAccountPageApi api) body) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await body(api);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqKeybaseMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _linksMessage(RasqKeybaseStatus st) => st.verifiedLinks.isEmpty
      ? appL10n.profileOwnershipKeybaseNoLinks
      : appL10n.profileOwnershipKeybaseLinksVerified(st.verifiedLinks.length);

  Future<void> _begin() => _run((api) async {
        final s = await api.startKeybase(_username.text.trim().replaceFirst(RegExp('^@'), '').toLowerCase());
        if (mounted) {
          setState(() {
            _start = s;
            _signature.clear();
          });
        }
      });

  Future<void> _verify() => _run((api) async {
        final st = await api.verifyKeybase(signature: _signature.text.trim());
        await ref.read(orgateAccountProvider.notifier).refresh();
        if (mounted) {
          setState(() {
            _start = null;
            _signature.clear();
            _message = appL10n.profileOwnershipKeybaseLinked(st.keybase?.username ?? '', _linksMessage(st));
          });
        }
      });

  Future<void> _refresh() => _run((api) async {
        final st = await api.verifyKeybase();
        if (mounted) setState(() => _message = _linksMessage(st));
      });

  Future<void> _unlink() => _run((api) async {
        await api.unlinkKeybase();
        await ref.read(orgateAccountProvider.notifier).refresh();
        if (mounted) setState(() => _message = appL10n.profileOwnershipKeybaseUnlinked);
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final account = ref.watch(orgateAccountProvider).value;
    final kb = account?.keybase;
    final l10n = context.l10n;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'Keybase'),
      body: account == null
          ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l10n.profileEditNotLoggedIn, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
          : ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
              if (kb != null) ...[
                Row(children: [
                  Icon(Icons.verified, size: 20, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('keybase.linked'),
                      onTap: () => launchUrl(kb.profileUrl, mode: LaunchMode.externalApplication),
                      child: Text('Keybase: @${kb.username}', style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
                    ),
                  ),
                ]),
                if (kb.verifiedAt != null) Text(l10n.profileOwnershipKeybaseVerifiedAt(_date(kb.verifiedAt)), style: caption),
                const SizedBox(height: RasqSpacing.sm),
                Text(rasqDetail(context, l10n.profileOwnershipKeybaseCaption(kb.username), l10n.profileOwnershipKeybaseCaptionDetail(kb.username)), style: caption),
                const SizedBox(height: RasqSpacing.md),
                Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
                  FilledButton.tonal(key: const ValueKey('keybase.refresh'), onPressed: _busy ? null : _refresh, child: Text(l10n.profileOwnershipKeybaseRefresh)),
                  TextButton(key: const ValueKey('keybase.unlink'), onPressed: _busy ? null : _unlink, child: Text(l10n.profileOwnershipKeybaseUnlink, style: TextStyle(color: tokens.danger))),
                ]),
              ] else ...[
                Text(rasqDetail(context, l10n.profileOwnershipKeybaseIntro, l10n.profileOwnershipKeybaseIntroDetail), style: RasqTypography.bodySmall),
                const SizedBox(height: RasqSpacing.md),
                Text(l10n.profileOwnershipKeybaseUsername, style: caption),
                const SizedBox(height: 4),
                RasqInput(key: const ValueKey('keybase.username'), controller: _username, hintText: 'username'),
                const SizedBox(height: RasqSpacing.sm),
                FilledButton(key: const ValueKey('keybase.start'), onPressed: _busy ? null : _begin, child: Text(_start == null ? l10n.profileOwnershipKeybaseStart : l10n.profileOwnershipRestart)),
                if (_start != null) ...[
                  const SizedBox(height: RasqSpacing.md),
                  Text(l10n.profileOwnershipKeybaseStep1, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: RasqSpacing.xs),
                  _CodeBox(valueKey: const ValueKey('keybase.command'), text: _start!.command, mono: true),
                  Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TextButton.icon(key: const ValueKey('keybase.copy'), onPressed: () => _copy(context, _start!.command, l10n.profileOwnershipKeybaseCopied), icon: const Icon(Icons.copy, size: 16), label: Text(l10n.profileOwnershipCopy)),
                    if (_start!.expiresAt != null) Text(l10n.profileOwnershipValidUntil(_date(_start!.expiresAt)), style: caption),
                  ]),
                  Text(l10n.profileOwnershipKeybaseStatement(_start!.statement), key: const ValueKey('keybase.statement'), style: caption),
                  const SizedBox(height: RasqSpacing.sm),
                  Text(l10n.profileOwnershipKeybaseStep2, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: RasqSpacing.xs),
                  RasqInput(key: const ValueKey('keybase.signature'), controller: _signature, maxLines: 6, hintText: 'BEGIN KEYBASE SALTPACK SIGNED MESSAGE. …'),
                  const SizedBox(height: RasqSpacing.sm),
                  FilledButton.tonal(key: const ValueKey('keybase.verify'), onPressed: _busy ? null : _verify, child: Text(l10n.profileOwnershipKeybaseVerify)),
                ],
              ],
              // 結果は、押したボタンのすぐ下に出す。
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, key: const ValueKey('keybase.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
              if (_message != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_message!, key: const ValueKey('keybase.message'), style: RasqTypography.bodySmall)),
              if (_busy) const Padding(padding: EdgeInsets.only(top: RasqSpacing.md), child: RasqLoading()),
            ]),
    );
  }
}
