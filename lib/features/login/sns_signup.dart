import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart' show SnsKind;
import 'package:url_launcher/url_launcher.dart';

/// 「{SNS}でログイン」の画面の「新規登録」(D-471)。
///
/// 契約(CONTRACT §3)に登録の入口は無い(`inspectServer` の `registrationOpen` だけ)ので、どの SNS もサーバーの登録ページを開く:
/// - **Misskey / Mastodon**: サーバーのタイルからの登録 (D-412) と同じ流れ。アプリの中の登録ページ(開けない端末は外部のブラウザ)+
///   RAi の案内 →「登録できた」→ そのサーバーのログイン → ログインしたら RASQ の機能の紹介 (D-471)。
///   登録ページは Mastodon が `/auth/sign_up`、Misskey 系はトップ(「新規登録」から)。
/// - **Bluesky / mixi2**: 外部のブラウザで登録ページ([snsSignupPageUrl])を開き、戻ってきたらログインの手順を出す。

/// SNS の標準の登録ページ。
Uri snsSignupPageUrl(SnsKind kind, String host) {
  final h = host.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first.toLowerCase();
  return switch (kind) {
    SnsKind.mastodon => Uri.https(h, '/auth/sign_up'),
    // Bluesky は PDS ではなくアプリ(bsky.app)の「アカウントを作成」から(別の PDS もそこでホスティングプロバイダーに選ぶ)。
    SnsKind.bluesky => Uri.https('bsky.app', '/'),
    // mixi2 の登録はトップ(とアプリ)から。
    SnsKind.mixi2 => Uri.https('mixi.social', '/'),
    _ => Uri.https(h, '/'),
  };
}

/// 外部のブラウザで開く口(テストで差し替える)。開けたら true。
final snsSignupLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication));

/// 「アカウントを持っていない」の段と「新規登録」のボタン。
class SnsSignupButton extends StatelessWidget {
  const SnsSignupButton({super.key, required this.kind, required this.onPressed});
  final SnsKind kind;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: RasqSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
            child: Text('${kind.label} のアカウントを持っていない', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: RasqSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('login.signup'),
          onPressed: onPressed,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('新規登録'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ]),
    );
  }
}

/// 外部のブラウザで登録ページを開いたあとの案内(戻ってきたら、この画面でログインする)。
class SnsSignupReturnHint extends StatelessWidget {
  const SnsSignupReturnHint({super.key, required this.text, required this.url, required this.onReopen});
  final String text;
  final Uri url;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('login.signup.hint'),
      margin: const EdgeInsets.only(top: RasqSpacing.md),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: scheme.primary),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text(text, style: RasqTypography.bodySmall)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onReopen, child: const Text('登録ページをもう一度開く')),
        ),
        SelectableText(url.toString(), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
