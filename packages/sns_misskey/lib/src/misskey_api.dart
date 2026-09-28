import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// Thin Misskey HTTP client. Every endpoint is `POST /api/{path}` with a JSON
/// body; the token travels as the `i` field.
class MisskeyApi {
  MisskeyApi(this.host, {this.token, http.Client? client, this.timeout = const Duration(seconds: 20)}) : _client = client ?? http.Client();

  final String host;
  final String? token;
  final http.Client _client;
  final Duration timeout;

  // 開発 / デモ用の差し替え (D-359) があればそちらへ。
  Uri endpoint(String path) => snsUri(host, '/api/$path');

  Future<Object?> call(String path, [Map<String, Object?> body = const {}]) async {
    final payload = <String, Object?>{...body};
    if (token != null) payload['i'] = token;
    http.Response res;
    try {
      res = await _client
          .post(endpoint(path), headers: const {'content-type': 'application/json'}, body: jsonEncode(payload))
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw SnsApiException(ErrorCode.timeout.copyWith(message: '$host からの応答がありません(${timeout.inSeconds}秒)。インターネット接続を確認してください'), cause: e);
    } on http.ClientException catch (e) {
      // Web: CORS / fetch failures. VM: some connection errors.
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '03', title: 'HTTP Client Error', message: '$host: ${e.message}'), cause: e);
    } on Exception catch (e) {
      // SocketException (DNS / refused / sandbox "Operation not permitted"),
      // HandshakeException (TLS) … kept platform-agnostic (no dart:io import).
      final msg = e.toString().replaceFirst(RegExp(r'^\w+Exception: '), '');
      final hint = msg.contains('not permitted') ? ' (アプリのネットワーク権限/サンドボックス設定を確認してください)' : '';
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable', message: '$host に接続できません: $msg$hint'), cause: e);
    }
    if (res.statusCode == 204) return null;
    Object? decoded;
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
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
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(req).timeout(const Duration(minutes: 2));
    } on TimeoutException catch (e) {
      throw SnsApiException(ErrorCode.timeout.copyWith(message: 'アップロードがタイムアウトしました'), cause: e);
    } on Exception catch (e) {
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '01', title: 'Network Unreachable', message: '$host に接続できません: $e'), cause: e);
    }
    final res = await http.Response.fromStream(streamed);
    final decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
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
