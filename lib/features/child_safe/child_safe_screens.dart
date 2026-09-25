import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../settings/account_security_screen.dart' show accountDeviceLabel;
import 'child_gate.dart';
import 'child_safe_api.dart';
import 'child_safe_links.dart';
import 'child_safe_policy.dart';
import 'child_safe_providers.dart';

export 'child_safe_links.dart' show childSafeCodeFromInput;

/// チャイルドセーフの画面(子の側と入口)(D-307)。保護者の画面は guardian_screen.dart。

Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);

void _toast(WidgetRef ref, String m) => ref.read(rootMessengerKeyProvider).currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

/// 「見守り中」の印(バンドルのタイル / 画面の見出し)。
class ChildSafeBadge extends StatelessWidget {
  const ChildSafeBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('childSafe.badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.child_care_outlined, size: 12, color: scheme.onTertiaryContainer),
        const SizedBox(width: 2),
        Text('見守り中', style: RasqTypography.caption.copyWith(color: scheme.onTertiaryContainer)),
      ]),
    );
  }
}

/// 見守りの時間の帯(シェルの上)。時間の外 / 見守られていなければ何も出さない。
class ChildSafeWindowBanner extends ConsumerWidget {
  const ChildSafeWindowBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(childGateProvider);
    if (!gate.inTimeWindow) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final topics = gate.policy!.time.topics;
    final list = topics.topics.join('・');
    return Material(
      key: const ValueKey('childSafe.windowBanner'),
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 6),
          child: Row(children: [
            Icon(Icons.bedtime_outlined, size: 16, color: scheme.onTertiaryContainer),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Text(
                '見守りの時間(${gate.windowLabel})です。${topics.allow ? (list.isEmpty ? '投稿は流れません' : '「$list」の話題だけが流れます') : (list.isEmpty ? '' : '「$list」の話題は流れません')}',
                style: RasqTypography.caption.copyWith(color: scheme.onTertiaryContainer),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 止めている面の代わりに出す(理由つき)。
class ChildSafeBlockedView extends StatelessWidget {
  const ChildSafeBlockedView({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => RasqEmptyView(key: const ValueKey('childSafe.blocked'), title: message, hint: '見守りの設定は保護者が決めています');
}

/// 止めている行 / ボタンを薄くして、押したら理由を出す。
class ChildSafeGreyed extends ConsumerWidget {
  const ChildSafeGreyed({super.key, required this.reason, required this.child});
  final String? reason;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reason == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toast(ref, reason!),
      child: Opacity(opacity: 0.38, child: AbsorbPointer(child: child)),
    );
  }
}

/// チャイルドセーフの入口 (`/child-safe`): 見守られている状態 / 保護者として見守る / 子としてつなぐ / セーフモード。
class ChildSafeHubScreen extends ConsumerWidget {
  const ChildSafeHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final cs = ref.watch(childSafeProvider).value ?? const ChildSafeState();
    final account = ref.watch(orgateAccountProvider).value;
    final gate = ref.watch(childGateProvider);
    return Scaffold(
      appBar: const RasqPageHeader(title: 'チャイルドセーフ'),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        _pad(Text('保護者の RASQ アカウントが、子の RASQ アカウントの使い方を決めます。投稿の判定はこの端末の中で行い、保護者に届くのは、送った数と止めた数と話題の見出しだけです(投稿の本文は送りません)。', style: caption)),
        if (cs.managed) ...[
          const RasqSectionHeader(title: '見守られています'),
          RasqValueListTile(key: const ValueKey('childSafe.hub.parent'), title: '保護者', value: cs.parentDisplayName?.isNotEmpty == true ? '${cs.parentDisplayName} (@${cs.parentHandle})' : '@${cs.parentHandle ?? '—'}'),
          RasqValueListTile(title: '状態', value: cs.locked ? '設定待ち' : '見守り中(設定 ${cs.revision})'),
          if (cs.offline) _pad(Text('いまは Central に届きません。前の設定のまま見守ります。', style: caption)),
          if (cs.error != null) _pad(Text(cs.error!, style: caption.copyWith(color: scheme.error))),
          if (!cs.locked) ...[for (final l in childSafeSummaryLines(gate)) _pad(Text('・$l', style: RasqTypography.bodySmall))],
          RasqListTile(key: const ValueKey('childSafe.hub.refresh'), title: '保護者の設定を取り直す', chevron: false, onTap: () => ref.read(childSafeProvider.notifier).refresh()),
        ],
        const RasqSectionHeader(title: '保護者として'),
        RasqListTile(
          key: const ValueKey('childSafe.hub.guardian'),
          title: '見守る(保護者)',
          subtitle: cs.guardian.verified ? '確認済み(${cs.guardian.methodLabel})。子のアカウントを作る / つなぐ / 設定' : '保護者の確認は Web コンソールで(日本はマイナンバーカード、ほかは自己申告)',
          enabled: account != null && !cs.managed,
          onTap: () => context.push('/child-safe/guardian'),
        ),
        const RasqSectionHeader(title: '子として'),
        if (!cs.managed)
          RasqListTile(
            key: const ValueKey('childSafe.hub.childMode'),
            title: 'チャイルドモード',
            subtitle: account == null ? '保護者からのコードでログインします' : 'このアカウントを、保護者のコードでつなぎます',
            onTap: () => context.push(account == null ? '/child-safe/login' : '/child-safe/pair'),
          ),
        if (account == null) RasqListTile(key: const ValueKey('childSafe.hub.login'), title: '保護者からのコードでログイン', subtitle: '保護者が作った子のアカウントに入ります', onTap: () => context.push('/child-safe/login')),
        const RasqSectionHeader(title: 'この端末'),
        RasqListTile(title: 'プライバシーとセーフモード', subtitle: cs.managed ? '見守り中は、閲覧注意のメディアを必ず隠します(変えられません)' : '閲覧注意メディアの扱い', onTap: () => context.push('/settings/dsl/sns.safety')),
      ]),
    );
  }
}

/// 話題の一覧 (D-315) の短い注記(`(流す話題: a・b)`)。空のブラックリストは書かない。
String _topicsNote(ChildSafeTopics t, {required String allow, required String deny}) =>
    t.topics.isEmpty && !t.allow ? '' : '(${t.allow ? allow : deny}: ${t.topics.isEmpty ? 'なし' : t.topics.join('・')})';

/// 見守りの制限を、子に見せる短い行に。
List<String> childSafeSummaryLines(ChildGate gate) {
  final p = gate.policy;
  if (p == null) return const [];
  final out = <String>[
    if (p.timeline.enabled) 'タイムライン: ${p.timeline.level.label}${_topicsNote(p.timeline.topics, allow: '流す話題', deny: '見せない話題')}',
    if (p.composer.enabled) '投稿の判定: ${p.composer.level.label}${_topicsNote(p.composer.topics, allow: '送れる話題', deny: '送れない話題')}',
    if (p.postsPerDay != null) '1 日に送れる投稿: ${p.postsPerDay} 件',
    if (p.time.enabled) '見守りの時間: ${p.time.start}〜${p.time.end}${p.time.topics.isEmptyWhitelist ? '(投稿は流れません)' : _topicsNote(p.time.topics, allow: '流す話題', deny: '流さない話題')}',
  ];
  final a = p.allow;
  if (a != null) {
    if (a.sns != null) out.add('使える SNS: ${a.sns!.kinds.isEmpty ? 'どれでも' : a.sns!.kinds.join('・')}${a.sns!.instances.isEmpty ? '' : '(${a.sns!.instances.join('・')})'}${a.sns!.addAccounts ? '' : '、追加はできません'}');
    final off = [for (final e in {...?a.features}.entries) if (!e.value) ChildSafeCatalog.fallback.features.where((f) => f.id == e.key).firstOrNull?.label ?? e.key];
    if (off.isNotEmpty) out.add('止めている機能: ${off.join('・')}');
    final searchOff = [for (final e in {...?a.search}.entries) if (!e.value) ChildSafeCatalog.fallback.search.where((f) => f.id == e.key).firstOrNull?.label ?? e.key];
    if (searchOff.isNotEmpty) out.add('止めている検索: ${searchOff.join('・')}');
    if (a.plugins != null) {
      final ids = a.plugins!.ids.length;
      out.add('プラグイン: ${switch (a.plugins!.install) {
        ChildSafeInstall.any => 'どれでも',
        ChildSafeInstall.examples => '選んだ $ids 個と、許す例に近いもの',
        _ => '選んだ $ids 個だけ',
      }}・インストールは${a.plugins!.install.label}');
    }
    final ex = a.examples;
    if (ex != null && ex.isNotEmpty) out.add('例: 許す例 ${ex.allow.length} / 止める例 ${ex.deny.length}(止める例に近いプラグイン / クリップ / リストは出ません)');
    if (a.rai != null) out.add(a.rai!.enabled ? 'RAi: ${a.rai!.groups.length} 種類の関数${a.rai!.automation ? '' : '(自動化なし)'}' : 'RAi: 使えません');
  }
  return out;
}

