import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'bounded_body.dart';
import 'json_bytes.dart';
import 'l10n.dart';

/// Thin Misskey HTTP client. Every endpoint is `POST /api/{path}` with a JSON
/// body; the token travels as the `i` field.
class MisskeyApi {
  MisskeyApi(this.host, {this.token, http.Client? client, this.timeout = const Duration(seconds: 20), this.bodyTimeout = const Duration(seconds: 90), this.maxResponseBytes = defaultMaxResponseBytes})
      : _client = client ?? http.Client();

  final String host;
  final String? token;
  final http.Client _client;

  /// 応答の頭までの期限。
  final Duration timeout;

  /// 本文を読み終えるまでの全体の期限 (セキュリティ確認 2026-11-11 の #13)。
  final Duration bodyTimeout;

  /// 応答の本文の上限(展開後のバイト数、#13)。超えたら読むのをやめて通信を切る。
  final int maxResponseBytes;

  /// [maxResponseBytes] の既定(大きなサーバーの絵文字の一覧も入る大きさ)。
  static const defaultMaxResponseBytes = 64 * 1024 * 1024;

  /// アップロードの応答(ファイルの情報 1 つ)の上限。
  static const maxUploadResponseBytes = 4 * 1024 * 1024;

  // 開発 / デモ用の差し替え (D-359) があればそちらへ。
  Uri endpoint(String path) => snsUri(host, '/api/$path');

  Future<Object?> call(String path, [Map<String, Object?> body = const {}]) async {
    final payload = <String, Object?>{...body};
    if (token != null) payload['i'] = token;
    ({int statusCode, Uint8List body}) res;
    try {
      // 上限 / 期限つきで読む (#13): 頭までは [timeout]、本文の最後までは [bodyTimeout]。超えたら要求を取り消す。
      res = await sendBounded(
        _client,
        (abort) => http.AbortableRequest('POST', endpoint(path), abortTrigger: abort)
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(payload),
        maxBytes: maxResponseBytes,
        headerTimeout: timeout,
        totalTimeout: bodyTimeout,
      );
    } on MisskeyResponseTooLarge catch (e) {
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '04', title: 'Response Too Large', message: snsMisskeyL10n.misskeyApiResponseTooLarge(host, e.maxBytes)), cause: e);
    } on TimeoutException catch (e) {
      throw SnsApiException(ErrorCode.timeout.copyWith(message: snsMisskeyL10n.misskeyApiTimeout(host, timeout.inSeconds)), cause: e);
    } on http.ClientException catch (e) {
      // Web: CORS / fetch failures. VM: some connection errors.
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '03', title: 'HTTP Client Error', message: '$host: ${e.message}'), cause: e);
    } on Exception catch (e) {
      // SocketException (DNS / refused / sandbox "Operation not permitted"),
      // HandshakeException (TLS) … kept platform-agnostic (no dart:io import).
      final msg = e.toString().replaceFirst(RegExp(r'^\w+Exception: '), '');
      final hint = msg.contains('not permitted') ? snsMisskeyL10n.misskeyApiSandboxHint : '';
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable', message: snsMisskeyL10n.misskeyApiUnreachable(host, msg, hint)), cause: e);
    }
    if (res.statusCode == 204) return null;
    Object? decoded;
    // 本文はバイトのまま解く(文字列にすると大きい応答で 2 回デコードになる)。大きいものは別の isolate で。
    if (res.body.isNotEmpty) {
      try {
        decoded = await decodeJsonBytes(res.body);
      } catch (_) {
        decoded = null;
      }
    }
    if (res.statusCode >= 400) {
      final err = decoded is Map ? decoded['error'] : null;
      final msg = err is Map ? (err['message'] ?? err['code'])?.toString() : null;
      throw SnsApiException(ErrorCode.http(res.statusCode, title: _title(res.statusCode), message: msg), cause: decoded);
    }
    return decoded;
  }

  /// Multipart upload (`drive/files/create`). Token goes in the `i` field.
  Future<Map<String, Object?>> upload(String path, {required Uint8List bytes, required String filename, String? mimeType, Map<String, String> fields = const {}}) async {
    final req = http.MultipartRequest('POST', endpoint(path))
      ..fields.addAll({...fields, 'i': ?token})
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: mimeType == null ? null : _mediaType(mimeType)));
    ({int statusCode, Uint8List body}) res;
    try {
      // 応答も上限 / 期限つきで読む (#13): 本文が続いても、期限と大きさで通信を切る。
      res = await sendBounded(
        _client,
        (abort) => http.AbortableMultipartRequest('POST', req.url, abortTrigger: abort)
          ..fields.addAll(req.fields)
          ..files.addAll(req.files),
        maxBytes: maxUploadResponseBytes,
        headerTimeout: const Duration(minutes: 2),
        totalTimeout: const Duration(minutes: 3),
      );
    } on MisskeyResponseTooLarge catch (e) {
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '04', title: 'Response Too Large', message: snsMisskeyL10n.misskeyApiResponseTooLarge(host, e.maxBytes)), cause: e);
    } on TimeoutException catch (e) {
      throw SnsApiException(ErrorCode.timeout.copyWith(message: snsMisskeyL10n.misskeyUploadTimeout), cause: e);
    } on Exception catch (e) {
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable', message: snsMisskeyL10n.misskeyApiUnreachablePlain(host, '$e')), cause: e);
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.body));
    if (res.statusCode >= 400) {
      final err = decoded is Map ? decoded['error'] : null;
      final msg = err is Map ? (err['message'] ?? err['code'])?.toString() : null;
      throw SnsApiException(ErrorCode.http(res.statusCode, title: _title(res.statusCode), message: msg), cause: decoded);
    }
    return (decoded as Map).cast<String, Object?>();
  }

  static http.MediaType? _mediaType(String mime) {
    final parts = mime.split('/');
    return parts.length == 2 ? http.MediaType(parts[0], parts[1]) : null;
  }

  Future<Map<String, Object?>> callMap(String path, [Map<String, Object?> body = const {}]) async =>
      (await call(path, body) as Map).cast<String, Object?>();

  Future<List<Map<String, Object?>>> callList(String path, [Map<String, Object?> body = const {}]) async =>
      [for (final e in (await call(path, body) as List)) (e as Map).cast<String, Object?>()];

  static String _title(int status) => switch (status) {
        400 => 'Bad Request',
        401 => 'Unauthorized',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method not Acceptable',
        408 => 'Request Timeout',
        429 => 'Too Many Requests',
        500 => 'Internal Server Error',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        _ => 'Error',
      };

  void close() => _client.close();
}
