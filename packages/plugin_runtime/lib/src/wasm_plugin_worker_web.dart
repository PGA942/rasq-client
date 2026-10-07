import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:web/web.dart' as web;

import 'wasm_web_guard.dart';
import 'wasm_worker_config.dart';

export 'wasm_worker_config.dart';

/// WASM プラグインのワーカーの **Web 版** (D-297): 端末の isolate + wasmi (FFI) の代わりに、
/// **Web Worker + ブラウザ自身の WebAssembly** で同じ ABI(PROTOCOL §4.1: `alloc` / `dealloc` / `snapshot` / `patch` / `call`、
/// import `rasq.host_fn`)を動かす。公開している形は端末版 ([WasmPluginWorker]) と同じ。
///
/// v1 の host_fn は同期なので、`net.fetch` は JSPI(下)で host_fn を非同期にして Worker の中の `fetch` で出す
/// (Worker の中なら UI は止まらない)。ブラウザの通信なので、相手のサーバーが CORS を許していること(Mastodon / Bluesky の API は許している)。
/// `storage.*` / `fow.*` / アプリ向けホスト関数は、端末版のワーカーと同じ振る舞い(storage はワーカーの中、fow / アプリ向けはメインへ中継)。
///
/// サイドロードの制限モード (D-308) は、埋込側が [WasmWorkerConfig] を絞って渡す(`permissions` から `network` /
/// `storage.unsafe` / `gpu_ml` / `fow.interstitial` / `fow.system` を外す、`fetchHosts` を空に、閉じる関数を `appFns` から外す)。
/// Worker の JS はその値で端末版と同じ門(`E01`)を掛ける: `net.fetch` = `permissions` の `network` と `hostPermitted`、
/// `storage.*` = `storage.<ns>`、`fow.open` = `fowPermissions`、アプリ向け = `appFns`。**fuel の予算は Web には無い**
/// (ブラウザの WebAssembly は fuel を数えない。`fuelPerCall` はここでは効かない)。代わりに要求ごとの期限
/// ([webWasmInitTimeout] / [webWasmCallTimeout]) を過ぎたらワーカーを止めて失敗にし、宣言したメモリと実行後のメモリを
/// 端末版と同じ上限 ([webWasmMaxMemoryBytes]) で見る (D-407、指摘 #10)。起動の前に、各メモリの最大をその上限内に
/// 書き込んでから instantiate する([capWasmMemory]、D-452)ので、実行中の `memory.grow` も上限で止まる。
///
/// `net.fetch` のリダイレクト (D-407 / D-408、指摘 #7): ブラウザが JSPI (`WebAssembly.Suspending` / `promising`) を持つなら、
/// `host_fn` を非同期にして `fetch(..., {redirect: "manual"})` で出し、リダイレクトは追わない(端末版と同じ)。
/// **JSPI の無いブラウザでは `net.fetch` を出さない**(`E01`「このブラウザでは通信できるプラグインを動かせません」)。
/// 前は同期 XHR に戻していたが、同期 XHR はリダイレクトを勝手に追い、宣言外のホストへ**送ってから**しか気づけない
/// (応答を渡さなくても、送った中身は届いてしまう)。同期のまま非同期の通信を待つ安全な口(メインスレッドへの中継など)は
/// Worker に無いので、断る方を選んだ(D-408)。通信しないプラグイン(storage / fow / アプリ向けだけ)はそのまま動く。
///
/// `net.fetch` の応答本文は端末版と同じ 32 MiB まで (D-453)。少しずつ読み、超えたら読むのをやめて通信を切り、端末版と同じ `B03` を返す。
class WasmPluginWorker {
  WasmPluginWorker._(this._worker, this._url) {
    _tracker = WasmRequestTracker(onFatal: (_) => _close());
  }

  final web.Worker _worker;
  final String _url;

  late final WasmRequestTracker _tracker;
  bool _closed = false;
  final _logs = StreamController<String>.broadcast();
  final _fows = StreamController<Map<String, Object?>>.broadcast();
  final _apps = StreamController<Map<String, Object?>>.broadcast();
  final _shapes = StreamController<Map<String, Object?>>.broadcast();
  final _storage = StreamController<Map<String, Object?>>.broadcast();

