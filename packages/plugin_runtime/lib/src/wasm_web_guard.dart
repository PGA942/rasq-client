import 'dart:async';
import 'dart:typed_data';

/// Web 版ワーカー (D-297) の守り (D-407、セキュリティ指摘 #10)。ブラウザの WebAssembly は fuel を数えないので、
/// 終わらない `start` / `snapshot` / `call` がワーカーを回し続け、読み込みが永遠に終わらなくなる。そこで:
/// - 要求ごとに期限を持ち、期限を過ぎたら**ワーカーを止め**(`terminate`)、待っている要求をすべて失敗させる。
///   以後の要求は即失敗(プラグインは失敗扱い。読み込み直すには作り直す)。
/// - 起動の前に、モジュールが宣言するメモリ(初期ページ数)を端末版と同じ上限で断り、各メモリの最大を上限内に
///   書き込む(D-452。実行後の検査より先に `memory.grow` でタブを落とさせない。[capWasmMemory])。
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

/// wasm の 1 ページ (64 KiB)。
const _wasmPageBytes = 65536;

/// wasm のバイト列の読み手(バイト / LEB128)。形が壊れていれば [FormatException]。
class _WasmReader {
  _WasmReader(this.bytes, this.pos);
  final Uint8List bytes;
  int pos;

  int u8() {
    if (pos >= bytes.length) throw const FormatException('truncated wasm module');
    return bytes[pos++];
  }

  /// 符号なし LEB128 の u32(仕様どおり 5 バイトまで、5 バイト目は下位 4 ビットまで)。
  int u32() {
    var result = 0;
    for (var i = 0; i < 5; i++) {
      final b = u8();
      result += (b & 0x7f) * (1 << (7 * i));
      if (b & 0x80 == 0) {
        if (i == 4 && b > 0x0f) break;
        return result;
      }
    }
    throw const FormatException('bad LEB128 in wasm module');
  }

  /// 値を使わない LEB128(s33 の型の添字、table64 の大きさなど)を読み飛ばす。
  void skipLeb() {
    for (var i = 0; i < 10; i++) {
      if (u8() & 0x80 == 0) return;
    }
    throw const FormatException('bad LEB128 in wasm module');
  }

  void skip(int n) {
    if (n > bytes.length - pos) throw const FormatException('truncated wasm module');
    pos += n;
  }

  /// 値の型 / 参照の型。GC 提案の `(ref null? ht)`(0x63 / 0x64)は型の添字が続く。
  void skipValType() {
    final t = u8();
    if (t == 0x63 || t == 0x64) skipLeb();
  }

  /// テーブルの大きさ(メモリではないので数えない)。
  void skipLimits() {
    final flags = u8();
    skipLeb();
    if (flags & 0x01 != 0) skipLeb();
  }
}

/// モジュールが自分で定義するメモリ 1 つの宣言(ページ数)。
class _WasmMemoryDecl {
  _WasmMemoryDecl(this.min, this.max);
  final int min;
  final int? max;
}

/// モジュールを節ごとに読み、メモリ節の中身と位置を返す。**メモリのインポート**(ホストは渡さないが、
/// 渡せば上限を書き込めない)、**共有メモリ**(threads)、**memory64**、**custom page size** は断る(ブラウザがそのまま
/// 起動してしまう形を、ここで読み違えないため。いまのプラグインはどれも使っていない)。
({List<_WasmMemoryDecl> memories, int sectionStart, int sectionEnd}) _readWasmMemories(Uint8List bytes) {
  if (bytes.length < 8 || bytes[0] != 0x00 || bytes[1] != 0x61 || bytes[2] != 0x73 || bytes[3] != 0x6d) throw const FormatException('not a wasm module');
  if (bytes[4] != 1 || bytes[5] != 0 || bytes[6] != 0 || bytes[7] != 0) throw const FormatException('unsupported wasm version');
  final r = _WasmReader(bytes, 8);
  final memories = <_WasmMemoryDecl>[];
  var sectionStart = -1, sectionEnd = -1;
  while (r.pos < bytes.length) {
    final start = r.pos;
    final id = r.u8();
    final size = r.u32();
    final end = r.pos + size;
    if (end > bytes.length) throw const FormatException('truncated wasm section');
    if (id == 2) {
      // インポート節: 種類ごとに読み飛ばし、メモリが来たら断る。
      final count = r.u32();
      for (var i = 0; i < count; i++) {
        r.skip(r.u32()); // モジュール名
        r.skip(r.u32()); // 名前
        switch (r.u8()) {
          case 0x00: // 関数
            r.u32();
          case 0x01: // テーブル
            r.skipValType();
            r.skipLimits();
          case 0x02:
            throw StateError('plugin imports a memory (not allowed: its size limit cannot be enforced)');
          case 0x03: // グローバル
            r.skipValType();
            r.u8();
          case 0x04: // タグ(例外)
            r.u8();
            r.u32();
          default:
            throw const FormatException('unknown import kind in wasm module');
        }
      }
      if (r.pos != end) throw const FormatException('bad wasm import section');
    } else if (id == 5) {
      if (sectionStart >= 0) throw const FormatException('duplicate wasm memory section');
      sectionStart = start;
      sectionEnd = end;
      final count = r.u32();
      for (var i = 0; i < count; i++) {
        final flags = r.u8();
        if (flags & 0x02 != 0) throw StateError('plugin declares a shared memory (not allowed)');
        if (flags & 0x04 != 0) throw StateError('plugin declares a 64-bit memory (not allowed)');
        // 64KiB ページ。custom page size (flags 0x08) は使わせない(大きさが読み違えられる)。
        if (flags & 0x08 != 0) throw StateError('plugin declares a custom page size (not allowed)');
        if (flags & ~0x01 != 0) throw const FormatException('bad memory limits in wasm module');
        final min = r.u32();
        final max = flags & 0x01 != 0 ? r.u32() : null;
        if (max != null && max < min) throw const FormatException('wasm memory maximum is below its minimum');
        memories.add(_WasmMemoryDecl(min, max));
      }
      if (r.pos != end) throw const FormatException('bad wasm memory section');
    }
    r.pos = end;
  }
  return (memories: memories, sectionStart: sectionStart, sectionEnd: sectionEnd);
}

