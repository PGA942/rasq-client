import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart' show OrgateException;
import '../../backend/rasq_account_page_api.dart';
import '../../session/sns_share.dart' show snsShareProvider, snsShareWaitingProvider;
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
    // SNS のアクセストークンの端末間共有 (D-322): 元の端末の承認を待っていて、共有されたログインを取り込んだら TL へ
    // (この画面がいちばん上のときだけ。個別の SNS のログイン画面を開いている途中では動かさない)。
    ref.listen(snsShareProvider.select((v) => v.joins), (prev, next) {
      if (next > (prev ?? 0) && context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) context.go(Routes.home);
    });

    return Scaffold(
      appBar: AppBar(
        // 戻る (D-422): SNS にまだ入っていなくても出す。戻る先が無ければ(RASQ アカウントのログインから `go` で来た)RASQ アカウントの入口へ
        // (別の RASQ アカウントで入り直す / 新しく作る / SNS アカウントだけで使う)。
        leading: IconButton(key: const ValueKey('login.back'), icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => popOr(context, hasSessions ? Routes.home : Routes.onboarding)),
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
            // 既存の RASQ アカウントへログインした端末 (D-316): そのアカウントの SNS アカウントのうち、まだこの端末で入っていないもの。
            const _BundleAccounts(),
            // SNS のアクセストークンの端末間共有 (D-319): 元の端末の承認を待っている間の案内(ログインボタンはそのまま使える)。
            if (ref.watch(snsShareWaitingProvider)) const _ShareWaiting(),
            // メールのリンクで「承認する(SNS はこの端末でログインし直す)」になった (D-422)。
            if (ref.watch(snsShareProvider.select((v) => v.status?.approvedWithoutSharing ?? false)))
              Container(
                key: const ValueKey('login.shareDeviceOnly'),
                margin: const EdgeInsets.only(top: RasqSpacing.sm),
                padding: const EdgeInsets.all(RasqSpacing.sm),
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.verified_user_outlined, color: scheme.primary),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text('メールでこの端末を承認しました。SNS アカウントには、下のボタンからこの端末でログインしてください', style: RasqTypography.bodySmall)),
                ]),
              ),
            const SizedBox(height: RasqSpacing.lg),
            SnsServiceButton(kind: SnsKind.bluesky, label: 'Blueskyでログイン', onTap: () => context.push(Routes.loginBluesky)),
            SnsServiceButton(kind: SnsKind.misskey, label: 'Misskeyでログイン', onTap: () => context.push(Routes.loginMisskey)),
            // mixi2 (D-206): サンプルプラグイン(API 申請前はダミーモード)。
            SnsServiceButton(kind: SnsKind.mixi2, label: 'mixi2でログイン', external: true, onTap: () => context.push(Routes.loginMixi2)),
            SnsServiceButton(kind: SnsKind.mastodon, label: 'Mastodonでログイン', onTap: () => context.push(Routes.loginMastodon)),
            const SizedBox(height: RasqSpacing.sm),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.onSurface, foregroundColor: scheme.surface, minimumSize: const Size.fromHeight(44)),
              // 探す画面 (D-414): 画像 / 人 / RAi から、合うサーバーと RASQ リストを探す。
              onPressed: () => context.push(Routes.snsDiscover),
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

/// 戻る (D-422): 戻れる画面があれば戻り、無ければ(`go` で来た / 通知・リンクから開いた)[fallback] へ。
void popOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// 元の端末の承認を待っている間の案内 (D-319 → D-422): 開いている端末が無くても、確認済みのメールのリンクから承認できる。
class _ShareWaiting extends ConsumerStatefulWidget {
  const _ShareWaiting();

  @override
  ConsumerState<_ShareWaiting> createState() => _ShareWaitingState();
}

class _ShareWaitingState extends ConsumerState<_ShareWaiting> {
  bool _busy = false;
  String? _note;

