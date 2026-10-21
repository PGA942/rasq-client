import 'dart:async';
import 'dart:typed_data';

/// Web 版ワーカー (D-297) の守り (D-407、セキュリティ指摘 #10)。ブラウザの WebAssembly は fuel を数えないので、
/// 終わらない `start` / `snapshot` / `call` がワーカーを回し続け、読み込みが永遠に終わらなくなる。そこで:
/// - 要求ごとに期限を持ち、期限を過ぎたら**ワーカーを止め**(`terminate`)、待っている要求をすべて失敗させる。
///   以後の要求は即失敗(プラグインは失敗扱い。読み込み直すには作り直す)。
/// - 起動の前に、モジュールが宣言するメモリ(初期ページ数)を端末版と同じ上限で断り、各メモリの最大を上限内に
///   書き込む(D-452。実行後の検査より先に `memory.grow` でタブを落とさせない。[capWasmMemory])。
/// - テーブルも同じく、数と要素数を端末版と同じ上限で断り、最大を上限内に書き込む(D-546。[capWasmTables])。
///
/// Web でしか使わないが、期限の振る舞いを VM のテストで確かめられるよう、ここはプラットフォームに依らない。

/// 起動(`WebAssembly.instantiate` + `start`)の期限。
const webWasmInitTimeout = Duration(seconds: 15);

/// `snapshot` / `patch` / `call` 1 回の期限(`net.fetch` の同期通信を含む)。
const webWasmCallTimeout = Duration(seconds: 30);

/// プラグインのメモリの上限(端末版 rasq_wasm_runtime_core の MAX_MEMORY_BYTES と同じ 256 MiB)。
const webWasmMaxMemoryBytes = 256 * 1024 * 1024;

/// プラグインが定義できるテーブルの数(端末版 rasq_wasm_runtime_core の MAX_TABLES と同じ 1。Rust の wasm32 は
/// `__indirect_function_table` の 1 本だけ)。D-546。
const webWasmMaxTables = 1;

/// テーブルの要素数の上限(全テーブルの最大の合計。端末版の MAX_TABLE_ELEMENTS と同じ 100,000)。ふつうの間接呼び出しなら
/// 数千も使わない。D-546。
const webWasmMaxTableElements = 100000;

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
}

/// モジュールが自分で定義するメモリ / テーブル 1 つの宣言(メモリはページ数、テーブルは要素数)。
/// [refType] はテーブルの要素の型(funcref 0x70 / externref 0x6f。メモリは 0)。
class _WasmLimits {
  _WasmLimits(this.min, this.max, {this.refType = 0});
  final int min;
  final int? max;
  final int refType;
}

/// 節の位置(id とバイトの範囲)。無ければ start = -1。
typedef _WasmSection = ({int start, int end});

/// モジュールを節ごとに読み、メモリ節とテーブル節の中身と位置を返す。**メモリ / テーブルのインポート**(ホストは
/// 渡さないが、渡せば上限を書き込めない)、**共有メモリ**(threads)、**memory64**、**custom page size**、
/// **table64・初期化式つきのテーブル・funcref / externref 以外のテーブル**は断る(ブラウザがそのまま起動してしまう形を、
/// ここで読み違えないため。いまのプラグインはどれも使っていない)。
({List<_WasmLimits> memories, _WasmSection memorySection, List<_WasmLimits> tables, _WasmSection tableSection}) _readWasmModule(Uint8List bytes) {
  if (bytes.length < 8 || bytes[0] != 0x00 || bytes[1] != 0x61 || bytes[2] != 0x73 || bytes[3] != 0x6d) throw const FormatException('not a wasm module');
  if (bytes[4] != 1 || bytes[5] != 0 || bytes[6] != 0 || bytes[7] != 0) throw const FormatException('unsupported wasm version');
  final r = _WasmReader(bytes, 8);
  final memories = <_WasmLimits>[];
  final tables = <_WasmLimits>[];
  var sectionStart = -1, sectionEnd = -1;
  var tableStart = -1, tableEnd = -1;
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
          case 0x01: // D-546: テーブルも上限を書き込めないので断る(ホストは渡さない)。
            throw StateError('plugin imports a table (not allowed: its size limit cannot be enforced)');
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
        memories.add(_WasmLimits(min, max));
      }
      if (r.pos != end) throw const FormatException('bad wasm memory section');
    } else if (id == 4) {
      // テーブル節 (D-546): 数と要素数を数える(前は読み飛ばし、宣言どおりの大きさでブラウザに確保させていた)。
      if (tableStart >= 0) throw const FormatException('duplicate wasm table section');
      tableStart = start;
      tableEnd = end;
      final count = r.u32();
      for (var i = 0; i < count; i++) {
        final refType = r.u8();
        // 0x40 0x00 = 初期化式つきのテーブル(function-references)、0x63 / 0x64 = GC の参照型。どちらも使わせない。
        if (refType != 0x70 && refType != 0x6f) throw StateError('plugin declares an unsupported table type (not allowed)');
        final flags = r.u8();
        // 0x04 = table64、0x02 = shared。最小 / 最大の u32 だけを許す。
        if (flags & ~0x01 != 0) throw StateError('plugin declares a 64-bit or shared table (not allowed)');
        final min = r.u32();
        final max = flags & 0x01 != 0 ? r.u32() : null;
        if (max != null && max < min) throw const FormatException('wasm table maximum is below its minimum');
        tables.add(_WasmLimits(min, max, refType: refType));
      }
      if (r.pos != end) throw const FormatException('bad wasm table section');
    }
    r.pos = end;
  }
  return (
    memories: memories,
    memorySection: (start: sectionStart, end: sectionEnd),
    tables: tables,
    tableSection: (start: tableStart, end: tableEnd),
  );
}