/// リンク(QR)から開いたときの注意: 入っているコードを確かめてから押す(自動では送らない)。
Widget _fromLinkNote(BuildContext context, String what) {
  final scheme = Theme.of(context).colorScheme;
  return _pad(Container(
    key: const ValueKey('childSafe.fromLink'),
    padding: const EdgeInsets.all(RasqSpacing.sm),
    decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
    child: Text('リンク(QR)からコードを入れました。自分の保護者から受け取ったものか確かめてから「$what」を押してください。知らない人のリンクなら、押さずに閉じてください。',
        style: RasqTypography.caption.copyWith(color: scheme.onTertiaryContainer)),
  ));
}

/// 子の端末: いまのアカウントを、保護者のコードでつなぐ (`POST /me/child-safe/pair`)。
/// [initialCode] = リンク `rasq://child-safe/pair?code=…`(端末のカメラで QR を読んだとき)から開いたときのコード(送らずに入れるだけ)。
class ChildPairScreen extends ConsumerStatefulWidget {
  const ChildPairScreen({super.key, this.initialCode});
  final String? initialCode;
  @override
  ConsumerState<ChildPairScreen> createState() => _ChildPairScreenState();
}

class _ChildPairScreenState extends ConsumerState<ChildPairScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  // 画面を開いたまま別のリンクが来たら、そのコードに入れ替える(送らない)。
  @override
  void didUpdateWidget(covariant ChildPairScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialCode != null && widget.initialCode != old.initialCode) _code.text = widget.initialCode!;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final code = childSafeCodeFromInput(_code.text);
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(childSafeProvider.notifier).pair(code);
      _toast(ref, '保護者とつなぎました。保護者が設定を決めるまで待ってください');
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final account = ref.watch(orgateAccountProvider).value;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'チャイルドモード'),
      body: ListView(children: [
        if (account == null) ...[
          _pad(Text('RASQ アカウントにログインしていません。保護者が作ったアカウントなら、保護者からのコードでログインします。', style: caption)),
          RasqListTile(title: '保護者からのコードでログイン', onTap: () => context.push('/child-safe/login')),
          RasqListTile(title: '既存の RASQ アカウントにログイン', onTap: () => context.push('/settings/account-login')),
        ] else ...[
          _pad(Text('@${account.handle} を、保護者の見守りにつなぎます。保護者の画面(アプリか Web コンソール)に出ているコード(8 字、例 ABCD-EFGH)を入れてください。つないだら、保護者が設定を決めるまでアプリは使えません。', style: caption)),
          if (widget.initialCode?.isNotEmpty == true) _fromLinkNote(context, 'つなぐ'),
          _pad(TextField(
            key: const ValueKey('childSafe.pair.code'),
            controller: _code,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'ABCD-EFGH', isDense: true),
            style: const TextStyle(letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
            onSubmitted: (_) => _pair(),
          )),
          if (_error != null) _pad(Text(_error!, key: const ValueKey('childSafe.pair.error'), style: caption.copyWith(color: scheme.error))),
          _pad(FilledButton(key: const ValueKey('childSafe.pair.submit'), onPressed: _busy ? null : _pair, child: const Text('つなぐ'))),
          // QR (D-309): アプリの中では読まない(カメラのパッケージは入れていない)。Android / iOS は端末のカメラアプリで
          // 読むと `rasq://child-safe/pair?code=…` でこの画面が開く。ほかの面はコードの入力と、リンクの貼り付け。
          _pad(Text(
            childSafeLinksOpenApp
                ? '保護者の画面の QR は、この端末のカメラアプリで読むと、コードが入った状態でこの画面が開きます。リンク(rasq://child-safe/pair?code=…)を貼り付けても、つなげます。'
                : 'この端末では QR を読めません。コードを入れるか、リンク(rasq://child-safe/pair?code=…)を貼り付けてください。',
            key: const ValueKey('childSafe.pair.qrHint'),
            style: caption,
          )),
        ],
      ]),
    );
  }
}

