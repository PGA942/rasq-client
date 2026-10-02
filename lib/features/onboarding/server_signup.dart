import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/router.dart';
import '../../backend/rasq_collections_api.dart' show RasqCollection;
import '../../backend/server_info_api.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../collections/rasq_list_picker.dart' show importRasqListToHomeWith;
import '../collections/rasq_collections.dart' show hasRasqAccountProvider;
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../post/post_resolve.dart';
import 'rasq_account_nudge.dart' show requestRasqAccountNudge;
import '../rai/rai_widgets.dart' show RaiIcon;

/// サーバーのタイルから始める登録 (D-412): タップ → **アプリの中でサーバーの登録ページ**(WebView。開けない端末は外部のブラウザ)+
/// **RAi が手順を文字で案内** →「登録できた」→ いつもの SNS のログイン(MiAuth / OAuth)→ ログインできたら、タップした投稿 /
/// RASQ リストを開く。
@immutable
class ServerSignupTarget {
  const ServerSignupTarget({required this.host, required this.kind, this.software, this.name, this.registrationOpen, this.post, this.list});
  final String host;

  /// ログインに使う SNS(Misskey 系 / Mastodon 系)。
  final SnsKind kind;
  final String? software;

  /// サーバーの名前(案内に出す)。
  final String? name;
  final bool? registrationOpen;

  /// タップした見本の投稿(ログインしたら開く)。
  final Post? post;

  /// タップした RASQ リスト(ログインしたら開いて、取り込む)。
  final RasqCollection? list;

  String get displayName => (name?.trim().isNotEmpty ?? false) ? name!.trim() : host;

  /// 登録ページ: Mastodon は `/auth/sign_up`、Misskey 系などはトップ(登録はトップの「新規登録」から)。
  Uri get signupUrl => software?.toLowerCase() == 'mastodon' ? Uri.https(host, '/auth/sign_up') : Uri.https(host, '/');

  /// ログインの画面(いつもの SNS のログイン、サーバーを入れておく)。
  String get loginLocation => '${kind == SnsKind.mastodon ? Routes.loginMastodon : Routes.loginMisskey}?host=${Uri.encodeQueryComponent(host)}';
}

/// nodeinfo のソフト名 → ログインに使う SNS(Central の系統と同じ見分け)。分からなければ null(登録の入口を出さない)。
SnsKind? signupKindOf(String? software) => switch (software?.toLowerCase()) {
      'misskey' || 'sharkey' || 'firefish' || 'calckey' || 'foundkey' || 'cherrypick' || 'iceshrimp' || 'meisskey' || 'catodon' || 'magnetar' => SnsKind.misskey,
      'mastodon' || 'hometown' || 'fedibird' || 'glitch-soc' || 'kmyblue' => SnsKind.mastodon,
      _ => null,
    };

/// サーバー情報 → 登録の行き先(登録の入口を出せないサーバーは null)。
ServerSignupTarget? signupTargetFor(RasqServerInfo info, {Post? post, RasqCollection? list}) {
  final kind = signupKindOf(info.software);
  if (kind == null) return null;
  return ServerSignupTarget(host: info.host, kind: kind, software: info.software, name: info.name, registrationOpen: info.registrationOpen, post: post, list: list);
}

/// 進めている登録(1 つだけ)。ログインできたら [followSignupTarget] が使って消す。
class ServerSignupTargetNotifier extends Notifier<ServerSignupTarget?> {
  @override
  ServerSignupTarget? build() => null;
  void set(ServerSignupTarget? t) => state = t;
}

final serverSignupTargetProvider = NotifierProvider<ServerSignupTargetNotifier, ServerSignupTarget?>(ServerSignupTargetNotifier.new);

/// タイルをタップした: 登録のページへ。見守り (D-307) で SNS アカウントを増やせない端末では、理由だけ伝える。
void startServerSignup(BuildContext context, WidgetRef ref, ServerSignupTarget target) {
  if (!ref.read(childGateProvider).canAddAccounts) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保護者が SNS アカウントの追加を止めています')));
    return;
  }
  ref.read(serverSignupTargetProvider.notifier).set(target);
  context.push(Routes.serverSignup);
}

