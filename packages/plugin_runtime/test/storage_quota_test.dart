// D-546 (セキュリティ確認 2026-10-21 の #2、csf_2e9abe156286029a2ec69d3b): storage.set のキー数・キーの長さ・値の大きさ・
// 合計の予算。前は名前空間の権限しか見ず、制限モード (storage.safe) のプラグインでも別のキーへ書き続けてホストのメモリを増やせた。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'web/storage_quota_cases.dart';

Map<String, dynamic> call(RasqHostEnvironment env, String fn, Map<String, Object?> args) =>
    jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': 'c', 'fn': fn, 'args': args}))) as Map<String, dynamic>;

/// 断られたときの誤りの符号(通れば null)。
String? code(Map<String, dynamic> r) => (r['error'] as Map?)?['code'] as String?;

void main() {
  group('RasqHostEnvironment の storage.set の予算(小さな上限で)', () {
    late List<(String, String, Object?)> writes;

    RasqHostEnvironment env({Set<String> permissions = const {RasqPermissions.storageSafe}, Map<String, Object?>? storage}) {
      writes = [];
      return RasqHostEnvironment(
        permissions: permissions,
        storage: storage,
        onStorageWrite: (ns, key, value) => writes.add((ns, key, value)),
        storageQuota: PluginStorageQuota(maxKeys: 3, maxKeyBytes: 8, maxValueBytes: 20, maxTotalBytes: 60),
      );
    }

    Map<String, dynamic> set(RasqHostEnvironment e, String key, Object? value, {String ns = 'safe'}) => call(e, 'storage.set', {'ns': ns, 'key': key, 'value': value});

    test('既定の上限', () {
      final q = PluginStorageQuota();
      expect((q.maxKeys, q.maxKeyBytes, q.maxValueBytes, q.maxTotalBytes), (1024, 512, 1024 * 1024, 4 * 1024 * 1024));
      expect(RasqHostEnvironment().storageQuota.maxTotalBytes, 4 * 1024 * 1024);
    });

    test('別のキーへの書き込みは、上限を超える前に E02 で断り、保存も写しもしない', () {
      final e = env();
      for (var i = 0; i < 3; i++) {
        expect(set(e, 'k$i', i)['ok'], isTrue);
      }
      final r = set(e, 'k3', 3);
      expect(r['ok'], isFalse);
      expect(r['error'], {'code': 'E02', 'message': 'storage key count exceeds 3'});
      expect(e.storage.keys, ['safe:k0', 'safe:k1', 'safe:k2']);
      expect(writes, hasLength(3), reason: '断った書き込みは写しを出さない');
      expect(e.storageQuota.keyCount, 3);
    });

    test('合計の上限: 超える書き込みは断り、上書きは差分、削除は丸ごと返す', () {
      final e = env();
      // 1 つ = "safe:a"(6) + "\"xxxxxxxxxxxx\""(14) = 20 バイト。3 つで 60 = ちょうど上限。
      final v = 'x' * 12;
      expect(set(e, 'a', v)['ok'], isTrue);
      expect(set(e, 'b', v)['ok'], isTrue);
      expect(e.storageQuota.totalBytes, 40);
      expect(set(e, 'cc', v)['error'], {'code': 'E02', 'message': 'storage exceeds 60 bytes in total'}, reason: '61 バイトになる');
      expect(e.storage.containsKey('safe:cc'), isFalse);
      expect(set(e, 'c', v)['ok'], isTrue);
      expect(e.storageQuota.totalBytes, 60);
      // 上書きで大きくするのは断る。前の値はそのまま。
      expect(code(set(e, 'a', '${v}x')), 'E02');
      expect(e.storage['safe:a'], v);
      // 上書きで小さくすれば、その差だけ空く。
      expect(set(e, 'a', 1)['ok'], isTrue);
      expect(e.storageQuota.totalBytes, 60 - 20 + 7);
      expect(set(e, 'b', '${v}xxxx')['ok'], isTrue);
      // 削除は丸ごと返す(キーの数も)。
      expect(call(e, 'storage.delete', {'ns': 'safe', 'key': 'c'})['ok'], isTrue);
      expect(e.storageQuota.keyCount, 2);
      expect(e.storageQuota.totalBytes, 7 + 24);
      expect(set(e, 'd', v)['ok'], isTrue);
      // 無いキーの削除は何も減らさない。
      call(e, 'storage.delete', {'ns': 'safe', 'key': 'nope'});
      expect(e.storageQuota.totalBytes, 7 + 24 + 20);
      expect(writes.where((w) => w.$3 != null).length, 6, reason: '写しは通った書き込みのぶんだけ');
    });

    test('値 1 つの大きさ・キーの長さの上限', () {
      final e = env();
      expect(set(e, 'a', 'x' * 19)['error'], {'code': 'E02', 'message': 'storage value exceeds 20 bytes'});
      expect(set(e, 'a', 'x' * 18)['ok'], isTrue);
      expect(code(set(e, 'a', {'k': 'x' * 20})), 'E02', reason: '入れ子の値も JSON の大きさで数える');
      expect(set(e, '123456789', 1)['error'], {'code': 'E02', 'message': 'storage key exceeds 8 bytes'});
      expect(code(set(e, 'ありがと', 1)), 'E02', reason: 'キーは UTF-8 のバイトで数える(12 バイト)');
      expect(set(e, '12345678', 1)['ok'], isTrue);
      expect(writes, hasLength(2));
    });

    test('制限モード (storage.safe だけ) も全権と同じ予算 / safe と unsafe で 1 つの予算を分け合う', () {
      List<bool> fill(RasqHostEnvironment e, List<String> nss) => [for (final (i, ns) in nss.indexed) set(e, 'k$i', i, ns: ns)['ok'] == true];
      final restricted = env();
      expect(fill(restricted, ['safe', 'safe', 'safe', 'safe']), [true, true, true, false]);
      final full = env(permissions: {RasqPermissions.storageSafe, RasqPermissions.storageUnsafe});
      expect(fill(full, ['safe', 'unsafe', 'safe', 'unsafe']), [true, true, true, false]);
      expect(full.storageQuota.keyCount, 3);
    });

    test('最初に渡された値も数に入る(それ自体は断らない。超えていれば、減らす上書きだけ通る)', () {
      final e = env(storage: {'safe:a': 'x' * 30, 'safe:b': 'x' * 30});
      expect(e.storageQuota.totalBytes, 2 * (6 + 32));
      expect(code(set(e, 'c', 1)), 'E02');
      expect(set(e, 'a', 'x' * 18)['ok'], isTrue, reason: '減らす上書き(合計はまだ上限を超えている)');
      expect(set(e, 'a', 'x' * 18)['ok'], isTrue, reason: '同じ大きさの上書き');
      expect(code(set(e, 'a', 'x' * 19)), 'E02', reason: '値の上限');
    });
  });

  group('端末版のワーカー (isolate + wasmi)', storageQuotaWorkerCases);
}
