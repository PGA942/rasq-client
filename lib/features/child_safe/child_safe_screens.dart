import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../settings/account_security_screen.dart' show accountDeviceLabel;
import '../../session/rasq_account_logout.dart';
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
        Text(context.l10n.childSafeScreensBadge, style: RasqTypography.caption.copyWith(color: scheme.onTertiaryContainer)),
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
    final l = context.l10n;
    final list = topics.topics.join(l.childSafeListSeparator);
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
                l.childSafeScreensWindowBanner(
                    gate.windowLabel, topics.allow ? (list.isEmpty ? l.childSafeScreensWindowNothing : l.childSafeScreensWindowAllowOnly(list)) : (list.isEmpty ? '' : l.childSafeScreensWindowDenied(list))),
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
  Widget build(BuildContext context) => RasqEmptyView(key: const ValueKey('childSafe.blocked'), title: message, hint: context.l10n.childSafeScreensBlockedHint);
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
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.childSafeScreensHubTitle),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        _pad(Text(rasqDetail(context, l.childSafeScreensHubIntro, l.childSafeScreensHubIntroDetail), style: caption)),
        if (cs.managed) ...[
          RasqSectionHeader(title: l.childSafeScreensHubManagedSection),
          RasqValueListTile(key: const ValueKey('childSafe.hub.parent'), title: l.childSafeScreensHubParent, value: cs.parentDisplayName?.isNotEmpty == true ? '${cs.parentDisplayName} (@${cs.parentHandle})' : '@${cs.parentHandle ?? '—'}'),
          RasqValueListTile(title: l.childSafeScreensHubState, value: cs.locked ? l.childSafeStatePending : l.childSafeScreensHubStateActive(cs.revision)),
          if (cs.offline) _pad(Text(l.childSafeScreensHubOffline, style: caption)),
          if (cs.error != null) _pad(Text(cs.error!, style: caption.copyWith(color: scheme.error))),
          if (!cs.locked) ...[for (final line in childSafeSummaryLines(gate)) _pad(Text(l.childSafeBullet(line), style: RasqTypography.bodySmall))],
          RasqListTile(key: const ValueKey('childSafe.hub.refresh'), title: l.childSafeScreensHubRefresh, chevron: false, onTap: () => ref.read(childSafeProvider.notifier).refresh()),
        ],
        RasqSectionHeader(title: l.childSafeScreensHubAsGuardian),
        RasqListTile(
          key: const ValueKey('childSafe.hub.guardian'),
          title: l.childSafeWatchAsGuardian,
          subtitle: cs.guardian.verified ? l.childSafeScreensHubGuardianVerified(cs.guardian.methodLabel) : l.childSafeScreensHubGuardianUnverified,
          enabled: account != null && !cs.managed,
          onTap: () => context.push('/child-safe/guardian'),
        ),
        RasqSectionHeader(title: l.childSafeScreensHubAsChild),
        if (!cs.managed)
          RasqListTile(
            key: const ValueKey('childSafe.hub.childMode'),
            title: l.childSafeChildMode,
            subtitle: account == null ? l.childSafeScreensHubChildModeLogin : l.childSafeScreensHubChildModePair,
            onTap: () => context.push(account == null ? '/child-safe/login' : '/child-safe/pair'),
          ),
        if (account == null) RasqListTile(key: const ValueKey('childSafe.hub.login'), title: l.childSafeLoginWithCode, subtitle: l.childSafeScreensHubLoginSubtitle, onTap: () => context.push('/child-safe/login')),
        RasqSectionHeader(title: l.childSafeScreensHubThisDevice),
        RasqListTile(title: l.childSafeScreensHubSafety, subtitle: cs.managed ? l.childSafeScreensHubSafetyManaged : l.childSafeScreensHubSafetyNormal, onTap: () => context.push('/settings/dsl/sns.safety')),
      ]),
    );
  }
}

/// 話題の一覧 (D-315) の短い注記(`(流す話題: a・b)`)。空のブラックリストは書かない。
String _topicsNote(ChildSafeTopics t, {required String allow, required String deny}) {
  final l = appL10n;
  return t.topics.isEmpty && !t.allow ? '' : l.childSafeScreensTopicsNote(t.allow ? allow : deny, t.topics.isEmpty ? l.childSafeScreensTopicsNone : t.topics.join(l.childSafeListSeparator));
}