/// RAi の案内の手順(文字だけ。ページの中の位置は指さない)。
List<String> signupGuideSteps(ServerSignupTarget t, {bool hasRasqAccount = true}) {
  final mastodon = t.software?.toLowerCase() == 'mastodon';
  return [
    if (t.registrationOpen == false) '${t.displayName} はいま新しい登録を受け付けていないか、招待制です。招待のリンクを持っていなければ、別のサーバーを選んでください。',
    if (mastodon) ...[
      '${t.displayName} の登録ページを開きました。サーバーのルールが出たら読んで、「同意する」を押してください。',
      '表示名・ユーザー名・メールアドレス・パスワードを入れます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。',
      '登録を押すと、確認のメールが届きます。メールのリンクを開いて、メールアドレスを確かめてください。',
    ] else ...[
      '${t.displayName} のページを開きました。ページの「新規登録」を押してください。',
      'ユーザー名とパスワードを決めます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。',
      'サーバーによっては、メールアドレス・招待コード・ロボットでないことの確認を聞かれます。画面の案内のとおりに入れてください。',
      'サーバーのルール(利用規約)を読んで同意します。メールの確認を求められたら、届いたメールのリンクを開いてください。',
    ],
    [
      '登録が終わったら、下の「登録できた」を押してください。RASQ からこのサーバーにログインします。',
      if (t.post != null) 'ログインできたら、さっきの投稿を開きます。',
      if (t.list != null) 'ログインできたら、RASQ リスト「${t.list!.name}」を開きます。',
      if (!hasRasqAccount) 'RASQ アカウントは、あとからサイドバーの … で作れます。',
    ].join(''),
  ];
}

/// ページの URL から、案内の手順を進める(分かるときだけ)。Mastodon は登録を送るとメールの確認のページへ移る。
int? signupStepForUrl(ServerSignupTarget t, Uri url, int stepCount) {
  if (url.host != t.host) return null;
  final p = url.path;
  if (p.startsWith('/auth/setup') || p.startsWith('/auth/confirmation')) return stepCount - 2;
  return null;
}

/// 登録ページの WebView の部分(テストで差し替える)。[onUrlChanged] = ページを移ったとき。
typedef SignupWebAreaBuilder = Widget Function(BuildContext context, Uri url, ValueChanged<Uri> onUrlChanged);

/// アプリの中で WebView を開ける端末か(webview_flutter: Android / iOS / macOS)。Linux / Windows / Web は外部のブラウザ。
bool get inAppSignupWebViewSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

final signupWebAreaProvider = Provider<SignupWebAreaBuilder>(
  (ref) => (context, url, onUrlChanged) => inAppSignupWebViewSupported ? _InAppSignupWebView(url: url, onUrlChanged: onUrlChanged) : _ExternalSignupPanel(url: url),
);

/// 登録のページ (D-412)。広い画面は左に登録ページ・右に RAi の案内、狭い画面は上に案内・下に登録ページ。
class ServerSignupScreen extends ConsumerStatefulWidget {
  const ServerSignupScreen({super.key});
  @override
  ConsumerState<ServerSignupScreen> createState() => _ServerSignupScreenState();
}

class _ServerSignupScreenState extends ConsumerState<ServerSignupScreen> {
  int _step = 0;

  void _onUrl(ServerSignupTarget t, Uri url, int count) {
    final s = signupStepForUrl(t, url, count);
    if (s != null && s > _step && mounted) setState(() => _step = s);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(serverSignupTargetProvider);
    if (t == null) {
      return Scaffold(appBar: AppBar(title: const Text('サーバーに登録')), body: const Center(child: Text('登録するサーバーが選ばれていません')));
    }
    final steps = signupGuideSteps(t, hasRasqAccount: ref.watch(hasRasqAccountProvider));
    final step = _step.clamp(0, steps.length - 1);
    final web = ref.watch(signupWebAreaProvider)(context, t.signupUrl, (u) => _onUrl(t, u, steps.length));
    final guide = SignupRaiGuide(
      steps: steps,
      index: step,
      onPrev: step == 0 ? null : () => setState(() => _step = step - 1),
      onNext: step >= steps.length - 1 ? null : () => setState(() => _step = step + 1),
    );
    final done = Padding(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      child: FilledButton.icon(
        key: const ValueKey('signup.done'),
        onPressed: () => context.push(t.loginLocation),
        icon: const Icon(Icons.login, size: 18),
        label: const Text('登録できた(ログインへ)'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => context.pop()),
        title: Text('${t.displayName} に登録', overflow: TextOverflow.ellipsis),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= RasqSizes.tabletBreakpoint) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: web),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(RasqSpacing.sm), child: guide)),
                  done,
                ]),
              ),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, 0), child: guide),
            const SizedBox(height: RasqSpacing.sm),
            Expanded(child: web),
            done,
          ]);
        }),
      ),
    );
  }
}