  Future<void> _sendMail() async {
    setState(() => _busy = true);
    String note;
    try {
      final to = await ref.read(snsShareProvider.notifier).requestEmailApproval();
      note = to == null ? 'いまは送れません' : '${to.isEmpty ? '確認済みのメールアドレス' : to} に承認のリンクを送りました(30 分有効)。ブラウザで開いて、RASQ アカウントでログインしてから承認してください';
    } on OrgateException catch (e) {
      note = switch (e.serverCode == 'no_verified_email' ? 'no_verified_email' : e.code.code) {
        'no_verified_email' => '確認済みのメールアドレスがありません。元の端末で承認するか、SNS アカウントにこの端末でログインしてください',
        '429' => '送りすぎです。しばらく待ってから、もう一度送ってください',
        '501' => 'このサーバーでは、メールでの承認を使えません',
        _ => '送れませんでした(${e.code.code})',
      };
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _note = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('login.shareWaiting'),
      margin: const EdgeInsets.only(top: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.devices_outlined, color: scheme.primary),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text('元の端末で共有を承認すると、SNS アカウントに一斉ログインします。確認済みのメールに届いたリンクからも承認できます', style: RasqTypography.bodySmall)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('login.shareEmail'),
            onPressed: _busy ? null : _sendMail,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('メールで承認する(リンクを送る)'),
          ),
        ),
        if (_note != null) Text(_note!, key: const ValueKey('login.shareEmailNote'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// いまの RASQ アカウントのバンドル(Central にある SNS アカウント)のうち、この端末でまだそのアカウントに入っていないもの (D-316)。
/// 押すと、この端末にログインがあればそのまま入れ、無ければその SNS のログイン画面(サーバーを入れた状態)へ。
class _BundleAccounts extends ConsumerWidget {
  const _BundleAccounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final links = ref.watch(currentBundleLinksProvider).value ?? const <RasqSnsLink>[];
    final state = ref.watch(sessionsProvider).value;
    final mine = {for (final s in state?.sessions ?? const <AccountSession>[]) s.account.key};
    final onDevice = {for (final s in state?.allSessions ?? const <AccountSession>[]) s.account.key};
    final pending = [for (final l in links) if (!mine.contains(l.accountKey)) l];
    if (pending.isEmpty) return const SizedBox.shrink();
    final handle = ref.watch(currentRasqAccountProvider)?.handle;
    Future<void> open(RasqSnsLink l) async {
      if (onDevice.contains(l.accountKey)) {
        await ref.read(rasqAccountsProvider.notifier).addSessionKey(l.accountKey);
        return;
      }
      final t = l.tile;
      final host = Uri.encodeQueryComponent(t.instance);
      context.push(switch (t.kind) {
        'misskey' => '${Routes.loginMisskey}?host=$host',
        'mastodon' => '${Routes.loginMastodon}?host=$host',
        'bluesky' => Routes.loginBluesky,
        'mixi2' => Routes.loginMixi2,
        _ => Routes.loginMisskey,
      });
    }

    return Container(
      key: const ValueKey('login.bundle'),
      margin: const EdgeInsets.only(top: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${handle == null || handle.isEmpty ? 'この RASQ アカウント' : '@$handle'} の SNS アカウント', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        Text('この端末では、まだログインしていません。押すとログインできます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 168),
          child: ListView(shrinkWrap: true, children: [
            for (final l in pending)
              InkWell(
                key: ValueKey('login.bundle.${l.accountKey}'),
                onTap: () => open(l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text('${l.tile.label}  @${l.tile.handle}@${l.tile.instance}', style: RasqTypography.bodySmall, overflow: TextOverflow.ellipsis)),
                    Text(onDevice.contains(l.accountKey) ? '使う' : 'ログイン', style: RasqTypography.bodySmall.copyWith(color: scheme.primary)),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// SNS ごとのログインのボタン(オンボーディング v2 の ③ でも使う)。
class SnsServiceButton extends StatelessWidget {
  const SnsServiceButton({super.key, required this.kind, required this.label, required this.onTap, this.external = false});
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
