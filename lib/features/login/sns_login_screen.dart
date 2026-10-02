import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sns_misskey/sns_misskey.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../onboarding/server_signup.dart';
import 'terms_sheet.dart';

/// SNS ログインの共通画面: インスタンスURL入力 → サーバー確認 → 利用規約 →
/// ブラウザ認証 → 「認証を確認」。
///
/// 流れは CONTRACT §3 の `BrowserAuthFlow{url, hint, complete()}` そのもの
/// なので SNS を問わず同じで、違うのは**どのプラグインに聞くか**だけ。
/// Misskey は MiAuth でクライアント単体で完結し、Mastodon は
/// orgate-server の OAuth ブローカー越しにトークンを受け取る (D-135) が、
/// 画面から見ればどちらも同じ 3 ステップになる。
class SnsLoginScreen extends ConsumerStatefulWidget {
  const SnsLoginScreen({
    super.key,
    required this.pluginId,
    required this.kind,
    required this.defaultHost,
    required this.authButtonLabel,
    this.hostHint,
  });

  final String pluginId;
  final SnsKind kind;

  /// 入力欄の初期値(代表的なインスタンス)。
  final String defaultHost;

  /// 「ブラウザで認証する (MiAuth)」のような、認証方式込みのラベル。
  final String authButtonLabel;
  final String? hostHint;

  @override
  ConsumerState<SnsLoginScreen> createState() => _SnsLoginScreenState();
}

class _SnsLoginScreenState extends ConsumerState<SnsLoginScreen> {
  late final _host = TextEditingController(text: widget.defaultHost);
  ServerInfo? _server;
  BrowserAuthFlow? _flow;
  bool _busy = false;
  String? _error;

  SnsPlugin get _plugin => ref.read(pluginRegistryProvider).plugin(widget.pluginId)!;

  @override
  void initState() {
    super.initState();
    // サーバーのタイルから登録してきた (D-412): サーバーは決まっているので、すぐ確かめる。
    if (ref.read(serverSignupTargetProvider)?.host == widget.defaultHost) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _inspect() : null);
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    setState(() {
      _busy = true;
      _error = null;
      _server = null;
      _flow = null;
    });
    try {
      final info = await _plugin.inspectServer(_host.text);
      setState(() => _server = info);
    } on SnsApiException catch (e) {
      setState(() => _error = '${e.code.display}\n${e.code.message ?? 'サーバーに接続できませんでした'}');
    } catch (e) {
      setState(() => _error = 'サーバーに接続できませんでした: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _startAuth() async {
    final manager = ref.read(overlayManagerProvider);
    final agreed = await showTermsSheet(manager, _plugin.manifest);
    if (!agreed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flow = await _plugin.beginAuth(_server!.host);
      if (flow is! BrowserAuthFlow) throw StateError('unexpected auth flow');
      setState(() => _flow = flow);
      final ok = await launchUrl(flow.url, mode: LaunchMode.externalApplication);
      if (!ok) setState(() => _error = 'ブラウザを開けませんでした。URL: ${flow.url}');
    } on SnsApiException catch (e) {
      // サーバー未設定 (B10) やブローカーのエラーはそのまま見せる。
      setState(() => _error = e.code.message ?? e.code.display);
    } catch (e) {
      setState(() => _error = '認証を開始できませんでした: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final flow = _flow;
    if (flow == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await flow.complete();
      await ref.read(sessionsProvider.notifier).add(result);
      if (!mounted) return;
      final container = ProviderScope.containerOf(context);
      context.go(Routes.home);
      // サーバーのタイルから登録してきたなら (D-412)、タップした投稿 / RASQ リストを開く。
      unawaited(followSignupTarget(container, result.session.account));
    } on SnsApiException catch (e) {
      setState(() => _error = e.code.message ?? e.code.display);
    } catch (e) {
      setState(() => _error = '認証の確認に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PDSを変更'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop())),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), children: [
          Text('PDSを変更すると、アプリ外でのURL表示が変わります。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.xl),
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: RasqSnsPill.colorOf(widget.kind), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(widget.kind.label.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: RasqInput(
                controller: _host,
                hintText: widget.hostHint ?? '移行先のURLを入力 (例: ${widget.defaultHost})',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _inspect(),
                suffix: IconButton(icon: const Icon(Icons.search), onPressed: _busy ? null : _inspect, tooltip: 'サーバーを検索'),
              ),
            ),
          ]),
          const SizedBox(height: RasqSpacing.lg),
          if (_busy) const RasqLoading(),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(RasqSpacing.md),
              decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: tokens.danger),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(child: Text(_error!, style: RasqTypography.bodySmall)),
              ]),
            ),
          if (_server != null) ...[
            const RasqSectionHeader(title: 'サーバーの検索', topMargin: 0),
            RasqListTile(
              title: _server!.name,
              subtitle: [
                _server!.host,
                if (_server!.version != null) '${_server!.software ?? widget.kind.label} ${_server!.version}',
                if (_server!.maintainer != null) '管理人:${_server!.maintainer}',
              ].join(' · '),
              leading: _server!.iconUrl == null ? const Icon(Icons.dns_outlined) : RasqAvatar(imageUrl: _server!.iconUrl, size: 32),
              trailing: _server!.registrationOpen == false ? const RasqPill(label: '登録停止中', color: RasqColors.muted) : null,
              chevron: false,
            ),
            if (_server!.description != null) Padding(padding: const EdgeInsets.symmetric(vertical: RasqSpacing.sm), child: Text(_server!.description!, style: RasqTypography.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: RasqSpacing.lg),
            if (_flow == null)
              FilledButton.icon(
                onPressed: _busy ? null : _startAuth,
                icon: const Icon(Icons.open_in_browser),
                label: Text(widget.authButtonLabel),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              )
            else ...[
              Text(_flow!.hint, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: RasqSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _complete,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('認証を確認'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              TextButton(onPressed: _busy ? null : () => launchUrl(_flow!.url, mode: LaunchMode.externalApplication), child: const Text('ブラウザをもう一度開く')),
            ],
          ],
        ]),
      ),
    );
  }
}

/// Misskey (MiAuth) — クライアント単体で完結する。
class MisskeyLoginScreen extends StatelessWidget {
  const MisskeyLoginScreen({super.key, this.host});

  /// 入力欄に先に入れておくサーバー(RASQ アカウントのバンドルからログインするとき。D-316)。
  final String? host;

  @override
  Widget build(BuildContext context) => SnsLoginScreen(
        pluginId: MisskeyPlugin.pluginId,
        kind: SnsKind.misskey,
        defaultHost: host ?? 'misskey.io',
        authButtonLabel: 'ブラウザで認証する (MiAuth)',
      );
}

/// Mastodon (OAuth) — インスタンスごとの client_secret が要るので、
/// トークン発行は orgate-server の OAuth ブローカーが代行する (D-135)。
class MastodonLoginScreen extends StatelessWidget {
  const MastodonLoginScreen({super.key, this.host});

  /// 入力欄に先に入れておくサーバー(RASQ アカウントのバンドルからログインするとき。D-316)。
  final String? host;

  @override
  Widget build(BuildContext context) => SnsLoginScreen(
        pluginId: mastodonPluginId,
        kind: SnsKind.mastodon,
        defaultHost: host ?? 'mastodon.social',
        authButtonLabel: 'ブラウザで認証する (OAuth)',
        hostHint: 'インスタンスのURLを入力 (例: mastodon.social)',
      );
}
