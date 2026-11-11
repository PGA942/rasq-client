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
import 'server_pick.dart';
import 'sns_signup.dart';
import 'terms_sheet.dart';
import '../../l10n/l10n.dart';

/// Bluesky のログイン (D-175、D-554 で 2 ページに分けた)。ブラウザ往復は無く、プラグインの `sns.login`(createSession)で完結する。
///
/// 1. [BlueskyLoginScreen] — **PDS を選ぶ**: URL の欄(空で始まる)に入れて「次へ」か、下の「サーバーの検索」のタイルを押す。
/// 2. [BlueskyHandleScreen] — **ハンドル(かメール)とアプリパスワード**。ハンドルに名前だけ(`.` の無い、URL の形でない文字)を
///    入れたときは、「ログイン」を押したときに `.<PDS>` を補う([blueskyIdentifierFor])。
const blueskyLoginHostKey = Key('login.bluesky.host');
const blueskyLoginNextKey = Key('login.bluesky.next');
const blueskyLoginIdKey = Key('login.bluesky.identifier');
const blueskyLoginPasswordKey = Key('login.bluesky.password');
const blueskyLoginButtonKey = Key('login.bluesky.submit');

/// ログインに送る ID: 名前だけ(`.` も `@` も無い)なら `.<PDS のホスト>` を補う。ハンドル(`alice.example.com`)・
/// メール・DID はそのまま。先頭の `@` は外す。
String blueskyIdentifierFor(String input, String host) {
  final id = input.trim().replaceFirst(RegExp(r'^@'), '');
  if (id.isEmpty || id.contains('.') || id.contains('@') || id.contains(':') || host.isEmpty) return id;
  return '$id.$host';
}

class BlueskyLoginScreen extends ConsumerStatefulWidget {
  const BlueskyLoginScreen({super.key});
  @override
  ConsumerState<BlueskyLoginScreen> createState() => _BlueskyLoginScreenState();
}

class _BlueskyLoginScreenState extends ConsumerState<BlueskyLoginScreen> {
  final _host = TextEditingController();
  String? _error;

  /// 新規登録 (D-471) で外部のブラウザに開いた登録ページ(戻ってきたらログインの手順を出す)。
  Uri? _signupUrl;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  /// PDS を決めて、ハンドルのページへ。欄が空なら既定の PDS。
  void _next([String? picked]) {
    final host = serverHostOf(picked ?? _host.text);
    context.push(Routes.loginBlueskyHandle(host.isEmpty ? blueskyDefaultHost : host));
  }

  /// 新規登録 (D-471): Bluesky のアプリ(bsky.app)の登録ページを外部のブラウザで開く。登録はブラウザで行い、戻ってきたら
  /// アプリパスワードを作ってログインする。
  Future<void> _signup() async {
    final url = snsSignupPageUrl(SnsKind.bluesky, _host.text.trim().isEmpty ? blueskyDefaultHost : _host.text);
    final ok = await ref.read(snsSignupLauncherProvider)(url);
    if (!mounted) return;
    setState(() {
      _signupUrl = url;
      _error = ok ? null : context.l10n.loginBrowserOpenFailed('$url');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.loginWithBluesky), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: context.l10n.loginBack, onPressed: () => popOr(context, Routes.login))),
      body: SafeArea(
        child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const RasqSnsMark(kind: SnsKind.bluesky),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: RasqInput(
                key: blueskyLoginHostKey,
                controller: _host,
                hintText: context.l10n.loginBlueskyHostHint,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _next(),
                suffix: IconButton(key: blueskyLoginNextKey, icon: const Icon(Icons.arrow_forward), onPressed: _next, tooltip: context.l10n.loginBlueskyNext),
              ),
            ),
          ]),
          const SizedBox(height: RasqSpacing.lg),
          // サーバーの検索 (D-554): 押すと、その PDS でハンドルのページへ。
          ServerPickList(kind: SnsKind.bluesky, onPick: _next),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
          SnsSignupButton(kind: SnsKind.bluesky, onPressed: _signup),
          if (_signupUrl != null)
            SnsSignupReturnHint(
              text: context.l10n.loginBlueskySignupHint,
              url: _signupUrl!,
              onReopen: _signup,
            ),
        ])),
      ),
    );
  }
}

/// Bluesky のハンドル(かメール)とアプリパスワードのページ (D-554)。[host] = 前のページで決めた PDS。
class BlueskyHandleScreen extends ConsumerStatefulWidget {
  const BlueskyHandleScreen({super.key, required this.host});
  final String host;
  @override
  ConsumerState<BlueskyHandleScreen> createState() => _BlueskyHandleScreenState();
}

class _BlueskyHandleScreenState extends ConsumerState<BlueskyHandleScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  String get _hostName => serverHostOf(widget.host).isEmpty ? blueskyDefaultHost : serverHostOf(widget.host);

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final plugin = ref.read(pluginRegistryProvider).plugin(blueskyPluginId);
    if (plugin == null) {
      setState(() => _error = context.l10n.loginPluginMissingBluesky);
      return;
    }
    // 名前だけなら `.<PDS>` を補い、補ったことが分かるように欄にも入れる。
    final identifier = blueskyIdentifierFor(_id.text, _hostName);
    if (identifier != _id.text) _id.text = identifier;
    final manager = ref.read(overlayManagerProvider);
    final agreed = await showTermsSheet(manager, plugin.manifest);
    if (!agreed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flow = await plugin.beginAuth(_hostName);
      if (flow is! CredentialAuthFlow) throw StateError('unexpected auth flow');
      final result = await flow.login(identifier: identifier, secret: _password.text);
      await ref.read(sessionsProvider.notifier).add(result);
      if (!mounted) return;
      context.go(Routes.home);
    } on SnsApiException catch (e) {
      setState(() => _error = e.code.message ?? e.code.display);
    } catch (e) {
      setState(() => _error = context.l10n.loginFailed(e is StateError ? e.message : '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final canSubmit = !_busy && _id.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.loginWithBluesky), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: context.l10n.loginBack, onPressed: () => popOr(context, Routes.loginBluesky))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), children: [
          // 前のページで決めた PDS。
          ServerPickTile(host: _hostName, kind: SnsKind.bluesky),
          const SizedBox(height: RasqSpacing.md),
          RasqInput(key: blueskyLoginIdKey, controller: _id, hintText: context.l10n.loginBlueskyIdHint, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
          const SizedBox(height: RasqSpacing.xs),
          Text(context.l10n.loginBlueskyHandleCompleteNote(_hostName), key: const ValueKey('login.bluesky.completeNote'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.sm),
          Row(children: [
            Expanded(child: RasqInput(key: blueskyLoginPasswordKey, controller: _password, hintText: context.l10n.loginBlueskyPasswordHint, obscureText: !_showPassword, onChanged: (_) => setState(() {}))),
            RasqIconButton(icon: _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, tooltip: _showPassword ? context.l10n.loginPasswordHide : context.l10n.loginPasswordShow, onPressed: () => setState(() => _showPassword = !_showPassword)),
          ]),
          const SizedBox(height: RasqSpacing.sm),
          Text(context.l10n.loginBlueskyPasswordNote, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.xl),
          FilledButton(key: blueskyLoginButtonKey, onPressed: canSubmit ? _login : null, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.l10n.loginButton)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
        ]),
      ),
    );
  }
}
