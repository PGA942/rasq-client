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
  const SyncFetchRequest({required this.method, required this.url, this.headers = const {}, this.body, this.bodyBytes});
  final String method;
  final Uri url;
  final Map<String, String> headers;

  /// UTF-8 のボディ。バイナリを送るときは [bodyBytes] を使う。
  final String? body;

  /// バイナリのボディ(host-fn schema の `body: {b64}`)。multipart の
  /// メディアアップロードはプラグインが本体を組み立ててここへ載せる —
  /// ホストは中身を解釈しない。
  final Uint8List? bodyBytes;
}

@immutable
class SyncFetchResponse {
  const SyncFetchResponse({required this.status, this.headers = const {}, this.bodyText, this.bodyBytes});
  final int status;
  final Map<String, String> headers;

  /// UTF-8 として読めた応答。
  final String? bodyText;

  /// UTF-8 として読めなかった応答(画像など)。`bodyB64` として渡る。
  final Uint8List? bodyBytes;
}

typedef SyncFetch = SyncFetchResponse Function(SyncFetchRequest request);

/// `fow.open` / `fow.close` の中継先 (D-064)。検証済みの args を受け取り、
/// host-fn の value を返す(null = 既定値: open `{opened:true}` / close `{}`)。
typedef FowHostRelay = Object? Function(String fn, Map<String, Object?> args);

/// スロット契約のアプリ向けホスト関数(`toast` / `sound.play` / `clipboard.set` /
/// `url.open` / `mute.add` / `astell.share` / `composer.*.replace` /
/// `viewer.overlay.set`、D-167)の中継先。fire-and-forget で、戻りは受理 `{}`。
typedef AppFnRelay = void Function(String fn, Map<String, Object?> args);

/// Host-proxied `net.fetch` via a synchronous `curl` subprocess.
///
/// v1 stop-gap for desktop dev: it blocks the calling isolate for the whole
/// request (run plugin work off the UI isolate or accept the jank). Mobile
/// needs the async v2 boundary — this throws where `curl` is unavailable.
SyncFetchResponse curlSyncFetch(SyncFetchRequest request) {
  // バイナリはコマンドラインに載せられないので一時ファイル経由。応答も
  // バイト列で受けたいので、ステータスは -w で別ファイルへ書かせる。
  final tmp = Directory.systemTemp.createTempSync('rasq-fetch');
  try {
    final bodyFile = File('${tmp.path}/body');
    final outFile = File('${tmp.path}/out');
    if (request.bodyBytes != null) {
      bodyFile.writeAsBytesSync(request.bodyBytes!);
    } else if (request.body != null) {
      bodyFile.writeAsStringSync(request.body!);
    }
    final hasBody = request.bodyBytes != null || request.body != null;
    final args = <String>[
      '-sS',
      '--max-time', '15',
      '-X', request.method,
      for (final e in request.headers.entries) ...['-H', '${e.key}: ${e.value}'],
      if (hasBody) ...['--data-binary', '@${bodyFile.path}'],
      '-o', outFile.path,
      '-w', '%{http_code}',
      request.url.toString(),
    ];
    final result = Process.runSync('curl', args, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (result.exitCode != 0) {
      throw ProcessException('curl', args, result.stderr.toString(), result.exitCode);
    }
    final status = int.tryParse(result.stdout.toString().trim()) ?? 0;
    final bytes = outFile.existsSync() ? outFile.readAsBytesSync() : Uint8List(0);
    try {
      return SyncFetchResponse(status: status, bodyText: utf8.decode(bytes));
    } on FormatException {
      // UTF-8 で読めない = バイナリ応答。
      return SyncFetchResponse(status: status, bodyBytes: bytes);
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
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
    this.onAppFn,
    this.appFns = const {},
  }) : storage = storage ?? {};

  /// アプリ向けホスト関数の中継 (D-167)。null → E01。
  AppFnRelay? onAppFn;

  /// 許可されたアプリ向けホスト関数名(スロット登録時にマニフェストの
  /// permissions / slots から決める)。範囲外は E01。
  final Set<String> appFns;

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
          // ボディは UTF-8 文字列か、バイナリの base64 (`{b64}`)。
          final rawBody = args['body'];
          Uint8List? bodyBytes;
          if (rawBody is Map && rawBody['b64'] is String) {
            try {
              bodyBytes = base64Decode(rawBody['b64'] as String);
            } catch (e) {
              throw _HostFnError('D01', 'bad body base64: $e');
            }
          }
          res = fetcher(SyncFetchRequest(
            method: '${args['method'] ?? 'GET'}',
            url: url,
            headers: (args['headers'] as Map?)?.cast<String, String>() ?? const {},
            body: rawBody is String ? rawBody : null,
            bodyBytes: bodyBytes,
          ));
        } catch (e) {
          if (e is _HostFnError) rethrow;
          throw _HostFnError('B01', 'fetch failed: $e');
        }
        return {
          'status': res.status,
          'headers': res.headers,
          'bodyText': res.bodyText,
          if (res.bodyBytes != null) 'bodyB64': base64Encode(res.bodyBytes!),
        };
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
      case RasqHostFns.toast ||
            RasqHostFns.soundPlay ||
            RasqHostFns.clipboardSet ||
            RasqHostFns.urlOpen ||
            RasqHostFns.muteAdd ||
            RasqHostFns.astellShare ||
            RasqHostFns.composerMediaReplace ||
            RasqHostFns.composerMediaPreview ||
            RasqHostFns.composerTextReplace ||
            RasqHostFns.viewerOverlaySet ||
            RasqHostFns.composerOpen:
        // スロット契約 (D-167): 権限内ならアプリへ fire-and-forget で中継。
        final relay = onAppFn;
        if (relay == null) throw _HostFnError('E01', '$fn not wired');
        if (!appFns.contains(fn)) throw _HostFnError('E01', '$fn not permitted');
        if (fn == RasqHostFns.urlOpen) {
          final u = Uri.tryParse('${args['url']}');
          if (u == null || !(u.isScheme('https') || u.isScheme('http'))) throw _HostFnError('B03', 'url.open: http(s) only');
        }
        if ((fn == RasqHostFns.composerMediaReplace || fn == RasqHostFns.composerMediaPreview || fn == RasqHostFns.composerTextReplace || fn == RasqHostFns.viewerOverlaySet || fn == RasqHostFns.composerOpen) && args['token'] is! String) {
          throw _HostFnError('D01', '$fn: token required');
        }
        relay(fn, args);
        return const <String, Object?>{};
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
