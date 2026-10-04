import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// D-422: プラグインが取り直したトークン(Bluesky の `{accessJwt, refreshJwt}`)を、ホストのセッションへ戻す。
void main() {
  group('storage の写し (RasqHostEnvironment.onStorageWrite)', () {
    test('storage.set / storage.delete をホストへ写す(名前空間・キー・値)', () {
      final writes = <(String, String, Object?)>[];
      final env = RasqHostEnvironment(permissions: const {'storage.safe'}, onStorageWrite: (ns, key, value) => writes.add((ns, key, value)));
      String call(String fn, Map<String, Object?> args) => env.dispatch(jsonEncode({'callId': 'c', 'fn': fn, 'args': args}));
      call('storage.set', {'ns': 'safe', 'key': 'session:did:plc:abc', 'value': {'accessJwt': 'a2', 'refreshJwt': 'r2'}});
      call('storage.delete', {'key': 'x'});
      expect([for (final w in writes) (w.$1, w.$2)], [('safe', 'session:did:plc:abc'), ('safe', 'x')]);
      expect(writes.first.$3, {'accessJwt': 'a2', 'refreshJwt': 'r2'});
      expect(writes.last.$3, isNull);
    });

    test('権限の無い書き込みは写さない', () {
      final writes = <String>[];
      final env = RasqHostEnvironment(onStorageWrite: (ns, key, value) => writes.add(key));
      final res = jsonDecode(env.dispatch(jsonEncode({'callId': 'c', 'fn': 'storage.set', 'args': {'key': 'k', 'value': 1}}))) as Map;
      expect(res['ok'], isFalse);
      expect(writes, isEmpty);
    });
  });

  group('WasmSnsPlugin.refreshedToken', () {
    final token = jsonEncode({'did': 'did:plc:abc', 'handle': 'alice.bsky.social', 'accessJwt': 'a1', 'refreshJwt': 'r1'});
    Map<String, Object?> write(String key, Object? value, {String ns = 'safe'}) => {'ns': ns, 'key': key, 'value': value};

    test('同じ did の取り直し → 組だけを差し替えたトークン', () {
      final next = WasmSnsPlugin.refreshedToken(token, write('session:did:plc:abc', {'accessJwt': 'a2', 'refreshJwt': 'r2'}));
      expect(jsonDecode(next!), {'did': 'did:plc:abc', 'handle': 'alice.bsky.social', 'accessJwt': 'a2', 'refreshJwt': 'r2'});
    });

    test('ほかの did / ほかのキー / 名前空間 / 形 / 変わらない → null', () {
      expect(WasmSnsPlugin.refreshedToken(token, write('session:did:plc:other', {'accessJwt': 'a2', 'refreshJwt': 'r2'})), isNull);
      expect(WasmSnsPlugin.refreshedToken(token, write('cursor', {'accessJwt': 'a2'})), isNull);
      expect(WasmSnsPlugin.refreshedToken(token, write('session:did:plc:abc', {'accessJwt': 'a2'}, ns: 'unsafe')), isNull);
      expect(WasmSnsPlugin.refreshedToken(token, write('session:did:plc:abc', 'not a map')), isNull);
      expect(WasmSnsPlugin.refreshedToken(token, write('session:did:plc:abc', null)), isNull);
      expect(WasmSnsPlugin.refreshedToken(token, write('session:did:plc:abc', {'accessJwt': 'a1', 'refreshJwt': 'r1'})), isNull);
      expect(WasmSnsPlugin.refreshedToken('plain-token', write('session:did:plc:abc', {'accessJwt': 'a2'})), isNull, reason: 'JSON でないトークン(Misskey など)は触らない');
    });
  });
}
