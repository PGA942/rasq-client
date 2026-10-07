// D-407 (セキュリティ指摘 #10): Web 版ワーカーの期限とメモリの宣言。ブラウザの WebAssembly は fuel を数えないので、
// 終わらない start / snapshot / call は期限でワーカーごと止め、待っている要求をすべて失敗にする。
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';

List<int> leb(int v) {
  final out = <int>[];
  do {
    var b = v & 0x7f;
    v >>= 7;
    if (v != 0) b |= 0x80;
    out.add(b);
  } while (v != 0);
  return out;
}

/// 節を並べたモジュール。
Uint8List wasmModule(List<(int, List<int>)> sections) =>
    Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0, for (final (id, body) in sections) ...[id, ...leb(body.length), ...body]]);

/// メモリ 1 つ分の宣言(flags, 初期, 最大)。
List<int> memType(int pages, {int? max, int flags = 0}) => [flags | (max == null ? 0 : 1), ...leb(pages), if (max != null) ...leb(max)];

/// メモリ節(と、あれば後ろに custom 節)だけの最小モジュール。
Uint8List moduleWithMemories(List<List<int>> mems, {bool trailer = false}) => wasmModule([
      (5, [...leb(mems.length), for (final m in mems) ...m]),
      if (trailer) (0, [4, ...'name'.codeUnits, 1, 2, 3]),
    ]);

/// メモリ節だけの最小モジュール(初期 [pages] ページ、[max] があれば上限付き)。
Uint8List moduleWithMemory(int pages, {int? max}) => moduleWithMemories([memType(pages, max: max)]);

/// 書き換えた後のメモリの宣言 (初期, 最大) を読む(テスト用の素朴な読み手)。
List<(int, int?)> memoriesOf(Uint8List bytes) {
  var pos = 8;
  int u() {
    var r = 0, shift = 0;
    while (true) {
      final b = bytes[pos++];
      r |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return r;
      shift += 7;
    }
  }

  final out = <(int, int?)>[];
  while (pos < bytes.length) {
    final id = bytes[pos++];
    final size = u();
    final end = pos + size;
    if (id == 5) {
      final n = u();
      for (var i = 0; i < n; i++) {
        final flags = bytes[pos++];
        final min = u();
        out.add((min, flags & 1 != 0 ? u() : null));
      }
      expect(pos, end, reason: '節の大きさ (LEB128) と中身が合っている');
    }
    pos = end;
  }
  return out;
}

