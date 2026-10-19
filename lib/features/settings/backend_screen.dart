import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/test_endpoints.dart';
import '../../backend/rasq_account.dart';
import '../../l10n/l10n.dart';
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
  final _testAddress = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _probe;

  @override
  void dispose() {
    _url.dispose();
    _central.dispose();
    _testAddress.dispose();
    super.dispose();
  }

  /// 入力を正して保存する (D-239)。解釈できない入力は保存せず、理由を出す。戻り値 = 保存できたか。
  Future<bool> _save({bool quiet = false}) async {
    final l = context.l10n;
    final central = _central.text.trim();
    final edge = _url.text.trim();
    final centralUri = central.isEmpty ? null : normalizeServerUrl(central);
    final edgeUri = edge.isEmpty ? null : normalizeServerUrl(edge);
    if ((central.isNotEmpty && centralUri == null) || (edge.isNotEmpty && edgeUri == null)) {
      setState(() => _probe = l.settingsBackendErrorUnparseable);
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
    if (mounted) setState(() { _busy = false; if (!quiet) _probe = l.settingsBackendSaved; });
    return true;
  }

  /// 接続テスト (D-239): **いま入力してある接続先**で試す(先に保存する。以前は保存前の値で試して
  /// 「接続先が設定されていません」になった)。D-405: Central に加えて ORGATE も確かめる(前は Central だけを見ていて、
  /// ORGATE の接続先を間違えても「接続 OK」になり、逆に ORGATE の URL を Central の欄に入れると訳の分からない 404 だった)。
  Future<void> _test() async {
    final l = context.l10n;
    if (!await _save(quiet: true)) return;
    setState(() { _busy = true; _probe = null; });
    final client = ref.read(centralClientProvider);
    if (client == null) {
      setState(() { _busy = false; _probe = l.settingsBackendErrorEnterUrl; });
      return;
    }
    final lines = [await _probeCentral(client), await _probeOrgate()];
    if (mounted) setState(() { _busy = false; _probe = lines.join('\n'); });
  }

  /// Central: 接続の成否は公開の口 `/store-key` だけで決める。`/me` は RASQ アカウントが要るので、未作成の
  /// 端末では 401 になる — それは「接続できない」ではない (D-240)。
  Future<String> _probeCentral(OrgateClient client) async {
    final l = context.l10n;
    final centralUrl = ref.read(centralBaseUrlProvider);
    final Map<String, Object?> key;
    try {
      key = await client.getJson('/store-key');
    } on OrgateException catch (e) {
      // ストアの口が無い = Central ではないサーバー(ORGATE の URL を Central の欄に入れた / Central の欄が空で ORGATE を流用した)。
      final hint = e.code.code == '404' ? '\n${l.settingsBackendCentralNotCentralHint}' : '';
      return l.settingsBackendCentralConnectFailed('$centralUrl', '$e', hint);
    }
    final ok = l.settingsBackendCentralOk('${key['algorithm']}', _head(key['publicKey'] as String? ?? ''));
    String accountLine;
    try {
      final me = await client.getJson('/me');
      accountLine = l.settingsBackendAccountLine('${me['handle']}', '${me['displayName']}');
    } on OrgateException catch (e) {
      accountLine = e.code.code == '401' ? l.settingsBackendAccountNotCreatedLine : l.settingsBackendAccountLoadFailedLine('$e');
    }
    return '$ok\n$accountLine';
  }

  /// ORGATE: アクセストークンの公開鍵の口 `/auth/keys`(認証なし、Central もここから鍵を読む)。
  Future<String> _probeOrgate() async {
    final l = context.l10n;
    final orgate = ref.read(orgateClientProvider);
    if (orgate == null) return l.settingsBackendOrgateNotConfiguredLine;
    final base = ref.read(orgateBaseUrlProvider);
    try {
      final keys = await orgate.getJson('/auth/keys');
      final n = keys['keys'] is List ? (keys['keys'] as List).length : 0;
      return n > 0 ? l.settingsBackendOrgateOk(n) : l.settingsBackendOrgateNoKeys('$base');
    } on OrgateException catch (e) {
      return l.settingsBackendOrgateConnectFailed('$base', '$e');
    }
  }

  static String _head(String s) => s.length <= 12 ? s : s.substring(0, 12);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final area = ref.watch(settingsAreaProvider(backendSettingsArea)).value;
    if (!_loaded && area != null) {
      _url.text = area['baseUrl'] is String ? area['baseUrl'] as String : '';
      _central.text = area['centralUrl'] is String ? area['centralUrl'] as String : '';
      _testAddress.text = area[TestEndpoints.keyAddress] is String ? area[TestEndpoints.keyAddress] as String : TestEndpoints.defaultAddress;
      _loaded = true;
    }
    final base = ref.watch(orgateBaseUrlProvider);
    final central = ref.watch(centralBaseUrlProvider);
    final account = ref.watch(orgateAccountProvider);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final l = context.l10n;

    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsBackendTitle),
      body: ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
        RasqCaption(
          l.settingsBackendCaption,
          detail: l.settingsBackendCaptionDetail,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: RasqSpacing.md),
        Text(l.settingsBackendCentralLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        RasqInput(key: const ValueKey('backend.central'), controller: _central, hintText: 'https://central.rasq.example', keyboardType: TextInputType.url),
        const SizedBox(height: RasqSpacing.sm),
        Text(l.settingsBackendOrgateLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        RasqInput(key: const ValueKey('backend.edge'), controller: _url, hintText: 'https://orgate.example', keyboardType: TextInputType.url),
        const SizedBox(height: RasqSpacing.sm),
        Row(children: [
          Expanded(child: FilledButton(key: const ValueKey('backend.save'), onPressed: _busy ? null : () => _save(), child: Text(l.settingsBackendSaveButton))),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: OutlinedButton(key: const ValueKey('backend.test'), onPressed: _busy ? null : _test, child: Text(l.settingsBackendTestButton))),
        ]),
        if (_probe != null) ...[
          const SizedBox(height: RasqSpacing.sm),
          Text(_probe!, key: const ValueKey('backend.probe'), style: RasqTypography.bodySmall),
        ],
        const SizedBox(height: RasqSpacing.sm),
        Text(
          [
            central == null ? rasqDetail(context, l.settingsBackendCentralDisconnected, l.settingsBackendCentralDisconnectedDetail) : 'Central: $central',
            base == null ? l.settingsBackendOrgateDisconnected : 'ORGATE: $base',
          ].join('\n'),
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        // テスト用の接続先 (D-360): プレビュー録画用のダミー環境(rasq-preview-assets の dummy/run_all.sh)。開発者モードのときだけ (D-393)。
        if (RasqDeveloperMode.of(context) || area?[TestEndpoints.keyEnabled] == true) ...[
        RasqSectionHeader(title: l.settingsBackendTestEndpointsSection),
        Builder(builder: (context) {
          final on = area?[TestEndpoints.keyEnabled] == true;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RasqSwitchListTile(
              key: const ValueKey('backend.testEndpoints'),
              title: l.settingsBackendTestEndpointsTitle,
              subtitle: l.settingsBackendTestEndpointsSubtitle,
              detail: l.settingsBackendTestEndpointsDetail(TestEndpoints.misskeyHost, TestEndpoints.mastodonHost, TestEndpoints.blueskyHost, '${TestEndpoints.centralPort}', '${TestEndpoints.orgatePort}'),
              value: on,
              onChanged: _busy
                  ? null
                  : (v) async {
                      await setTestEndpoints(ref, enabled: v, address: _testAddress.text);
                      ref.invalidate(orgateAccountProvider);
                      if (mounted) setState(() => _central.text = ref.read(settingsAreaProvider(backendSettingsArea)).value?['centralUrl'] as String? ?? '');
                    },
            ),
            const SizedBox(height: 4),
            Text(l.settingsBackendTestAddressLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            RasqInput(
              key: const ValueKey('backend.testAddress'),
              controller: _testAddress,
              hintText: TestEndpoints.defaultAddress,
              keyboardType: TextInputType.url,
              onSubmitted: (_) async {
                if (on) await setTestEndpoints(ref, enabled: true, address: _testAddress.text);
              },
            ),
            const SizedBox(height: 4),
            RasqCaption(
              l.settingsBackendTestCaption,
              detail: l.settingsBackendTestCaptionDetail,
              padding: EdgeInsets.zero,
            ),
          ]);
        }),
        ],
        RasqSectionHeader(title: l.settingsBackendAccountSection),
        account.when(
          loading: () => const RasqLoading(),
          error: (e, _) => Text(l.settingsBackendAccountLoadError('$e'), style: RasqTypography.bodySmall.copyWith(color: RasqTokens.of(context).danger)),
          data: (a) => a == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(central == null ? l.settingsBackendNoServer : l.settingsBackendAccountNotCreated, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                  if (central != null)
                    TextButton(key: const ValueKey('backend.account'), onPressed: () => openRasqAccountFow(ref), child: Text(l.settingsBackendOpenAccountButton)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${a.handle}', style: RasqTypography.title),
                  Text(a.displayName, style: RasqTypography.bodySmall),
                  const SizedBox(height: 2),
                  Text(l.settingsBackendAccountDeviceOnly,
                      style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ]),
        ),
        RasqSectionHeader(title: l.settingsBackendBundleSection),
        RasqCaption(
          // 規約案 02 第 4 項 (D-372): 鍵(アクセストークン)が端末の外へ出る経路を正しく。
          l.settingsBackendBundleCaption,
          detail: l.settingsBackendBundleCaptionDetail,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        if (sessions.isEmpty)
          Text(l.settingsBackendNoSessions, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
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
