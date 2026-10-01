import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';

import '../features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'rasq_account.dart' show OrgateTokenHolder, orgateTokenHolderProvider;

/// ORGATE-Server(`orgate-server`)への接続 — **本人だけが見る情報**の置き場 (D-398)。
///
/// 受け持つのは、ログイン(端末の発行 / パスワード / メールのコード)・セッションとトークンの取り直し・
/// メールアドレス・操作の確認コード・アカウント削除の入口と、Mastodon などアクセストークン発行に `client_secret` が
/// 要る SNS の OAuth ブローカー (CONTRACT §3)(第 1 段階、D-398)。第 2 段階 (D-399) で、SNS のトークンの預け入れ
/// (`/me/sns-accounts/{key}/token*`。トークンは ORGATE から出ず、読んだ公開の投稿だけが Central に来る)・Web 版の保管庫
/// (`/me/vault`)・データ同期 (`/me/data`)・端末間の SNS トークン共有 (`/me/sns-share`) も。公開・共有のもの(ストア / AsTell / 投稿 / リスト…)は RASQ Central。
/// ORGATE が出すアクセストークン(JWT)を、Central にもそのまま Bearer で渡す。
///
/// 接続先は `--dart-define=ORGATE_BASE_URL=...` を既定にし、KV
/// `backend.v1` の `baseUrl` で上書きできる(開発中に手元のサーバーへ
/// 向けるため)。**未設定なら null** — 呼び出し側はモックへ縮退する。

/// ビルド時に焼き込む既定の接続先(**ORGATE-Server**: ログイン / 本人だけの情報 / OAuth ブローカー、D-398)。
const _defaultBaseUrl = String.fromEnvironment('ORGATE_BASE_URL');

/// **RASQ Central** (`rasq-central`, D-138) — RASQ アカウント / ストア /
/// プラグイン管理 / ユーザーデータ。未設定なら [_defaultBaseUrl](ORGATE)へ
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
  return normalizeServerUrl(raw);
});

/// サーバーに繋がる構成かどうか。false ならストアはモック、RASQ アカウントは
/// 最初のログインアカウントからの流用に縮退する。
final orgateConfiguredProvider = Provider<bool>((ref) => ref.watch(orgateBaseUrlProvider) != null);

Uri? _parseBase(String raw) => normalizeServerUrl(raw);

/// 接続先の入力を正す (D-239): 前後の空白 / 全角の「:/.」/ 末尾の `/` を直し、スキームが無ければ
/// IP アドレス・localhost・ポート付きは `http://`、それ以外は `https://` を補う。解釈できなければ null。
Uri? normalizeServerUrl(String raw) {
  var t = raw.trim().replaceAll('\uFF1A', ':').replaceAll('\uFF0F', '/').replaceAll('\uFF0E', '.').replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(t)) {
    final hostPart = t.split('/').first;
    final local = RegExp(r'^(\d{1,3}(\.\d{1,3}){3}|localhost|\[[0-9a-fA-F:]+\]|[^.]+)(:\d+)?$').hasMatch(hostPart) || RegExp(r':\d+$').hasMatch(hostPart);
    t = '${local ? 'http' : 'https'}://$t';
  }
  while (t.endsWith('/')) {
    t = t.substring(0, t.length - 1);
  }
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  return uri;
}

