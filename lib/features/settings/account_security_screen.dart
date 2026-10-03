import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/account_security_api.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';
import '../onboarding/rasq_register_screen.dart' show rasqPasswordMinChars, rasqPasswordProblem;
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../../session/rasq_account_logout.dart';
import '../../session/sns_share.dart' show snsShareProvider;
import 'sns_share_section.dart';

/// この端末の呼び名(ログイン中の端末の一覧に出る)。
String accountDeviceLabel() => 'RASQ (${switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    }})';

String _ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes} 分前';
  if (d.inDays < 1) return '${d.inHours} 時間前';
  return '${d.inDays} 日前';
}

/// アカウントのセキュリティ (D-268 / S-019): メールアドレスの登録と確認、パスワード、ログイン中の端末、アカウントの削除。
/// メールで届くのはどれも 確認コード(リンクは無い)。
class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  ConsumerState<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  final _password = TextEditingController();
  final _currentPassword = TextEditingController();
  final _passwordCode = TextEditingController();
  final _confirmCode = TextEditingController();
  final _emailCurrentPassword = TextEditingController();
  final _emailChangeCode = TextEditingController();
  final _secondFactorPassword = TextEditingController();
  final _secondFactorCode = TextEditingController();
  bool _busy = false;

  /// ログインの 2 段階目を切ろうとしている(いまのパスワードかコードの欄を出す、D-419)。
  bool _disablingSecondFactor = false;

  /// コードを送った操作(入力欄を出す)。送り先の目安つき。
  ConfirmAction? _pending;
  String _pendingTo = '';
  List<RasqLoginSession>? _sessions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  @override
  void dispose() {
    for (final c in [_email, _emailCode, _password, _currentPassword, _passwordCode, _confirmCode, _emailCurrentPassword, _emailChangeCode, _secondFactorPassword, _secondFactorCode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    // 前のお知らせが残っていたら差し替える(並べて待たせない)。
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadSessions() async {
    final api = ref.read(accountSecurityApiProvider);
    if (api == null || ref.read(orgateAccountProvider).value == null) return;
    try {
      final list = await api.sessions();
      if (mounted) setState(() => _sessions = list);
      // 端末を失効させると、その端末の共有の鍵も消える (D-319)。共有の一覧も取り直す。
      if (mounted) ref.read(snsShareProvider.notifier).check();
    } on OrgateException catch (_) {}
  }

  /// 1 つの操作: 実行中はボタンを止め、失敗は 1 行で伝え、終わったら `/me` を取り直す。
  Future<void> _run(Future<String?> Function(AccountSecurityApi api) action) async {
    final api = ref.read(accountSecurityApiProvider);
    if (api == null || _busy) return;
    setState(() => _busy = true);
    try {
      final message = await action(api);
      await ref.read(orgateAccountProvider.notifier).refresh();
      if (message != null) _toast(message);
    } on OrgateException catch (e) {
      _toast(accountSecurityMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendConfirm(ConfirmAction action) => _run((api) async {
        final to = await api.requestConfirmation(action);
        setState(() {
          _pending = action;
          _pendingTo = to;
          _confirmCode.clear();
        });
        return '$to へ確認コードを送りました';
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(orgateAccountProvider).value;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    if (account == null) {
      return Scaffold(
        appBar: const RasqPageHeader(title: 'アカウントのセキュリティ'),
        body: ListView(children: [
          pad(Text('RASQ アカウントにログインしていません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
          RasqListTile(key: const ValueKey('security.toLogin'), title: '既存の RASQ アカウントにログイン', subtitle: 'ハンドル(かメール)とパスワード', onTap: () => context.push('/settings/account-login')),
        ]),
      );
    }
    final pendingMail = account.emailPending;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'アカウントのセキュリティ'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        // ── メール ──
        const RasqSectionHeader(title: 'メールアドレス'),
        const RasqCaption(
          'パスワードを忘れたときの再設定と、ログインの 2 段階目の確認に使います。ほかの人には見えません。',
          detail: '登録すると、パスワードを忘れたときの再設定、ほかの端末からログインするときの 2 段階目の確認(パスワードのあとにメールの確認コード)、大事な操作の確認とお知らせに使えます。'
              'メールを確認していないと、パスワードを忘れたときに再設定できません。ほかの人には見えません。',
          padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
        ),
        RasqValueListTile(key: const ValueKey('security.email'), title: 'いまのメール', value: account.emailVerified ? (account.email ?? '') : '未登録'),
        pad(Row(children: [
          Expanded(child: RasqInput(key: const ValueKey('security.email.input'), controller: _email, hintText: account.emailVerified ? '新しいメールアドレス' : 'メールアドレス', keyboardType: TextInputType.emailAddress)),
          const SizedBox(width: RasqSpacing.sm),
          FilledButton(
            key: const ValueKey('security.email.send'),
            onPressed: _busy ? null : () => _sendEmail(account),
            child: const Text('コードを送る'),
          ),
        ])),
        // 確認済みのメールの付け替え (ORGATE O-008): いまのパスワードか、いまのメールに届くコードで本人か確かめる。
        if (account.emailVerified) ...[
          pad(Text(
            account.hasPassword ? '付け替えるには、いまのパスワードか、いまのメールに届く確認コードが要ります。' : '付け替えるには、いまのメールに届く確認コードが要ります。',
            style: caption,
          )),
          if (account.hasPassword) pad(RasqInput(key: const ValueKey('security.email.currentPassword'), controller: _emailCurrentPassword, hintText: 'いまのパスワード', obscureText: true)),
          if (_pending == ConfirmAction.emailChange)
            pad(_CodeInput(key: const ValueKey('security.email.changeCode'), controller: _emailChangeCode))
          else
            pad(Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const ValueKey('security.email.byCode'),
                onPressed: _busy ? null : () => _sendConfirm(ConfirmAction.emailChange),
                child: const Text('いまのメールにコードを送る'),
              ),
            )),
        ],
        // パスワードを設定したアカウントが初めてメールを付ける (ORGATE O-009、D-408): いまのパスワードが要る
        // (トークンだけでメールを付けて、パスワードの再設定に使わせない)。パスワードの無いアカウントは何も要らない。
        if (!account.emailVerified && account.hasPassword) ...[
          pad(Text('パスワードを設定したアカウントでは、メールアドレスを付けるのにいまのパスワードが要ります。', key: const ValueKey('security.email.needsPassword'), style: caption)),
          pad(RasqInput(key: const ValueKey('security.email.currentPassword'), controller: _emailCurrentPassword, hintText: 'いまのパスワード', obscureText: true)),
        ],
        if (pendingMail != null) ...[
          pad(Text('$pendingMail に届いたコードを入れてください(15 分で無効になります)。', key: const ValueKey('security.email.pending'), style: caption)),
          pad(Row(children: [
            Expanded(child: _CodeInput(key: const ValueKey('security.email.code'), controller: _emailCode)),
            const SizedBox(width: RasqSpacing.sm),
            FilledButton(
              key: const ValueKey('security.email.verify'),
              onPressed: _busy ? null : () => _run((api) async {
                    await api.verifyEmail(_emailCode.text.trim());
                    _email.clear();
                    _emailCode.clear();
                    return 'メールアドレスを確認しました';
                  }),
              child: const Text('確認'),
            ),
          ])),
        ],
        if (account.emailVerified)
          RasqListTile(key: const ValueKey('security.email.remove'), title: 'メールアドレスを外す', subtitle: '確認コードが要ります', chevron: false, onTap: _busy ? null : () => _sendConfirm(ConfirmAction.emailRemove)),

        // ── パスワード ──
        const RasqSectionHeader(title: 'パスワード'),
        pad(Text(
          account.hasPassword
              ? '変えると、ほかの端末はログアウトになります。いまのパスワードか、メールの確認コードが要ります。'
              : 'パスワードが無いと、ほかの端末からはログインできません(この端末でだけ使えます)。付けると、別の端末からハンドル(かメール)とパスワードで同じアカウントに入れます。',
          style: caption,
        )),
        if (account.hasPassword) pad(RasqInput(key: const ValueKey('security.password.current'), controller: _currentPassword, hintText: 'いまのパスワード', obscureText: true)),
        pad(RasqInput(key: const ValueKey('security.password.new'), controller: _password, hintText: account.hasPassword ? '新しいパスワード(8 文字以上)' : 'パスワード(8 文字以上)', obscureText: true)),
        if (account.hasPassword && _pending == ConfirmAction.passwordChange) pad(_CodeInput(key: const ValueKey('security.password.code'), controller: _passwordCode)),
        pad(Row(children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('security.password.save'),
              onPressed: _busy ? null : () => _run((api) async {
                    final current = _currentPassword.text;
                    final code = _passwordCode.text.trim();
                    await api.setPassword(_password.text, currentPassword: current.isEmpty ? null : current, code: code.isEmpty ? null : code);
                    _password.clear();
                    _currentPassword.clear();
                    _passwordCode.clear();
                    if (_pending == ConfirmAction.passwordChange) _pending = null;
                    await _loadSessions();
                    return account.hasPassword ? 'パスワードを変えました' : 'パスワードを設定しました';
                  }),
              child: Text(account.hasPassword ? 'パスワードを変える' : 'パスワードを設定'),
            ),
          ),
          if (account.hasPassword && account.emailVerified) ...[
            const SizedBox(width: RasqSpacing.sm),
            OutlinedButton(key: const ValueKey('security.password.byCode'), onPressed: _busy ? null : () => _sendConfirm(ConfirmAction.passwordChange), child: const Text('メールのコードで変える')),
          ],
        ])),
        if (account.hasPassword)
          const RasqNotice.warning(
            text: 'パスワードを「再設定」すると、同期した設定は読めなくなります。',
            detail: 'パスワードは、同期した設定の暗号化にも使います。「パスワードの再設定」(ログイン画面)をすると、前のパスワードで暗号化したデータは復号できなくなります。',
          ),

        // ── ログインの 2 段階目 (D-419 / ORGATE O-010) ──
        const RasqSectionHeader(title: 'ログインの 2 段階目'),
        pad(Text(
          !account.emailVerified
              ? 'メールアドレスを確認すると、ほかの端末からログインするとき、パスワードのあとにメールの確認コードも求めます(既定で ON)。'
              : account.secondFactorActive
                  ? 'ほかの端末からログインするとき、パスワードのあとに、メールに届く確認コード(10 分有効)も求めます。'
                  : '切っています。ほかの端末からは、パスワードだけでログインできます。',
          key: const ValueKey('security.2fa.state'),
          style: caption,
        )),
        RasqListTile(
          key: const ValueKey('security.2fa'),
          title: 'メールの確認コードも求める',
          subtitle: account.emailVerified ? null : 'メールアドレスの確認が要ります',
          chevron: false,
          trailing: Switch(
            key: const ValueKey('security.2fa.switch'),
            value: account.emailVerified && account.secondFactor && !_disablingSecondFactor,
            onChanged: !account.emailVerified || _busy
                ? null
                : (on) {
                    if (on) {
                      setState(() => _disablingSecondFactor = false);
                      if (!account.secondFactor) {
                        _run((api) async {
                          await api.setSecondFactor(enabled: true);
                          return 'ログインの 2 段階目を入れました';
                        });
                      }
                    } else {
                      setState(() => _disablingSecondFactor = true);
                    }
                  },
          ),
        ),
        if (_disablingSecondFactor && account.emailVerified) ...[
          pad(Text(
            account.hasPassword ? '切るには、いまのパスワードか、メールに届く確認コードが要ります。' : '切るには、メールに届く確認コードが要ります。',
            style: caption,
          )),
          if (account.hasPassword) pad(RasqInput(key: const ValueKey('security.2fa.password'), controller: _secondFactorPassword, hintText: 'いまのパスワード', obscureText: true)),
          if (_pending == ConfirmAction.secondFactorDisable)
            pad(_CodeInput(key: const ValueKey('security.2fa.code'), controller: _secondFactorCode))
          else
            pad(Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const ValueKey('security.2fa.byCode'),
                onPressed: _busy ? null : () => _sendConfirm(ConfirmAction.secondFactorDisable),
                child: const Text('メールにコードを送る'),
              ),
            )),
          pad(Row(children: [
            TextButton(key: const ValueKey('security.2fa.cancel'), onPressed: _busy ? null : () => setState(() => _disablingSecondFactor = false), child: const Text('やめる')),
            const Spacer(),
            FilledButton(
              key: const ValueKey('security.2fa.off'),
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: _busy ? null : () => _run((api) async {
                    final pw = _secondFactorPassword.text;
                    final code = _secondFactorCode.text.trim();
                    await api.setSecondFactor(enabled: false, currentPassword: pw.isEmpty ? null : pw, code: code.isEmpty ? null : code);
                    _secondFactorPassword.clear();
                    _secondFactorCode.clear();
                    if (_pending == ConfirmAction.secondFactorDisable) _pending = null;
                    _disablingSecondFactor = false;
                    return 'ログインの 2 段階目を切りました';
                  }),
              child: const Text('2 段階目を切る'),
            ),
          ])),
        ],

        // ── 端末 ──
        RasqSectionHeader(
          title: 'ログイン中の端末',
          trailing: (_sessions?.length ?? 0) > 1
              ? TextButton(
                  key: const ValueKey('security.sessions.revokeOthers'),
                  onPressed: _busy ? null : () => _run((api) async {
                        final n = await api.revokeOtherSessions();
                        await _loadSessions();
                        return 'ほかの $n 台をログアウトさせました';
                      }),
                  child: const Text('ほかを全部ログアウト'),
                )
              : null,
        ),
        if (_sessions == null)
          const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading())
        else
          for (final s in _sessions!)
            RasqListTile(
              key: ValueKey('security.session.${s.sessionId}'),
              title: '${s.label ?? s.deviceId ?? '名前のない端末'}${s.current ? '(この端末)' : ''}',
              subtitle: '最後に使った: ${_ago(s.lastUsedAt ?? s.createdAt)}${s.lastIp == null ? '' : ' ・ ${s.lastIp}'}${s.expiresAt == null ? '' : ' ・ 期限 ${s.expiresAt!.toLocal().toString().substring(0, 10)}'}',
              chevron: false,
              trailing: s.current
                  ? null
                  : TextButton(
                      onPressed: _busy ? null : () => _run((api) async {
                            await api.revokeSession(s.sessionId);
                            await _loadSessions();
                            return 'ログアウトさせました';
                          }),
                      child: const Text('ログアウト'),
                    ),
            ),

        // ── SNS のアクセストークンの共有 (D-319) ──
        const SnsShareSection(),

        // ── 確認コードの入力(メールを外す / 削除)──
        if (_pending == ConfirmAction.emailRemove || _pending == ConfirmAction.accountDelete) ...[
          RasqSectionHeader(title: _pending == ConfirmAction.accountDelete ? 'アカウントの削除の確認' : 'メールアドレスを外す確認'),
          pad(Text('$_pendingTo に届いたコードを入れてください。', style: caption)),
          pad(Row(children: [
            Expanded(child: _CodeInput(key: const ValueKey('security.confirm.code'), controller: _confirmCode)),
            const SizedBox(width: RasqSpacing.sm),
            FilledButton(
              key: const ValueKey('security.confirm.run'),
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: _busy ? null : _runPending,
              child: Text(_pending == ConfirmAction.accountDelete ? '削除する' : '外す'),
            ),
          ])),
        ],

        // ── 削除 ──
        const RasqSectionHeader(title: 'アカウントの削除'),
        RasqListTile(
          key: const ValueKey('security.delete'),
          title: 'RASQ アカウントを削除',
          subtitle: account.emailVerified ? 'メールの確認コードが要ります。元に戻せません' : '元に戻せません',
          chevron: false,
          onTap: _busy ? null : _delete,
        ),
        if (account.roles.isNotEmpty) ...[
          const RasqSectionHeader(title: '役割'),
          RasqValueListTile(title: 'このアカウントの役割', value: account.roles.map((r) => r == 'developer' ? '開発者' : (r == 'reviewer' ? '審査員' : r)).join(' / ')),
        ],
      ]),
    );
  }

  /// メールの登録 / 付け替え。確認済みのメールを別のアドレスへ付け替えるときは、いまのパスワードか `email.change` の
  /// 確認コードを添える(どちらも無ければ送らずに伝える。サーバーも 403 で断る、ORGATE O-008)。
  /// パスワードを設定したアカウントが初めて付けるときは、いまのパスワードを添える(無ければ送らない。ORGATE O-009)。
  Future<void> _sendEmail(RasqAccount account) async {
    final email = _email.text.trim();
    final current = _emailCurrentPassword.text;
    final code = _pending == ConfirmAction.emailChange ? _emailChangeCode.text.trim() : '';
    final replacing = account.emailVerified && email.toLowerCase() != (account.email ?? '').toLowerCase();
    final firstWithPassword = !account.emailVerified && account.hasPassword;
    if (replacing && current.isEmpty && code.isEmpty) {
      _toast(account.hasPassword ? 'いまのパスワードを入れるか、いまのメールに届く確認コードで確かめてください' : 'いまのメールに届く確認コードで確かめてください');
      return;
    }
    if (firstWithPassword && current.isEmpty) {
      _toast('いまのパスワードを入れてください');
      return;
    }
    await _run((api) async {
      await api.setEmail(email, currentPassword: (replacing || firstWithPassword) && current.isNotEmpty ? current : null, code: replacing && code.isNotEmpty ? code : null);
      _emailCode.clear();
      _emailCurrentPassword.clear();
      _emailChangeCode.clear();
      if (_pending == ConfirmAction.emailChange) _pending = null;
      return '確認コードを送りました';
    });
  }

  /// 削除のときに SNS アカウントをどうするか (D-409)。確認コードを待つあいだも覚えておく。
  RasqLogoutSns _deleteSns = RasqLogoutSns.logout;

  Future<void> _delete() async {
    final account = ref.read(orgateAccountProvider).value;
    if (account == null) return;
    final sns = await askRasqLogoutSns(
      ref.read,
      id: 'security.delete.confirm',
      title: 'RASQ アカウントを削除',
      message: 'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、AsTell のルームと共有、通知トークン、同意の記録を削除します。元に戻せません。',
      confirmText: account.emailVerified ? '確認コードを送る' : '削除する',
    );
    if (sns == null || !mounted) return;
    _deleteSns = sns;
    if (account.emailVerified) return _sendConfirm(ConfirmAction.accountDelete);
    await _deleteWith(null);
  }

  Future<void> _deleteWith(String? code) async {
    setState(() => _busy = true);
    // 閉じたあとは ref が使えないので、台帳はコンテナから読む。
    final read = ProviderScope.containerOf(context, listen: false).read;
    try {
      // 消すのは、いま使っている Central のアカウント(D-316: 台帳の「最初の」Central のアカウントではない)。
      final central = ref.read(rasqAccountsProvider).value?.centralRecord(ref.read(orgateAccountProvider).value?.id);
      await ref.read(orgateAccountProvider.notifier).deleteAccount(code: code);
      _toast('RASQ アカウントを削除しました');
      // 先に閉じてから台帳を直す(ログインと同じ理由: ルーターの作り直しと重ねない)。
      final sns = _deleteSns;
      if (mounted) context.pop();
      if (central != null) await releaseRasqAccount(read, central.id, sns: sns);
    } on OrgateException catch (e) {
      _toast(accountSecurityMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runPending() async {
    final code = _confirmCode.text.trim();
    if (_pending == ConfirmAction.accountDelete) return _deleteWith(code);
    await _run((api) async {
      await api.removeEmail(code: code);
      _pending = null;
      return 'メールアドレスを外しました';
    });
  }
}

/// 確認コードの欄に入ったものを、サーバーへ送る形に (S-028)。
/// - メールの確認リンク(`…/auth/email/open#p=…&e=…&t=<長いトークン>` や `rasq://auth/email?…&t=…`)を貼り付けたら、トークンだけを取り出す。
/// - それ以外は、Base58 と `-` / 空白だけを残す(短いコードは 10 文字、長いトークンは 40 文字)。
String emailCodeFromInput(String input) {
  final link = RegExp(r'[#?&]t=([1-9A-HJ-NP-Za-km-z]{20,64})').firstMatch(input);
  if (link != null) return link.group(1)!;
  final kept = input.replaceAll(RegExp(r'[^1-9A-HJ-NP-Za-km-z\- ]'), '');
  return kept.length > 48 ? kept.substring(0, 48) : kept;
}

/// 確認コードの欄(Base58 で 10 文字。メールには `3mJr7-AoUXx` の形で載る)。大文字と小文字は区別する。
/// 貼り付けの空白や `-` はサーバーが無視するので、そのまま送る(Base58 に無い字だけ落とす)。
class _CodeInput extends StatelessWidget {
  const _CodeInput({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        // 短いコードのほか、メールのリンク / QR の長いトークン (S-028) も受ける。リンクごと貼り付けたら、トークンだけを取り出す。
        inputFormatters: [TextInputFormatter.withFunction((_, next) => next.copyWith(text: emailCodeFromInput(next.text), selection: TextSelection.collapsed(offset: emailCodeFromInput(next.text).length)))],
        decoration: const InputDecoration(hintText: '確認コード(例 3mJr7-AoUXx)', helperText: 'メールのリンクを貼り付けても確認できます', isDense: true),
        style: const TextStyle(letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
      );
}

/// パスワードが無いアカウント / パスワード違いのときの案内 (D-419)。サーバーはどちらも同じ `401` を返す(アカウントがあるかを
/// 外から分からないように)ので、両方を言う。
const rasqLoginFailedHelp = 'ハンドル(メール)かパスワードが違います。\n'
    'パスワードを設定していない RASQ アカウントには、ほかの端末からはログインできません。そのアカウントを作った端末(いまもログインしている端末)で'
    '「設定 → アカウントのセキュリティ」からパスワードを設定してから、もう一度ログインしてください。';

/// 既存の RASQ アカウントにログイン (D-268 / S-019 → D-419): ハンドル(か確認済みのメール)+ **パスワード**。
/// 確認済みのメールがあるアカウントは、そのあとメールに届く確認コード(2 段階目、ORGATE O-010)。
/// メールのコードだけのログインは無くなった。パスワードを忘れたら [AccountResetScreen]。
class AccountLoginScreen extends ConsumerStatefulWidget {
  const AccountLoginScreen({super.key, this.initialIdentifier});

  /// 入れておくハンドル / メール(再設定のあとなど)。
  final String? initialIdentifier;

  @override
  ConsumerState<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends ConsumerState<AccountLoginScreen> {
  late final _identifier = TextEditingController(text: widget.initialIdentifier ?? '');
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  /// パスワードは合っていて、2 段階目のコードを待っている。
  RasqLoginChallenge? _challenge;

  /// フォームの下に残す案内(ログインできなかった理由)。
  String? _problem;

  @override
  void dispose() {
    for (final c in [_identifier, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    // 前のお知らせが残っていたら差し替える(並べて待たせない)。
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function(AccountSecurityApi api) action) async {
    final api = ref.read(accountSecurityApiProvider);
    if (api == null) return _toast('RASQ サーバーの接続先が未設定です');
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(api);
    } on OrgateException catch (e) {
      _toast(accountSecurityMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ログインできた → **先に画面を閉じてから**、アカウントをこの端末のものにする(台帳に載せて、いまのアカウントにする。
  /// いまのアカウントの SNS は持ち込まない。D-316)。
  /// 下の画面(止まっている Consumer)が動き出す瞬間にアカウントが変わっていると、Riverpod が build の最中に作り直しを
  /// 始めてしまう。台帳の変化はルーターの作り直し(refresh)も起こし、閉じるのと重なると、閉じたはずの画面が戻ってくる。
  Future<void> _adopt(Map<String, Object?> res) async {
    final accounts = ref.read(orgateAccountProvider.notifier);
    final messenger = ref.read(rootMessengerKeyProvider);
    if (mounted) context.pop();
    await WidgetsBinding.instance.endOfFrame;
    final account = await accounts.adoptLogin(res);
    if (account == null) {
      messenger.currentState?.showSnackBar(const SnackBar(content: Text('ログインできませんでした')));
      return;
    }
    messenger.currentState?.showSnackBar(SnackBar(content: Text('@${account.handle} にログインしました')));
  }

  /// パスワードの段。2 段階目が要れば、コードの入力へ(コードはメールに届く)。「送り直す」もここ(新しいコードになる)。
  Future<void> _login() => _run((api) async {
        final id = _identifier.text.trim();
        if (id.isEmpty || _password.text.isEmpty) return _toast('ハンドル(かメール)とパスワードを入れてください');
        setState(() => _problem = null);
        final device = await ref.read(orgateAccountProvider.notifier).ensureDeviceId();
        try {
          await _adopt(await api.login(identifier: id, password: _password.text, deviceId: device, label: accountDeviceLabel()));
        } on OrgateException catch (e) {
          final challenge = RasqLoginChallenge.of(e);
          if (challenge != null) {
            setState(() {
              _challenge = challenge;
              _code.clear();
            });
            return _toast('${challenge.email.isEmpty ? '確認済みのメール' : challenge.email} へ確認コードを送りました');
          }
          if (e.code.code == '401') return setState(() => _problem = rasqLoginFailedHelp);
          rethrow;
        }
      });

  /// 2 段階目: 届いたコード。
  Future<void> _confirm() => _run((api) async {
        final challenge = _challenge;
        final code = _code.text.trim();
        if (challenge == null || code.isEmpty) return;
        await _adopt(await api.confirmLogin(challengeId: challenge.challengeId, code: code));
      });

  Future<void> _forgot() async {
    final id = _identifier.text.trim();
    final email = await context.push<String>(Uri(path: '${Routes.settings}/account-reset', queryParameters: {if (id.contains('@')) 'email': id}).toString());
    if (email == null || !mounted) return;
    setState(() {
      _identifier.text = email;
      _password.clear();
      _challenge = null;
      _problem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    final challenge = _challenge;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'RASQ アカウントにログイン'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        if (challenge == null) ...[
          pad(Text(
            rasqDetail(context, 'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。',
                'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。確認済みのメールがあるアカウントは、そのあとメールに届く確認コードも入れます(2 段階目の確認)。'),
            style: caption,
          )),
          pad(RasqInput(key: const ValueKey('login.identifier'), controller: _identifier, hintText: 'ハンドル または メールアドレス', keyboardType: TextInputType.emailAddress)),
          pad(RasqInput(key: const ValueKey('login.password'), controller: _password, hintText: 'パスワード', obscureText: true, onSubmitted: (_) => _login())),
          pad(FilledButton(key: const ValueKey('login.submit'), onPressed: _busy ? null : _login, child: const Text('ログイン'))),
          if (_problem != null) RasqNotice.warning(key: const ValueKey('login.problem'), text: _problem!),
          pad(Align(
            alignment: Alignment.centerLeft,
            child: TextButton(key: const ValueKey('login.forgot'), onPressed: _busy ? null : _forgot, child: const Text('パスワードを忘れた')),
          )),
          pad(Text(
            'パスワードを設定していないアカウントは、ほかの端末からはログインできません(作った端末でだけ使えます)。'
            'その端末の「設定 → アカウントのセキュリティ」でパスワードを設定してください。',
            key: const ValueKey('login.noPasswordHint'),
            style: caption,
          )),
        ] else ...[
          // 2 段階目 (D-419 / ORGATE O-010)。
          const RasqSectionHeader(title: '確認コード'),
          pad(Text(
            '${challenge.email.isEmpty ? '確認済みのメールアドレス' : challenge.email} に確認コードを送りました(${(challenge.expiresInSeconds / 60).round()} 分有効、1 回きり)。届いたコードを入れてください。',
            key: const ValueKey('login.challenge'),
            style: caption,
          )),
          pad(_CodeInput(key: const ValueKey('login.code'), controller: _code)),
          pad(FilledButton(key: const ValueKey('login.confirm'), onPressed: _busy ? null : _confirm, child: const Text('確認してログイン'))),
          pad(Wrap(spacing: RasqSpacing.sm, children: [
            TextButton(key: const ValueKey('login.resend'), onPressed: _busy ? null : _login, child: const Text('コードを送り直す')),
            TextButton(
              key: const ValueKey('login.back'),
              onPressed: _busy ? null : () => setState(() => _challenge = null),
              child: const Text('ハンドル / パスワードに戻る'),
            ),
          ])),
          pad(Text('メールが届かないときは、迷惑メールのフォルダも見てください。ログインに心当たりが無いメールが届いたら、パスワードを変えてください。', style: caption)),
        ],
        // チャイルドセーフ (D-307): 保護者がアプリで作った子のアカウントへ、1 度きりのコードで入る。
        const RasqSectionHeader(title: '子のアカウント'),
        RasqListTile(key: const ValueKey('login.childCode'), title: '保護者からのコードでログイン', subtitle: '保護者が作った子のアカウントに入ります', onTap: () => context.push('/child-safe/login')),
      ]),
    );
  }
}

/// パスワードの再設定 (D-419 / ORGATE O-010): 確認済みのメールへコード(10 分)→ コード + 新しいパスワード。
/// **ほかの端末はすべてログアウト**(この端末のログインは残せる)。メールを確認していないアカウントは再設定できない
/// (元の端末でパスワードを設定するよう案内する)。アカウントがあるかどうかは、送ったあとの文面からも分からない。
/// 閉じるときに、入れたメールアドレスを返す(ログインの画面に入れる)。
class AccountResetScreen extends ConsumerStatefulWidget {
  const AccountResetScreen({super.key, this.initialEmail});
  final String? initialEmail;

  @override
  ConsumerState<AccountResetScreen> createState() => _AccountResetScreenState();
}

class _AccountResetScreenState extends ConsumerState<AccountResetScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  /// この端末のログインは残す(いまの RASQ アカウントが、再設定するアカウントと同じときだけサーバーが残す)。
  bool _keep = true;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function(AccountSecurityApi api) action) async {
    final api = ref.read(accountSecurityApiProvider);
    if (api == null) return _toast('RASQ サーバーの接続先が未設定です');
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(api);
    } on OrgateException catch (e) {
      _toast(accountSecurityMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run((api) async {
        final email = _email.text.trim();
        if (!email.contains('@')) return _toast('確認済みのメールアドレスを入れてください');
        await api.requestPasswordReset(email);
        setState(() => _sent = true);
        _toast('そのメールアドレスを確認済みのアカウントがあれば、確認コードを送りました(10 分有効)');
      });

  bool get _ready => _sent && _code.text.trim().isNotEmpty && _password.text.isNotEmpty && rasqPasswordProblem(_password.text) == null && _confirm.text == _password.text;

  Future<void> _submit() => _run((api) async {
        final notifier = ref.read(orgateAccountProvider.notifier);
        final signedIn = ref.read(orgateAccountProvider).value != null;
        final keep = signedIn && _keep;
        // この端末を残すなら、アクセストークンを新しくしておく(切れていると、サーバーはこの端末の分を見分けられない)。
        if (keep) {
          try {
            await notifier.refresh();
          } on OrgateException catch (_) {}
        }
        final email = _email.text.trim();
        final res = await api.confirmPasswordReset(email: email, code: _code.text.trim(), password: _password.text, keepCurrentSession: keep);
        final accountId = res.accountId;
        if (res.keptSession && res.restoreSecret != null && accountId != null) await notifier.storeRestoreSecret(accountId, res.restoreSecret!);
        // 下のログインの画面と同じ ScaffoldMessenger に出す(閉じたあとも残る)。
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        context.pop(email);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(res.keptSession
                ? 'パスワードを再設定しました。ほかの ${res.revokedSessions} 台の端末をログアウトしました'
                : 'パスワードを再設定しました(${res.revokedSessions} 台の端末をログアウトしました)。新しいパスワードでログインしてください'),
          ));
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    final signedIn = ref.watch(orgateAccountProvider).value != null;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'パスワードの再設定'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        pad(Text('確認済みのメールアドレスへ確認コード(10 分有効、1 回きり)を送り、新しいパスワードを決めます。ほかの端末はすべてログアウトになります。', style: caption)),
        const RasqNotice.warning(
          key: ValueKey('reset.noEmail'),
          text: 'メールアドレスを確認していないアカウントは、パスワードを再設定できません。',
          detail: 'そのアカウントを作った端末(いまもログインしている端末)で「設定 → アカウントのセキュリティ」から新しいパスワードを設定してください。'
              'その端末も無いときは、アカウントに戻る方法はありません。',
        ),
        pad(Row(children: [
          Expanded(child: RasqInput(key: const ValueKey('reset.email'), controller: _email, hintText: '確認済みのメールアドレス', keyboardType: TextInputType.emailAddress)),
          const SizedBox(width: RasqSpacing.sm),
          OutlinedButton(key: const ValueKey('reset.send'), onPressed: _busy ? null : _send, child: Text(_sent ? '送り直す' : 'コードを送る')),
        ])),
        if (_sent) ...[
          pad(_CodeInput(key: const ValueKey('reset.code'), controller: _code)),
          pad(TextField(
            key: const ValueKey('reset.password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: '新しいパスワード($rasqPasswordMinChars 文字以上)', errorText: rasqPasswordProblem(_password.text)),
          )),
          pad(TextField(
            key: const ValueKey('reset.passwordConfirm'),
            controller: _confirm,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: '新しいパスワード(確認)', errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text ? '一致しません' : null),
          )),
          if (signedIn)
            CheckboxListTile(
              key: const ValueKey('reset.keep'),
              value: _keep,
              onChanged: (v) => setState(() => _keep = v ?? true),
              title: const Text('この端末のログインは残す'),
              subtitle: Text('いまこの端末でログインしているアカウントの再設定のときだけ残ります', style: caption),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const RasqNotice.warning(
            text: '再設定すると、同期した設定は読めなくなります。',
            detail: 'パスワードは、同期した設定の暗号化にも使います。前のパスワードで暗号化したデータは復号できなくなります。',
          ),
          pad(FilledButton(
            key: const ValueKey('reset.submit'),
            onPressed: _busy || !_ready ? null : _submit,
            child: const Text('パスワードを再設定'),
          )),
        ],
      ]),
    );
  }
}
