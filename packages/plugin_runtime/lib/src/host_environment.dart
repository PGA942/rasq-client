import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// A synchronous HTTP request/response pair for `net.fetch`.
///
/// Synchronous because host-function v1 blocks the wasm call
/// (PROTOCOL §4.1); async host functions are the planned v2.
@immutable
class SyncFetchRequest {
  const SyncFetchRequest({required this.method, required this.url, this.headers = const {}, this.body});
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
}

@immutable
class SyncFetchResponse {
  const SyncFetchResponse({required this.status, this.headers = const {}, this.bodyText});
  final int status;
  final Map<String, String> headers;
  final String? bodyText;
}

typedef SyncFetch = SyncFetchResponse Function(SyncFetchRequest request);

/// `fow.open` / `fow.close` の中継先 (D-064)。検証済みの args を受け取り、
/// host-fn の value を返す(null = 既定値: open `{opened:true}` / close `{}`)。
typedef FowHostRelay = Object? Function(String fn, Map<String, Object?> args);

/// Host-proxied `net.fetch` via a synchronous `curl` subprocess.
///
/// v1 stop-gap for desktop dev: it blocks the calling isolate for the whole
/// request (run plugin work off the UI isolate or accept the jank). Mobile
/// needs the async v2 boundary — this throws where `curl` is unavailable.
SyncFetchResponse curlSyncFetch(SyncFetchRequest request) {
  final args = <String>[
    '-sS',
    '--max-time', '15',
    '-X', request.method,
    for (final e in request.headers.entries) ...['-H', '${e.key}: ${e.value}'],
    if (request.body != null) ...['--data', request.body!],
    '-w', r'\n%{http_code}',
    request.url.toString(),
  ];
  final result = Process.runSync('curl', args, stdoutEncoding: utf8, stderrEncoding: utf8);
  if (result.exitCode != 0) {
    throw ProcessException('curl', args, result.stderr.toString(), result.exitCode);
  }
  final out = result.stdout.toString();
  final cut = out.lastIndexOf('\n');
  final status = int.tryParse(out.substring(cut + 1).trim()) ?? 0;
  return SyncFetchResponse(status: status, bodyText: out.substring(0, cut < 0 ? 0 : cut));
}

/// Serves a plugin's host-function calls (`rasq.hostfn/1` request JSON →
/// response JSON) per `schema/host-fn.schema.json`.
///
/// Backends are injectable so tests run hermetically. Unknown fns answer
/// `C01`; wired-but-unavailable ones answer `B01`/`E01` — never an exception
/// across the wasm boundary.
class RasqHostEnvironment {
  RasqHostEnvironment({
    Map<String, Object?>? storage,
    this.fetch,
    this.nativeFetch = false,
    this.onAlert,
    this.onLog,
    this.onFow,
    this.fowPermissions = const {'widget'},
  }) : storage = storage ?? {};

  /// Serve `net.fetch` inside the wasm runtime (blocking rustls HTTP —
  /// mobile-capable, D-023). Takes precedence over [fetch]; the runtime
  /// short-circuits before the Dart dispatcher sees the call.
  final bool nativeFetch;

  /// `storage.*` backing map (the app injects secure-storage-backed maps
  /// per plugin namespace later; D-004 `storage.safe`).
  final Map<String, Object?> storage;

  /// `net.fetch` backend; null → B01 network unreachable.
  final SyncFetch? fetch;

  /// `alert` backend: returns confirmed?. Default: log + true.
  final bool Function(String title, String message)? onAlert;

  final void Function(String message)? onLog;

  /// `fow.open` / `fow.close` の中継先 (D-064)。null → E01(未配線)。
  /// コントローラが後から差すため mutable(同期コントローラは `load()` で
  /// 自分の写像を、ワーカーは isolate 間ポートへの送信を差す)。
  FowHostRelay? onFow;

  /// マニフェストで許可された FOW type(`widget` / `interstitial` /
  /// `system`)。範囲外の `spec.type` は E01(D-004 の権限モデル)。
  final Set<String> fowPermissions;