/// 初期の合計が [limit] 以下の宣言に、合計が [limit] を超えない最大を配る(宣言の順に残りを取る。宣言した最大が
/// それ以下ならそのまま)。初期の合計が超えていれば null。
List<int>? _capMaxima(List<_WasmLimits> decls, int limit) {
  final initial = decls.fold<int>(0, (s, d) => s + d.min);
  if (initial > limit) return null;
  var spare = limit - initial;
  final maxima = <int>[];
  for (final d in decls) {
    final want = (d.max ?? limit) - d.min;
    final give = want < spare ? want : spare;
    spare -= give;
    maxima.add(d.min + give);
  }
  return maxima;
}

/// [section] の節を、id [id]・中身 [body] の節に差し替える。節の大きさの LEB128 は書き直す
/// (ほかの節の中身は位置に依らないので、そのまま写す)。
Uint8List _replaceSection(Uint8List bytes, _WasmSection section, int id, List<int> body) => (BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(bytes, 0, section.start))
      ..addByte(id)
      ..add(_leb(body.length))
      ..add(body)
      ..add(Uint8List.sublistView(bytes, section.end)))
    .takeBytes();

/// モジュールが自分で定義するメモリの初期サイズ(バイト、最大のもの)。メモリ節が無ければ 0。形が壊れていれば
/// [FormatException](起動前に断る)。インポートするメモリ・共有メモリ・memory64 は [StateError] で断る。
int wasmDeclaredMemoryBytes(Uint8List bytes) {
  var maxBytes = 0;
  for (final m in _readWasmModule(bytes).memories) {
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
  final parsed = _readWasmModule(bytes);
  final limitPages = limit ~/ _wasmPageBytes;
  // 初期サイズの残りを、宣言の順に配る(1 つ目 = Rust の `memory` が先に取る)。合計は limitPages を超えない。
  final maxima = _capMaxima(parsed.memories, limitPages);
  if (maxima == null) {
    final initialPages = parsed.memories.fold<int>(0, (s, m) => s + m.min);
    throw StateError('plugin declares ${initialPages * _wasmPageBytes} bytes of memory (limit $limit)');
  }
  var changed = false;
  final body = <int>[..._leb(parsed.memories.length)];
  for (final (i, m) in parsed.memories.indexed) {
    if (maxima[i] != m.max) changed = true;
    body
      ..add(0x01)
      ..addAll(_leb(m.min))
      ..addAll(_leb(maxima[i]));
  }
  if (!changed) return bytes;
  return _replaceSection(bytes, parsed.memorySection, 5, body);
}

/// 起動の前のテーブルの検査と**上限の書き込み** (D-546、セキュリティ確認 2026-10-21 の #1)。
/// 前はテーブル節を読み飛ばしていたので、線形メモリを 256 MiB 以内に保ったまま、大きなテーブル(何本でも、最大なしなら
/// `table.grow` でブラウザの実装上限まで)をタブのヒープに確保できた(実行後の `checkMemory` は線形メモリしか見ない)。そこで:
/// - テーブルのインポート・table64・初期化式つき・funcref / externref 以外は断る([StateError]、[_readWasmModule])。
/// - 数が [maxTables] を超える、または初期の要素数の合計が [maxElements] を超えるなら断る([StateError])。
/// - **各テーブルの最大を書き込む**(合計が [maxElements] を超えないよう、宣言の順に残りを配る。宣言した最大がそれ以下なら
///   そのまま)。上限に当たった `table.grow` は -1 を返す(端末版の `StoreLimits` / 合計の ResourceLimiter と同じ上限)。
/// Rust の wasm32 のテーブルは初期 = 最大(伸びない)なので、ふつうは書き換えずに元のまま返る。
Uint8List capWasmTables(Uint8List bytes, {int maxTables = webWasmMaxTables, int maxElements = webWasmMaxTableElements}) {
  final parsed = _readWasmModule(bytes);
  if (parsed.tables.length > maxTables) {
    throw StateError('plugin declares ${parsed.tables.length} tables (limit $maxTables)');
  }
  final maxima = _capMaxima(parsed.tables, maxElements);
  if (maxima == null) {
    final initial = parsed.tables.fold<int>(0, (s, t) => s + t.min);
    throw StateError('plugin declares $initial table elements (limit $maxElements)');
  }
  var changed = false;
  final body = <int>[..._leb(parsed.tables.length)];
  for (final (i, t) in parsed.tables.indexed) {
    if (maxima[i] != t.max) changed = true;
    body
      ..add(t.refType)
      ..add(0x01)
      ..addAll(_leb(t.min))
      ..addAll(_leb(maxima[i]));
  }
  if (!changed) return bytes;
  return _replaceSection(bytes, parsed.tableSection, 4, body);
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
