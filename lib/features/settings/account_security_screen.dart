import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/account_security_api.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;

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
  bool _busy = false;

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
    for (final c in [_email, _emailCode, _password, _currentPassword, _passwordCode, _confirmCode]) {
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
          RasqListTile(key: const ValueKey('security.toLogin'), title: '既存の RASQ アカウントにログイン', subtitle: 'ハンドル / メールとパスワード、またはメールのコード', onTap: () => context.push('/settings/account-login')),
        ]),
      );
    }
    final pendingMail = account.emailPending;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'アカウントのセキュリティ'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        // ── メール ──
        const RasqSectionHeader(title: 'メールアドレス'),
        pad(Text('登録すると、パスワードを忘れたときの再設定、メールでのログイン、大事な操作の確認とお知らせに使えます。ほかの人には見えません。メールに届くのは 確認コードだけです(リンクは送りません)。', style: caption)),
        RasqValueListTile(key: const ValueKey('security.email'), title: 'いまのメール', value: account.emailVerified ? (account.email ?? '') : '未登録'),
        pad(Row(children: [
          Expanded(child: RasqInput(key: const ValueKey('security.email.input'), controller: _email, hintText: account.emailVerified ? '新しいメールアドレス' : 'メールアドレス', keyboardType: TextInputType.emailAddress)),
          const SizedBox(width: RasqSpacing.sm),
          FilledButton(
            key: const ValueKey('security.email.send'),
            onPressed: _busy ? null : () => _run((api) async {
                  await api.setEmail(_email.text.trim());
                  _emailCode.clear();
                  return '確認コードを送りました';
                }),
            child: const Text('コードを送る'),
          ),
        ])),
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
              : 'パスワードを付けると、別の端末からハンドル(かメール)とパスワードで同じアカウントに入れます。',
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
          pad(Text('パスワードは、同期した設定の暗号化にも使います。「パスワードの再設定」(ログイン画面)をすると、前のパスワードで暗号化したデータは復号できなくなります。', style: caption)),

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

  Future<void> _delete() async {
    final account = ref.read(orgateAccountProvider).value;
    if (account == null) return;
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'security.delete.confirm',
          title: 'RASQ アカウントを削除',
          message: 'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、AsTell のルームと共有、通知トークン、同意の記録を削除します。元に戻せません。',
          confirmText: account.emailVerified ? '確認コードを送る' : '削除する',
          cancelText: 'キャンセル',
          destructive: true,
        );
    if (!ok || !mounted) return;
    if (account.emailVerified) return _sendConfirm(ConfirmAction.accountDelete);
    await _deleteWith(null);
  }

  Future<void> _deleteWith(String? code) async {
    setState(() => _busy = true);
    try {
      final central = ref.read(rasqAccountsProvider).value?.central;
      await ref.read(orgateAccountProvider.notifier).deleteAccount(code: code);
      _toast('RASQ アカウントを削除しました');
      // 先に閉じてから台帳を直す(ログインと同じ理由: ルーターの作り直しと重ねない)。
      final ledger = ref.read(rasqAccountsProvider.notifier);
      if (mounted) context.pop();
      if (central != null) await ledger.detachCentral(central.id);
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
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[1-9A-HJ-NP-Za-km-z\- ]')), LengthLimitingTextInputFormatter(16)],
        decoration: const InputDecoration(hintText: '確認コード(例 3mJr7-AoUXx)', isDense: true),
        style: const TextStyle(letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
      );
}

/// 既存の RASQ アカウントにログイン (D-268 / S-019): ハンドル(かメール)+ パスワード / メールのコード / パスワードの再設定。
class AccountLoginScreen extends ConsumerStatefulWidget {
  const AccountLoginScreen({super.key});
  @override
  ConsumerState<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

enum _LoginMode { password, code, reset }

class _AccountLoginScreenState extends ConsumerState<AccountLoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _LoginMode _mode = _LoginMode.password;
  bool _busy = false;
  bool _codeSent = false;

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
    if (api == null) return _toast('RASQ Central の接続先が未設定です');
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

  /// ログインできた → **先に画面を閉じてから**、アカウントをこの端末のものにする。
  /// 下の画面(止まっている Consumer)が動き出す瞬間にアカウントが変わっていると、Riverpod が build の最中に作り直しを
  /// 始めてしまう。台帳の変化はルーターの作り直し(refresh)も起こし、閉じるのと重なると、閉じたはずの画面が戻ってくる。
  Future<void> _adopt(Map<String, Object?> res) async {
    final accounts = ref.read(orgateAccountProvider.notifier);
    final ledger = ref.read(rasqAccountsProvider.notifier);
    final messenger = ref.read(rootMessengerKeyProvider);
    if (mounted) context.pop();
    await WidgetsBinding.instance.endOfFrame;
    final account = await accounts.adoptLogin(res);
    if (account == null) {
      messenger.currentState?.showSnackBar(const SnackBar(content: Text('ログインできませんでした')));
      return;
    }
    await ledger.attachCentral(centralAccountId: account.id, handle: account.handle, displayName: account.displayName, avatarUrl: account.avatarUrl);
    messenger.currentState?.showSnackBar(SnackBar(content: Text('@${account.handle} にログインしました')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    final notifier = ref.read(orgateAccountProvider.notifier);
    return Scaffold(
      appBar: const RasqPageHeader(title: 'RASQ アカウントにログイン'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        pad(SegmentedButton<_LoginMode>(
          segments: const [
            ButtonSegment(value: _LoginMode.password, label: Text('パスワード')),
            ButtonSegment(value: _LoginMode.code, label: Text('メールのコード')),
            ButtonSegment(value: _LoginMode.reset, label: Text('再設定')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _codeSent = false;
            _code.clear();
          }),
        )),
        pad(Text(
          switch (_mode) {
            _LoginMode.password => 'ハンドル(@ は無くてもよい)か、確認済みのメールアドレスと、パスワードで入ります。',
            _LoginMode.code => '確認済みのメールアドレスへ確認コードを送ります。パスワードは要りません。',
            _LoginMode.reset => '確認済みのメールアドレスへコードを送り、新しいパスワードを決めます。すべての端末がログアウトになり、前のパスワードで暗号化した同期データは復号できなくなります。',
          },
          style: caption,
        )),
        pad(RasqInput(key: const ValueKey('login.identifier'), controller: _identifier, hintText: _mode == _LoginMode.password ? 'ハンドル または メールアドレス' : 'メールアドレス', keyboardType: TextInputType.emailAddress)),
        if (_mode != _LoginMode.password)
          pad(OutlinedButton(
            key: const ValueKey('login.sendCode'),
            onPressed: _busy ? null : () => _run((api) async {
                  final email = _identifier.text.trim();
                  await (_mode == _LoginMode.code ? api.requestLoginCode(email) : api.requestPasswordReset(email));
                  setState(() => _codeSent = true);
                  _toast('そのメールアドレスのアカウントがあれば、コードを送りました');
                }),
            child: Text(_codeSent ? 'コードを送り直す' : 'コードを送る'),
          )),
        if (_mode != _LoginMode.password && _codeSent) pad(_CodeInput(key: const ValueKey('login.code'), controller: _code)),
        if (_mode == _LoginMode.password || (_mode == _LoginMode.reset && _codeSent))
          pad(RasqInput(key: const ValueKey('login.password'), controller: _password, hintText: _mode == _LoginMode.reset ? '新しいパスワード(8 文字以上)' : 'パスワード', obscureText: true)),
        if (_mode == _LoginMode.password || _codeSent)
          pad(FilledButton(
            key: const ValueKey('login.submit'),
            onPressed: _busy ? null : () => _run((api) async {
                  final id = _identifier.text.trim();
                  final device = await notifier.ensureDeviceId();
                  final label = accountDeviceLabel();
                  switch (_mode) {
                    case _LoginMode.password:
                      await _adopt(await api.login(identifier: id, password: _password.text, deviceId: device, label: label));
                    case _LoginMode.code:
                      await _adopt(await api.loginWithCode(email: id, code: _code.text.trim(), deviceId: device, label: label));
                    case _LoginMode.reset:
                      await api.confirmPasswordReset(email: id, code: _code.text.trim(), password: _password.text);
                      await _adopt(await api.login(identifier: id, password: _password.text, deviceId: device, label: label));
                  }
                }),
            child: Text(_mode == _LoginMode.reset ? 'パスワードを決めてログイン' : 'ログイン'),
          )),
      ]),
    );
  }
}
