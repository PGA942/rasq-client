import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
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

  bool get _ready => _agree && _age != null && (!_age!.needsGuardian || _guardian);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Text('サーバーには「どの SNS アカウントを束ねているか」だけを送ります。SNS のアクセストークンは端末から出ません。', style: caption),
            ),
            RasqRadioListTile<bool>(
              key: const ValueKey('register.bundle.replace'),
              title: 'この端末の SNS アカウントで置き換える',
              subtitle: 'ログイン中の ${widget.snsCount} 件を RASQ アカウントのバンドルにします。サーバーに前のバンドルが残っていれば、この内容に置き換わります',
              value: true,
              groupValue: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
            RasqRadioListTile<bool>(
              key: const ValueKey('register.bundle.keep'),
              title: '置き換えない',
              subtitle: 'SNS アカウントは「この端末のみ」に残します。サーバーのバンドルは消しません',
              value: false,
              groupValue: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
            child: Text('学習へのデータ提供は、この登録には含まれません(別の任意の同意で、既定は「提供しない」です)。RASQ アカウントはいつでも削除できます。', style: caption),
          ),
        ])),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
        child: FilledButton(
          key: const ValueKey('register.submit'),
          onPressed: _ready ? () => widget.onDone(RasqRegisterChoice(age: _age!, replaceBundle: widget.snsCount > 0 ? _replace : true)) : null,
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
    onMessage('RASQ Central の接続先が設定されていません');
    return null;
  }
  final snsCount = ref.read(sessionsProvider).value?.sessions.length ?? 0;
  final choice = await showRasqRegisterFow(ref.read(overlayManagerProvider), snsCount: snsCount, column: column, onOpenDoc: (route) => ref.read(routerProvider).push(route));
  if (choice == null) return null;
  final notifier = ref.read(orgateAccountProvider.notifier);
  final account = await notifier.createAccount(displayName: displayName);
  if (account == null) {
    onMessage('RASQ Central の接続先が設定されていません');
    return null;
  }
  final client = ref.read(centralClientProvider);
  if (client != null) {
    try {
      await RasqConsentApi(client).recordRegistration(choice);
    } on OrgateException catch (e) {
      // 古いサーバー(S-015 より前)には同意の口が無い。登録は続ける。
      debugPrint('rasq register: consent was not recorded: $e');
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
