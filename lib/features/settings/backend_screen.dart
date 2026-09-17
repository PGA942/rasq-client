import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_account_fow.dart';
import 'settings_dsl.dart';

/// RASQ サーバーの接続設定 (`/settings/server`)。
///
/// 2 面 (D-138): **RASQ Central**(`rasq-central` — RASQ アカウント / ストア /
/// プラグイン管理 / ユーザーデータ)と**エッジ**(`orgate-server` —
/// カルクレーター / AsTell / OAuth ブローカー)。接続先は本来ビルド時に
/// `--dart-define=RASQ_CENTRAL_URL` / `ORGATE_BASE_URL` で焼き込むが、開発中は
/// 手元のサーバーへ向け直せる必要がある。ここでの入力は KV `backend.v1` の
/// `centralUrl` / `baseUrl` に入り、焼き込み値より優先される。Central が空なら
/// エッジの接続先を流用する(1 台で兼ねる開発構成)。
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
  final _central = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _probe;

  @override
  void dispose() {
    _url.dispose();
    _central.dispose();
    super.dispose();
  }

  /// 入力を正して保存する (D-239)。解釈できない入力は保存せず、理由を出す。戻り値 = 保存できたか。
  Future<bool> _save({bool quiet = false}) async {
    final central = _central.text.trim();
    final edge = _url.text.trim();
    final centralUri = central.isEmpty ? null : normalizeServerUrl(central);
    final edgeUri = edge.isEmpty ? null : normalizeServerUrl(edge);
    if ((central.isNotEmpty && centralUri == null) || (edge.isNotEmpty && edgeUri == null)) {
      setState(() => _probe = '接続先を解釈できません。「http://192.168.3.14:8080」や「https://central.example」の形で入れてください。');
      return false;
    }
    setState(() => _busy = true);
    // 正した形を欄にも戻す(スキームの補完など)。
    _central.text = centralUri?.toString() ?? '';
    _url.text = edgeUri?.toString() ?? '';
    await ref.read(settingsAreaProvider(backendSettingsArea).notifier).set('baseUrl', _url.text);
    await ref.read(settingsAreaProvider(backendSettingsArea).notifier).set('centralUrl', _central.text);
    // 接続先が変わったので、アカウントとストアを取り直す。
    ref.invalidate(orgateAccountProvider);
    ref.invalidate(storeKeyProbeProvider);
    if (mounted) setState(() { _busy = false; if (!quiet) _probe = '保存しました'; });
    return true;
  }

  /// 接続テスト (D-239): **いま入力してある接続先**で試す(先に保存する。以前は保存前の値で試して
  /// 「接続先が設定されていません」になった)。
  Future<void> _test() async {
    if (!await _save(quiet: true)) return;
    setState(() { _busy = true; _probe = null; });
    final client = ref.read(centralClientProvider);
    if (client == null) {
      setState(() { _busy = false; _probe = '接続先を入力してください(例: http://192.168.3.14:8080)'; });
      return;
    }
    // 接続の成否は公開の口 `/store-key` だけで決める。`/me` は RASQ アカウントが要るので、未作成の
    // 端末では 401 になる — それは「接続できない」ではない (D-240)。
    final Map<String, Object?> key;
    try {
      key = await client.getJson('/store-key');
    } on OrgateException catch (e) {
      if (mounted) setState(() { _busy = false; _probe = '接続できませんでした(${ref.read(centralBaseUrlProvider)})— $e'; });
      return;
    }
    final ok = '接続 OK — 署名鍵 ${key['algorithm']} ${_head(key['publicKey'] as String? ?? '')}…';
    String accountLine;
    try {
      final me = await client.getJson('/me');
      accountLine = 'RASQ アカウント: @${me['handle']} (${me['displayName']})';
    } on OrgateException catch (e) {
      accountLine = e.code.code == '401' ? 'RASQ アカウント: 未作成(下の「RASQ アカウントを開く」から作成できます)' : 'RASQ アカウントを取得できませんでした — $e';
    }
    if (mounted) setState(() { _busy = false; _probe = '$ok\n$accountLine'; });
  }

  static String _head(String s) => s.length <= 12 ? s : s.substring(0, 12);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final area = ref.watch(settingsAreaProvider(backendSettingsArea)).value;
    if (!_loaded && area != null) {
      _url.text = area['baseUrl'] is String ? area['baseUrl'] as String : '';
      _central.text = area['centralUrl'] is String ? area['centralUrl'] as String : '';
      _loaded = true;
    }
    final base = ref.watch(orgateBaseUrlProvider);
    final central = ref.watch(centralBaseUrlProvider);
    final account = ref.watch(orgateAccountProvider);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];

    return Scaffold(
      appBar: const RasqPageHeader(title: 'RASQ サーバー'),
      body: ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
        Text(
          'RASQ Central は RASQ アカウント・プラグインストア・プラグイン管理・ユーザーデータのサーバー、'
          'エッジはカルクレーター / AsTell と Mastodon などのログイン(OAuth ブローカー)のサーバーです。'
          'SNS の投稿やタイムラインはどちらも通らず、プラグインが各インスタンスへ直接接続します。',
          style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: RasqSpacing.md),
        Text('RASQ Central の接続先(空ならエッジを流用)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        RasqInput(key: const ValueKey('backend.central'), controller: _central, hintText: 'https://central.rasq.example', keyboardType: TextInputType.url),
        const SizedBox(height: RasqSpacing.sm),
        Text('エッジ(orgate-server)の接続先', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        RasqInput(key: const ValueKey('backend.edge'), controller: _url, hintText: 'https://orgate.example', keyboardType: TextInputType.url),
        const SizedBox(height: RasqSpacing.sm),
        Row(children: [
          Expanded(child: FilledButton(key: const ValueKey('backend.save'), onPressed: _busy ? null : () => _save(), child: const Text('保存'))),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: OutlinedButton(key: const ValueKey('backend.test'), onPressed: _busy ? null : _test, child: const Text('接続テスト'))),
        ]),
        if (_probe != null) ...[
          const SizedBox(height: RasqSpacing.sm),
          Text(_probe!, key: const ValueKey('backend.probe'), style: RasqTypography.bodySmall),
        ],
        const SizedBox(height: RasqSpacing.sm),
        Text(
          [
            central == null ? 'Central: 未接続 — プラグインストアはモック、RASQ アカウントは作成できません(この端末のみ)。' : 'Central: $central',
            base == null ? 'エッジ: 未接続' : 'エッジ: $base',
          ].join('\n'),
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        const RasqSectionHeader(title: 'RASQ アカウント'),
        account.when(
          loading: () => const RasqLoading(),
          error: (e, _) => Text('アカウントを取得できませんでした: $e', style: RasqTypography.bodySmall.copyWith(color: RasqTokens.of(context).danger)),
          data: (a) => a == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(central == null ? '接続先が設定されていません。' : 'RASQ アカウントは未作成です。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                  if (central != null)
                    TextButton(key: const ValueKey('backend.account'), onPressed: () => openRasqAccountFow(ref), child: const Text('RASQ アカウントを開く')),
                ])
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
  final client = ref.watch(centralClientProvider);
  if (client == null) return const {};
  return client.getJson('/store-key');
});
