import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show centralSignedInAccountIdsProvider, orgateAccountProvider;
import '../../l10n/l10n.dart';
import 'onboarding_steps.dart';

/// RASQ アカウントの入口 (D-138 → D-301): SNS のログインより先に出る。
///
/// - **初回**(台帳が空): 「作成しますか?」— 作成が主、ログインとスキップが従。
/// - **ログアウトしたあと**(オンボーディング済みで、RASQ アカウントが無い): 「ログイン」が主、作成とスキップが従。
///   Web 版では SNS のログインも RASQ アカウントに預けてある (D-300) ので、ここで入り直すと SNS のログインごと戻る。
/// - この端末でログインしたままのほかの RASQ アカウントが台帳にあれば(D-316 の複数アカウントで、ひとつからログアウト
///   した)、そのアカウントで続けるボタンも出す(D-318: パスワードを入れ直さずに切り替える)。
///
/// 旧: 初回オンボーディング (D-138): RASQ アカウントの作成を求める。
///
/// - **作成**: RASQ Central に端末登録 → 台帳に載せる → プロフィール編集 →
///   SNS ログインへ。導入したプラグイン/設定/バンドルが Central に同期される。
/// - **スキップ**: 従来のシステム(「この端末のみ」のアカウント。導入した
///   プラグインなどは端末上にのみ保存)。あとからサイドバーの … → RASQ
///   アカウント FOW で作成できる。
///
/// 既に SNS にログイン済みの端末(移行)には出さない —
/// [RasqAccountsNotifier.build] が従来のバンドルをローカルアカウントにして
/// `onboardingDone` を立てる。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  /// 新しく作る (D-414): ① のページ(ユーザー名・パスワード・年齢)→ ② 規約・チャイルドセーフ → 登録 → ③ SNS のログイン。
  void _create() => context.push(Routes.onboardingAccount);

  /// いまの RASQ アカウントが Central のもので、この端末がそのトークンを持っているか(ログインで台帳に載り、いまのアカウントに
  /// なる)。D-318: 台帳にほかの Central のアカウント / トークンの無い行が残っていても、それだけではログインできたことにしない。
  bool get _hasCentral {
    final id = ref.read(rasqAccountsProvider).value?.currentCentral?.centralAccountId;
    return id != null && ref.read(orgateAccountProvider.notifier).signedInAccountIds.contains(id);
  }

  /// すでに RASQ アカウントを持っている人 (D-296): ログイン(パスワード、必要なら 2 段階目のメールのコード)→ できていたら、オンボーディングを済みにする。
  Future<void> _login() async {
    await context.push('${Routes.settings}/account-login');
    // ログインできていれば、台帳に Central のアカウントが付いている(閉じたあとに付くので、少し待つ)。この端末の SNS を
    // 持ち込むかを聞いている間 (D-461) は、答えが出るまで待つ。
    final accounts = ref.read(orgateAccountProvider.notifier);
    for (var i = 0; mounted && !_hasCentral && (i < 50 || accounts.adopting); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || !_hasCentral) return;
    await ref.read(rasqAccountsProvider.notifier).completeOnboarding();
    await _proceed();
  }

  /// RASQ アカウントに入ったあと: SNS のログインが戻ってきていれば(Web 版 D-300 の保管庫 / そのアカウントの SNS)ホームへ、
  /// 無ければ SNS のログインへ。
  Future<void> _proceed() async {
    for (var i = 0; i < 20 && mounted && !_loggedIn; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) context.go(_loggedIn ? Routes.home : Routes.login);
  }

  /// この端末でログインしたままのほかの RASQ アカウントで続ける (D-318): 台帳で切り替えるだけ(トークンは端末にある)。
  Future<void> _resume(RasqAccountRecord r) async {
    setState(() => _busy = true);
    try {
      await ref.read(rasqAccountsProvider.notifier).select(r.id);
      try {
        await ref.read(orgateAccountProvider.future);
      } catch (_) {}
      await _proceed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _loggedIn => ref.read(sessionsProvider).value?.isLoggedIn ?? false;

  Future<void> _skip() async {
    setState(() => _busy = true);
    await ref.read(rasqAccountsProvider.notifier).completeOnboarding(skipped: true);
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final centralOk = ref.watch(centralConfiguredProvider);
    // ログアウトしたあと (D-301): 初回の案内ではなく、ログインを主にする。
    final ledger = ref.watch(rasqAccountsProvider).value;
    final returning = ledger?.onboardingDone ?? false;
    // この端末がトークンを持っている Central のアカウント(ひとつからログアウトしても、ほかは残る。D-316)。
    final signedIn = ref.watch(centralSignedInAccountIdsProvider) ?? const <String>{};
    final resumable = [for (final a in ledger?.accounts ?? const <RasqAccountRecord>[]) if (a.isCentral && signedIn.contains(a.centralAccountId)) a];

    Widget action({required Key key, required Widget icon, required String label, required VoidCallback? onPressed, required bool primary}) => primary
        ? FilledButton.icon(key: key, onPressed: onPressed, icon: icon, label: Text(label), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)))
        : OutlinedButton.icon(key: key, onPressed: onPressed, icon: icon, label: Text(label), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)));
    Widget create({required bool primary}) => action(
          key: const ValueKey('onboarding.create'),
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const RasqBrandIcon(size: 18),
          label: returning ? context.l10n.onboardingEntryCreateNew : context.l10n.onboardingEntryCreate,
          onPressed: _busy || !centralOk ? null : _create,
          primary: primary,
        );
    Widget login({required bool primary}) => action(
          key: const ValueKey('onboarding.login'),
          icon: const Icon(Icons.login, size: 18),
          label: context.l10n.onboardingEntryLogin,
          onPressed: _busy || !centralOk ? null : _login,
          primary: primary,
        );

    // 狭い画面 (D-412 → D-414): 左カラムが無いので、探す画面への入口を出す(前はサーバー / リストの見本のページ)。
    final discover = TextButton.icon(
      key: const ValueKey('onboarding.discover'),
      onPressed: _busy ? null : () => context.push(Routes.snsDiscover),
      icon: const Icon(Icons.travel_explore, size: 18),
      label: Text(context.l10n.onboardingEntryDiscover),
    );
    final resumeButtons = [
      for (final r in resumable) ...[
        const SizedBox(height: RasqSpacing.sm),
        OutlinedButton.icon(
          key: ValueKey('onboarding.resume.${r.id}'),
          onPressed: _busy ? null : () => _resume(r),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(r.handle == null ? context.l10n.onboardingEntryResume(r.displayName ?? context.l10n.onboardingEntryResumeFallbackName) : context.l10n.onboardingEntryResumeWithHandle(r.displayName ?? r.handle!, r.handle!), overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
      ],
    ];
    Widget skip() => OutlinedButton(
          key: const ValueKey('onboarding.skip'),
          onPressed: _busy ? null : _skip,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: Text(returning ? context.l10n.onboardingEntrySnsOnly : context.l10n.onboardingEntrySkip),
        );

    // 初回 (D-414): ① のページ(ユーザー名・パスワード・年齢)そのもの。下に、持っている人のログイン / スキップ。
    if (!returning) {
      return OnboardingFrame(
        builder: (context, narrow) => OnboardingAccountStep(narrow: narrow, alternatives: [
          ...resumeButtons,
          const SizedBox(height: RasqSpacing.sm),
          Row(children: [
            Expanded(
              child: TextButton(
                key: const ValueKey('onboarding.login'),
                onPressed: _busy || !centralOk ? null : _login,
                child: Text(context.l10n.onboardingEntryHaveAccount, textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const ValueKey('onboarding.skip'),
                onPressed: _busy ? null : _skip,
                child: Text(context.l10n.onboardingEntrySkip, textAlign: TextAlign.center),
              ),
            ),
          ]),
          if (narrow && centralOk) discover,
        ]),
      );
    }

    Widget content({required bool narrow}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(top: RasqSpacing.xxl, bottom: RasqSpacing.md), child: Center(child: RasqLogo(height: 44))),
            Text(returning ? context.l10n.onboardingEntryLoginQuestion : context.l10n.onboardingEntryCreateQuestion, style: RasqTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: RasqSpacing.md),
            Text(
              returning
                  ? context.l10n.onboardingEntryLoginBody
                  : context.l10n.onboardingEntryCreateBody,
              style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: RasqSpacing.sm),
            Text(
              returning
                  // Web 版 (D-300) は、SNS のログインも RASQ アカウントに預けてある。
                  ? (kIsWeb
                      // 規約案 02 第 4 項 (D-372): Web 版の保管庫はサーバーが復号できる方式。
                      ? context.l10n.onboardingEntryWebNote
                      : context.l10n.onboardingEntrySnsOnlyNote)
                  : context.l10n.onboardingEntrySkipNote,
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (narrow && centralOk) discover,
            login(primary: true),
            if (!centralOk)
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(context.l10n.onboardingNoCentral, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                TextButton(onPressed: () => context.push('${Routes.settings}/server'), child: Text(context.l10n.onboardingSetCentral)),
              ]),
            ...resumeButtons,
            const SizedBox(height: RasqSpacing.sm),
            create(primary: false),
            const SizedBox(height: RasqSpacing.sm),
            skip(),
            const SizedBox(height: RasqSpacing.xl),
          ]),
        );
    // 幅の広い画面 (D-405 → D-414): 2 カラム。左の小カラムに公開 RASQ リストの投稿、右の大型カラムに入口。
    return OnboardingFrame(builder: (context, narrow) => content(narrow: narrow));
  }
}
