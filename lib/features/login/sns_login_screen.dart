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
import 'login_screen.dart' show popOr;
import 'server_pick.dart';
import 'sns_signup.dart';
import 'terms_sheet.dart';
import '../../l10n/l10n.dart';

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
    this.initialHost,
  });

  final String pluginId;
  final SnsKind kind;

  /// 入力欄の例に出すホスト(代表的なインスタンス)。入力欄そのものは空で始める (D-554)。
  final String defaultHost;

  /// 入力欄に先に入れておくサーバー(RASQ アカウントのバンドルからのログイン D-316 / サーバーのタイルからの登録 D-412)。
  final String? initialHost;

  /// 「ブラウザで認証する (MiAuth)」のような、認証方式込みのラベル。
  final String authButtonLabel;
  final String? hostHint;

  @override
  ConsumerState<SnsLoginScreen> createState() => _SnsLoginScreenState();
}

class _SnsLoginScreenState extends ConsumerState<SnsLoginScreen> {
  late final _host = TextEditingController(text: widget.initialHost ?? '');
  ServerInfo? _server;
  BrowserAuthFlow? _flow;
  bool _busy = false;
  String? _error;

  SnsPlugin get _plugin => ref.read(pluginRegistryProvider).plugin(widget.pluginId)!;

  @override
  void initState() {
    super.initState();
    // サーバーのタイルから登録してきた (D-412): サーバーは決まっているので、すぐ確かめる。
    if (widget.initialHost != null && ref.read(serverSignupTargetProvider)?.host == widget.initialHost) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _inspect() : null);
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
      setState(() => _error = '${e.code.display}\n${e.code.message ?? context.l10n.loginServerUnreachable}');
    } catch (e) {
      setState(() => _error = context.l10n.loginServerUnreachableWithError('$e'));
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 「サーバーの検索」のタイルを押した (D-554): そのサーバーを確かめて、そのまま認証(規約 → ブラウザ)へ進む。
  Future<void> _pick(String host) async {
    _host.text = host;
    await _inspect();
    if (mounted && _server != null) await _startAuth();
  }

  /// 新規登録 (D-471): サーバーを確かめて(済んでいればそのまま)、D-412 の登録ページ(RAi の案内つき)へ。
  /// 登録できたら「登録できた」→ このサーバーのログイン → ログインしたら RASQ の機能の紹介。
  Future<void> _signup() async {
    var info = _server;
    // 入力欄が空なら、代表のサーバー(例に出しているもの)で登録する。
    if (_host.text.trim().isEmpty) _host.text = widget.defaultHost;
    final typed = serverHostOf(_host.text);
    if (info == null || (typed.isNotEmpty && info.host != typed)) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        info = await _plugin.inspectServer(_host.text);
        if (mounted) setState(() => _server = info);
      } on SnsApiException catch (e) {
        if (mounted) setState(() => _error = '${e.code.display}\n${e.code.message ?? context.l10n.loginServerUnreachable}');
        return;
      } catch (e) {
        if (mounted) setState(() => _error = context.l10n.loginServerUnreachableWithError('$e'));
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    final server = info;
    if (!mounted) return;
    startServerSignup(
      context,
      ref,
      ServerSignupTarget(
        host: server.host,
        kind: widget.kind,
        software: server.software ?? (widget.kind == SnsKind.mastodon ? 'mastodon' : 'misskey'),
        name: server.name,
        registrationOpen: server.registrationOpen,
      ),
    );
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
      if (!ok) setState(() => _error = context.l10n.loginBrowserOpenFailed('${flow.url}'));
    } on SnsApiException catch (e) {
      // サーバー未設定 (B10) やブローカーのエラーはそのまま見せる。
      setState(() => _error = e.code.message ?? e.code.display);
    } catch (e) {
      setState(() => _error = context.l10n.loginAuthStartFailed('$e'));
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
      setState(() => _error = context.l10n.loginAuthCheckFailed(e is StateError ? e.message : '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.loginSnsTitle), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: context.l10n.loginBack, onPressed: () => popOr(context, Routes.login))),
      body: SafeArea(
        // 一覧が長くても下の「新規登録」まで作っておく(遅延の ListView にしない)。
        child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xl, vertical: RasqSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: RasqSpacing.md),
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
                hintText: widget.hostHint ?? context.l10n.loginSnsHostHint(widget.defaultHost),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _inspect(),
                suffix: IconButton(icon: const Icon(Icons.search), onPressed: _busy ? null : _inspect, tooltip: context.l10n.loginSnsSearch),
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
            RasqSectionHeader(title: context.l10n.loginSnsServerSection, topMargin: 0),
            // 確かめたサーバー(ワイヤーフレーム p.4 のタイルの形、D-554)。
            ServerPickTile(
              host: _server!.host,
              kind: widget.kind,
              name: _server!.name,
              iconUrl: _server!.iconUrl,
              description: _server!.description ?? '',
              trailing: _server!.registrationOpen == false ? RasqPill(label: context.l10n.loginSnsRegistrationClosed, color: RasqColors.muted) : null,
            ),
            if (_server!.version != null || _server!.maintainer != null)
              Text(
                [
                  if (_server!.version != null) '${_server!.software ?? widget.kind.label} ${_server!.version}',
                  if (_server!.maintainer != null) context.l10n.loginSnsMaintainer(_server!.maintainer!),
                ].join(' · '),
                style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
              ),
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
                label: Text(context.l10n.loginSnsAuthCheck),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              TextButton(onPressed: _busy ? null : () => launchUrl(_flow!.url, mode: LaunchMode.externalApplication), child: Text(context.l10n.loginSnsReopenBrowser)),
            ],
          ],
          // サーバーの検索 (D-554): まだサーバーを決めていない間は、有力なサーバーを並べる。押すとそのまま認証へ。
          if (_server == null) ServerPickList(kind: widget.kind, enabled: !_busy, onPick: _pick),
          // 新規登録 (D-471): アカウントを持っていない人は、このサーバー(入力欄)の登録ページへ。
          SnsSignupButton(kind: widget.kind, onPressed: _busy ? null : _signup),
        ])),
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
        defaultHost: 'misskey.io',
        initialHost: host,
        authButtonLabel: context.l10n.loginMisskeyAuthButton,
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
        defaultHost: 'mastodon.social',
        initialHost: host,
        authButtonLabel: context.l10n.loginMastodonAuthButton,
        hostHint: context.l10n.loginMastodonHostHint,
      );
}
