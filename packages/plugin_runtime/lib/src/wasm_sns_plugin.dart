import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'async_wasm_plugin_controller.dart';
import 'fuel_budget.dart';
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
///   管理させない)。トークンの発行経路はプラグイン種別で違うので
///   [authFlowFactory] として外から注入する — 例えば Mastodon は
///   `client_secret` が要るためサーバー(orgate-server)の OAuth ブローカー
///   経由になる。注入が無ければ従来どおり「既存トークンでの実登録」
///   (dev 画面)のみ。発行後は [AccountSession.token] として保持し、
///   呼び出し毎に `args.token` で wasm へ渡す。
class WasmSnsPlugin extends SnsPlugin {
  WasmSnsPlugin({
    required this.manifest,
    required this.kind,
    required Future<Uint8List> Function() loadBytes,
    this.fowPermissions = const {'widget'},
    this.nativeFetch = true,
    this.authFlowFactory,
  }) : _loadBytes = loadBytes; // ignore: prefer_initializing_formals

  /// 認証フローの供給元。null なら [beginAuth] は [UnsupportedError]。
  final Future<AuthFlow> Function(String host, {Uri? callback})? authFlowFactory;

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
        // 権限はマニフェスト宣言がそのまま実行時のゲートになる (D-004)。
        final permissions = manifest.permissions.toSet();
        final c = AsyncWasmPluginController(wasmBytes: await _loadBytes(), fowPermissions: fowPermissions, nativeFetch: nativeFetch, permissions: permissions, fuelPerCall: fuelBudgetFor(permissions: permissions));
        await c.load();
        return c;
      });

  /// 認証前の呼び出し用に 1 つだけ持つ匿名コントローラ。アカウントごとの
  /// ものとは別に置く(まだ [AccountSession] が無いため)。
  static const _anonymousKey = '';

  /// セッション無しの匿名ワーカーで `fn` を呼ぶ(D-175: Bluesky の `sns.login` など、
  /// 認証前の呼び出し)。戻りは `{ok, value}` / `{ok:false, error}` の生の結果。
  Future<Map<String, dynamic>> callAnonymous(String fn, Map<String, Object?> args) async {
    final controller = await _controllerFor(_anonymousKey);
    return controller.invoke(fn, args);
  }

  @override
  Future<ServerInfo> inspectServer(String host) async {
    final h = normalizeHost(host);
    // サーバー情報の取り方は SNS ごとに違うのでプラグインに聞く
    // (`sns.inspectServer`)。未実装(C01)や失敗はホスト名だけで縮退する
    // — サーバー検索画面が出せなくなるより、名前だけでも出す方がよい。
    try {
      final controller = await _controllerFor(_anonymousKey);
      final result = await controller.invoke('sns.inspectServer', {'host': h});
      if (result['ok'] == true) {
        final s = ((result['value'] as Map?)?['server'] as Map?)?.cast<String, Object?>();
        if (s != null) {
          return ServerInfo(
            host: s['host'] as String? ?? h,
            name: s['name'] as String? ?? h,
            software: s['software'] as String?,
            version: s['version'] as String?,
            description: s['description'] as String?,
            iconUrl: switch (s['iconUrl']) { final String u when u.isNotEmpty => Uri.tryParse(u), _ => null },
            registrationOpen: s['registrationOpen'] as bool?,
            maintainer: s['maintainer'] as String?,
          );
        }
      }
    } catch (e) {
      debugPrint('${manifest.id}: sns.inspectServer failed, falling back to the host name: $e');
    }
    return ServerInfo(host: h, name: h);
  }

  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) {
    final factory = authFlowFactory;
    if (factory == null) {
      throw UnsupportedError('${manifest.id}: 認証フローが構成されていません(既存トークンでの実登録のみ)');
    }
    return factory(normalizeHost(host), callback: callback);
  }

  /// 開いているワーカーをすべて閉じる。アカウントごとのものは
  /// [SnsSession.close] で落ちるが、[inspectServer] が開く匿名ワーカーは
  /// セッションを持たないのでここでしか片付けられない。
  Future<void> dispose() async {
    final pending = _controllers.values.toList();
    _controllers.clear();
    for (final p in pending) {
      (await p).dispose();
    }
  }

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