  /// Worker の中の `storage.set` / `storage.delete` の写し (D-422)。要素は `{ns, key, value}`。
  Stream<Map<String, Object?>> get storageWrites => _storage.stream;

  Stream<String> get logs => _logs.stream;

  /// 初めて見た `net.fetch` の形(端末版と同じ計算を Worker の JS でする)。
  Stream<Map<String, Object?>> get fetchShapes => _shapes.stream;
  Stream<Map<String, Object?>> get appRequests => _apps.stream;
  Stream<Map<String, Object?>> get fowRequests => _fows.stream;

  static Future<WasmPluginWorker> spawn(WasmWorkerConfig config) async {
    // 起動する前に、宣言したメモリの大きさを断り(指摘 #10)、最大を上限内に書き込む(D-452: 実行後の
    // checkMemory より先に memory.grow でブラウザのメモリを使い切らせない)。Worker に渡すのは書き換えた方。
    final wasmBytes = capWasmMemory(config.wasmBytes);
    final blob = web.Blob([_workerSource.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript'));
    final url = web.URL.createObjectURL(blob);
    final worker = WasmPluginWorker._(web.Worker(url.toJS), url);
    worker._worker.onmessage = ((web.MessageEvent e) => worker._onMessage((e.data as JSString).toDart)).toJS;
    worker._worker.onerror = ((web.Event e) {
      worker._tracker.fail(StateError('wasm worker failed: ${e.isA<web.ErrorEvent>() ? (e as web.ErrorEvent).message : e.type}'));
    }).toJS;
    try {
      // 起動確認(instantiate の失敗は、ここで例外になる)。メッセージは JSON の文字列でやり取りする。
      // 終わらない start でも期限 (webWasmInitTimeout) でワーカーごと止まる。
      await worker._request('init', timeout: webWasmInitTimeout, args: {
        'maxMemoryBytes': webWasmMaxMemoryBytes,
        'wasm': base64Encode(wasmBytes),
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
    if (map['shape'] != null) return _shapes.add((map['shape'] as Map).cast<String, Object?>());
    if (map['storage'] != null) return _storage.add((map['storage'] as Map).cast<String, Object?>());
    if (map['ok'] == true) {
      _tracker.complete(map['id'], '${map['result']}');
    } else if (map['fatal'] == true) {
      // メモリの上限を超えた等: インスタンスはもう使えない。ワーカーごと止める。
      _tracker.fail(StateError('${map['error']}'));
    } else {
      _tracker.completeError(map['id'], StateError('${map['error']}'));
    }
  }

  Future<String> _request(String op, {Map<String, Object?> args = const {}, Duration timeout = webWasmCallTimeout}) =>
      _tracker.start(op, (id) => _worker.postMessage(jsonEncode({'id': id, 'op': op, ...args}).toJS), timeout: timeout);

  Future<String> snapshot() => _request('snapshot');
  Future<String> patch() => _request('patch');
  Future<String> call({required String fn, required String argsJson, required String callId}) => _request('call', args: {'fn': fn, 'args': argsJson, 'callId': callId});

  /// セッションのインスタンスのホストを `net.fetch` に許可する(マニフェストが `network.instance` を宣言している場合だけ効く)。
  Future<String> grantHost(String? host) => _request('grantHost', args: {'host': host});

  void _close() {
    if (_closed) return;
    _closed = true;
    _tracker.fail(StateError('wasm worker closed'));
    _worker.terminate();
    web.URL.revokeObjectURL(_url);
    _logs.close();
    _fows.close();
    _apps.close();
    _shapes.close();
    _storage.close();
  }

  Future<void> dispose() async => _close();
}

/// Worker の中身(JS)。Blob から起こすので、配るファイルは増えない。
const _workerSource = r'''
"use strict";
let inst = null, ex = null, storage = {}, maxMemoryBytes = 256 * 1024 * 1024, cfg = {fowPermissions: [], appFns: [], knownAppFns: [], permissions: [], fetchHosts: [], instanceAllowed: false, instanceHost: null};
// JSPI (D-407、指摘 #7): host_fn を非同期にでき、net.fetch を fetch(redirect: "manual") で出せる。
// 無ければ net.fetch は断る(同期 XHR はリダイレクトを追って宣言外へ送ってしまう。D-408)。
const JSPI = typeof WebAssembly.Suspending === "function" && typeof WebAssembly.promising === "function";
const enc = new TextEncoder(), dec = new TextDecoder();
const TOKEN_FNS = ["composer.media.replace","composer.media.preview","composer.text.replace","viewer.overlay.set","composer.open","composer.media.overlay","page.render","page.end","shared.set","shared.op","shared.call"];
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

// ── 通信の形 (端末版 rasq_wasm_runtime_core の fetch_shape と同じ規則。片方を変えたらもう片方も) ──
const seenShapes = new Set();
let shapesOverflow = false;
const MAX_FETCH_SHAPES = 256;
function fnv1a64(s) {
  let h = 0xcbf29ce484222325n;
  for (const b of new TextEncoder().encode(s)) { h ^= BigInt(b); h = (h * 0x100000001b3n) & 0xffffffffffffffffn; }
  return h.toString(16).padStart(16, "0");
}
function segKind(s) {
  if (!s) return "";
  if (/^[0-9]+$/.test(s)) return "{n}";
  if (s.length === 36 && (s.match(/-/g) || []).length === 4 && /^[0-9a-fA-F-]+$/.test(s)) return "{uuid}";
  if (s.length >= 16 && /^[0-9a-fA-F]+$/.test(s)) return "{hex}";
  if (s.includes("@")) return "{acct}";
  if (s.length > 24 || !/^[A-Za-z0-9._-]+$/.test(s)) return "{s}";
  return s.toLowerCase();
}
function skeleton(v, depth) {
  if (depth >= 4) return "…";
  if (v === null) return null;
  if (Array.isArray(v)) return v.length ? [skeleton(v[0], depth + 1)] : [];
  if (typeof v === "object") { const o = {}; for (const k of Object.keys(v).sort().slice(0, 64)) o[k] = skeleton(v[k], depth + 1); return o; }
  if (typeof v === "string") return "s";
  if (typeof v === "number") return "n";
  if (typeof v === "boolean") return "b";
  return null;
}
// serde_json の Map は BTreeMap なので、正規形はキーをソートした JSON。
function canonical(v) {
  if (Array.isArray(v)) return "[" + v.map(canonical).join(",") + "]";
  if (v && typeof v === "object") return "{" + Object.keys(v).sort().map((k) => JSON.stringify(k) + ":" + canonical(v[k])).join(",") + "}";
  return JSON.stringify(v);
}
function fetchShape(args) {
  const url = String(args.url || "");
  if (!(url.startsWith("https://") || url.startsWith("http://"))) return null;
  let u; try { u = new URL(url); } catch (_) { return null; }
  const path = "/" + u.pathname.split("/").filter((s) => s).map(segKind).join("/");
  const query = Array.from(new Set(Array.from(u.searchParams.keys()).map((k) => k.toLowerCase()))).sort();
  const headers = Array.from(new Set(Object.keys(args.headers || {}).map((k) => k.toLowerCase()))).sort();
  let body = "none";
  if (typeof args.body === "string") { try { const j = JSON.parse(args.body); body = (j && typeof j === "object") ? skeleton(j, 0) : "text"; } catch (_) { body = "text"; } }
  else if (args.body && typeof args.body === "object") body = (typeof args.body.b64 === "string") ? "bytes" : skeleton(args.body, 0);
  const shape = {host: u.hostname.toLowerCase(), method: String(args.method || "GET").toUpperCase(), path, query, headers, body};
  return {hash: fnv1a64(canonical(shape)), shape};
}
function recordShape(args) {
  const s = fetchShape(args);
  if (!s || seenShapes.has(s.hash)) return;
  if (seenShapes.size >= MAX_FETCH_SHAPES) { if (!shapesOverflow) { shapesOverflow = true; send({shape: {overflow: true}}); } return; }
  seenShapes.add(s.hash);
  send({shape: s});
}

// net.fetch の門(送る前): 権限・スキーム・宣言した接続先。通れば URL を返す。
function checkFetch(args) {
  recordShape(args); // 通信の形は、通る通らないに関わらず控える(端末版のランタイムと同じ)
  if (!cfg.permissions.includes("network")) throw new HostFnError("E01", "network not permitted");
  const url = String(args.url || "");
  if (!(url.startsWith("https://") || url.startsWith("http://"))) throw new HostFnError("B03", "bad url: " + url);
  // 宣言した先だけ (schema v0.12)。
  if (!hostPermitted(hostOf(url))) throw new HostFnError("E01", "host not permitted: " + hostOf(url));
  return url;
}
function fetchBody(args) {
  if (args.body && typeof args.body === "object" && typeof args.body.b64 === "string") {
    try { return b64ToBytes(args.body.b64); } catch (e) { throw new HostFnError("D01", "bad body base64: " + e); }
  }
  return typeof args.body === "string" ? args.body : null;
}
function fetchResult(status, headers, bytes) {
  // 応答は UTF-8 なら bodyText、そうでなければ bodyB64(端末のランタイムと同じ)。
  try { return {status, headers, bodyText: new TextDecoder("utf-8", {fatal: true}).decode(bytes)}; }
  catch (_) { return {status, headers, bodyB64: bytesToB64(bytes)}; }
}

// 応答本文の上限 (D-453、Codex の指摘 resource-exhaustion.web-fetch-response-buffer): 端末版 (rasq_wasm_runtime_core の
// MAX_FETCH_BODY_BYTES) と同じ 32 MiB。超えたときの答えも同じ (B03 "response body exceeds 33554432 bytes")。片方を変えたらもう片方も。
// 前は res.arrayBuffer() で相手が送るだけ Worker の JS ヒープに載せ、そのあと文字列 / base64 / JSON で写しを増やしていた
// (checkMemory はゲストのメモリしか見ないので止まらない。期限も速い巨大な応答は止めない)。いまは本文を少しずつ読み、
// 上限を 1 バイトでも超えたら、文字列にする前に読むのをやめて通信も切る (reader.cancel + AbortController)。
// Content-Length が上限を超えていれば読む前に断る(圧縮されている応答は展開後の大きさが分からないので、読みながら数える方に任せる)。
// 同時に出る通信は 1 本だけ: 呼び出しは 1 つずつ順に処理し (下の queue)、net.fetch を待つ間ゲストは JSPI で止まっている。
const MAX_FETCH_BODY_BYTES = 32 * 1024 * 1024;
function bodyTooLarge() { return new HostFnError("B03", "response body exceeds " + MAX_FETCH_BODY_BYTES + " bytes"); }
async function readBodyLimited(res, abort) {
  const len = res.headers.get("content-length"), coding = (res.headers.get("content-encoding") || "identity").trim().toLowerCase();
  if (len !== null && coding === "identity" && /^\s*\d+\s*$/.test(len) && Number(len) > MAX_FETCH_BODY_BYTES) { abort.abort(); throw bodyTooLarge(); }
  if (!res.body) return new Uint8Array(0);
  const reader = res.body.getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    let r;
    try { r = await reader.read(); } catch (e) { abort.abort(); throw new HostFnError("B03", "read body failed: " + e); }
    if (r.done) break;
    total += r.value.byteLength;
    if (total > MAX_FETCH_BODY_BYTES) {
      chunks.length = 0; // 読んだぶんもすぐ手放す
      reader.cancel().catch(() => {});
      abort.abort();
      throw bodyTooLarge();
    }
    chunks.push(r.value);
  }
  const out = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) { out.set(c, off); off += c.byteLength; }
  return out;
}

// JSPI のとき: fetch をリダイレクトを追わずに出す (D-407、指摘 #7)。3xx は宣言外へ一切送らずに断る(端末版も追わない)。
async function netFetchAsync(args) {
  const url = checkFetch(args);
  const headers = new Headers();
  for (const [k, v] of Object.entries(args.headers || {})) {
    // ブラウザが触らせないヘッダ(User-Agent など)は、付けられないだけで通信は続ける。
    try { if (typeof v === "string") headers.set(k, v); } catch (_) {}
  }
  const method = String(args.method || "GET").toUpperCase();
  const body = method === "GET" || method === "HEAD" ? null : fetchBody(args);
  const abort = new AbortController();
  let res;
  try { res = await fetch(url, {method, headers, body, redirect: "manual", signal: abort.signal}); }
  catch (e) { throw new HostFnError("B01", "fetch failed (network / CORS): " + e); }
  if (res.type === "opaqueredirect" || (res.status >= 300 && res.status < 400)) {
    throw new HostFnError("E01", "redirect is not followed (" + hostOf(url) + ")");
  }
  const out = {};
  res.headers.forEach((v, k) => { out[k.toLowerCase()] = v; });
  return fetchResult(res.status, out, await readBodyLimited(res, abort));
}

// JSPI の無いブラウザ: 通信は出さない(D-408、指摘 #7 の残り)。同期 XHR はリダイレクトを勝手に追い、宣言外のホストへ
// 送ってからしか気づけないので使わない。門(権限・宣言した接続先)の答えは JSPI のときと同じ順に返す(宣言外は宣言外の E01)。
const NO_JSPI_FETCH = "このブラウザでは通信できるプラグインを動かせません";
function netFetch(args) {
  checkFetch(args);
  throw new HostFnError("E01", NO_JSPI_FETCH);
}

function invoke(fn, args) {
  const ns = () => String(args.ns == null ? "safe" : args.ns);
  const key = () => ns() + ":" + String(args.key);
  // storage.* は ns ごとに別権限 (D-004)。端末版の _requireStorage と同じ。
  const requireStorage = () => { if (!cfg.permissions.includes("storage." + ns())) throw new HostFnError("E01", "storage." + ns() + " not permitted"); };
  switch (fn) {
    case "storage.get": { requireStorage(); const v = storage[key()]; return {value: v === undefined ? null : v}; }
    case "storage.set": requireStorage(); storage[key()] = args.value === undefined ? null : args.value; send({storage: {ns: ns(), key: String(args.key), value: storage[key()]}}); return {};
    case "storage.delete": requireStorage(); delete storage[key()]; send({storage: {ns: ns(), key: String(args.key), value: null}}); return {};
    case "net.fetch": return JSPI ? netFetchAsync(args) : netFetch(args);
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
    // gpu.compute (D-081) は Web ではまだ無い(WebGPU への写しは未実装)ので、門に関係なく常に E01 = ml.infer へ縮退。
    // 実装するときは端末版と同じ門(審査済み / dev の付与 = WasmWorkerConfig.gpuCompute、かつ permissions に gpu_ml)と、
    // rasq-sdk-sample docs/host-functions.md「gpu.compute の権限と上限」の上限・10 秒の壁時計を Worker の中で守ること。
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

function dispatchError(callId, e) { return JSON.stringify({callId, ok: false, error: {code: e instanceof HostFnError ? e.code : "F00", message: String(e.message || e)}}); }
function parseRequest(requestJson) {
  try { return JSON.parse(requestJson); } catch (e) { return {bad: "bad hostfn request: " + e}; }
}

function dispatch(requestJson) {
  const req = parseRequest(requestJson);
  if (req.bad) return JSON.stringify({ok: false, error: {code: "D01", message: req.bad}});
  const callId = req.callId === undefined ? null : req.callId;
  send({log: "hostFn: " + req.fn});
  try { return JSON.stringify({callId, ok: true, value: invoke(String(req.fn || ""), req.args || {})}); }
  catch (e) { return dispatchError(callId, e); }
}

// JSPI のとき: invoke が Promise(net.fetch)を返したら待つ。wasm 側の呼び出しはその間止まっている。
async function dispatchAsync(requestJson) {
  const req = parseRequest(requestJson);
  if (req.bad) return JSON.stringify({ok: false, error: {code: "D01", message: req.bad}});
  const callId = req.callId === undefined ? null : req.callId;
  send({log: "hostFn: " + req.fn});
  try { return JSON.stringify({callId, ok: true, value: await invoke(String(req.fn || ""), req.args || {})}); }
  catch (e) { return dispatchError(callId, e); }
}

function packResult(json) {
  const res = enc.encode(json);
  const out = writeBytes(res);
  return (BigInt(out) << 32n) | BigInt(res.length);
}
function hostFn(ptr, len) { return packResult(dispatch(readStr(ptr, len))); }
async function hostFnAsync(ptr, len) {
  const req = readStr(ptr, len); // 待つ前に読む(待つ間にメモリが伸びても困らない)
  return packResult(await dispatchAsync(req));
}

// メモリの上限 (D-407、指摘 #10): 端末版と同じ。超えたらインスタンスごと捨てる(fatal でワーカーを止めてもらう)。
// 主な守りは起動前に書き込んだ最大 (D-452、capWasmMemory) で、ここは二段目(書き込みを抜けた場合の後始末)。
class FatalError extends Error {}
function checkMemory() {
  const n = inst.exports.memory.buffer.byteLength;
  if (n > maxMemoryBytes) throw new FatalError("plugin exceeded its memory limit (" + maxMemoryBytes + " bytes)");
}

async function handle(ev) {
  const m = JSON.parse(ev.data);
  try {
    switch (m.op) {
      case "init": {
        storage = Object.assign({}, m.storage || {});
        if (typeof m.maxMemoryBytes === "number") maxMemoryBytes = m.maxMemoryBytes;
        cfg = {fowPermissions: m.fowPermissions || [], appFns: m.appFns || [], knownAppFns: m.knownAppFns || [],
               permissions: m.permissions || [], fetchHosts: m.fetchHosts || [], instanceAllowed: !!m.instanceAllowed, instanceHost: null};
        // JSPI の無いブラウザでは、通信を宣言したプラグインの net.fetch は E01 になる(D-408)。開発者に見えるように記録だけ残す。
        if (!JSPI && cfg.permissions.includes("network")) send({log: "net.fetch: " + NO_JSPI_FETCH});
        const hostImport = JSPI ? new WebAssembly.Suspending(hostFnAsync) : hostFn;
        const {instance} = await WebAssembly.instantiate(b64ToBytes(m.wasm), {rasq: {host_fn: hostImport}});
        for (const name of ["memory", "alloc", "dealloc", "snapshot", "patch", "call"]) {
          if (!instance.exports[name]) throw new Error("missing export: " + name);
        }
        inst = instance;
        // JSPI のとき、host_fn を呼びうる入口は promising で包む(呼ぶ側は await)。
        ex = JSPI
          ? {snapshot: WebAssembly.promising(instance.exports.snapshot), patch: WebAssembly.promising(instance.exports.patch), call: WebAssembly.promising(instance.exports.call)}
          : {snapshot: instance.exports.snapshot, patch: instance.exports.patch, call: instance.exports.call};
        checkMemory();
        return send({id: m.id, ok: true, result: "pong"});
      }
      case "grantHost": {
        // 宣言 (network.instance) が無ければ無視する: 呼び出し側の都合で権限を後から足せない。
        if (cfg.instanceAllowed) { const h = String(m.host || "").trim().toLowerCase(); cfg.instanceHost = h || null; }
        return send({id: m.id, ok: true, result: cfg.instanceHost || ""});
      }
      case "snapshot": { const r = readPacked(await ex.snapshot()); checkMemory(); return send({id: m.id, ok: true, result: r}); }
      case "patch": { const r = readPacked(await ex.patch()); checkMemory(); return send({id: m.id, ok: true, result: r}); }
      case "call": {
        const parts = [m.fn, m.args, m.callId].map((s) => enc.encode(String(s)));
        const ptrs = parts.map(writeBytes);
        const packed = await ex.call(ptrs[0], parts[0].length, ptrs[1], parts[1].length, ptrs[2], parts[2].length);
        ptrs.forEach((p, i) => inst.exports.dealloc(p, parts[i].length));
        const r = readPacked(packed);
        checkMemory();
        return send({id: m.id, ok: true, result: r});
      }
      default: return send({id: m.id, ok: false, error: "unknown op: " + m.op});
    }
  } catch (e) {
    send({id: m.id, ok: false, fatal: e instanceof FatalError, error: String(e && e.message || e)});
  }
}
// 1 つずつ順に(JSPI で net.fetch を待っている間に、次の呼び出しが同じインスタンスへ入り込まないように)。
let queue = Promise.resolve();
self.onmessage = (ev) => { queue = queue.then(() => handle(ev)); };
''';
