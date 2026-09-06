import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';

import '../features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'rasq_account.dart' show orgateTokenHolderProvider;

/// ORGATE サーバー(`orgate-server`)への接続。
///
/// サーバーが受け持つのは**クライアント単体では成立しない仕事**だけ:
/// プラグインストア (D-033)、RASQ アカウント (D-087)、そして Mastodon など
/// アクセストークン発行に `client_secret` が要る SNS の OAuth ブローカー
/// (CONTRACT §3)。SNS のデータ経路(CONTRACT §5)はここを通らない —
/// TL 取得も投稿もプラグインがインスタンスへ直接出す。
///
/// 接続先は `--dart-define=ORGATE_BASE_URL=...` を既定にし、KV
/// `backend.v1` の `baseUrl` で上書きできる(開発中に手元のサーバーへ
/// 向けるため)。**未設定なら null** — 呼び出し側はモックへ縮退する。

/// ビルド時に焼き込む既定の接続先(**エッジ**: カルクレーター / AsTell /
/// OAuth ブローカー = `orgate-server`)。
const _defaultBaseUrl = String.fromEnvironment('ORGATE_BASE_URL');

/// **RASQ Central** (`rasq-central`, D-138) — RASQ アカウント / ストア /
/// プラグイン管理 / ユーザーデータ。未設定なら [_defaultBaseUrl](エッジ)へ
/// 縮退する(1 台で両方を兼ねる開発構成をそのまま動かすため)。
const _defaultCentralUrl = String.fromEnvironment('RASQ_CENTRAL_URL');

/// ストアの署名検証に使う ed25519 公開鍵 (base64) をビルド時に焼き込む。
/// 焼き込んであれば、サーバーが返す `storePublicKey` がこれと一致することを
/// 確かめてから署名検証する(サーバーがすり替わっても気付ける)。
const pinnedStorePublicKey = String.fromEnvironment('ORGATE_STORE_PUBLIC_KEY');

/// KV `backend.v1` の設定領域名。
const backendSettingsArea = 'backend';

/// 現在の接続先。末尾スラッシュは落とす。未設定は null。
final orgateBaseUrlProvider = Provider<Uri?>((ref) {
  final override = ref.watch(settingsAreaProvider(backendSettingsArea)).value?['baseUrl'];
  final raw = (override is String && override.trim().isNotEmpty) ? override.trim() : _defaultBaseUrl;
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return uri;
});

/// サーバーに繋がる構成かどうか。false ならストアはモック、RASQ アカウントは
/// 最初のログインアカウントからの流用に縮退する。
final orgateConfiguredProvider = Provider<bool>((ref) => ref.watch(orgateBaseUrlProvider) != null);

Uri? _parseBase(String raw) {
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return uri;
}

/// RASQ Central の接続先 (D-138)。KV `backend.v1` の `centralUrl` →
/// `--dart-define=RASQ_CENTRAL_URL` → 無ければ**エッジの接続先を流用**。
final centralBaseUrlProvider = Provider<Uri?>((ref) {
  final override = ref.watch(settingsAreaProvider(backendSettingsArea)).value?['centralUrl'];
  final raw = (override is String && override.trim().isNotEmpty) ? override.trim() : _defaultCentralUrl;
  return _parseBase(raw) ?? ref.watch(orgateBaseUrlProvider);
});

/// RASQ アカウントを作れる(Central に繋がる)構成か。オンボーディングの
/// 「RASQ アカウントを作成」とストアのブックマークはこれで出し分ける。
final centralConfiguredProvider = Provider<bool>((ref) => ref.watch(centralBaseUrlProvider) != null);

/// サーバーが返す `{"error": {"code", "message"}}`。code は CONTRACT §9 の
/// 体系なので、そのまま [ErrorCode] に落ちる。
class OrgateException implements Exception {
  OrgateException(this.code, this.message);
  final ErrorCode code;
  final String message;

  /// ユーザーに見せる 1 行。
  @override
  String toString() => '${code.code}: $message';
}

/// `/api/v1` 配下への薄い HTTP 口。認証は Bearer だけで Cookie は使わない。
class OrgateClient {
  OrgateClient({required this.baseUrl, http.Client? httpClient, this.tokenProvider}) : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _http;

  /// 呼び出しごとに現在の RASQ アカウントトークンを取りに行く。null なら匿名。
  final String? Function()? tokenProvider;

  static const _timeout = Duration(seconds: 20);

