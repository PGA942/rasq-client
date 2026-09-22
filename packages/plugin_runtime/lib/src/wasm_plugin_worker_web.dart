import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:web/web.dart' as web;

import 'wasm_worker_config.dart';

export 'wasm_worker_config.dart';

/// WASM プラグインのワーカーの **Web 版** (D-297): 端末の isolate + wasmi (FFI) の代わりに、
/// **Web Worker + ブラウザ自身の WebAssembly** で同じ ABI(PROTOCOL §4.1: `alloc` / `dealloc` / `snapshot` / `patch` / `call`、
/// import `rasq.host_fn`)を動かす。公開している形は端末版 ([WasmPluginWorker]) と同じ。
///
/// v1 の host_fn は同期なので、`net.fetch` は Worker の中の**同期 XHR**で出す(Worker の中なら UI は止まらない)。
/// ブラウザの通信なので、相手のサーバーが CORS を許していること(Mastodon / Bluesky の API は許している)。
/// `storage.*` / `fow.*` / アプリ向けホスト関数は、端末版のワーカーと同じ振る舞い(storage はワーカーの中、fow / アプリ向けはメインへ中継)。
class WasmPluginWorker {
  WasmPluginWorker._(this._worker, this._url);

  final web.Worker _worker;
  final String _url;

  final Map<int, Completer<String>> _pending = {};
  int _seq = 0;
  final _logs = StreamController<String>.broadcast();
  final _fows = StreamController<Map<String, Object?>>.broadcast();
  final _apps = StreamController<Map<String, Object?>>.broadcast();

  Stream<String> get logs => _logs.stream;
  Stream<Map<String, Object?>> get appRequests => _apps.stream;
  Stream<Map<String, Object?>> get fowRequests => _fows.stream;

