import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show centralSignedInAccountIdsProvider, orgateAccountProvider;
import '../../shell/column_layout.dart';
import '../../shell/rasq_account_fow.dart';
import 'onboarding_previews.dart';
import 'rasq_register_screen.dart';

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

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      // 登録のページ (D-241 → D-405): 利用規約 / 年齢 / バンドルを置き換えるか → 登録 → 同意の記録。
      final rec = await registerRasqAccount(ref, onMessage: _toast);
      if (rec == null) return;
      await ref.read(rasqAccountsProvider.notifier).completeOnboarding();
      if (!mounted) return;
      await openRasqProfileSheet(context, ref, record: rec);
      if (mounted) context.go(Routes.login);
    } on OrgateException catch (e) {
      _toast('RASQ アカウントを作成できませんでした: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// いまの RASQ アカウントが Central のもので、この端末がそのトークンを持っているか(ログインで台帳に載り、いまのアカウントに
  /// なる)。D-318: 台帳にほかの Central のアカウント / トークンの無い行が残っていても、それだけではログインできたことにしない。
  bool get _hasCentral {
    final id = ref.read(rasqAccountsProvider).value?.currentCentral?.centralAccountId;
    return id != null && ref.read(orgateAccountProvider.notifier).signedInAccountIds.contains(id);
  }

  /// すでに RASQ アカウントを持っている人 (D-296): ログイン(パスワード / メールのコード)→ できていたら、オンボーディングを済みにする。
  Future<void> _login() async {
    await context.push('${Routes.settings}/account-login');
    // ログインできていれば、台帳に Central のアカウントが付いている(閉じたあとに付くので、少し待つ)。
    for (var i = 0; i < 50 && mounted && !_hasCentral; i++) {
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
          label: returning ? '新しく RASQ アカウントを作成' : 'RASQ アカウントを作成',
          onPressed: _busy || !centralOk ? null : _create,
          primary: primary,
        );
    Widget login({required bool primary}) => action(
          key: const ValueKey('onboarding.login'),
          icon: const Icon(Icons.login, size: 18),
          label: 'RASQ アカウントにログイン',
          onPressed: _busy || !centralOk ? null : _login,
          primary: primary,
        );

    final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(top: RasqSpacing.xxl, bottom: RasqSpacing.md), child: Center(child: RasqLogo(height: 44))),
            Text(returning ? 'RASQ アカウントにログインしますか?' : 'RASQ アカウントを作成しますか?', style: RasqTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: RasqSpacing.md),
            Text(
              returning
                  ? 'RASQ アカウントに入ると、束ねた SNS アカウント・導入したプラグイン・設定が、この端末に戻ります。'
                  : 'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。'
                      '作成すると、導入したプラグイン・設定・アカウントの束ね方が RASQ Central に保存され、別の端末からも同じ状態で使えます。',
              style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: RasqSpacing.sm),
            Text(
              returning
                  // Web 版 (D-300) は、SNS のログインも RASQ アカウントに預けてある。
                  ? (kIsWeb
                      // 規約案 02 第 4 項 (D-372): Web 版の保管庫はサーバーが復号できる方式。
                      ? 'Web 版では、SNS のログイン情報を RASQ のサーバーの保管庫に預けます(サーバーの鍵で暗号化し、RASQ のサーバーは復号できます)。SNS だけで使うこともできますが、そのときはこのタブを閉じるとログインが消えます。'
                      : 'SNS アカウントだけで使うこともできます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます。')
                  : 'スキップしても RASQ は使えます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます(あとからサイドバーの … で作成できます)。',
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            returning ? login(primary: true) : create(primary: true),
            if (!centralOk)
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('RASQ Central の接続先が未設定です', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                TextButton(onPressed: () => context.push('${Routes.settings}/server'), child: const Text('接続先を設定')),
              ]),
            for (final r in resumable) ...[
              const SizedBox(height: RasqSpacing.sm),
              OutlinedButton.icon(
                key: ValueKey('onboarding.resume.${r.id}'),
                onPressed: _busy ? null : () => _resume(r),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text('${r.displayName ?? r.handle ?? 'RASQ アカウント'}${r.handle == null ? '' : '(@${r.handle})'}で続ける', overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ],
            const SizedBox(height: RasqSpacing.sm),
            returning ? create(primary: false) : login(primary: false),
            const SizedBox(height: RasqSpacing.sm),
            OutlinedButton(
              key: const ValueKey('onboarding.skip'),
              onPressed: _busy ? null : _skip,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(returning ? 'SNS アカウントだけで使う' : 'スキップしてこの端末だけで使う'),
            ),
            const SizedBox(height: RasqSpacing.xl),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        // 幅の広い画面 (D-405): シェルと同じく 2 カラム。左の小カラムに SNS / サーバーの見本、右の大型カラムに入口。
        // 小カラムの幅は「カラムの幅」の設定 (D-320) に従う。
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < RasqSizes.tabletBreakpoint) return content;
          final split = splitColumns(c.maxWidth, ref.watch(columnLayoutProvider));
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: split.small, child: const OnboardingPreviewColumn()),
            const VerticalDivider(width: 1),
            Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content))),
          ]);
        }),
      ),
    );
  }
}
