import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../backend/account_security_api.dart';
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../backend/rasq_consent.dart';

/// RASQ アカウントの登録 FOW (D-241)。
///
/// 「作成」を押したあと、サーバーへ登録する**前**に出す:
/// 1. 利用規約 / プライバシーポリシーへの同意(文書は設定の「ヘルプ、法的表示」と同じページ)。
/// 2. 年齢の申告(13 歳以上。18 歳未満は保護者の同意)。
/// 3. アカウントバンドルを置き換えるか(この端末に SNS アカウントがあるときだけ)。
///
/// 学習へのデータ提供はここでは聞かない(別の任意の同意、既定は「なし」)。
const rasqRegisterFowId = 'fow.rasq.register';

/// パスワードの最短 (S-019)。
const rasqPasswordMinChars = 8;

Future<RasqRegisterChoice?> showRasqRegisterFow(OverlayManager manager, {required int snsCount, required ValueChanged<String> onOpenDoc, int column = 0}) {
  return manager.showFow<RasqRegisterChoice>(
    id: rasqRegisterFowId,
    spec: FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: 0.78,
      minHeightFactor: 0.4,
      maxHeightFactor: 0.92,
      title: 'RASQ アカウントの登録',
      cancelText: 'キャンセル',
      columnIndex: column,
    ),
    semanticsLabel: 'RASQ アカウントの登録',
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _RegisterPanel(
      snsCount: snsCount,
      onOpenDoc: onOpenDoc,
      onDone: (c) => handle.close(result: c),
    ),
  );
}

class _RegisterPanel extends StatefulWidget {
  const _RegisterPanel({required this.snsCount, required this.onOpenDoc, required this.onDone});
  final int snsCount;
  final ValueChanged<String> onOpenDoc;
  final ValueChanged<RasqRegisterChoice> onDone;

  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  bool _agree = false;
  RasqAgeBand? _age;
  bool _guardian = false;
  bool _replace = true;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// パスワードの手前の確かめ(サーバーの決まり S-019 と同じ: 8〜256 文字、1 種類の字だけは不可)。よくあるもの / ハンドルと同じ、はサーバーが断る。
  String? get _passwordError {
    final p = _password.text;
    if (p.isEmpty) return null;
    if (p.characters.length < rasqPasswordMinChars) return '$rasqPasswordMinChars 文字以上にしてください';
    if (p.characters.length > 256) return '256 文字までです';
    if (p.characters.toSet().length == 1) return '同じ字の繰り返しは使えません';
    return null;
  }

  bool get _passwordOk => _password.text.isNotEmpty && _passwordError == null && _confirm.text == _password.text;

  bool get _ready => _agree && _age != null && (!_age!.needsGuardian || _guardian) && _passwordOk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget check(Key key, String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) => RasqListTile(
          key: key,
          title: title,
          subtitle: subtitle,
          chevron: false,
          onTap: () => onChanged(!value),
          trailing: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        // 行は少ないので全部組む(遅延の ListView にしない = 画面外の行もテストと読み上げから見える)。
        child: SingleChildScrollView(
          key: const ValueKey('register.list'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const RasqSectionHeader(title: '利用規約とプライバシーポリシー'),
          RasqListTile(key: const ValueKey('register.terms'), title: '利用規約を読む', onTap: () => widget.onOpenDoc('/settings/dsl/about.terms')),
          RasqListTile(key: const ValueKey('register.privacy'), title: 'プライバシーポリシーを読む', onTap: () => widget.onOpenDoc('/settings/dsl/about.privacy')),
          check(const ValueKey('register.agree'), '利用規約とプライバシーポリシーに同意する', _agree, (v) => setState(() => _agree = v)),
          const RasqSectionHeader(title: '年齢'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Text('RASQ は 13 歳以上で使えます。18 歳未満の人は、保護者の同意が必要です。各 SNS の年齢の条件のほうが高い場合は、そちらにも従ってください。', style: caption),
          ),
          for (final a in RasqAgeBand.values)
            RasqRadioListTile<RasqAgeBand>(key: ValueKey('register.age.${a.wire}'), title: a.label, value: a, groupValue: _age, onChanged: (v) => setState(() => _age = v)),
          if (_age?.needsGuardian ?? false)
            check(const ValueKey('register.guardian'), '保護者の同意を得ています', _guardian, (v) => setState(() => _guardian = v)),
          if (widget.snsCount > 0) ...[
            const RasqSectionHeader(title: 'アカウントバンドル'),
            const RasqCaption(
              'サーバーには、まとめている SNS アカウントの一覧だけを送ります。SNS のログインの鍵は端末から出ません。',
              detail: 'サーバーには「どの SNS アカウントを束ねているか」だけを送ります。SNS のアクセストークンは端末から出ません。',
              padding: EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            ),
            RasqRadioListTile<bool>(
              key: const ValueKey('register.bundle.replace'),
              title: 'この端末の SNS アカウントで置き換える',
              subtitle: 'ログイン中の ${widget.snsCount} 件を、この RASQ アカウントにまとめます',
              detail: 'ログイン中の ${widget.snsCount} 件を RASQ アカウントのバンドルにします。サーバーに前のバンドルが残っていれば、この内容に置き換わります',
              value: true,
              groupValue: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
            RasqRadioListTile<bool>(
              key: const ValueKey('register.bundle.keep'),
              title: '置き換えない',
              subtitle: 'SNS アカウントはこの端末だけに残します',
              detail: 'SNS アカウントは「この端末のみ」に残します。サーバーのバンドルは消しません',
              value: false,
              groupValue: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
          ],
          // パスワード (D-299): 必須。ほかの端末 / Web 版からこのアカウントに入る手段になる(端末を失くしても戻れる)。
          const RasqSectionHeader(title: 'パスワード', topMargin: RasqSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                key: const ValueKey('register.password'),
                controller: _password,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'パスワード($rasqPasswordMinChars 文字以上)',
                  errorText: _passwordError,
                  suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility), tooltip: _show ? '隠す' : '表示', onPressed: () => setState(() => _show = !_show)),
                ),
              ),
              TextField(
                key: const ValueKey('register.passwordConfirm'),
                controller: _confirm,
                obscureText: !_show,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'パスワード(確認)', errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text ? '一致しません' : null),
              ),
              const SizedBox(height: RasqSpacing.xs),
              Text('ほかの端末や Web 版から、このアカウントにログインするときに使います。', style: caption),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
            child: Text('「アルゴリズムとコミュニティへの貢献」は、この登録には含まれません(別の任意の同意で、既定は「提供しない」です)。RASQ アカウントはいつでも削除できます。', style: caption),
          ),
        ])),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
        child: FilledButton(
          key: const ValueKey('register.submit'),
          onPressed: _ready ? () => widget.onDone(RasqRegisterChoice(age: _age!, replaceBundle: widget.snsCount > 0 ? _replace : true, password: _password.text)) : null,
          child: const Text('同意して登録する'),
        ),
      ),
    ]);
  }
}