  Uri _url(String path, [Map<String, String?> query = const {}]) {
    final q = {for (final e in query.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    return baseUrl.replace(
      path: '${baseUrl.path}/api/v1$path',
      queryParameters: q.isEmpty ? null : q,
    );
  }

  Map<String, String> _headers({bool json = false}) {
    final token = tokenProvider?.call();
    return {
      if (json) 'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Never _fail(http.Response r) {
    String message = 'サーバーエラー (${r.statusCode})';
    ErrorCode code = ErrorCode.http(r.statusCode);
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (body is Map && body['error'] is Map) {
        final err = (body['error'] as Map).cast<String, Object?>();
        message = err['message'] as String? ?? message;
        code = ErrorCode.tryParse(err['code'] as String? ?? '') ?? code;
      }
    } catch (_) {
      // JSON でない応答(プロキシのエラーページ等)は HTTP コードのまま扱う。
    }
    throw OrgateException(code, message);
  }

  Future<Object?> _send(http.BaseRequest req) async {
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on Exception catch (e) {
      // 到達不能は B01 (CONTRACT §9)。オフライン表示の判定に使える。
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    if (r.statusCode == 204 || r.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  http.Request _req(String method, String path, {Map<String, String?> query = const {}, Object? body}) {
    final req = http.Request(method, _url(path, query))..headers.addAll(_headers(json: body != null));
    if (body != null) req.body = jsonEncode(body);
    return req;
  }

  Future<Map<String, Object?>> getJson(String path, [Map<String, String?> query = const {}]) async =>
      ((await _send(_req('GET', path, query: query))) as Map?)?.cast<String, Object?>() ?? const {};

  Future<List<Object?>> getList(String path, [Map<String, String?> query = const {}]) async =>
      (await _send(_req('GET', path, query: query))) as List? ?? const [];

  Future<Map<String, Object?>> postJson(String path, Object body) async =>
      ((await _send(_req('POST', path, body: body))) as Map?)?.cast<String, Object?>() ?? const {};

  Future<Map<String, Object?>> patchJson(String path, Object body) async =>
      ((await _send(_req('PATCH', path, body: body))) as Map?)?.cast<String, Object?>() ?? const {};

  /// 生バイト列の POST(共有コンテンツのアップロード等)。応答は JSON。
  Future<Map<String, Object?>> postBytes(String path, List<int> bytes, {required String contentType, Map<String, String> headers = const {}}) async {
    final http.Response r;
    try {
      r = await _http
          .post(_url(path), headers: {..._headers(), 'content-type': contentType, ...headers}, body: bytes)
          .timeout(_timeout * 6);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    final body = r.bodyBytes.isEmpty ? const {} : jsonDecode(utf8.decode(r.bodyBytes));
    return (body as Map?)?.cast<String, Object?>() ?? const {};
  }

  Future<Map<String, Object?>> putJson(String path, Object body) async =>
      ((await _send(_req('PUT', path, body: body))) as Map?)?.cast<String, Object?>() ?? const {};

  Future<void> delete(String path) => _send(_req('DELETE', path));

  /// 配布物のバイト列。JSON ではないので `_send` は通さない。
  Future<Uint8List> getBytes(String path, [Map<String, String?> query = const {}]) async {
    final http.Response r;
    try {
      r = await _http.get(_url(path, query), headers: _headers()).timeout(_timeout);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    return r.bodyBytes;
  }

  void close() => _http.close();
}

/// RASQ Central への口 (D-138)。Central 専用の接続先が無い(= エッジと同じ)
/// ときは [orgateClientProvider] のインスタンスをそのまま使う — テストの
/// 差し替えも 1 箇所で効く。
final centralClientProvider = Provider<OrgateClient?>((ref) {
  final central = ref.watch(centralBaseUrlProvider);
  final edge = ref.watch(orgateBaseUrlProvider);
  // Central 専用の接続先が無い(未設定 or エッジと同じ)→ エッジの口を共有。
  if (central == null || central == edge) return ref.watch(orgateClientProvider);
  final holder = ref.read(orgateTokenHolderProvider);
  final client = OrgateClient(baseUrl: central, tokenProvider: () => holder.token);
  ref.onDispose(client.close);
  debugPrint('rasq-central: using $central');
  return client;
});

/// Overridable in tests. 接続先が未設定なら null。
final orgateClientProvider = Provider<OrgateClient?>((ref) {
  final base = ref.watch(orgateBaseUrlProvider);
  if (base == null) return null;
  // トークンは毎回読み直す(端末登録の完了で後から入る)。
  final holder = ref.read(orgateTokenHolderProvider);
  final client = OrgateClient(baseUrl: base, tokenProvider: () => holder.token);
  ref.onDispose(client.close);
  debugPrint('orgate: using $base');
  return client;
});
