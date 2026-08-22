import 'dart:convert';

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

  Uri endpoint(String path) => Uri.https(host, '/api/$path');

  Future<Object?> call(String path, [Map<String, Object?> body = const {}]) async {
    final payload = <String, Object?>{...body};
    if (token != null) payload['i'] = token;
    http.Response res;
    try {
      res = await _client
          .post(endpoint(path), headers: const {'content-type': 'application/json'}, body: jsonEncode(payload))
          .timeout(timeout);
    } on Exception catch (e) {
      throw SnsApiException(ErrorCode.timeout, cause: e);
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