/// 登録の一連 (D-241): FOW → `POST /auth/device` → 同意の記録 → 台帳へ載せる。
///
/// キャンセルなら null。接続先が無ければ [onMessage] で知らせて null。失敗は [OrgateException] のまま投げる。
Future<RasqAccountRecord?> registerRasqAccount(WidgetRef ref, {String? displayName, int column = 0, required ValueChanged<String> onMessage}) async {
  if (ref.read(centralClientProvider) == null) {
    onMessage('RASQ サーバーの接続先が設定されていません');
    return null;
  }
  final snsCount = ref.read(sessionsProvider).value?.sessions.length ?? 0;
  final choice = await showRasqRegisterFow(ref.read(overlayManagerProvider), snsCount: snsCount, column: column, onOpenDoc: (route) => ref.read(routerProvider).push(route));
  if (choice == null) return null;
  final notifier = ref.read(orgateAccountProvider.notifier);
  // 登録と承諾は一緒に (D-371 / S-053、規約案 06 CONS-02): サーバーが同じ処理で残す。承諾を残せなければアカウントも作られない
  // (以前は作ったあとで同意を書き、失敗しても登録を続けていた)。
  final RasqAccount? account;
  try {
    account = await notifier.createAccount(displayName: displayName, consents: choice.toConsentsJson());
  } on OrgateException catch (e) {
    if (isTermsVersionError(e)) {
      onMessage('利用規約が新しくなっています。アプリを更新してから、もう一度登録してください');
      return null;
    }
    rethrow;
  }
  if (account == null) {
    onMessage('RASQ サーバーの接続先が設定されていません');
    return null;
  }
  // 端末ですでに作っていたアカウントへ戻ったときは、承諾がまだなら承諾を送る(戻ったアカウントは作成の処理を通らない)。
  final client = ref.read(centralClientProvider);
  if (client != null && account.termsAccepted == false) {
    await RasqConsentApi(client).acceptCurrent(age: account.termsMissing.contains('age') ? choice.age : null);
    await notifier.refresh();
  }
  // パスワード (D-299)。すでに設定済みのアカウントへ戻ったとき(この端末の前のアカウント)は、変えない。
  final security = ref.read(accountSecurityApiProvider);
  if (choice.password.isNotEmpty && !account.hasPassword && security != null) {
    try {
      await security.setPassword(choice.password);
      await notifier.refresh();
    } on OrgateException catch (e) {
      onMessage('アカウントは作成しましたが、パスワードを設定できませんでした(${accountSecurityMessage(e)})。設定 →「アカウントの保護」から設定してください');
    }
  }
  if (notifier.lastRestored) onMessage('この端末の RASQ アカウントへ戻りました');
  return ref.read(rasqAccountsProvider.notifier).attachCentral(
        centralAccountId: account.id,
        handle: account.handle,
        displayName: account.displayName,
        avatarUrl: account.avatarUrl,
        inheritSessions: choice.replaceBundle,
      );
}
