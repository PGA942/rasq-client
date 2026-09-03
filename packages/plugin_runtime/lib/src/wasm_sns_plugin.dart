import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'async_wasm_plugin_controller.dart';
import 'wasm_sns_session.dart';

/// wasm SNS プラグインの**実登録の口** (D-079 / M5d): [SnsPlugin] 契約を
/// wasm モジュールに写すアダプター。[PluginRegistry] に登録すると、この
/// pluginId を持つ [AccountSession] が [WasmSnsSession](sns.* 境界)として
/// 解決される — アプリの通常パイプライン(TL/スレッド/アクション)が
/// そのまま wasm 境界の上で動く。
///
/// - アカウント毎にワーカー isolate([AsyncWasmPluginController])を 1 つ
///   開く(UI 非ブロック)。wasm バイトは初回に [loadBytes] で遅延ロード。
/// - **認証はホスト所有**(CONTRACT §18: アクセストークンをプラグインに
///   管理させない)。[beginAuth] は v1 では未対応 — 登録はホストが持つ
///   既存トークンを [AccountSession.token] として供給し、呼び出し毎に
///   `args.token` で wasm へ渡す(dev 画面の「実登録」)。
class WasmSnsPlugin extends SnsPlugin {
  WasmSnsPlugin({required this.manifest, required this.kind, required Future<Uint8List> Function() loadBytes, this.fowPermissions = const {'widget'}, this.nativeFetch = true}) : _loadBytes = loadBytes; // ignore: prefer_initializing_formals

  /// テストでは false(ネットワークを持たないワーカーになり、net.fetch は
  /// B01 で返る)。
  final bool nativeFetch;

  @override
  final PluginManifest manifest;

  @override
  final SnsKind kind;

  final Future<Uint8List> Function() _loadBytes;
  final Set<String> fowPermissions;

  final Map<String, Future<AsyncWasmPluginController>> _controllers = {};

  Future<AsyncWasmPluginController> _controllerFor(String accountKey) => _controllers.putIfAbsent(accountKey, () async {
        final c = AsyncWasmPluginController(wasmBytes: await _loadBytes(), fowPermissions: fowPermissions, nativeFetch: nativeFetch);
        await c.load();
        return c;
      });

  @override
  Future<ServerInfo> inspectServer(String host) async {
    final h = normalizeHost(host);
    return ServerInfo(host: h, name: h);
  }

  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) =>
      throw UnsupportedError('${manifest.id}: 認証はホスト所有 — v1 は既存トークンでの実登録(dev「実登録」)のみ');

  @override
  SnsSession open(AccountSession session) {
    final key = session.account.key;
    return WasmSnsSession(
      account: session.account,
      pluginId: manifest.id,
      // 接続先とトークンはホストが毎回供給する(v1 の規約、PROTOCOL §4.3)。
      extraArgs: {'host': session.account.instance, 'token': session.token},
      invoke: (fn, args) async => (await _controllerFor(key)).invoke(fn, args),
      onClose: () async {
        final pending = _controllers.remove(key);
        if (pending != null) (await pending).dispose();
      },
    );
  }
}