void main() {
  // 期限は本番 (webWasmInitTimeout / webWasmCallTimeout) より短くして、実時間で確かめる。
  const short = Duration(milliseconds: 40);
  group('WasmRequestTracker', () {
    test('終わらない起動(start が無限ループ)は期限でワーカーごと止まり、要求は失敗する', () async {
      final fatal = <Object>[];
      final t = WasmRequestTracker(onFatal: fatal.add);
      final sent = <int>[];
      final f = t.start('init', sent.add, timeout: short);
      expect(sent, [0]);
      expect(fatal, isEmpty);
      await expectLater(f, throwsA(isA<WasmWorkerTimeout>()));
      expect(fatal, hasLength(1), reason: '止める(terminate)のは 1 回');
      expect(t.stoppedBy, isA<WasmWorkerTimeout>());
    });

    test('終わらない call: 待っている要求(ほかの snapshot も)をすべて失敗にし、以後の要求は即失敗', () async {
      var fatal = 0;
      final t = WasmRequestTracker(onFatal: (_) => fatal++);
      final call = t.start('call', (_) {}, timeout: short);
      final snap = t.start('snapshot', (_) {}, timeout: const Duration(minutes: 5));
      await expectLater(call, throwsA(isA<WasmWorkerTimeout>()));
      await expectLater(snap, throwsA(isA<WasmWorkerTimeout>()));
      expect(t.pendingCount, 0);
      expect(fatal, 1);
      var sentLater = false;
      await expectLater(t.start('call', (_) => sentLater = true, timeout: short), throwsStateError);
      expect(sentLater, isFalse, reason: '止まったワーカーには送らない');
      // 後から届いた応答は無視される。
      t.complete(0, 'late');
      t.fail(StateError('again'));
      expect(fatal, 1);
    });

    test('期限内に返った要求はそのまま成功し、ワーカーは止まらない', () async {
      final t = WasmRequestTracker(onFatal: (_) => fail('止めない'));
      final r = await t.start('call', (id) => scheduleMicrotask(() => t.complete(id, 'ok')), timeout: short);
      expect(r, 'ok');
      await Future<void>.delayed(short * 2);
      expect(t.stoppedBy, isNull);
      expect(webWasmCallTimeout, greaterThan(Duration.zero));
      expect(webWasmInitTimeout, greaterThan(Duration.zero));
    });
  });

  group('wasmDeclaredMemoryBytes', () {
    test('宣言した初期メモリを読む / 上限を超える宣言は起動前に断る', () {
      expect(wasmDeclaredMemoryBytes(moduleWithMemory(17)), 17 * 65536);
      expect(wasmDeclaredMemoryBytes(moduleWithMemory(2, max: 100)), 2 * 65536);
      expect(wasmDeclaredMemoryBytes(Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0])), 0);
      expect(() => capWasmMemory(moduleWithMemory(4096)), returnsNormally); // 256 MiB ちょうど
      expect(() => capWasmMemory(moduleWithMemory(4097)), throwsStateError);
      expect(() => capWasmMemory(moduleWithMemory(65536)), throwsStateError);
      expect(() => wasmDeclaredMemoryBytes(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });

  // D-452 (Codex セキュリティ検査の指摘 resource-exhaustion.web-wasm-memory-growth): 実行後の検査より先に
  // memory.grow でブラウザのメモリを使い切らせないよう、起動前に各メモリの最大を上限内に書き込む。
  group('capWasmMemory', () {
    const limitPages = webWasmMaxMemoryBytes ~/ 65536; // 4096

    test('最大の無いメモリ(Rust の wasm32 の形)は、上限を最大として書き込む', () {
      final capped = capWasmMemory(moduleWithMemory(17));
      expect(memoriesOf(capped), [(17, limitPages)]);
      expect(wasmDeclaredMemoryBytes(capped), 17 * 65536, reason: '初期サイズは変えない');
    });

    test('上限を超える最大は上限に下げる / 上限以下の最大はそのまま(書き換えない)', () {
      expect(memoriesOf(capWasmMemory(moduleWithMemory(2, max: 65536))), [(2, limitPages)]);
      expect(memoriesOf(capWasmMemory(moduleWithMemory(2, max: 4097))), [(2, limitPages)]);
      final small = moduleWithMemory(2, max: 100);
      expect(identical(capWasmMemory(small), small), isTrue);
      final exact = moduleWithMemory(1, max: limitPages);
      expect(identical(capWasmMemory(exact), exact), isTrue);
      // 上限ちょうどの初期サイズ: 最大も初期と同じ(伸ばせない)。
      expect(memoriesOf(capWasmMemory(moduleWithMemory(limitPages))), [(limitPages, limitPages)]);
      // 上限を小さくしても同じ規則。
      expect(memoriesOf(capWasmMemory(moduleWithMemory(3), limit: 10 * 65536)), [(3, 10)]);
      expect(() => capWasmMemory(moduleWithMemory(11), limit: 10 * 65536), throwsStateError);
    });

    test('初期サイズが上限を超えるものは断る', () {
      expect(() => capWasmMemory(moduleWithMemory(limitPages + 1)), throwsStateError);
      expect(() => capWasmMemory(moduleWithMemory(limitPages + 1, max: limitPages + 1)), throwsStateError);
    });

    test('複数のメモリ(multi-memory): 1 つずつ見て、合計も上限に収める', () {
      // 初期の合計が上限を超える → 断る(1 つずつは上限以下でも)。
      expect(() => capWasmMemory(moduleWithMemories([memType(3000), memType(1100)])), throwsStateError);
      // 残りは宣言の順に配る: 1 つ目が残りを取り、2 つ目は初期のまま。
      final a = capWasmMemory(moduleWithMemories([memType(10), memType(20)]));
      expect(memoriesOf(a), [(10, limitPages - 20), (20, 20)]);
      // 1 つ目が小さな最大を宣言していれば、残りは 2 つ目へ。
      final b = capWasmMemory(moduleWithMemories([memType(10, max: 50), memType(20)]));
      expect(memoriesOf(b), [(10, 50), (20, limitPages - 50)]);
      for (final m in [a, b]) {
        final total = memoriesOf(m).fold<int>(0, (s, e) => s + e.$2!);
        expect(total, lessThanOrEqualTo(limitPages));
      }
    });

    test('インポートするメモリ・共有メモリ・memory64・custom page size は断る', () {
      // (import "env" "memory" (memory 1))
      final imported = wasmModule([
        (2, [1, 3, ...'env'.codeUnits, 6, ...'memory'.codeUnits, 0x02, 0x00, 1]),
      ]);
      expect(() => capWasmMemory(imported), throwsStateError);
      expect(() => capWasmMemory(moduleWithMemories([memType(1, max: 10, flags: 0x02)])), throwsStateError);
      expect(() => capWasmMemory(moduleWithMemories([memType(1, flags: 0x04)])), throwsStateError);
      expect(() => capWasmMemory(moduleWithMemories([memType(1, flags: 0x08)])), throwsStateError);
      // 関数・テーブル・グローバルのインポートは通す(メモリではない)。
      final otherImports = wasmModule([
        (1, [1, 0x60, 0, 0]), // type: () -> ()
        (2, [
          3,
          4, ...'rasq'.codeUnits, 7, ...'host_fn'.codeUnits, 0x00, 0, // func
          3, ...'env'.codeUnits, 1, ...'t'.codeUnits, 0x01, 0x70, 0x00, 1, // table funcref
          3, ...'env'.codeUnits, 1, ...'g'.codeUnits, 0x03, 0x7f, 0x00, // global i32
        ]),
        (5, [1, ...memType(17)]),
      ]);
      expect(memoriesOf(capWasmMemory(otherImports)), [(17, limitPages)]);
    });

    test('形の壊れたものは断る(最大 < 初期、メモリ節の重複、途中で切れた節)', () {
      expect(() => capWasmMemory(moduleWithMemory(10, max: 5)), throwsFormatException);
      final dup = wasmModule([(5, [1, ...memType(1)]), (5, [1, ...memType(1)])]);
      expect(() => capWasmMemory(dup), throwsFormatException);
      final truncated = moduleWithMemory(17);
      expect(() => capWasmMemory(Uint8List.sublistView(truncated, 0, truncated.length - 1)), throwsFormatException);
      expect(() => capWasmMemory(Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 2, 0, 0, 0])), throwsFormatException);
    });

    test('節の大きさの LEB128 が伸びても、後ろの節はそのまま写る', () {
      // 120 メモリ × 2 バイト + 1 = 241 バイト(LEB128 で 2 バイト)→ 最大を足すと伸びる。初期 0 ページで、
      // 1 つ目が残りの 4096 ページ(LEB128 で 2 バイト)を取る。
      final mems = [for (var i = 0; i < 120; i++) memType(0)];
      final src = moduleWithMemories(mems, trailer: true);
      expect(src[9], greaterThan(0x7f), reason: '元の節の大きさは 2 バイトの LEB128');
      final capped = capWasmMemory(src);
      final decl = memoriesOf(capped);
      expect(decl, hasLength(120));
      expect(decl.first, (0, limitPages));
      expect(decl.skip(1).every((m) => m == (0, 0)), isTrue);
      // 後ろの custom 節が崩れていない。
      final tail = [0, 8, 4, ...'name'.codeUnits, 1, 2, 3];
      expect(capped.sublist(capped.length - tail.length), tail);
      // 1 バイトの LEB128 → 2 バイトに伸びる場合(初期 1 + 最大 4096 = 1 + 1 + 2 バイト)。
      final one = [for (var i = 0; i < 60; i++) memType(0)];
      final s2 = moduleWithMemories(one);
      expect(s2[9], lessThan(0x80));
      expect(memoriesOf(capWasmMemory(s2)).first, (0, limitPages));
    });

    // 同梱のプラグイン(Rust の wasm32 で作ったもの)は最大を宣言しないので、書き換えて通す。
    // 書き換えた後も正しい wasm であることを、端末版のランタイム(wasmi)で読み込んで確かめる。
    final bundled = Directory('../../assets/plugins');
    final files = bundled.existsSync() ? (bundled.listSync().whereType<File>().where((f) => f.path.endsWith('.wasm')).toList()..sort((a, b) => a.path.compareTo(b.path))) : <File>[];
    test('同梱のプラグインは書き換えて通り、書き換えた後も正しい wasm', () {
      expect(files, isNotEmpty, reason: 'assets/plugins/*.wasm');
      for (final f in files) {
        final src = Uint8List.fromList(f.readAsBytesSync());
        final capped = capWasmMemory(src);
        final decl = memoriesOf(capped);
        expect(decl, hasLength(1), reason: f.path);
        expect(decl.single.$2, limitPages, reason: '${f.path}: 最大 = 上限');
        expect(memoriesOf(src).single.$2, isNull, reason: '${f.path}: 元は最大を宣言していない');
        expect(wasmDeclaredMemoryBytes(capped), wasmDeclaredMemoryBytes(src));
        expect(identical(capWasmMemory(capped), capped), isTrue, reason: '2 回目は書き換えない');
        final plugin = RasqWasmPlugin.fromBytes(capped);
        plugin.dispose();
      }
    }, skip: files.isEmpty ? 'assets/plugins/*.wasm がありません' : false);
  });
}