/// RASQ Central の接続先 (D-138)。KV `backend.v1` の `centralUrl` →
/// `--dart-define=RASQ_CENTRAL_URL` → 無ければ**ORGATE の接続先を流用**(1 つの URL で両方を兼ねるテスト / 開発の構成)。
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

  /// 同じ接続先 / HTTP クライアントで、別のトークンを使う口 (D-239: 通知専用のアクセストークンで受信箱を読む)。
  OrgateClient withToken(String? Function() tokenProvider) => OrgateClient(baseUrl: baseUrl, httpClient: _http, tokenProvider: tokenProvider);

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

  /// 生バイト列の PUT(プロフィールの画像など)。応答は JSON。
  Future<Map<String, Object?>> putBytes(String path, List<int> bytes, {required String contentType}) async {
    final http.Response r;
    try {
      r = await _http.put(_url(path), headers: {..._headers(), 'content-type': contentType}, body: bytes).timeout(_timeout * 6);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    final body = r.bodyBytes.isEmpty ? const {} : jsonDecode(utf8.decode(r.bodyBytes));
    return (body as Map?)?.cast<String, Object?>() ?? const {};
  }

  /// JSON を送ってバイト列(音声など)を受ける。
  Future<Uint8List> postForBytes(String path, Object body) async {
    final http.Response r;
    try {
      r = await _http.post(_url(path), headers: _headers(json: true), body: jsonEncode(body)).timeout(_timeout * 3);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    return r.bodyBytes;
  }

  Future<Map<String, Object?>> putJson(String path, Object body) async =>
      ((await _send(_req('PUT', path, body: body))) as Map?)?.cast<String, Object?>() ?? const {};

  /// POST で配列を受ける(AsTell の招待の結果など)。
  Future<List<Object?>> postList(String path, Object body) async => (await _send(_req('POST', path, body: body))) as List? ?? const [];

  /// PUT で配列を受ける(AsTell の BAN 一覧など)。
  Future<List<Object?>> putList(String path, Object body) async => (await _send(_req('PUT', path, body: body))) as List? ?? const [];

  Future<void> delete(String path, [Map<String, String?> query = const {}]) => _send(_req('DELETE', path, query: query));

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

  /// ユーザーデータ同期 (`GET /me/data/{area}`) の中身と版(`ETag`)。無ければ null。
  Future<({Uint8List bytes, int version})?> getData(String area) async {
    final http.Response r;
    try {
      r = await _http.get(_url('/me/data/$area'), headers: _headers()).timeout(_timeout);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) _fail(r);
    return (bytes: r.bodyBytes, version: _etagVersion(r.headers['etag']) ?? 0);
  }

  /// ユーザーデータ同期 (`PUT /me/data/{area}`) で置き換える。[ifMatch] = 読んだときの版(ほかの端末が先に書いていれば
  /// `409` の [OrgateException])。[encrypted] = 端末で暗号化済み(`X-Rasq-Encrypted`)。戻り = 新しい版。
  Future<int?> putData(String area, List<int> bytes, {String contentType = 'application/json', bool encrypted = false, int? ifMatch}) async {
    final http.Response r;
    try {
      r = await _http
          .put(_url('/me/data/$area'), headers: {..._headers(), 'content-type': contentType, if (encrypted) 'x-rasq-encrypted': 'true', if (ifMatch != null) 'if-match': '"$ifMatch"'}, body: bytes)
          .timeout(_timeout);
    } on Exception catch (e) {
      throw OrgateException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable'), '$e');
    }
    if (r.statusCode >= 400) _fail(r);
    return _etagVersion(r.headers['etag']);
  }

  static int? _etagVersion(String? etag) => etag == null ? null : int.tryParse(etag.replaceAll('"', '').trim());

  void close() => _http.close();
}

/// アクセストークンの取り直し (D-398): 応答が 401 で、送ったトークンが**いまのアクセストークン**なら、1 回だけ
/// [OrgateTokenHolder.refresh](ORGATE の `POST /auth/refresh`)で取り直して、同じ要求を新しいトークンで送り直す。
/// 通知専用のトークンなど、ほかのトークンで送った要求には何もしない。
class TokenRefreshingClient extends http.BaseClient {
  TokenRefreshingClient(this._inner, this._holder);
  final http.Client _inner;
  final OrgateTokenHolder _holder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _inner.send(request);
    if (res.statusCode != 401 || request is! http.Request) return res;
    final current = _holder.token;
    if (current == null || current.isEmpty || request.headers['authorization'] != 'Bearer $current') return res;
    final fresh = await _holder.refresh();
    if (fresh == null || fresh == current) return res;
    await res.stream.drain<void>();
    final retry = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..bodyBytes = request.bodyBytes;
    retry.headers['authorization'] = 'Bearer $fresh';
    return _inner.send(retry);
  }

  @override
  void close() => _inner.close();
}

/// RASQ Central への口 (D-138)。Central 専用の接続先が無い(= ORGATE と同じ)
/// ときは [orgateClientProvider] のインスタンスをそのまま使う — テストの
/// 差し替えも 1 箇所で効く。
final centralClientProvider = Provider<OrgateClient?>((ref) {
  final central = ref.watch(centralBaseUrlProvider);
  final edge = ref.watch(orgateBaseUrlProvider);
  // Central 専用の接続先が無い(未設定 or ORGATE と同じ)→ ORGATE の口を共有(1 つの URL で兼ねるテスト / 開発)。
  if (central == null || central == edge) return ref.watch(orgateClientProvider);
  final holder = ref.read(orgateTokenHolderProvider);
  final client = OrgateClient(baseUrl: central, httpClient: TokenRefreshingClient(http.Client(), holder), tokenProvider: () => holder.token);
  ref.onDispose(client.close);
  debugPrint('rasq-central: using $central');
  return client;
});

/// ORGATE-Server への口 (D-398: ログイン / トークンの取り直し / パスワード / メール / 削除 / OAuth ブローカー)。
/// Overridable in tests. 接続先が未設定なら null。
final orgateClientProvider = Provider<OrgateClient?>((ref) {
  final base = ref.watch(orgateBaseUrlProvider);
  if (base == null) return null;
  // トークンは毎回読み直す(端末登録の完了で後から入る)。
  final holder = ref.read(orgateTokenHolderProvider);
  final client = OrgateClient(baseUrl: base, httpClient: TokenRefreshingClient(http.Client(), holder), tokenProvider: () => holder.token);
  ref.onDispose(client.close);
  debugPrint('orgate: using $base');
  return client;
});
