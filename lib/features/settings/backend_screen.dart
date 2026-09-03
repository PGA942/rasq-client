import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';
import 'settings_dsl.dart';

/// RASQ サーバー (`orgate-server`) の接続設定 (`/settings/server`)。
///
/// 接続先は本来ビルド時に `--dart-define=ORGATE_BASE_URL` で焼き込むが、
/// 開発中は手元のサーバーへ向け直せる必要がある。ここでの入力は KV
/// `backend.v1` の `baseUrl` に入り、焼き込み値より優先される。
///
/// 設定 DSL (D-031) ではなく素の画面なのは、設定 DSL の L2 タイル集合に
/// **自由入力の Input タイルがまだ無い**ため。タイルが増えたら
/// `assets/settings/backend.server.rrl.json` へ移せる。
class BackendSettingsScreen extends ConsumerStatefulWidget {
  const BackendSettingsScreen({super.key});
  @override
  ConsumerState<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends ConsumerState<BackendSettingsScreen> {
  final _url = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _probe;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref.read(settingsAreaProvider(backendSettingsArea).notifier).set('baseUrl', _url.text.trim());
    // 接続先が変わったので、アカウントとストアを取り直す。
    ref.invalidate(orgateAccountProvider);
    ref.invalidate(storeKeyProbeProvider);
    if (mounted) setState(() { _busy = false; _probe = null; });
  }

  Future<void> _test() async {
    setState(() { _busy = true; _probe = null; });
    final client = ref.read(orgateClientProvider);
    if (client == null) {
      setState(() { _busy = false; _probe = '接続先が設定されていません'; });
      return;
    }
    try {
      final key = await client.getJson('/store-key');
      final me = await client.getJson('/me');
      if (mounted) {
        setState(() {
          _busy = false;
          _probe = '接続 OK — 署名鍵 ${key['algorithm']} ${(key['publicKey'] as String? ?? '').substring(0, 12)}…'
              '\nRASQ アカウント: @${me['handle']} (${me['displayName']})';
        });
      }
    } on OrgateException catch (e) {
      if (mounted) setState(() { _busy = false; _probe = '接続できませんでした — $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = ref.watch(settingsAreaProvider(backendSettingsArea)).value?['baseUrl'];
    if (!_loaded && saved is String) {
      _url.text = saved;
      _loaded = true;
    }
    final base = ref.watch(orgateBaseUrlProvider);
    final account = ref.watch(orgateAccountProvider);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];

    return Scaffold(
      appBar: const RasqPageHeader(title: 'RASQ サーバー'),
      body: ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
        Text(
          'プラグインストアと RASQ アカウント、Mastodon などのログイン(OAuth ブローカー)に使うサーバーです。'
          'SNS の投稿やタイムラインはここを通らず、プラグインが各インスタンスへ直接接続します。',
          style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: RasqSpacing.md),
        Text('接続先', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        RasqInput(controller: _url, hintText: 'https://orgate.example', keyboardType: TextInputType.url),
        const SizedBox(height: RasqSpacing.sm),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: const Text('保存'))),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: OutlinedButton(onPressed: _busy ? null : _test, child: const Text('接続テスト'))),
        ]),
        if (_probe != null) ...[
          const SizedBox(height: RasqSpacing.sm),
          Text(_probe!, style: RasqTypography.bodySmall),
        ],
        const SizedBox(height: RasqSpacing.sm),
        Text(
          base == null
              ? '未接続 — プラグインストアはモック、RASQ アカウントは最初のログインアカウントからの流用になります。'
              : '接続中: $base',
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        const RasqSectionHeader(title: 'RASQ アカウント'),
        account.when(
          loading: () => const RasqLoading(),
          error: (e, _) => Text('アカウントを取得できませんでした: $e', style: RasqTypography.bodySmall.copyWith(color: RasqTokens.of(context).danger)),
          data: (a) => a == null
              ? Text('接続先が設定されていません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${a.handle}', style: RasqTypography.title),
                  Text(a.displayName, style: RasqTypography.bodySmall),
                  const SizedBox(height: 2),
                  Text('この端末でだけ有効なアカウントです。ハンドルと表示名はプロフィール編集から変更できます。',
                      style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ]),
        ),
        const RasqSectionHeader(title: 'アカウントバンドル'),
        Text(
          'サーバーには「どの SNS アカウントを束ねているか」だけを送ります。アクセストークンは端末から出ません。',
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (sessions.isEmpty)
          Text('ログイン中のアカウントはありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
        else
          for (final s in sessions) Text('・${s.account}', style: RasqTypography.bodySmall),
      ]),
    );
  }
}

/// 接続テストの結果をキャッシュしないためのダミー(invalidate 対象)。
final storeKeyProbeProvider = FutureProvider<Map<String, Object?>>((ref) async {
  final client = ref.watch(orgateClientProvider);
  if (client == null) return const {};
  return client.getJson('/store-key');
});
