import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import '../../l10n/l10n.dart';

/// onnxruntime-web (D-302) の入口。端末の onnxruntime (FFI) の代わりに、ブラウザの WebAssembly で ONNX を回す。
///
/// - ランタイムは**使うときに** CDN から読み込む(版は固定)。モデルを入れない人には何も読み込まない。
/// - モデルのファイルは **IndexedDB** に置く(Cache API は https / localhost でしか使えない。IndexedDB は http の開発環境でも動く)。
/// - 推論は wasm の 1 スレッド(複数スレッドは crossOriginIsolated が要る)。いまはメインスレッドで回すので、重いモデルでは画面が一瞬止まる。
const ortWebVersion = '1.22.0';
const _ortBase = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@$ortWebVersion/dist/';

const _helperSource = r'''
window.__rasqOrt = (() => {
  const DB = 'rasq-models', STORE = 'files';
  const open = () => new Promise((res, rej) => { const r = indexedDB.open(DB, 1); r.onupgradeneeded = () => r.result.createObjectStore(STORE); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); });
  const tx = async (mode, f) => { const db = await open(); return new Promise((res, rej) => { const t = db.transaction(STORE, mode); const q = f(t.objectStore(STORE)); t.oncomplete = () => { db.close(); res(q.result); }; t.onerror = t.onabort = () => { db.close(); rej(t.error); }; }); };
  const aborts = {};
  return {
    has: (id) => tx('readonly', (s) => s.count(id)).then((n) => n > 0),
    remove: (id) => tx('readwrite', (s) => s.delete(id)),
    cancel: (id) => { if (aborts[id]) aborts[id].abort(); },
    async download(id, url, token, fallbackTotal, onProgress) {
      const ac = new AbortController(); aborts[id] = ac;
      try {
        const r = await fetch(url, {signal: ac.signal, headers: token ? {Authorization: 'Bearer ' + token} : {}});
        if (!r.ok) throw new Error('HTTP ' + r.status);
        const total = Number(r.headers.get('content-length')) || fallbackTotal;
        const reader = r.body.getReader(); const chunks = []; let got = 0, last = -1;
        for (;;) {
          const {done, value} = await reader.read(); if (done) break;
          chunks.push(value); got += value.length;
          const pct = Math.min(99, Math.floor(got * 100 / total));
          if (pct !== last) { last = pct; onProgress(pct); }
        }
        await tx('readwrite', (s) => s.put(new Blob(chunks), id));
      } finally { delete aborts[id]; }
    },
    async session(id) {
      const blob = await tx('readonly', (s) => s.get(id)); if (!blob) return null;
      const buf = new Uint8Array(await blob.arrayBuffer());
      return await ort.InferenceSession.create(buf, {executionProviders: ['wasm'], graphOptimizationLevel: 'all'});
    },
    inputs: (s) => s.inputNames,
    outputs: (s) => s.outputNames,
    async run(s, feeds, out) {
      const f = {};
      for (const [k, v] of Object.entries(feeds)) {
        f[k] = v.type === 'int64' ? new ort.Tensor('int64', BigInt64Array.from(v.data, (x) => BigInt(x)), v.dims) : new ort.Tensor('float32', v.data, v.dims);
      }
      const t = (await s.run(f, [out]))[out];
      return {data: t.data, dims: Array.from(t.dims)};
    },
    release: (s) => s.release(),
  };
})();
''';

extension type _Helper._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> has(String id);
  external JSPromise<JSAny?> remove(String id);
  external void cancel(String id);
  external JSPromise<JSAny?> download(String id, String url, String? token, int fallbackTotal, JSFunction onProgress);
  external JSPromise<JSObject?> session(String id);
  external JSArray<JSString> inputs(JSObject session);
  external JSArray<JSString> outputs(JSObject session);
  external JSPromise<_RunResult> run(JSObject session, JSObject feeds, String out);
  external JSPromise<JSAny?> release(JSObject session);
}

extension type _RunResult._(JSObject _) implements JSObject {
  external JSFloat32Array get data;
  external JSArray<JSNumber> get dims;
}

_Helper get _helper {
  if (!globalContext.has('__rasqOrt')) {
    final s = web.document.createElement('script') as web.HTMLScriptElement..text = _helperSource;
    web.document.head!.append(s);
  }
  return globalContext['__rasqOrt'] as _Helper;
}

Future<void>? _ortLoading;

/// onnxruntime-web を読み込む(1 回だけ)。
Future<void> _ensureOrt() => _ortLoading ??= () async {
      if (!globalContext.has('ort')) {
        final done = Completer<void>();
        final s = web.document.createElement('script') as web.HTMLScriptElement
          ..src = '${_ortBase}ort.wasm.min.js'
          ..crossOrigin = 'anonymous';
        s.onload = ((web.Event _) => done.complete()).toJS;
        s.onerror = ((web.Event _) => done.completeError(StateError(appL10n.platformWebRuntimeLoadFailed))).toJS;
        web.document.head!.append(s);
        try {
          await done.future;
        } catch (_) {
          _ortLoading = null;
          rethrow;
        }
      }
      final wasm = ((globalContext['ort'] as JSObject)['env'] as JSObject)['wasm'] as JSObject;
      wasm['wasmPaths'] = _ortBase.toJS;
      wasm['numThreads'] = 1.toJS;
    }();

/// IndexedDB に置いたモデルのファイル。
class WebModelStore {
  const WebModelStore();
  Future<bool> has(String id) async => (await _helper.has(id).toDart).toDart;
  Future<void> remove(String id) => _helper.remove(id).toDart;
  void cancel(String id) => _helper.cancel(id);
  Future<void> download(String id, Uri url, {String? token, required int fallbackTotal, required void Function(int pct) onProgress}) =>
      _helper.download(id, '$url', token, fallbackTotal, ((JSNumber p) => onProgress(p.toDartInt)).toJS).toDart;
}

/// 読み込んだ ONNX のセッション。
class WebOrtSession {
  WebOrtSession._(this._s, this.inputNames, this.outputNames);
  final JSObject _s;
  final List<String> inputNames;
  final List<String> outputNames;

  /// IndexedDB の [id] のモデルを読み込む。無ければ null。
  static Future<WebOrtSession?> open(String id) async {
    await _ensureOrt();
    final s = await _helper.session(id).toDart;
    if (s == null) return null;
    return WebOrtSession._(s, [for (final n in _helper.inputs(s).toDart) n.toDart], [for (final n in _helper.outputs(s).toDart) n.toDart]);
  }

  /// [ints](int64 として渡す)と [floats] を入力に、[output] を取り出す。戻りは (平らなデータ, 形)。
  Future<(Float32List, List<int>)> run({Map<String, (Int32List, List<int>)> ints = const {}, Map<String, (Float32List, List<int>)> floats = const {}, required String output}) async {
    final feeds = JSObject();
    JSObject feed(String type, JSAny data, List<int> dims) => JSObject()
      ..['type'] = type.toJS
      ..['data'] = data
      ..['dims'] = [for (final d in dims) d.toJS].toJS;
    for (final e in ints.entries) {
      feeds[e.key] = feed('int64', e.value.$1.toJS, e.value.$2);
    }
    for (final e in floats.entries) {
      feeds[e.key] = feed('float32', e.value.$1.toJS, e.value.$2);
    }
    final r = await _helper.run(_s, feeds, output).toDart;
    return (r.data.toDart, [for (final d in r.dims.toDart) d.toDartInt]);
  }

  Future<void> release() => _helper.release(_s).toDart;
}