  static Future<WasmPluginWorker> spawn(WasmWorkerConfig config) async {
    final blob = web.Blob([_workerSource.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript'));
    final url = web.URL.createObjectURL(blob);
    final worker = WasmPluginWorker._(web.Worker(url.toJS), url);
    worker._worker.onmessage = ((web.MessageEvent e) => worker._onMessage((e.data as JSString).toDart)).toJS;
    worker._worker.onerror = ((web.Event e) {
      final err = StateError('wasm worker failed: ${e.isA<web.ErrorEvent>() ? (e as web.ErrorEvent).message : e.type}');
      for (final c in worker._pending.values) {
        if (!c.isCompleted) c.completeError(err);
      }
      worker._pending.clear();
    }).toJS;
    try {
      // 起動確認(instantiate の失敗は、ここで例外になる)。メッセージは JSON の文字列でやり取りする。
      await worker._request('init', {
        'wasm': base64Encode(config.wasmBytes),
        'storage': config.seedStorage,
        'fowPermissions': config.fowPermissions.toList(),
        'appFns': config.appFns.toList(),
        'knownAppFns': RasqHostFns.appFns.toList(),
        // 権限のゲート (D-004) と接続先の宣言 (schema v0.12) は端末版と同じ規則で Worker の中で効かせる。
        'permissions': config.permissions.toList(),
        'fetchHosts': config.fetchHosts.toList(),
        'instanceAllowed': config.instanceAllowed,
      });
    } catch (_) {
      worker._close();
      rethrow;
    }
    return worker;
  }

  void _onMessage(String data) {
    final map = (jsonDecode(data) as Map).cast<String, Object?>();
    if (map['log'] != null) return _logs.add('${map['log']}');
    if (map['fow'] != null) return _fows.add((map['fow'] as Map).cast<String, Object?>());
    if (map['app'] != null) return _apps.add((map['app'] as Map).cast<String, Object?>());
    final completer = _pending.remove(map['id']);
    if (completer == null) return;
    if (map['ok'] == true) {
      completer.complete('${map['result']}');
    } else {
      completer.completeError(StateError('${map['error']}'));
    }
  }

  Future<String> _request(String op, [Map<String, Object?> args = const {}]) {
    final id = _seq++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _worker.postMessage(jsonEncode({'id': id, 'op': op, ...args}).toJS);
    return completer.future;
  }

  Future<String> snapshot() => _request('snapshot');
  Future<String> patch() => _request('patch');
  Future<String> call({required String fn, required String argsJson, required String callId}) => _request('call', {'fn': fn, 'args': argsJson, 'callId': callId});

  /// セッションのインスタンスのホストを `net.fetch` に許可する(マニフェストが `network.instance` を宣言している場合だけ効く)。
  Future<String> grantHost(String? host) => _request('grantHost', {'host': host});

  void _close() {
    _worker.terminate();
    web.URL.revokeObjectURL(_url);
    _logs.close();
    _fows.close();
    _apps.close();
  }

  Future<void> dispose() async => _close();
}

/// Worker の中身(JS)。Blob から起こすので、配るファイルは増えない。
const _workerSource = r'''
"use strict";
let inst = null, storage = {}, cfg = {fowPermissions: [], appFns: [], knownAppFns: [], permissions: [], fetchHosts: [], instanceAllowed: false, instanceHost: null};
const enc = new TextEncoder(), dec = new TextDecoder();
const TOKEN_FNS = ["composer.media.replace","composer.media.preview","composer.text.replace","viewer.overlay.set","composer.open","composer.media.overlay"];
const send = (m) => self.postMessage(JSON.stringify(m));

function bytesAt(ptr, len) { return new Uint8Array(inst.exports.memory.buffer, ptr >>> 0, len >>> 0); }
function readStr(ptr, len) { return dec.decode(bytesAt(ptr, len).slice()); }
function writeBytes(bytes) {
  const ptr = inst.exports.alloc(bytes.length) >>> 0;
  bytesAt(ptr, bytes.length).set(bytes);
  return ptr;
}
function readPacked(packed) {
  const v = BigInt.asUintN(64, packed);
  const ptr = Number(v >> 32n), len = Number(v & 0xffffffffn);
  const s = readStr(ptr, len);
  inst.exports.dealloc(ptr, len);
  return s;
}
function b64ToBytes(b64) { const bin = atob(b64); const out = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i); return out; }
function bytesToB64(bytes) { let bin = ""; for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000)); return btoa(bin); }

class HostFnError extends Error { constructor(code, message) { super(message); this.code = code; } }

// 端末版 (host_environment.dart の fetchHostPermitted / Rust の host_permitted) と同じ規則:
// 完全一致 / "*.example.com" はサブドメインだけ / "*" はどこでも。空のホストは常に不許可。
function hostPermitted(host) {
  const h = String(host || "").trim().toLowerCase();
  if (!h) return false;
  const pats = cfg.fetchHosts.concat(cfg.instanceHost ? [cfg.instanceHost] : []);
  return pats.some((raw) => {
    const p = String(raw).trim().toLowerCase();
    if (p === "*") return true;
    if (p.startsWith("*.")) { const suf = p.slice(2); return h.length > suf.length + 1 && h.endsWith("." + suf); }
    return h === p;
  });
}
function hostOf(url) { try { return new URL(url).hostname.toLowerCase(); } catch (_) { return ""; } }

function netFetch(args) {
  if (!cfg.permissions.includes("network")) throw new HostFnError("E01", "network not permitted");
  const url = String(args.url || "");
  if (!(url.startsWith("https://") || url.startsWith("http://"))) throw new HostFnError("B03", "bad url: " + url);
  // 宣言した先だけ (schema v0.12)。
  if (!hostPermitted(hostOf(url))) throw new HostFnError("E01", "host not permitted: " + hostOf(url));
  const xhr = new XMLHttpRequest();
  xhr.open(String(args.method || "GET").toUpperCase(), url, false);
  xhr.responseType = "arraybuffer";
  for (const [k, v] of Object.entries(args.headers || {})) {
    // ブラウザが触らせないヘッダ(User-Agent など)は、付けられないだけで通信は続ける。
    try { if (typeof v === "string") xhr.setRequestHeader(k, v); } catch (_) {}
  }
  let body = null;
  if (args.body && typeof args.body === "object" && typeof args.body.b64 === "string") {
    try { body = b64ToBytes(args.body.b64); } catch (e) { throw new HostFnError("D01", "bad body base64: " + e); }
  } else if (typeof args.body === "string") {
    body = args.body;
  }
  try { xhr.send(body); } catch (e) { throw new HostFnError("B01", "fetch failed (network / CORS): " + e); }
  // 同期 XHR はリダイレクトを勝手に追う(端末版は追わない)。飛んだ先が宣言外なら、応答をプラグインに渡さない。
  if (xhr.responseURL && !hostPermitted(hostOf(xhr.responseURL))) throw new HostFnError("E01", "redirected to a host that is not permitted: " + hostOf(xhr.responseURL));
  const headers = {};
  for (const line of (xhr.getAllResponseHeaders() || "").trim().split(/[\r\n]+/)) {
    const i = line.indexOf(":");
    if (i > 0) headers[line.slice(0, i).trim().toLowerCase()] = line.slice(i + 1).trim();
  }
  const bytes = new Uint8Array(xhr.response || new ArrayBuffer(0));
  // 応答は UTF-8 なら bodyText、そうでなければ bodyB64(端末のランタイムと同じ)。
  try { return {status: xhr.status, headers, bodyText: new TextDecoder("utf-8", {fatal: true}).decode(bytes)}; }
  catch (_) { return {status: xhr.status, headers, bodyB64: bytesToB64(bytes)}; }
}

function invoke(fn, args) {
  const ns = () => String(args.ns == null ? "safe" : args.ns);
  const key = () => ns() + ":" + String(args.key);
  // storage.* は ns ごとに別権限 (D-004)。端末版の _requireStorage と同じ。
  const requireStorage = () => { if (!cfg.permissions.includes("storage." + ns())) throw new HostFnError("E01", "storage." + ns() + " not permitted"); };
  switch (fn) {
    case "storage.get": { requireStorage(); const v = storage[key()]; return {value: v === undefined ? null : v}; }
    case "storage.set": requireStorage(); storage[key()] = args.value === undefined ? null : args.value; return {};
    case "storage.delete": requireStorage(); delete storage[key()]; return {};
    case "net.fetch": return netFetch(args);
    case "alert": return {confirmed: true};
    case "ml.infer": throw new HostFnError("E01", "ml.infer backend not wired yet (model: " + args.model + ")");
    case "fow.open": {
      if (typeof args.id !== "string" || !args.id) throw new HostFnError("D01", "fow.open: id required");
      if (!args.root || typeof args.root !== "object") throw new HostFnError("D01", "fow.open: root required");
      const type = String((args.spec || {}).type || "");
      if (!["widget", "interstitial", "system"].includes(type)) throw new HostFnError("D01", 'fow.open: bad spec.type "' + type + '"');
      if (!cfg.fowPermissions.includes(type)) throw new HostFnError("E01", "fow." + type + " not permitted");
      send({fow: {fn, args}});
      return {opened: true};
    }
    case "fow.close":
      if (typeof args.id !== "string" || !args.id) throw new HostFnError("D01", "fow.close: id required");
      send({fow: {fn, args}});
      return {};
    case "gpu.compute": throw new HostFnError("E01", "gpu.compute requires the native runtime (fall back to ml.infer)");
    case "wasm.call": case "store.read": case "geometry.lookup": throw new HostFnError("E01", fn + " not wired yet");
    default:
      if (cfg.knownAppFns.includes(fn)) {
        if (!cfg.appFns.includes(fn)) throw new HostFnError("E01", fn + " not permitted");
        if (fn === "url.open" && !/^https?:\/\//.test(String(args.url || ""))) throw new HostFnError("B03", "url.open: http(s) only");
        if (TOKEN_FNS.includes(fn) && typeof args.token !== "string") throw new HostFnError("D01", fn + ": token required");
        send({app: {fn, args}});
        return {};
      }
      throw new HostFnError("C01", "unknown host fn: " + fn);
  }
}

function dispatch(requestJson) {
  let req;
  try { req = JSON.parse(requestJson); } catch (e) { return JSON.stringify({ok: false, error: {code: "D01", message: "bad hostfn request: " + e}}); }
  const callId = req.callId === undefined ? null : req.callId;
  send({log: "hostFn: " + req.fn});
  try { return JSON.stringify({callId, ok: true, value: invoke(String(req.fn || ""), req.args || {})}); }
  catch (e) { return JSON.stringify({callId, ok: false, error: {code: e instanceof HostFnError ? e.code : "F00", message: String(e.message || e)}}); }
}

function hostFn(ptr, len) {
  const res = enc.encode(dispatch(readStr(ptr, len)));
  const out = writeBytes(res);
  return (BigInt(out) << 32n) | BigInt(res.length);
}

self.onmessage = async (ev) => {
  const m = JSON.parse(ev.data);
  try {
    switch (m.op) {
      case "init": {
        storage = Object.assign({}, m.storage || {});
        cfg = {fowPermissions: m.fowPermissions || [], appFns: m.appFns || [], knownAppFns: m.knownAppFns || [],
               permissions: m.permissions || [], fetchHosts: m.fetchHosts || [], instanceAllowed: !!m.instanceAllowed, instanceHost: null};
        const {instance} = await WebAssembly.instantiate(b64ToBytes(m.wasm), {rasq: {host_fn: hostFn}});
        for (const name of ["memory", "alloc", "dealloc", "snapshot", "patch", "call"]) {
          if (!instance.exports[name]) throw new Error("missing export: " + name);
        }
        inst = instance;
        return send({id: m.id, ok: true, result: "pong"});
      }
      case "grantHost": {
        // 宣言 (network.instance) が無ければ無視する: 呼び出し側の都合で権限を後から足せない。
        if (cfg.instanceAllowed) { const h = String(m.host || "").trim().toLowerCase(); cfg.instanceHost = h || null; }
        return send({id: m.id, ok: true, result: cfg.instanceHost || ""});
      }
      case "snapshot": return send({id: m.id, ok: true, result: readPacked(inst.exports.snapshot())});
      case "patch": return send({id: m.id, ok: true, result: readPacked(inst.exports.patch())});
      case "call": {
        const parts = [m.fn, m.args, m.callId].map((s) => enc.encode(String(s)));
        const ptrs = parts.map(writeBytes);
        const packed = inst.exports.call(ptrs[0], parts[0].length, ptrs[1], parts[1].length, ptrs[2], parts[2].length);
        ptrs.forEach((p, i) => inst.exports.dealloc(p, parts[i].length));
        return send({id: m.id, ok: true, result: readPacked(packed)});
      }
      default: return send({id: m.id, ok: false, error: "unknown op: " + m.op});
    }
  } catch (e) {
    send({id: m.id, ok: false, error: String(e && e.message || e)});
  }
};
''';