/// モジュールが自分で定義するメモリの初期サイズ(バイト、最大のもの)。メモリ節が無ければ 0。形が壊れていれば
/// [FormatException](起動前に断る)。インポートするメモリ・共有メモリ・memory64 は [StateError] で断る。
int wasmDeclaredMemoryBytes(Uint8List bytes) {
  var maxBytes = 0;
  for (final m in _readWasmMemories(bytes).memories) {
    final b = m.min * _wasmPageBytes;
    if (b > maxBytes) maxBytes = b;
  }
  return maxBytes;
}

/// 起動の前の検査と**上限の書き込み** (D-452、Codex セキュリティ検査の指摘 `resource-exhaustion.web-wasm-memory-growth`)。
/// ブラウザの WebAssembly は宣言した最大(無ければ 4 GiB 近く)まで `memory.grow` できるので、実行後の検査
/// (Worker の `checkMemory`)より先に `start` / `call` の中でメモリを使い切り、タブごと落とせた。そこで起動する前に:
/// - 初期サイズの合計が [limit] を超えるなら断る([StateError])。インポート / 共有 / memory64 も断る。
/// - **各メモリの最大を書き込む**(合計が [limit] を超えないよう、宣言の順に残りを配る。宣言した最大がそれ以下なら
///   そのまま)。Rust の wasm32 は最大を宣言しない(同梱のプラグインはどれも初期だけ)ので、断らずに書き換える。
///   上限に当たった `memory.grow` は -1 を返し、ゲストのアロケータが落ちる(端末版の `StoreLimits` と同じ上限)。
/// 書き換えたモジュール(書き換えが要らなければ元のまま)を返す。メモリ節の大きさの LEB128 は書き直す
/// (ほかの節の中身は位置に依らないので、そのまま写す)。実行後の検査と期限は、二段目の守りとして残す。
Uint8List capWasmMemory(Uint8List bytes, {int limit = webWasmMaxMemoryBytes}) {
  final parsed = _readWasmMemories(bytes);
  final limitPages = limit ~/ _wasmPageBytes;
  final initialPages = parsed.memories.fold<int>(0, (s, m) => s + m.min);
  if (initialPages > limitPages) {
    throw StateError('plugin declares ${initialPages * _wasmPageBytes} bytes of memory (limit $limit)');
  }
  // 初期サイズの残りを、宣言の順に配る(1 つ目 = Rust の `memory` が先に取る)。合計は limitPages を超えない。
  var spare = limitPages - initialPages;
  var changed = false;
  final body = <int>[..._leb(parsed.memories.length)];
  for (final m in parsed.memories) {
    final want = (m.max ?? limitPages) - m.min;
    final give = want < spare ? want : spare;
    spare -= give;
    final max = m.min + give;
    if (max != m.max) changed = true;
    body
      ..add(0x01)
      ..addAll(_leb(m.min))
      ..addAll(_leb(max));
  }
  if (!changed) return bytes;
  return (BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(bytes, 0, parsed.sectionStart))
        ..addByte(5)
        ..add(_leb(body.length))
        ..add(body)
        ..add(Uint8List.sublistView(bytes, parsed.sectionEnd)))
      .takeBytes();
}

/// 符号なし LEB128(最短の形)。
List<int> _leb(int v) {
  final out = <int>[];
  do {
    var b = v % 128;
    v = v ~/ 128;
    if (v != 0) b |= 0x80;
    out.add(b);
  } while (v != 0);
  return out;
}
