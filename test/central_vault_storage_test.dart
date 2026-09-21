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
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// Web 版の保存先 (D-300): SNS のログイン情報は Central の保管庫へ。ブラウザ(local)には RASQ のトークンなどだけ。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  ({ProviderContainer c, Map<String, String> vault, MemorySessionStorage local}) setUpWith({required bool loggedIn, Map<String, String> localSeed = const {}, Map<String, String>? sharedVault}) {
    final vault = sharedVault ?? <String, String>{};
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
      sessionStorageProvider.overrideWith((ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero)),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
    ]);
    addTearDown(c.dispose);
    return (c: c, vault: vault, local: local);
  }

  const key = SessionsNotifier.storageKey;
  AccountSession session(String handle, {String token = 't'}) =>
      AccountSession(account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: handle), pluginId: 'test.fake', token: token, createdAt: DateTime(2026, 8, 22), displayName: handle);
  String list(List<AccountSession> l) => jsonEncode({'sessions': [for (final s in l) s.toJson()], 'current': l.firstOrNull?.account.key});
  List<String> handles(String? raw) => raw == null ? [] : [for (final s in (jsonDecode(raw) as Map)['sessions'] as List) (s as Map)['handle'] as String];

  test('ログイン中: SNS のセッションは保管庫へ(操作の台帳として)。ブラウザには置かない。ほかのキーはブラウザに置く', () async {
    final t = setUpWith(loggedIn: true);
    final s = t.c.read(sessionStorageProvider);
    await s.write(key, list([session('a')]));
    await s.write('other.key', 'v');
    final doc = jsonDecode(t.vault[key]!) as Map;
    expect(doc['v'], 2);
    expect((doc['ops'] as Map).values.single['op'], 'login');
    expect(t.local.keys, isNot(contains(key)));
    expect(await t.local.read('other.key'), 'v');
    expect(handles(await s.read(key)), ['a']);
    // 全部消す = 「ログアウトした」という操作として残る(保管庫ごとは消さない)。
    await s.delete(key);
    expect(((jsonDecode(t.vault[key]!) as Map)['ops'] as Map).values.single['op'], 'logout');
    expect(handles(await s.read(key)), isEmpty);
  });

  test('2 つの端末: 互いのログインを消さない。ログアウトは、古い一覧を持った端末の保存では生き返らない (D-302)', () async {
    final vault = <String, String>{};
    final a = setUpWith(loggedIn: true, sharedVault: vault).c.read(sessionStorageProvider);
    final b = setUpWith(loggedIn: true, sharedVault: vault).c.read(sessionStorageProvider);
    expect(handles(await a.read(key)), isEmpty);
    expect(handles(await b.read(key)), isEmpty);
    // A で x に、B で y にログイン(B は x を知らないまま保存する)。
    await a.write(key, list([session('x')]));
    await b.write(key, list([session('y')]));
    expect(handles(await a.read(key)), ['x', 'y']);
    // B は x を知らないので、x をログアウトした扱いにはしていない。読み直すと x も見える。
    expect(handles(await b.read(key)), ['x', 'y']);
    // B で x をログアウト。A は古い一覧(x, y)のまま z にログインして保存する → x は生き返らない。
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.write(key, list([session('y')]));
    await a.write(key, list([session('x'), session('y'), session('z')]));
    expect(handles(await a.read(key)), ['y', 'z']);
    expect(handles(await b.read(key)), ['y', 'z']);
    // ログアウトのあとで、もう一度ログインすれば戻る(新しい操作が勝つ)。
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.write(key, list([session('y'), session('z'), session('x', token: 'new')]));
    expect(handles(await a.read(key)), ['y', 'z', 'x']);
  });

  test('前の版の中身(一覧そのまま)が保管庫 / ブラウザにあれば、台帳に直して引き継ぎ、ブラウザからは消す', () async {
    final t = setUpWith(loggedIn: true, localSeed: {key: list([session('old')])});
    final s = t.c.read(sessionStorageProvider);
    expect(handles(await s.read(key)), ['old']);
    expect((jsonDecode(t.vault[key]!) as Map)['v'], 2);
    expect(t.local.keys, isNot(contains(key)));
    // 保管庫に前の版の形で入っていた場合も読める。
    final t2 = setUpWith(loggedIn: true, sharedVault: {key: list([session('v1')])});
    expect(handles(await t2.c.read(sessionStorageProvider).read(key)), ['v1']);
  });

  test('RASQ アカウントにログインしていない間は、メモリにだけ持つ(保管庫にもブラウザにも書かない)', () async {
    final t = setUpWith(loggedIn: false);
    final s = t.c.read(sessionStorageProvider);
    await s.write(key, list([session('a')]));
    expect(t.vault, isEmpty);
    expect(t.local.keys, isNot(contains(key)));
    expect(handles(await s.read(key)), ['a']);
  });

  test('操作の台帳: 古いログアウトの記録は捨てる / 中身が同じなら操作を起こさない', () {
    final t0 = DateTime.utc(2026, 1, 1);
    final ops = SessionOps().applying(list([session('a'), session('b')]), at: t0).applying(list([session('a')]), at: t0.add(const Duration(days: 1)));
    expect(ops.loggedInKeys.length, 1);
    expect(ops.ops.length, 2);
    expect(ops.applying(list([session('a')]), at: t0.add(const Duration(days: 2))).ops.values.map((o) => o.at).toSet(), {t0, t0.add(const Duration(days: 1))});
    expect(ops.pruned(t0.add(const Duration(days: 40))).ops.length, 1);
  });
}
