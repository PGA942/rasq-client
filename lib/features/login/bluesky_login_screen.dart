import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../session/bluesky_auth.dart';
import 'login_screen.dart' show popOr;
import 'sns_signup.dart';
import 'terms_sheet.dart';

/// Bluesky のログイン (D-175): PDS / ハンドル(かメール)/ アプリパスワード。
/// ブラウザ往復は無く、プラグインの `sns.login`(createSession)で完結する。
const blueskyLoginHostKey = Key('login.bluesky.host');
const blueskyLoginIdKey = Key('login.bluesky.identifier');
const blueskyLoginPasswordKey = Key('login.bluesky.password');
const blueskyLoginButtonKey = Key('login.bluesky.submit');

class BlueskyLoginScreen extends ConsumerStatefulWidget {
  const BlueskyLoginScreen({super.key});
  @override
  ConsumerState<BlueskyLoginScreen> createState() => _BlueskyLoginScreenState();
}

class _BlueskyLoginScreenState extends ConsumerState<BlueskyLoginScreen> {
  final _host = TextEditingController(text: blueskyDefaultHost);
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  /// 新規登録 (D-471) で外部のブラウザに開いた登録ページ(戻ってきたらログインの手順を出す)。
  Uri? _signupUrl;

  @override
  void dispose() {
    _host.dispose();
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final plugin = ref.read(pluginRegistryProvider).plugin(blueskyPluginId);
    if (plugin == null) {
      setState(() => _error = 'Bluesky プラグインが見つかりません');
      return;
    }
    final manager = ref.read(overlayManagerProvider);
    final agreed = await showTermsSheet(manager, plugin.manifest);
    if (!agreed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var host = _host.text.trim().isEmpty ? blueskyDefaultHost : _host.text.trim();
      host = host.replaceFirst(RegExp(r'^https?://'), '').split('/').first.toLowerCase();
      final flow = await plugin.beginAuth(host);
      if (flow is! CredentialAuthFlow) throw StateError('unexpected auth flow');
      final result = await flow.login(identifier: _id.text.trim(), secret: _password.text);
      await ref.read(sessionsProvider.notifier).add(result);
      if (!mounted) return;
      context.go(Routes.home);
    } on SnsApiException catch (e) {
      setState(() => _error = e.code.message ?? e.code.display);
    } catch (e) {
      setState(() => _error = 'ログインできませんでした: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 新規登録 (D-471): Bluesky のアプリ(bsky.app)の登録ページを外部のブラウザで開く。登録はブラウザで行い、戻ってきたら
  /// アプリパスワードを作ってこの画面でログインする。
  Future<void> _signup() async {
    final url = snsSignupPageUrl(SnsKind.bluesky, _host.text);
    final ok = await ref.read(snsSignupLauncherProvider)(url);
    if (!mounted) return;
    setState(() {
      _signupUrl = url;
      _error = ok ? null : 'ブラウザを開けませんでした。URL: $url';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final canSubmit = !_busy && _id.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Blueskyでログイン'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => popOr(context, Routes.login))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: RasqSnsPill.colorOf(SnsKind.bluesky), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: RasqSpacing.md),
            Expanded(child: RasqInput(key: blueskyLoginHostKey, controller: _host, hintText: 'PDS (例: bsky.social)', keyboardType: TextInputType.url)),
          ]),
          const SizedBox(height: RasqSpacing.md),
          RasqInput(key: blueskyLoginIdKey, controller: _id, hintText: 'ハンドル (例: you.bsky.social) またはメール', keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
          const SizedBox(height: RasqSpacing.sm),
          Row(children: [
            Expanded(child: RasqInput(key: blueskyLoginPasswordKey, controller: _password, hintText: 'アプリパスワード', obscureText: !_showPassword, onChanged: (_) => setState(() {}))),
            RasqIconButton(icon: _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, tooltip: _showPassword ? '隠す' : '表示', onPressed: () => setState(() => _showPassword = !_showPassword)),
          ]),
          const SizedBox(height: RasqSpacing.sm),
          Text('Bluesky の「設定 → プライバシーとセキュリティ → アプリパスワード」で作ったパスワードを使ってください。本パスワードは入れないでください。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.xl),
          FilledButton(key: blueskyLoginButtonKey, onPressed: canSubmit ? _login : null, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('ログイン')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
          SnsSignupButton(kind: SnsKind.bluesky, onPressed: _busy ? null : _signup),
          if (_signupUrl != null)
            SnsSignupReturnHint(
              text: 'ブラウザの Bluesky で「アカウントを作成」から登録してください。登録できたら、Bluesky の「設定 → プライバシーとセキュリティ → アプリパスワード」でパスワードを作り、上のハンドルとアプリパスワードでログインします。',
              url: _signupUrl!,
              onReopen: _signup,
            ),
        ]),
      ),
    );
  }
}