/// 子の端末: 保護者が作ったアカウントへ、1 度きりのコードでログイン (`POST /auth/child-login`)。
/// **この端末の SNS アカウントは引き継がない**(保護者の SNS のトークンも貸さない)。
/// [initialCode] = リンク `rasq://child-safe/login?code=…` から開いたときのコード(送らずに入れるだけ)。
class ChildLoginScreen extends ConsumerStatefulWidget {
  const ChildLoginScreen({super.key, this.initialCode});
  final String? initialCode;
  @override
  ConsumerState<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends ConsumerState<ChildLoginScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  // 画面を開いたまま別のリンクが来たら、そのコードに入れ替える(送らない)。
  @override
  void didUpdateWidget(covariant ChildLoginScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialCode != null && widget.initialCode != old.initialCode) _code.text = widget.initialCode!;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final api = ref.read(childSafeApiProvider);
    final code = childSafeCodeFromInput(_code.text);
    if (api == null) return setState(() => _error = 'RASQ Central の接続先が未設定です');
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final accounts = ref.read(orgateAccountProvider.notifier);
    final childSafe = ref.read(childSafeProvider.notifier);
    try {
      final res = await api.childLogin(code: code, deviceId: await accounts.ensureDeviceId());
      // 先に画面を閉じてから、アカウントをこの端末のものにする(ログイン画面と同じ理由)。
      if (mounted) context.pop();
      await WidgetsBinding.instance.endOfFrame;
      // 台帳にも載せて、いまのアカウントにする(いまのアカウントの SNS は持ち込まない。D-316)。
      final account = await accounts.adoptLogin(res);
      if (account == null) return _toast(ref, 'ログインできませんでした');
      await childSafe.refresh();
      _toast(ref, '@${account.handle} にログインしました(${accountDeviceLabel()})');
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: const RasqPageHeader(title: '保護者からのコードでログイン'),
      body: ListView(children: [
        _pad(Text('保護者がアプリで子のアカウントを作ると、1 度だけ使えるコードが出ます。そのコードを入れると、この端末がそのアカウントになります。この端末の SNS アカウントは引き継ぎません。', style: caption)),
        if (widget.initialCode?.isNotEmpty == true) _fromLinkNote(context, 'ログイン'),
        _pad(TextField(
          key: const ValueKey('childSafe.login.code'),
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ログインのコード', isDense: true),
          style: const TextStyle(letterSpacing: 2),
          onSubmitted: (_) => _login(),
        )),
        if (_error != null) _pad(Text(_error!, key: const ValueKey('childSafe.login.error'), style: caption.copyWith(color: scheme.error))),
        _pad(FilledButton(key: const ValueKey('childSafe.login.submit'), onPressed: _busy ? null : _login, child: const Text('ログイン'))),
      ]),
    );
  }
}

