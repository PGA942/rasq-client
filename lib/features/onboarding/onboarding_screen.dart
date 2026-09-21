import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../session/rasq_accounts.dart';
import '../../shell/rasq_account_fow.dart';
import '../../shell/rasq_register_fow.dart';

/// 初回オンボーディング (D-138): RASQ アカウントの作成を求める。
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
      // 登録の FOW (D-241): 利用規約 / 年齢 / バンドルを置き換えるか → 登録 → 同意の記録。
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

  bool get _hasCentral => ref.read(rasqAccountsProvider).value?.accounts.any((a) => a.isCentral) ?? false;

  /// すでに RASQ アカウントを持っている人 (D-296): ログイン(パスワード / メールのコード)→ できていたら、オンボーディングを済みにする。
  Future<void> _login() async {
    await context.push('${Routes.settings}/account-login');
    // ログインできていれば、台帳に Central のアカウントが付いている(閉じたあとに付くので、少し待つ)。
    for (var i = 0; i < 50 && mounted && !_hasCentral; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || !_hasCentral) return;
    await ref.read(rasqAccountsProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.login);
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    await ref.read(rasqAccountsProvider.notifier).completeOnboarding(skipped: true);
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final centralOk = ref.watch(centralConfiguredProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(top: RasqSpacing.xxl, bottom: RasqSpacing.md), child: Center(child: RasqLogo(height: 44))),
            Text('RASQ アカウントを作成しますか?', style: RasqTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: RasqSpacing.md),
            Text(
              'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。'
              '作成すると、導入したプラグイン・設定・アカウントの束ね方が RASQ Central に保存され、別の端末からも同じ状態で使えます。',
              style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: RasqSpacing.sm),
            Text(
              'スキップしても RASQ は使えます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます(あとからサイドバーの … で作成できます)。',
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _busy || !centralOk ? null : _create,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const RasqBrandIcon(size: 18),
              label: const Text('RASQ アカウントを作成'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (!centralOk)
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('RASQ Central の接続先が未設定です', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                TextButton(onPressed: () => context.push('${Routes.settings}/server'), child: const Text('接続先を設定')),
              ]),
            const SizedBox(height: RasqSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('onboarding.login'),
              onPressed: _busy || !centralOk ? null : _login,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('RASQ アカウントにログイン'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            const SizedBox(height: RasqSpacing.sm),
            OutlinedButton(
              onPressed: _busy ? null : _skip,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('スキップしてこの端末だけで使う'),
            ),
            const SizedBox(height: RasqSpacing.xl),
          ]),
        ),
      ),
    );
  }
}
