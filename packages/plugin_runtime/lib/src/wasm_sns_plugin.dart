import 'dart:convert';

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
    this.onFetchShape,
    this.onSessionToken,
  }) : _loadBytes = loadBytes; // ignore: prefer_initializing_formals

  /// プラグインがトークンを取り直した (D-422): 新しいトークン(ホストが [AccountSession.token] として持つ形)。
  /// アプリは端末のセッションの保存を書き換える(再起動しても、ほかの端末へ共有しても、取り直した組が使われるように)。
  /// 前は取り直した組がワーカーのメモリ(`storage.safe`)にしか無く、再起動すると使い終わった古い組に戻っていた。
  final void Function(AccountId account, String token)? onSessionToken;

  /// 開いているセッション(アカウントのキーごと)。取り直しの写しを、どのセッションのものか見分ける。
  final Map<String, AccountSession> _open = {};

  /// `storage.set` の写し [write] (`{ns, key, value}`) が、[token] の取り直し(`safe` の `session:<id>` に
  /// `{accessJwt, refreshJwt}`。Bluesky の規約、D-175)なら、組を差し替えたトークン。違えば / 変わらなければ null。
  @visibleForTesting
  static String? refreshedToken(String token, Map<String, Object?> write) {
    if (write['ns'] != 'safe') return null;
    final key = '${write['key']}';
    if (!key.startsWith('session:')) return null;
    final value = write['value'];
    if (value is! Map) return null;
    final Object? current;
    try {
      current = jsonDecode(token);
    } catch (_) {
      return null;
    }
    if (current is! Map) return null;
    final id = key.substring('session:'.length);
    if (current['did'] != null && '${current['did']}' != id) return null;
    final merged = <String, Object?>{...current.cast<String, Object?>()};
    var changed = false;
    for (final k in const ['accessJwt', 'refreshJwt']) {
      final v = value[k];
      if (v is String && v.isNotEmpty && merged[k] != v) {
        merged[k] = v;
        changed = true;
      }
    }
    return changed ? jsonEncode(merged) : null;
  }

  /// 初めて見た `net.fetch` の形(値は無い)の受け口。アプリが同意を見て
  /// ストアへ報告する。null なら捨てる。
  final void Function(String pluginId, String version, Map<String, Object?> shape)? onFetchShape;

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

  /// インスタンスのホストを渡し済みのアカウント(controller の生存と同じ寿命)。
  final Map<String, String> _granted = {};

  Future<AsyncWasmPluginController> _controllerFor(String accountKey) => _controllers.putIfAbsent(accountKey, () async {
        // 権限はマニフェスト宣言がそのまま実行時のゲートになる (D-004)。
        // 接続先も同じ (schema v0.12): `network.hosts` は静的に、インスタンスは
        // セッションごとに `grantHost` で。宣言が無ければどこにも繋げない。
        final permissions = manifest.permissions.toSet();
        final network = manifest.network ?? PluginNetwork.none;
        final c = AsyncWasmPluginController(
          wasmBytes: await _loadBytes(), fowPermissions: fowPermissions, nativeFetch: nativeFetch, permissions: permissions,
          fuelPerCall: fuelBudgetFor(permissions: permissions),
          fetchHosts: network.hosts.toSet(), instanceAllowed: network.instance,
          // gpu.compute (D-081): 審査済み (`verified`) のマニフェストだけ。`gpu_ml` の宣言は env が重ねて見る。
          gpuCompute: manifest.verified,
        );
        await c.load();
        final hook = onFetchShape;
        if (hook != null) c.fetchShapes.listen((s) => hook(manifest.id, manifest.version, s));
        // 取り直したトークンをホストへ戻す (D-422)。匿名ワーカー(ログイン前)には無い。
        if (accountKey != _anonymousKey) {
          c.storageWrites.listen((w) {
            final session = _open[accountKey];
            final cb = onSessionToken;
            if (session == null || cb == null) return;
            final next = refreshedToken(session.token, w);
            if (next == null) return;
            _open[accountKey] = session.copyWith(token: next);
            cb(session.account, next);
          });
        }
        return c;
      });

  /// 開発 / デモ用の接続先の差し替え (D-359、`RASQ_DEV_SNS_BASE`): プラグインへ `baseUrl` を渡す。
  static Map<String, Object?> _baseArgs(String host) {
    final base = devSnsBaseFor(host);
    return base == null ? const {} : {'baseUrl': base.toString().replaceAll(RegExp(r'/$'), '')};
  }

  /// ランタイムに許可するホスト: 差し替えがあればその基底 URL のホスト(ランタイムはポートを除いて比べる)。
  static String _grantedHostFor(String host) => devSnsBaseFor(host)?.host ?? host;

  /// 認証前の呼び出し用に 1 つだけ持つ匿名コントローラ。アカウントごとの
  /// ものとは別に置く(まだ [AccountSession] が無いため)。
  static const _anonymousKey = '';

  /// セッション無しの匿名ワーカーで `fn` を呼ぶ(D-175: Bluesky の `sns.login` など、
  /// 認証前の呼び出し)。戻りは `{ok, value}` / `{ok:false, error}` の生の結果。
  Future<Map<String, dynamic>> callAnonymous(String fn, Map<String, Object?> args) async {
    final controller = await _controllerFor(_anonymousKey);
    // 匿名の呼び出しはまだセッションが無いので、ホストが渡す `args.host`
    // (ユーザーが選んだ先)をそのまま今回のインスタンスとして許可する。
    final host = args['host'] is String ? args['host'] as String : null;
    await controller.grantHost(host == null ? null : _grantedHostFor(host));
    return controller.invoke(fn, {...args, if (host != null) ..._baseArgs(host)});
  }

  /// 設定ページ (D-044 / D-482): `sns.settingsPages {}` → `{pages: [rasq.settings-page/1 …]}`。
  /// アカウントに依らないので匿名ワーカーで 1 度だけ読んで持つ。未実装(C01)は「ページ無し」として持つ。
  /// 失敗(ワーカーが起きない等)は持たず、次に開いたときに読み直す。
  /// 表示の言語ごとに持つ (D-484 / 契約 v0.24): ページの文言はプラグインが `args.locale` で選ぶので、言語が変われば読み直す。
  List<String> _settingsPages = const [];
  Future<List<String>>? _settingsPagesLoad;
  String? _settingsPagesLocale;

  @override
  List<String> get settingsPages => _settingsPages;

  @override
  Future<List<String>> loadSettingsPages() {
    if (_settingsPagesLocale != RasqUiLocale.tag) {
      _settingsPagesLocale = RasqUiLocale.tag;
      _settingsPagesLoad = null;
    }
    return _loadSettingsPages();
  }

  Future<List<String>> _loadSettingsPages() => _settingsPagesLoad ??= () async {
        try {
          final result = await callAnonymous('sns.settingsPages', const {});
          if (result['ok'] != true) {
            final code = (result['error'] as Map?)?['code'];
            if (code != 'C01') _settingsPagesLoad = null;
            return _settingsPages = const [];
          }
          final pages = ((result['value'] as Map?)?['pages'] as List?) ?? const [];
          return _settingsPages = [
            for (final p in pages)
              if (p is Map) jsonEncode(p) else if (p is String) p,
          ];
        } catch (e) {
          debugPrint('${manifest.id}: sns.settingsPages failed: $e');
          _settingsPagesLoad = null;
          return const <String>[];
        }
      }();

  @override
  Future<ServerInfo> inspectServer(String host) async {
    final h = normalizeHost(host);
    // サーバー情報の取り方は SNS ごとに違うのでプラグインに聞く
    // (`sns.inspectServer`)。未実装(C01)や失敗はホスト名だけで縮退する
    // — サーバー検索画面が出せなくなるより、名前だけでも出す方がよい。
    try {
      final controller = await _controllerFor(_anonymousKey);
      await controller.grantHost(_grantedHostFor(h));
      final result = await controller.invoke('sns.inspectServer', {'host': h, ..._baseArgs(h)});
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
    _open[key] = session;
    return WasmSnsSession(
      account: session.account,
      pluginId: manifest.id,
      // 接続先とトークンはホストが毎回供給する(v1 の規約、PROTOCOL §4.3)。
      extraArgs: {'host': session.account.instance, 'token': session.token},
      // `network.instance`: ランタイムに許可するのも同じホスト。ワーカーごとに
      // 1 アカウントなので、初回に一度渡せばよい(メッセージは順序を保つ)。
      invoke: (fn, args) async {
        final c = await _controllerFor(key);
        // 差し替え (D-359 / 実行時の「テスト用の接続先」) は呼び出しのたびに読む: 途中で切り替えても次の呼び出しから効く。
        final grant = _grantedHostFor(session.account.instance);
        if (_granted[key] != grant) {
          _granted[key] = grant;
          await c.grantHost(grant);
        }
        return c.invoke(fn, {...args, ..._baseArgs(session.account.instance)});
      },
      onClose: () async {
        _granted.remove(key);
        _open.remove(key);
        final pending = _controllers.remove(key);
        if (pending != null) (await pending).dispose();
      },
    );
  }
}
