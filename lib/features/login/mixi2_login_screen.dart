import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../session/mixi2_auth.dart';
import 'terms_sheet.dart';

/// mixi2 のログイン (D-206、サンプル): 公式 API は申請制 + OAuth(RASQ サーバーのブローカー)なので、
/// 「ブラウザで認証」はサーバー設定後に動く。いまは「ダミーアカウントで試す」で流れを確かめる。
const mixi2LoginHostKey = Key('login.mixi2.host');
const mixi2LoginBrowserKey = Key('login.mixi2.browser');
const mixi2LoginDummyKey = Key('login.mixi2.dummy');

class Mixi2LoginScreen extends ConsumerStatefulWidget {
  const Mixi2LoginScreen({super.key});
  @override
  ConsumerState<Mixi2LoginScreen> createState() => _Mixi2LoginScreenState();
}

class _Mixi2LoginScreenState extends ConsumerState<Mixi2LoginScreen> {
  final _host = TextEditingController(text: mixi2DefaultHost);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _login({required bool dummy}) async {
    final plugin = ref.read(pluginRegistryProvider).plugin(mixi2PluginId);
    if (plugin == null) {
      setState(() => _error = 'mixi2 プラグインが見つかりません');
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
      final host = dummy ? mixi2DummyHost : _host.text.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first.toLowerCase();
      final flow = await plugin.beginAuth(host.isEmpty ? mixi2DefaultHost : host);
      final AuthResult result;
      if (flow is CredentialAuthFlow) {
        result = await flow.login(identifier: 'me', secret: '');
      } else if (flow is BrowserAuthFlow) {
        // ブラウザ往復はサーバー側(ブローカー)が用意でき次第。ここでは開始 URL を出して止める。
        setState(() => _error = 'ブラウザで許可してからアプリに戻ってください: ${flow.url}');
        return;
      } else {
        throw StateError('unexpected auth flow');
      }
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('mixi2でログイン'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop())),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), children: [
          Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: RasqSnsPill.colorOf(SnsKind.mixi2), shape: BoxShape.circle), alignment: Alignment.center, child: const Text('m', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: RasqSpacing.md),
            Expanded(child: RasqInput(key: mixi2LoginHostKey, controller: _host, hintText: 'ホスト (例: mixi.social)', keyboardType: TextInputType.url)),
          ]),
          const SizedBox(height: RasqSpacing.sm),
          Text('mixi2 の公式 API は申請制で、ログインは OAuth(RASQ サーバーのブローカー経由)です。申請とサーバーの設定が済むまで「ブラウザで認証」は使えません。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.xl),
          FilledButton(key: mixi2LoginBrowserKey, onPressed: _busy ? null : () => _login(dummy: false), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('ブラウザで認証')),
          // ダミーアカウント(プラグインの中の投稿だけで動く)は、開発者モードのときだけ (D-393)。
          if (RasqDeveloperMode.of(context)) ...[
          const SizedBox(height: RasqSpacing.md),
          OutlinedButton.icon(key: mixi2LoginDummyKey, onPressed: _busy ? null : () => _login(dummy: true), icon: const Icon(Icons.science_outlined), label: const Text('ダミーアカウントで試す')),
          const SizedBox(height: RasqSpacing.sm),
          Text('ダミーはネットワークを使わず、プラグインの中の投稿で TL / いいね / リポスト / 投稿 / 通知の流れを確かめられます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, key: const ValueKey('login.mixi2.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
        ]),
      ),
    );
  }
}