  /// Entry point handed to `RasqWasmPlugin.fromBytes(hostFn: …)`.
  String dispatch(String requestJson) {
    Map<String, dynamic> req;
    try {
      req = jsonDecode(requestJson) as Map<String, dynamic>;
    } catch (e) {
      return jsonEncode({'ok': false, 'error': {'code': 'D01', 'message': 'bad hostfn request: $e'}});
    }
    final callId = req['callId'];
    final fn = req['fn'] as String? ?? '';
    final args = (req['args'] as Map?)?.cast<String, Object?>() ?? const {};
    onLog?.call('hostFn: $fn');
    try {
      final value = _invoke(fn, args);
      return jsonEncode({'callId': callId, 'ok': true, 'value': value});
    } on _HostFnError catch (e) {
      return jsonEncode({'callId': callId, 'ok': false, 'error': {'code': e.code, 'message': e.message}});
    } catch (e) {
      return jsonEncode({'callId': callId, 'ok': false, 'error': {'code': 'F00', 'message': '$e'}});
    }
  }

  Object? _invoke(String fn, Map<String, Object?> args) {
    switch (fn) {
      case RasqHostFns.storageGet:
        return {'value': storage[_storageKey(args)]};
      case RasqHostFns.storageSet:
        storage[_storageKey(args)] = args['value'];
        return const <String, Object?>{};
      case RasqHostFns.storageDelete:
        storage.remove(_storageKey(args));
        return const <String, Object?>{};
      case RasqHostFns.netFetch:
        final fetcher = fetch;
        if (fetcher == null) throw _HostFnError('B01', 'network backend not available');
        final url = Uri.tryParse('${args['url']}');
        if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
          throw _HostFnError('B03', 'bad url: ${args['url']}');
        }
        final SyncFetchResponse res;
        try {
          res = fetcher(SyncFetchRequest(
            method: '${args['method'] ?? 'GET'}',
            url: url,
            headers: (args['headers'] as Map?)?.cast<String, String>() ?? const {},
            body: args['body'] as String?,
          ));
        } catch (e) {
          throw _HostFnError('B01', 'fetch failed: $e');
        }
        return {'status': res.status, 'headers': res.headers, 'bodyText': res.bodyText};
      case RasqHostFns.alert:
        final confirmed = onAlert?.call('${args['title'] ?? ''}', '${args['message'] ?? ''}') ?? true;
        return {'confirmed': confirmed};
      case RasqHostFns.mlInfer:
        // Placement resolution (device onnx/llama vs server Triton/vLLM) is
        // M4+ work — the interface is fixed (model-manifest.schema.json).
        throw _HostFnError('E01', 'ml.infer backend not wired yet (model: ${args['model']})');
      case RasqHostFns.fowOpen:
        final relay = onFow;
        if (relay == null) throw _HostFnError('E01', 'fow backend not wired');
        final id = args['id'];
        if (id is! String || id.isEmpty) throw _HostFnError('D01', 'fow.open: id required');
        if (args['root'] is! Map) throw _HostFnError('D01', 'fow.open: root required');
        final type = '${((args['spec'] as Map?) ?? const {})['type'] ?? ''}';
        if (!const {'widget', 'interstitial', 'system'}.contains(type)) {
          throw _HostFnError('D01', 'fow.open: bad spec.type "$type"');
        }
        if (!fowPermissions.contains(type)) throw _HostFnError('E01', 'fow.$type not permitted');
        return relay(fn, args) ?? const {'opened': true};
      case RasqHostFns.fowClose:
        final relay = onFow;
        if (relay == null) throw _HostFnError('E01', 'fow backend not wired');
        final id = args['id'];
        if (id is! String || id.isEmpty) throw _HostFnError('D01', 'fow.close: id required');
        return relay(fn, args) ?? const <String, Object?>{};
      case RasqHostFns.gpuCompute:
        // gpu.compute (D-081) はランタイム内(wgpu)で短絡処理される —
        // ここへ来るのは旧ランタイムのみ。プラグインはクラウド
        // カルクレーター(ml.infer)へフォールバックする規約。
        throw _HostFnError('E01', 'gpu.compute requires the native runtime (fall back to ml.infer)');
      case RasqHostFns.wasmCall || RasqHostFns.storeRead || RasqHostFns.geometryLookup:
        throw _HostFnError('E01', '$fn not wired yet');
      default:
        throw _HostFnError('C01', 'unknown host fn: $fn');
    }
  }

  static String _storageKey(Map<String, Object?> args) => '${args['ns'] ?? 'safe'}:${args['key']}';
}

class _HostFnError implements Exception {
  _HostFnError(this.code, this.message);
  final String code;
  final String message;
}
