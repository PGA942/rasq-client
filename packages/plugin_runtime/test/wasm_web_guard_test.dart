// D-407 (セキュリティ指摘 #10): Web 版ワーカーの期限とメモリの宣言。ブラウザの WebAssembly は fuel を数えないので、
// 終わらない start / snapshot / call は期限でワーカーごと止め、待っている要求をすべて失敗にする。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// メモリ節だけの最小モジュール(初期 [pages] ページ、[max] があれば上限付き)。
Uint8List moduleWithMemory(int pages, {int? max}) {
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

  final body = [1, if (max == null) 0x00 else 0x01, ...leb(pages), if (max != null) ...leb(max)];
  return Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0, 5, ...leb(body.length), ...body]);
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
      expect(() => checkWasmMemoryDeclaration(moduleWithMemory(4096)), returnsNormally); // 256 MiB ちょうど
      expect(() => checkWasmMemoryDeclaration(moduleWithMemory(4097)), throwsStateError);
      expect(() => checkWasmMemoryDeclaration(moduleWithMemory(65536)), throwsStateError);
      expect(() => wasmDeclaredMemoryBytes(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });
}