/// 設定待ちの鍵 (`/child-safe/pending`): 保護者が決めるまで、ここだけ(更新 / ログアウト)。
class ChildSafePendingScreen extends ConsumerWidget {
  const ChildSafePendingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cs = ref.watch(childSafeProvider).value ?? const ChildSafeState();
    final account = ref.watch(orgateAccountProvider).value;
    final parent = cs.parentDisplayName?.isNotEmpty == true ? cs.parentDisplayName! : (cs.parentHandle == null ? '保護者' : '@${cs.parentHandle}');
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(RasqSpacing.page),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.child_care_outlined, size: 48, color: scheme.primary),
                  const SizedBox(height: RasqSpacing.md),
                  Text(cs.state == 'unverified' ? '保護者の設定を確かめられません' : '保護者が設定を決めるまで待ってください', key: const ValueKey('childSafe.pending.title'), style: RasqTypography.title, textAlign: TextAlign.center),
                  const SizedBox(height: RasqSpacing.sm),
                  Text(
                    cs.state == 'unverified' ? (cs.error ?? '設定の署名が合いません。') : '$parent と見守りでつながっています。$parent が使い方を決めると、使えるようになります。',
                    style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (cs.offline) Text('いまは Central に届きません。', style: RasqTypography.caption.copyWith(color: scheme.error), textAlign: TextAlign.center),
                  const SizedBox(height: RasqSpacing.lg),
                  if (account != null) ...[
                    FilledButton(key: const ValueKey('childSafe.pending.refresh'), onPressed: () => ref.read(childSafeProvider.notifier).refresh(), child: const Text('更新')),
                    const SizedBox(height: RasqSpacing.sm),
                    OutlinedButton(key: const ValueKey('childSafe.pending.logout'), onPressed: () => childSafeSignOut(ref), child: const Text('ログアウト')),
                  ] else ...[
                    FilledButton(onPressed: () => context.push('/child-safe/login'), child: const Text('保護者からのコードでログイン')),
                    const SizedBox(height: RasqSpacing.sm),
                    OutlinedButton(onPressed: () => context.push('/settings/account-login'), child: const Text('RASQ アカウントにログイン')),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 設定待ちの画面の「ログアウト」: RASQ アカウントからログアウトして台帳から外す。まだ守る制限が無ければ控えも消える。
Future<void> childSafeSignOut(WidgetRef ref) async {
  final ledger = ref.read(rasqAccountsProvider.notifier);
  // いま使っている Central のアカウントからだけ出る(D-316: ほかの Central のアカウントのトークンは残す)。
  final me = ref.read(orgateAccountProvider).value;
  final central = ref.read(rasqAccountsProvider).value?.centralRecord(me?.id);
  final childSafe = ref.read(childSafeProvider.notifier);
  await ref.read(orgateAccountProvider.notifier).signOut(accountId: me?.id);
  if (central != null) await ledger.detachCentral(central.id);
  await childSafe.refresh();
}