/// 見守りの制限を、子に見せる短い行に。
List<String> childSafeSummaryLines(ChildGate gate) {
  final p = gate.policy;
  if (p == null) return const [];
  final l = appL10n;
  final sep = l.childSafeListSeparator;
  final out = <String>[
    if (p.timeline.enabled) l.childSafeScreensSummaryTimeline(p.timeline.level.label, _topicsNote(p.timeline.topics, allow: l.childSafeScreensTopicsShown, deny: l.childSafeScreensTopicsHidden)),
    if (p.composer.enabled) l.childSafeScreensSummaryComposer(p.composer.level.label, _topicsNote(p.composer.topics, allow: l.childSafeScreensTopicsSendable, deny: l.childSafeScreensTopicsUnsendable)),
    if (p.postsPerDay != null) l.childSafeScreensSummaryPostsPerDay(p.postsPerDay!),
    if (p.time.enabled)
      l.childSafeScreensSummaryTime(l.childSafeTimeRange(p.time.start, p.time.end),
          p.time.topics.isEmptyWhitelist ? l.childSafeScreensSummaryTimeNothing : _topicsNote(p.time.topics, allow: l.childSafeScreensTopicsShown, deny: l.childSafeScreensTopicsNotShown)),
  ];
  final a = p.allow;
  if (a != null) {
    if (a.sns != null) {
      out.add(l.childSafeScreensSummarySns(a.sns!.kinds.isEmpty ? l.childSafeScreensSummaryAny : a.sns!.kinds.join(sep), a.sns!.instances.isEmpty ? '' : l.childSafeScreensSummarySnsServers(a.sns!.instances.join(sep)),
          a.sns!.addAccounts ? '' : l.childSafeScreensSummarySnsNoAdd));
    }
    final off = [for (final e in {...?a.features}.entries) if (!e.value) ChildSafeCatalog.fallback.features.where((f) => f.id == e.key).firstOrNull?.label ?? e.key];
    if (off.isNotEmpty) out.add(l.childSafeScreensSummaryFeaturesOff(off.join(sep)));
    final searchOff = [for (final e in {...?a.search}.entries) if (!e.value) ChildSafeCatalog.fallback.search.where((f) => f.id == e.key).firstOrNull?.label ?? e.key];
    if (searchOff.isNotEmpty) out.add(l.childSafeScreensSummarySearchOff(searchOff.join(sep)));
    if (a.plugins != null) {
      final ids = a.plugins!.ids.length;
      out.add(l.childSafeScreensSummaryPlugins(
          switch (a.plugins!.install) {
            ChildSafeInstall.any => l.childSafeScreensSummaryAny,
            ChildSafeInstall.examples => l.childSafeScreensSummaryPluginsExamples(ids),
            _ => l.childSafeScreensSummaryPluginsListed(ids),
          },
          a.plugins!.install.label));
    }
    final ex = a.examples;
    if (ex != null && ex.isNotEmpty) out.add(l.childSafeScreensSummaryExamples(ex.allow.length, ex.deny.length));
    if (a.rai != null) out.add(a.rai!.enabled ? l.childSafeScreensSummaryRai(a.rai!.groups.length, a.rai!.automation ? '' : l.childSafeScreensSummaryRaiNoAuto) : l.childSafeScreensSummaryRaiOff);
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
    child: Text(context.l10n.childSafeScreensFromLink(what),
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
      _toast(ref, appL10n.childSafeScreensPaired);
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
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.childSafeChildMode),
      body: ListView(children: [
        if (account == null) ...[
          _pad(Text(l.childSafeScreensPairNotLoggedIn, style: caption)),
          RasqListTile(title: l.childSafeLoginWithCode, onTap: () => context.push('/child-safe/login')),
          RasqListTile(title: l.childSafeScreensPairExistingLogin, onTap: () => context.push('/settings/account-login')),
        ] else ...[
          _pad(Text(rasqDetail(context, l.childSafeScreensPairIntro(account.handle), l.childSafeScreensPairIntroDetail(account.handle)), style: caption)),
          if (widget.initialCode?.isNotEmpty == true) _fromLinkNote(context, l.childSafeScreensPairButton),
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
          _pad(FilledButton(key: const ValueKey('childSafe.pair.submit'), onPressed: _busy ? null : _pair, child: Text(l.childSafeScreensPairButton))),
          // QR (D-309): アプリの中では読まない(カメラのパッケージは入れていない)。Android / iOS は端末のカメラアプリで
          // 読むと `rasq://child-safe/pair?code=…` でこの画面が開く。ほかの面はコードの入力と、リンクの貼り付け。
          _pad(Text(
            childSafeLinksOpenApp
                ? rasqDetail(context, l.childSafeScreensPairQrHint, l.childSafeScreensPairQrHintDetail)
                : rasqDetail(context, l.childSafeScreensPairNoQr, l.childSafeScreensPairNoQrDetail),
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
    if (api == null) return setState(() => _error = context.l10n.childSafeNoServer);
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
      // 台帳にも載せて、いまのアカウントにする(いまのアカウントの SNS は持ち込まない。D-316)。この端末の SNS も、
      // 持ち込むかを聞かずに持ち込まない(画面で「引き継ぎません」と案内している。D-461)。
      final account = await accounts.adoptLogin(res, offerCarry: false);
      if (account == null) return _toast(ref, appL10n.childSafeScreensLoginFailed);
      await childSafe.refresh();
      _toast(ref, appL10n.childSafeScreensLoggedIn(account.handle, accountDeviceLabel()));
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
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.childSafeLoginWithCode),
      body: ListView(children: [
        _pad(Text(l.childSafeScreensLoginIntro, style: caption)),
        if (widget.initialCode?.isNotEmpty == true) _fromLinkNote(context, l.childSafeScreensLoginButton),
        _pad(TextField(
          key: const ValueKey('childSafe.login.code'),
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: l.childSafeScreensLoginCodeHint, isDense: true),
          style: const TextStyle(letterSpacing: 2),
          onSubmitted: (_) => _login(),
        )),
        if (_error != null) _pad(Text(_error!, key: const ValueKey('childSafe.login.error'), style: caption.copyWith(color: scheme.error))),
        _pad(FilledButton(key: const ValueKey('childSafe.login.submit'), onPressed: _busy ? null : _login, child: Text(l.childSafeScreensLoginButton))),
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
    final l = context.l10n;
    final parent = cs.parentDisplayName?.isNotEmpty == true ? cs.parentDisplayName! : (cs.parentHandle == null ? l.childSafeScreensPendingParent : '@${cs.parentHandle}');
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
                  Text(cs.state == 'unverified' ? l.childSafeScreensPendingUnverifiedTitle : l.childSafeScreensPendingTitle, key: const ValueKey('childSafe.pending.title'), style: RasqTypography.title, textAlign: TextAlign.center),
                  const SizedBox(height: RasqSpacing.sm),
                  Text(
                    cs.state == 'unverified' ? (cs.error ?? l.childSafeScreensPendingSignatureMismatch) : l.childSafeScreensPendingBody(parent),
                    style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (cs.offline) Text(l.childSafeScreensPendingOffline, style: RasqTypography.caption.copyWith(color: scheme.error), textAlign: TextAlign.center),
                  const SizedBox(height: RasqSpacing.lg),
                  if (account != null) ...[
                    FilledButton(key: const ValueKey('childSafe.pending.refresh'), onPressed: () => ref.read(childSafeProvider.notifier).refresh(), child: Text(l.childSafeScreensPendingRefresh)),
                    const SizedBox(height: RasqSpacing.sm),
                    OutlinedButton(key: const ValueKey('childSafe.pending.logout'), onPressed: () => childSafeSignOut(ref), child: Text(l.childSafeScreensPendingLogout)),
                  ] else ...[
                    FilledButton(onPressed: () => context.push('/child-safe/login'), child: Text(l.childSafeLoginWithCode)),
                    const SizedBox(height: RasqSpacing.sm),
                    OutlinedButton(onPressed: () => context.push('/settings/account-login'), child: Text(l.childSafeScreensPendingRasqLogin)),
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
/// SNS アカウントは既定(D-409: 「SNS アカウントもログアウトする」)で — 見守りの設定待ちの端末に、ほかのアカウントの
/// SNS を残さない。
Future<void> childSafeSignOut(WidgetRef ref) async {
  // いま使っている Central のアカウントからだけ出る(D-316: ほかの Central のアカウントのトークンは残す)。
  final me = ref.read(orgateAccountProvider).value;
  final central = ref.read(rasqAccountsProvider).value?.centralRecord(me?.id);
  final childSafe = ref.read(childSafeProvider.notifier);
  final read = ProviderScope.containerOf(ref.context, listen: false).read;
  await ref.read(orgateAccountProvider.notifier).signOut(accountId: me?.id);
  if (central != null) await releaseRasqAccount(read, central.id, sns: RasqLogoutSns.logout);
  await childSafe.refresh();
}