/// RAi の案内(手順を 1 つずつ。前へ / 次へ)。
class SignupRaiGuide extends StatelessWidget {
  const SignupRaiGuide({super.key, required this.steps, required this.index, this.onPrev, this.onNext});
  final List<String> steps;
  final int index;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('signup.guide'),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const RaiIcon(size: 32),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text('RAi の案内', style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
          Text('${index + 1}/${steps.length}', key: const ValueKey('signup.guide.count'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(steps[index], key: const ValueKey('signup.guide.text'), style: RasqTypography.bodySmall),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(key: const ValueKey('signup.guide.prev'), onPressed: onPrev, child: const Text('前へ')),
          TextButton(key: const ValueKey('signup.guide.next'), onPressed: onNext, child: const Text('次へ')),
        ]),
      ]),
    );
  }
}

/// アプリの中の WebView(Android / iOS / macOS)。そのサーバーの中だけ開き、ほかのサイトへのリンクは外部のブラウザへ。
class _InAppSignupWebView extends StatefulWidget {
  const _InAppSignupWebView({required this.url, required this.onUrlChanged});
  final Uri url;
  final ValueChanged<Uri> onUrlChanged;
  @override
  State<_InAppSignupWebView> createState() => _InAppSignupWebViewState();
}

class _InAppSignupWebViewState extends State<_InAppSignupWebView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(
      onUrlChange: (c) {
        final u = c.url == null ? null : Uri.tryParse(c.url!);
        if (u != null) widget.onUrlChanged(u);
      },
      onNavigationRequest: (r) {
        final u = Uri.tryParse(r.url);
        if (!r.isMainFrame || u == null || u.host == widget.url.host || u.host.endsWith('.${widget.url.host}')) return NavigationDecision.navigate;
        if (u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'mailto') unawaited(launchUrl(u, mode: LaunchMode.externalApplication));
        return NavigationDecision.prevent;
      },
    ))
    ..loadRequest(widget.url);

  @override
  Widget build(BuildContext context) => WebViewWidget(key: const ValueKey('signup.webview'), controller: _controller);
}

/// アプリの中で開けない端末(Linux / Windows / Web): 外部のブラウザで開く。案内と「登録できた」はそのまま使う。
class _ExternalSignupPanel extends StatelessWidget {
  const _ExternalSignupPanel({required this.url});
  final Uri url;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RasqSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.open_in_browser, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: RasqSpacing.sm),
          Text('この端末では、アプリの中で登録ページを開けません。ブラウザで開いて登録し、終わったらこの画面に戻ってください。',
              style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: RasqSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('signup.openBrowser'),
            onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('ブラウザで登録ページを開く'),
          ),
          const SizedBox(height: RasqSpacing.xs),
          SelectableText(url.toString(), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// SNS のログインが済んだ (D-412): 進めていた登録と同じサーバーなら、タップした投稿 / RASQ リストを開く。
/// 投稿は新しいアカウントで引き直す(D-411 の [resolvePostOn]: 同じサーバーなので同じ id で読める)。見つからなければホームのまま伝える。
/// RASQ リストはページを開き、RASQ アカウントがあればホームの TL に取り込む(D-347、取れないリストは理由を伝える)。
///
/// D-413: タイルから登録した人は RASQ アカウントの問いを通っていないので、ここまで済んだら(最初のオンボーディングの終わり)
/// RASQ アカウントのポップアップを 1 回だけ頼む([requestRasqAccountNudge]。持っている人には出さない)。
Future<void> followSignupTarget(ProviderContainer c, AccountId account) async {
  final t = c.read(serverSignupTargetProvider);
  if (t == null || t.host != account.instance) return;
  c.read(serverSignupTargetProvider.notifier).set(null);
  try {
    await _openSignupTarget(c, t, account);
  } finally {
    await requestRasqAccountNudge(c);
  }
}

Future<void> _openSignupTarget(ProviderContainer c, ServerSignupTarget t, AccountId account) async {
  final router = c.read(routerProvider);
  void toast(String m) => c.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(m)));
  final post = t.post;
  if (post != null) {
    final found = await c.read(postResolverProvider)(post, account);
    if (found == null) {
      toast('${account.handle}@${account.instance} では、さっきの投稿を見つけられませんでした');
      return;
    }
    unawaited(router.push('/post/${Uri.encodeComponent(found.id)}', extra: found));
    return;
  }
  final list = t.list;
  if (list != null) {
    unawaited(router.push(Routes.rasqCollection(list.code ?? list.id)));
    if (c.read(hasRasqAccountProvider)) {
      final (message, _) = await importRasqListToHomeWith(c, list);
      toast(message);
    }
  }
}
