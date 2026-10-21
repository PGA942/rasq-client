import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'relay_module.dart';

/// `storage.set` の予算 (D-546、セキュリティ確認 2026-10-21 の #2) を、ワーカーを通して確かめる。端末版 (isolate + wasmi、
/// `test/storage_quota_test.dart`) と Web 版 (Web Worker + ブラウザの WebAssembly、`test/web/wasm_web_storage_quota_test.dart`)
/// で同じ確かめ方をする。ゲストは要求をそのまま host_fn に渡すだけ (relayModule) なので、小さな同じバッファを使い回して
/// 別のキーへ書き続ける、指摘どおりの形になる。
void storageQuotaWorkerCases() {
  const maxKeys = PluginStorageQuota.defaultMaxKeys;
  const maxValue = PluginStorageQuota.defaultMaxValueBytes;
  const maxTotal = PluginStorageQuota.defaultMaxTotalBytes;

  late WasmPluginWorker worker;
  late List<Map<String, Object?>> writes;
  StreamSubscription<Map<String, Object?>>? sub;

  Future<void> spawn(Set<String> permissions, {Map<String, Object?> seed = const {}}) async {
    worker = await WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: relayModule, permissions: permissions, seedStorage: seed));
    writes = [];
    sub = worker.storageWrites.listen(writes.add);
  }

  tearDown(() async {
    await sub?.cancel();
    sub = null;
    await worker.dispose();
  });

  Future<Map<String, Object?>> host(String fn, Map<String, Object?> args) async {
    final request = jsonEncode({'fn': fn, 'callId': 'c1', 'args': args});
    return (jsonDecode(await worker.call(fn: 'x', argsJson: request, callId: 'c1')) as Map).cast<String, Object?>();
  }

  Future<Map<String, Object?>> set(String key, Object? value, {String ns = 'safe'}) => host('storage.set', {'ns': ns, 'key': key, 'value': value});

  /// 写し (storageWrites) は応答より先に送られている。届くのを 1 巡だけ待つ。
  Future<int> writesSoFar() async {
    await Future<void>.delayed(Duration.zero);
    return writes.length;
  }

  for (final (label, permissions) in [
    ('制限モード (storage.safe だけ)', {RasqPermissions.storageSafe}),
    ('全権 (storage.safe + storage.unsafe)', {RasqPermissions.storageSafe, RasqPermissions.storageUnsafe}),
  ]) {
    test('$label: 別のキーへ書き続けると、キー数の上限で E02 になり、断った書き込みは保存も写しもしない', () async {
      await spawn(permissions);
      for (var i = 0; i < maxKeys; i++) {
        final r = await set('k$i', i);
        expect(r['ok'], isTrue, reason: 'k$i: $r');
      }
      expect(await writesSoFar(), maxKeys);
      final r = await set('one-more', 1);
      expect(r['ok'], isFalse);
      expect(r['error'], {'code': 'E02', 'message': 'storage key count exceeds $maxKeys'});
      expect(await writesSoFar(), maxKeys, reason: '断った書き込みは写しを出さない');
      expect((await host('storage.get', {'ns': 'safe', 'key': 'one-more'}))['value'], {'value': null});
      // 上書きは数を増やさないので通る。消せば 1 つ空く。
      expect((await set('k0', 'again'))['ok'], isTrue);
      expect((await host('storage.delete', {'ns': 'safe', 'key': 'k1'}))['ok'], isTrue);
      expect((await set('one-more', 1))['ok'], isTrue);
      expect((await set('two-more', 1))['error'], {'code': 'E02', 'message': 'storage key count exceeds $maxKeys'});
    });

    test('$label: 大きな値を別のキーへ書き続けると、合計の上限の手前で断る / 上書き・削除で戻る', () async {
      await spawn(permissions);
      final big = 'x' * (maxValue - 100); // JSON にして 1 MiB の少し手前
      var accepted = 0;
      while ((await set('big$accepted', big))['ok'] == true) {
        accepted++;
        expect(accepted, lessThanOrEqualTo(4), reason: '合計の上限を超えて溜められない');
      }
      expect(accepted, 4, reason: '1 MiB 近い値は合計 4 MiB に 4 つまで');
      final r = await set('big$accepted', big);
      expect(r['error'], {'code': 'E02', 'message': 'storage exceeds $maxTotal bytes in total'});
      expect(await writesSoFar(), accepted, reason: '断った書き込みは写しを出さない');
      // 上書きで小さくすれば、その差だけ空く。
      expect((await set('big0', 'small'))['ok'], isTrue);
      expect((await set('big$accepted', big))['ok'], isTrue);
      expect((await set('big${accepted + 1}', big))['ok'], isFalse);
      // 消せば丸ごと空く。
      expect((await host('storage.delete', {'ns': 'safe', 'key': 'big1'}))['ok'], isTrue);
      expect((await set('big${accepted + 1}', big))['ok'], isTrue);
    });

    test('$label: 1 つの値の大きさ・キーの長さの上限', () async {
      await spawn(permissions);
      final r = await set('v', 'x' * maxValue); // JSON の引用符 2 バイトで超える
      expect(r['error'], {'code': 'E02', 'message': 'storage value exceeds $maxValue bytes'});
      expect((await set('v', 'x' * (maxValue - 2)))['ok'], isTrue, reason: 'ちょうど上限');
      const maxKey = PluginStorageQuota.defaultMaxKeyBytes;
      expect((await set('k' * (maxKey + 1), 1))['error'], {'code': 'E02', 'message': 'storage key exceeds $maxKey bytes'});
      expect((await set('k' * maxKey, 1))['ok'], isTrue);
      expect(await writesSoFar(), 2);
    });
  }

  test('safe と unsafe は 1 つの予算を分け合う / 最初に渡された値も数に入る', () async {
    final seed = {for (var i = 0; i < maxKeys - 2; i++) 'safe:s$i': i};
    await spawn({RasqPermissions.storageSafe, RasqPermissions.storageUnsafe}, seed: seed);
    expect((await set('a', 1, ns: 'unsafe'))['ok'], isTrue);
    expect((await set('b', 1))['ok'], isTrue);
    expect((await set('c', 1, ns: 'unsafe'))['error'], {'code': 'E02', 'message': 'storage key count exceeds $maxKeys'});
    expect((await set('s0', 'overwrite'))['ok'], isTrue, reason: '最初に渡された値の上書きは数を増やさない');
  });
}
