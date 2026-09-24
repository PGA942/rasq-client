import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../rai/rai_overlay.dart';
import '../rai/rai_providers.dart';

/// ログイン (マルチPDS). Wireframe: BlueSky / Misskey / mixi2 / Mastodon /
/// サービスを探してログイン + Raiのインストラクチャ.
/// Misskey (MiAuth) と Mastodon (OAuth ブローカー経由, D-135) が有効。
/// BlueSky / mixi2 はまだプラグインが無いので理由を出して止める。
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasSessions = ref.watch(sessionsProvider).value?.isLoggedIn ?? false;


    return Scaffold(
      appBar: AppBar(
        leading: hasSessions ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop()) : null,
        automaticallyImplyLeading: false,
        title: const Text('SNSにログイン'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(top: RasqSpacing.xl, bottom: RasqSpacing.sm), child: Center(child: RasqLogo(height: 44))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RasqSpacing.md),
              child: Text('初回ログイン前に、プラグインのロードが行われます。ネット環境の良い場所で行ってください。',
                  style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            ),
            // チャイルドセーフ (D-307): 保護者が SNS アカウントの追加を止めていれば、そう伝える(ルーターも先へ進ませない)。
            if (!ref.watch(childGateProvider).canAddAccounts)
              Text('保護者が SNS アカウントの追加を止めています', key: const ValueKey('childSafe.login.blocked'), style: RasqTypography.bodySmall.copyWith(color: scheme.error), textAlign: TextAlign.center),
            const SizedBox(height: RasqSpacing.lg),
            _ServiceButton(kind: SnsKind.bluesky, label: 'Blueskyでログイン', onTap: () => context.push(Routes.loginBluesky)),
            _ServiceButton(kind: SnsKind.misskey, label: 'Misskeyでログイン', onTap: () => context.push(Routes.loginMisskey)),
            // mixi2 (D-206): サンプルプラグイン(API 申請前はダミーモード)。
            _ServiceButton(kind: SnsKind.mixi2, label: 'mixi2でログイン', external: true, onTap: () => context.push(Routes.loginMixi2)),
            _ServiceButton(kind: SnsKind.mastodon, label: 'Mastodonでログイン', onTap: () => context.push(Routes.loginMastodon)),
            const SizedBox(height: RasqSpacing.sm),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.onSurface, foregroundColor: scheme.surface, minimumSize: const Size.fromHeight(44)),
              onPressed: () => context.push(Routes.loginMisskey),
              child: const Text('サービスを探してログイン'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              // RAi インストラクション (D-179): 入力欄付きのバーを出す(このページのまま)。
              onPressed: () => showRai(ref, mode: RaiMode.instruction, asking: true),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Raiのインストラクチャ'),
            ),
            const SizedBox(height: RasqSpacing.lg),
          ]),
        ),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({required this.kind, required this.label, required this.onTap, this.external = false});
  final SnsKind kind;
  final String label;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: RasqSpacing.md),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              height: 48,
              decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: RasqSnsPill.colorOf(kind), shape: BoxShape.circle), alignment: Alignment.center,
                    child: Text(kind.label.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: color))),
                Icon(external ? Icons.north_east : Icons.chevron_right, color: color),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
