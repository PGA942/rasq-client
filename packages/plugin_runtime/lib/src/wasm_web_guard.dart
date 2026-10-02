import 'dart:async';
import 'dart:typed_data';

/// Web 版ワーカー (D-297) の守り (D-407、セキュリティ指摘 #10)。ブラウザの WebAssembly は fuel を数えないので、
/// 終わらない `start` / `snapshot` / `call` がワーカーを回し続け、読み込みが永遠に終わらなくなる。そこで:
/// - 要求ごとに期限を持ち、期限を過ぎたら**ワーカーを止め**(`terminate`)、待っている要求をすべて失敗させる。
///   以後の要求は即失敗(プラグインは失敗扱い。読み込み直すには作り直す)。
/// - 起動の前に、モジュールが宣言するメモリ(初期ページ数)を端末版と同じ上限で断る。
///
/// Web でしか使わないが、期限の振る舞いを VM のテストで確かめられるよう、ここはプラットフォームに依らない。

/// 起動(`WebAssembly.instantiate` + `start`)の期限。
const webWasmInitTimeout = Duration(seconds: 15);

/// `snapshot` / `patch` / `call` 1 回の期限(`net.fetch` の同期通信を含む)。
const webWasmCallTimeout = Duration(seconds: 30);

/// プラグインのメモリの上限(端末版 rasq_wasm_runtime_core の MAX_MEMORY_BYTES と同じ 256 MiB)。
const webWasmMaxMemoryBytes = 256 * 1024 * 1024;

/// 期限の過ぎた要求。ワーカーはもう止まっている。
class WasmWorkerTimeout implements Exception {
  WasmWorkerTimeout(this.op, this.timeout);
  final String op;
  final Duration timeout;
  @override
  String toString() => 'wasm plugin "$op" did not finish within ${timeout.inMilliseconds} ms (the worker was terminated)';
}

/// ワーカーへの要求と期限の帳簿。[onFatal] でワーカーを止める(1 回だけ呼ばれる)。
class WasmRequestTracker {
  WasmRequestTracker({required this.onFatal});

  final void Function(Object error) onFatal;
  final Map<int, Completer<String>> _pending = {};
  final Map<int, Timer> _timers = {};
  int _seq = 0;
  Object? _stopped;

  /// 止まった理由(止まっていなければ null)。
  Object? get stoppedBy => _stopped;
  int get pendingCount => _pending.length;

  /// 要求を出す: [send] に id を渡す。[timeout] までに [complete] / [completeError] が来なければ、ワーカーを止める。
  Future<String> start(String op, void Function(int id) send, {required Duration timeout}) {
    final stopped = _stopped;
    if (stopped != null) return Future.error(StateError('wasm worker is stopped: $stopped'));
    final id = _seq++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _timers[id] = Timer(timeout, () => fail(WasmWorkerTimeout(op, timeout)));
    try {
      send(id);
    } catch (e) {
      _finish(id)?.completeError(e);
    }
    return completer.future;
  }

  Completer<String>? _finish(Object? id) {
    _timers.remove(id)?.cancel();
    return _pending.remove(id);
  }

  void complete(Object? id, String result) {
    final c = _finish(id);
    if (c != null && !c.isCompleted) c.complete(result);
  }

  void completeError(Object? id, Object error) {
    final c = _finish(id);
    if (c != null && !c.isCompleted) c.completeError(error);
  }

  /// ワーカーを止める: 待っている要求をすべて [error] で失敗させ、[onFatal] を呼ぶ。2 回目以降は何もしない。
  void fail(Object error) {
    if (_stopped != null) return;
    _stopped = error;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    final pending = Map.of(_pending);
    _pending.clear();
    for (final c in pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    onFatal(error);
  }
}

/// モジュールが自分で定義するメモリの初期サイズ(バイト、最大のもの)。メモリ節が無ければ 0。形が壊れていれば
/// [FormatException](起動前に断る)。インポートするメモリはここでは数えない(ホストは渡さないので起動が失敗する)。
int wasmDeclaredMemoryBytes(Uint8List bytes) {
  var pos = 0;
  int u8() {
    if (pos >= bytes.length) throw const FormatException('truncated wasm module');
    return bytes[pos++];
  }

  int leb() {
    var result = 0, shift = 0;
    while (true) {
      final b = u8();
      if (shift < 53) result += (b & 0x7f) * (1 << shift);
      if (b & 0x80 == 0) return result;
      shift += 7;
      if (shift > 70) throw const FormatException('bad LEB128 in wasm module');
    }
  }

  if (bytes.length < 8 || bytes[0] != 0x00 || bytes[1] != 0x61 || bytes[2] != 0x73 || bytes[3] != 0x6d) throw const FormatException('not a wasm module');
  pos = 8;
  var maxBytes = 0;
  while (pos < bytes.length) {
    final id = u8();
    final size = leb();
    final end = pos + size;
    if (end > bytes.length) throw const FormatException('truncated wasm section');
    if (id == 5) {
      final count = leb();
      for (var i = 0; i < count; i++) {
        final flags = leb();
        final min = leb();
        if (flags & 0x01 != 0) leb(); // max
        // 64KiB ページ。custom page size (flags 0x08) は使わせない(初期の大きさが読めない)。
        if (flags & 0x08 != 0) throw const FormatException('custom page sizes are not supported');
        final b = min * 65536;
        if (b > maxBytes) maxBytes = b;
      }
    }
    pos = end;
  }
  return maxBytes;
}

/// 起動の前の検査: 宣言したメモリが [webWasmMaxMemoryBytes] を超えるなら断る。
void checkWasmMemoryDeclaration(Uint8List bytes, {int limit = webWasmMaxMemoryBytes}) {
  final declared = wasmDeclaredMemoryBytes(bytes);
  if (declared > limit) throw StateError('plugin declares $declared bytes of memory (limit $limit)');
}
