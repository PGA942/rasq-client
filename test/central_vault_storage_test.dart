import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/session/central_vault_storage.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';

/// Web 版の保存先 (D-300): SNS のログイン情報は Central の保管庫へ。ブラウザ(local)には RASQ のトークンなどだけ。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  ({ProviderContainer c, Map<String, String> vault, MemorySessionStorage local}) setUpWith({required bool loggedIn, Map<String, String> localSeed = const {}}) {
    final vault = <String, String>{};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (path == '/me' && req.method == 'GET') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (path.startsWith('/me/vault/')) {
        if (req.headers['authorization'] != 'Bearer device-token') return json({'error': {'code': '401', 'message': 'no'}}, 401);
        final name = path.substring('/me/vault/'.length);
        if (req.method == 'GET') return vault[name] == null ? json({'error': {'code': '404', 'message': 'nothing'}}, 404) : json({'value': vault[name]});
        if (req.method == 'PUT') {
          vault[name] = (jsonDecode(req.body) as Map)['value'] as String;
          return http.Response('', 204);
        }
        if (req.method == 'DELETE') {
          vault.remove(name);
          return http.Response('', 204);
        }
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final local = MemorySessionStorage({
      ...localSeed,
      if (loggedIn) OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWith((ref) => CentralVaultSessionStorage(ref, local)),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
    ]);
    addTearDown(c.dispose);
    return (c: c, vault: vault, local: local);
  }

  test('ログイン中: SNS のセッションは保管庫へ。ブラウザには置かない。ほかのキーはブラウザに置く', () async {
    final t = setUpWith(loggedIn: true);
    final s = t.c.read(sessionStorageProvider);
    await s.write(SessionsNotifier.storageKey, '{"sessions":["tok"]}');
    await s.write('other.key', 'v');
    expect(t.vault[SessionsNotifier.storageKey], '{"sessions":["tok"]}');
    expect(t.local.keys, isNot(contains(SessionsNotifier.storageKey)));
    expect(await t.local.read('other.key'), 'v');
    expect(await s.read(SessionsNotifier.storageKey), '{"sessions":["tok"]}');
    await s.delete(SessionsNotifier.storageKey);
    expect(t.vault, isEmpty);
  });

  test('前の版がブラウザに置いていたぶんは、保管庫へ移してブラウザから消す', () async {
    final t = setUpWith(loggedIn: true, localSeed: {SessionsNotifier.storageKey: '{"sessions":["old"]}'});
    final s = t.c.read(sessionStorageProvider);
    expect(await s.read(SessionsNotifier.storageKey), '{"sessions":["old"]}');
    expect(t.vault[SessionsNotifier.storageKey], '{"sessions":["old"]}');
    expect(t.local.keys, isNot(contains(SessionsNotifier.storageKey)));
  });

  test('RASQ アカウントにログインしていない間は、メモリにだけ持つ(保管庫にもブラウザにも書かない)', () async {
    final t = setUpWith(loggedIn: false);
    final s = t.c.read(sessionStorageProvider);
    await s.write(SessionsNotifier.storageKey, '{"sessions":["tok"]}');
    expect(t.vault, isEmpty);
    expect(t.local.keys, isNot(contains(SessionsNotifier.storageKey)));
    expect(await s.read(SessionsNotifier.storageKey), '{"sessions":["tok"]}');
  });
}
