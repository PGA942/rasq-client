import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/session/central_vault_storage.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_design/rasq_design.dart' show RasqUserRow;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-316: 1 台の端末に、2 つの RASQ(Central)アカウント。
///
/// 前は端末に Central のトークンが 1 本だけで、2 つ目のアカウントにログインすると、名前は新しいアカウントなのに
/// 中身(バンドル / 保管庫 / SNS / Central への問い合わせ)は前のアカウントのまま、になっていた。
/// いまは**アカウントごとにトークン**を持ち、台帳の「いま」でどれを使うかが決まる。
void main() {
  const snsA = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice_sns');
  const snsB = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob_sns');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't-${a.handle}', createdAt: DateTime(2026, 9, 1), displayName: a.handle);
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  /// 2 つのアカウントを持つ偽の Central。トークンでアカウントを見分け、リクエストごとに Authorization を記録する。
  ({MockClient client, List<({String method, String path, String? auth})> seen, Map<String, Set<String>> bundles, Map<String, Map<String, String>> vaults}) fakeCentral({Map<String, Set<String>>? bundles, FutureOr<http.Response?> Function(http.Request req)? intercept}) {
    const accounts = {
      'tok-a': {'id': 'acc-a', 'handle': 'alice', 'displayName': 'アリス'},
      'tok-b': {'id': 'acc-b', 'handle': 'bob', 'displayName': 'ボブ'},
    };
    final seen = <({String method, String path, String? auth})>[];
    final bundle = bundles ?? {'acc-a': <String>{}, 'acc-b': <String>{}};
    final vaults = {'acc-a': <String, String>{}, 'acc-b': <String, String>{}};
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final auth = req.headers['authorization'];
      seen.add((method: req.method, path: path, auth: auth));
      final intercepted = await intercept?.call(req);
      if (intercepted != null) return intercepted;
      final me = accounts[auth?.replaceFirst('Bearer ', '')];
      if (me == null) return json({'error': {'code': '401', 'message': 'no token'}}, 401);
      final id = me['id']!;
      if (path == '/me' && req.method == 'GET') return json(me);
      if (path == '/me/sns-accounts' && req.method == 'GET') {
        return json([
          for (final k in bundle[id]!) {'accountKey': k, 'kind': k.split(':')[0], 'instance': k.split(':')[1], 'handle': k.split(':')[2]},
        ]);
      }
      if (path == '/me/sns-accounts' && req.method == 'PUT') {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        bundle[id]!.add('${b['kind']}:${b['instance']}:${b['handle']}');
        return json({'ok': true});
      }
      if (path.startsWith('/me/sns-accounts/') && req.method == 'DELETE') {
        bundle[id]!.remove(Uri.decodeComponent(path.substring('/me/sns-accounts/'.length)));
        return http.Response('', 204);
      }
      if (path.startsWith('/me/vault/')) {
        final name = path.substring('/me/vault/'.length);
        if (req.method == 'GET') return vaults[id]![name] == null ? json({'error': {'code': '404', 'message': 'nothing'}}, 404) : json({'value': vaults[id]![name]});
        if (req.method == 'PUT') {
          vaults[id]![name] = (jsonDecode(req.body) as Map)['value'] as String;
          return http.Response('', 204);
        }
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    return (client: client, seen: seen, bundles: bundle, vaults: vaults);
  }

  ProviderContainer containerWith(MockClient mock, SessionStorage storage, {SessionStorage Function(Ref ref)? storageFor}) {
    final c = ProviderContainer(overrides: [
      if (storageFor != null) sessionStorageProvider.overrideWith(storageFor) else sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Map<String, Object?>> stored(SessionStorage s) async => (jsonDecode((await s.read(OrgateAccountNotifier.storageKey))!) as Map).cast<String, Object?>();

  group('2 つの Central のアカウント (D-316)', () {
    test('2 つ目にログインしても、前のアカウントの SNS を持ち込まない。名前 / トークン / SNS / バンドルがアカウントごとに分かれ、切り替えで全部そろって変わる', () async {
      final central = fakeCentral(bundles: {'acc-a': {snsA.key}, 'acc-b': <String>{}});
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [session(snsA).toJson()], 'current': snsA.key}),
      });
      final c = containerWith(central.client, storage);
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      final accounts = c.read(orgateAccountProvider.notifier);

      // A にログイン: A のバンドルにあって、この端末にもログインがある SNS は、そのまま A に入る。
      final a = await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      expect(a!.handle, 'alice');
      await settle();
      expect(c.read(rasqAccountsProvider).value!.current!.id, 'central-acc-a');
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
      expect(c.read(rasqAccountProvider).displayName, 'アリス');

      // B にログイン: A の SNS は持ち込まない(前はここで A のセッションを引き継ぎ、名前だけ B になっていた)。
      final b = await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
      expect(b!.handle, 'bob');
      await settle();
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.current!.id, 'central-acc-b');
      expect(ledger.centralRecord('acc-b')!.sessionKeys, isEmpty);
      expect(ledger.centralRecord('acc-b')!.pruneBundle, isFalse, reason: '既存のアカウントのバンドルは、この端末に無いぶんを消さない');
      expect(ledger.centralRecord('acc-a')!.sessionKeys, [snsA.key]);
      expect((await c.read(sessionsProvider.future)).sessions, isEmpty);
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
      expect(c.read(rasqAccountProvider).displayName, 'ボブ');
      expect(c.read(orgateTokenHolderProvider).token, 'tok-b');
      central.seen.clear();

      // B で SNS にログイン → B のバンドルへ、B のトークンで送る。A のバンドルには入らない。
      await c.read(sessionsProvider.notifier).add(AuthResult(session: session(snsB), me: UserSummary(id: 'u', account: snsB, displayName: 'bob_sns')));
      await settle();
      expect(central.bundles['acc-b'], {snsB.key});
      expect(central.bundles['acc-a'], {snsA.key});
      final puts = central.seen.where((r) => r.method == 'PUT' && r.path == '/me/sns-accounts');
      expect(puts, isNotEmpty);
      expect(puts.map((r) => r.auth).toSet(), {'Bearer tok-b'}, reason: 'B でログインした SNS は、B のトークンでだけ送る');

      // A へ切り替え: トークン / 名前 / 見える SNS が、そろって A に戻る。
      await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');
      expect(c.read(orgateTokenHolderProvider).token, 'tok-a');
      expect(c.read(rasqAccountProvider).displayName, 'アリス');
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
      expect(c.read(currentCentralHandleProvider), 'alice');
      central.seen.clear();
      await c.read(centralClientProvider)!.getJson('/me');
      expect(central.seen.single.auth, 'Bearer tok-a');

      // B へ戻す。
      await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
      central.seen.clear();
      await c.read(centralClientProvider)!.getJson('/me');
      expect(central.seen.single.auth, 'Bearer tok-b');
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsB]);

      // 保存の形: アカウントごとのトークン。
      final s = await stored(storage);
      expect(s['tokens'], {'acc-a': 'tok-a', 'acc-b': 'tok-b'});
      expect(s['currentAccountId'], 'acc-b');
    });

    test('「この端末のみ」を選んでいるあいだは、どの Central のアカウントのトークンも使わない(ローカルの SNS を Central のバンドルへ写さない)', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [session(snsA).toJson()], 'current': snsA.key}),
      });
      final c = containerWith(central.client, storage);
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      await c.read(rasqAccountsProvider.notifier).select(RasqAccountsNotifier.localId);
      expect(await c.read(orgateAccountProvider.future), isNull);
      expect(c.read(orgateTokenHolderProvider).token, isNull);
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
      await settle();
      expect(central.bundles['acc-a'], isEmpty);
    });

    test('ひとつからログアウトしても、もうひとつのトークンは残る', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage();
      final c = containerWith(central.client, storage);
      final accounts = c.read(orgateAccountProvider.notifier);
      await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
      await settle();
      // いまは B。B からログアウトして台帳から外す → 「この端末のみ」へ。A は残る。
      await accounts.signOut(accountId: 'acc-b');
      await c.read(rasqAccountsProvider.notifier).detachCentral('central-acc-b');
      expect(await c.read(orgateAccountProvider.future), isNull);
      expect((await stored(storage))['tokens'], {'acc-a': 'tok-a'});
      expect(c.read(centralSignedInAccountIdsProvider), {'acc-a'});
      await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
      expect((await c.read(orgateAccountProvider.future))!.handle, 'alice');
      expect(c.read(orgateTokenHolderProvider).token, 'tok-a');

      // 使っていないアカウントからのログアウト: いまのアカウントはそのまま。
      await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
      await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');
      await accounts.signOut(accountId: 'acc-b');
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');
      expect(c.read(orgateTokenHolderProvider).token, 'tok-a');
      expect((await stored(storage))['tokens'], {'acc-a': 'tok-a'});
    });
  });

  group('前の保存の形(端末に 1 本だけ)からの移行 (D-316)', () {
    test('{token, accountId} はそのアカウントのトークンになる', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'token': 'tok-a', 'accountId': 'acc-a'}),
      });
      final c = containerWith(central.client, storage);
      expect((await c.read(orgateAccountProvider.future))!.handle, 'alice');
      expect(central.seen.last.auth, 'Bearer tok-a');
      // 次のログインで、新しい形で残る(前のトークンも残る)。
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
      final s = await stored(storage);
      expect(s['deviceId'], 'dev-1');
      expect(s['tokens'], {'acc-a': 'tok-a', 'acc-b': 'tok-b'});
      expect(s.containsKey('token'), isFalse);
    });

    test('アカウント id の無い古いトークンは、GET /me で分かった id に付け直す', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'token': 'tok-b'}),
      });
      final c = containerWith(central.client, storage);
      expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
      final s = await stored(storage);
      expect(s['tokens'], {'acc-b': 'tok-b'});
      expect(s['currentAccountId'], 'acc-b');
    });

    test('前の版で上書きされていた端末(台帳に 2 つ、トークンは後のほうだけ): 前のほうは「ログインが必要」、後のほうはそのまま使える', () async {
      final central = fakeCentral();
      RasqAccountRecord rec(String id, String handle) => RasqAccountRecord(id: 'central-$id', kind: RasqAccountKind.central, handle: handle, displayName: handle, centralAccountId: id, createdAt: DateTime(2026, 9, 1));
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'token': 'tok-b', 'accountId': 'acc-b'}),
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [rec('acc-a', 'alice').toJson(), rec('acc-b', 'bob').toJson()],
          'current': 'central-acc-a',
          'onboardingDone': true,
        }),
      });
      final c = containerWith(central.client, storage);
      await c.read(rasqAccountsProvider.future);
      expect(await c.read(orgateAccountProvider.future), isNull, reason: 'A のトークンは無い(B のトークンで A の中身を出さない)');
      expect(c.read(centralSignedInAccountIdsProvider), {'acc-b'});
      expect(c.read(rasqAccountProvider).account.handle, 'alice');
      await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
      expect((await c.read(orgateAccountProvider.future))!.handle, 'bob');
      expect(central.seen.every((r) => r.auth == 'Bearer tok-b'), isTrue);
    });
  });

  test('Web 版の保管庫もアカウントごと: 切り替えると、そのアカウントの保管庫を、そのアカウントのトークンで読む (D-316)', () async {
    final central = fakeCentral();
    final local = MemorySessionStorage();
    final c = containerWith(central.client, local, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
    // アプリでは、いつも誰かが RASQ アカウントを listen している(通知の受信箱 / サイドバー)。ここでも同じにする。
    c.listen(orgateAccountProvider, (_, _) {});
    await c.read(sessionsProvider.future);
    final accounts = c.read(orgateAccountProvider.notifier);
    AuthResult login(AccountId a) => AuthResult(session: session(a), me: UserSummary(id: 'u', account: a, displayName: a.handle));

    await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
    await settle();
    await c.read(sessionsProvider.future);
    await c.read(sessionsProvider.notifier).add(login(snsA));
    await settle();

    await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
    await settle();
    expect((await c.read(sessionsProvider.future)).sessions, isEmpty, reason: 'B の保管庫は空');
    await c.read(sessionsProvider.notifier).add(login(snsB));
    await settle();

    List<String> loggedIn(String? raw) => raw == null ? const [] : SessionOps.parse(raw).loggedInKeys;
    expect(loggedIn(central.vaults['acc-a']![SessionsNotifier.storageKey]), [snsA.key]);
    expect(loggedIn(central.vaults['acc-b']![SessionsNotifier.storageKey]), [snsB.key]);
    expect(local.keys, isNot(contains(SessionsNotifier.storageKey)));

    // A へ切り替え → A の保管庫を A のトークンで読む。
    central.seen.clear();
    await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
    await settle();
    expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
    final vaultReads = central.seen.where((r) => r.path.startsWith('/me/vault/'));
    expect(vaultReads, isNotEmpty);
    expect(vaultReads.map((r) => r.auth).toSet(), {'Bearer tok-a'});
    expect(loggedIn(central.vaults['acc-b']![SessionsNotifier.storageKey]), [snsB.key], reason: 'B の保管庫に A の SNS は入らない');
  });

  test('D-407 (指摘 #20): A の保管庫へ預け損ねた SNS のセッションは、B に切り替えても B の保管庫へ移らない。A に戻ったら A へ預け直す', () async {
    var failA = false;
    final puts = <({String? auth, String body})>[];
    final central = fakeCentral(intercept: (req) {
      if (req.method == 'PUT' && req.url.path.contains('/me/vault/')) {
        puts.add((auth: req.headers['authorization'], body: req.body));
        if (failA && req.headers['authorization'] == 'Bearer tok-a') return json({'error': {'code': '500', 'message': 'down'}}, 500);
      }
      return null;
    });
    final mock = central.client;
    final local = MemorySessionStorage();
    final c = containerWith(mock, local, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
    c.listen(orgateAccountProvider, (_, _) {});
    await c.read(sessionsProvider.future);
    final accounts = c.read(orgateAccountProvider.notifier);
    AuthResult login(AccountId a) => AuthResult(session: session(a), me: UserSummary(id: 'u', account: a, displayName: a.handle));
    const snsC = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'carol_sns');
    List<String> loggedIn(String? raw) => raw == null ? const [] : SessionOps.parse(raw).loggedInKeys;

    await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
    await settle();
    await c.read(sessionsProvider.future);
    await c.read(sessionsProvider.notifier).add(login(snsA));
    await settle();
    expect(loggedIn(central.vaults['acc-a']![SessionsNotifier.storageKey]), [snsA.key]);

    // A の保管庫への書き込みが失敗する(A の SNS のトークン入りのぶんがメモリに残る)。
    failA = true;
    await c.read(sessionsProvider.notifier).add(login(snsC));
    await settle();
    expect(loggedIn(central.vaults['acc-a']![SessionsNotifier.storageKey]), [snsA.key]);

    // そのまま B へ。
    await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
    await settle();
    expect((await c.read(sessionsProvider.future)).sessions, isEmpty, reason: 'B には A の SNS が見えない');
    await settle();
    expect(loggedIn(central.vaults['acc-b']![SessionsNotifier.storageKey]), isNot(contains(snsC.key)));
    expect(loggedIn(central.vaults['acc-b']![SessionsNotifier.storageKey]), isNot(contains(snsA.key)));
    final bPuts = puts.where((p) => p.auth == 'Bearer tok-b');
    expect(bPuts.where((p) => p.body.contains('t-carol_sns') || p.body.contains('t-alice_sns')), isEmpty, reason: 'A の SNS の資格情報を B のトークンで送らない');

    // A に戻る → A の保管庫へだけ預け直す。
    failA = false;
    await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
    await settle();
    await c.read(sessionsProvider.future);
    await settle();
    expect(loggedIn(central.vaults['acc-a']![SessionsNotifier.storageKey]), containsAll([snsA.key, snsC.key]));
    expect(loggedIn(central.vaults['acc-b']![SessionsNotifier.storageKey]), isNot(contains(snsC.key)));
  });

  test('セキュリティ確認 2026-10-09 の [22]: A の保管庫の答えが B へ切り替えた後に届いても、B の知った状態に入らない。B が読めなくても B の保存に A の SNS は入らない', () async {
    Completer<void>? holdA;
    var failB = false;
    final puts = <({String? auth, String body})>[];
    final central = fakeCentral(intercept: (req) async {
      if (!req.url.path.contains('/me/vault/')) return null;
      final auth = req.headers['authorization'];
      if (req.method == 'PUT') puts.add((auth: auth, body: req.body));
      if (req.method == 'GET' && auth == 'Bearer tok-a' && holdA != null) await holdA.future;
      if (req.method == 'GET' && auth == 'Bearer tok-b' && failB) return json({'error': {'code': '500', 'message': 'down'}}, 500);
      return null;
    });
    final local = MemorySessionStorage();
    final c = containerWith(central.client, local, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
    c.listen(orgateAccountProvider, (_, _) {});
    await c.read(sessionsProvider.future);
    final accounts = c.read(orgateAccountProvider.notifier);
    AuthResult login(AccountId a) => AuthResult(session: session(a), me: UserSummary(id: 'u', account: a, displayName: a.handle));
    List<String> loggedIn(String? raw) => raw == null ? const [] : SessionOps.parse(raw).loggedInKeys;
    const key = SessionsNotifier.storageKey;

    await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
    await settle();
    await c.read(sessionsProvider.future);
    await c.read(sessionsProvider.notifier).add(login(snsA));
    await settle();
    await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
    await settle();
    await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
    await settle();
    await c.read(sessionsProvider.future);
    expect(loggedIn(central.vaults['acc-a']![key]), [snsA.key]);

    // A の保管庫の読みが遅れているあいだに B へ。B の保管庫は読めない。
    final storage = c.read(sessionStorageProvider);
    holdA = Completer<void>();
    final lateA = storage.read(key);
    await settle();
    failB = true;
    await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
    await settle();
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
    // 切り替えのあとの B の読み(画面の作り直し)が先に済む(読めない)。
    expect(await storage.read(key) ?? '', isNot(contains('t-alice_sns')));
    holdA.complete();
    holdA = null;
    expect(await lateA, isNot(contains('t-alice_sns')), reason: '切り替わった後に戻った A の読みは、答えを出さない');
    await settle();

    // B を読み直す(読めない)→ 戻りに A の SNS は無い。そのまま SNS を追加して保存しても、B の保管庫へ A の SNS は行かない。
    expect(await storage.read(key) ?? '', isNot(contains('t-alice_sns')));
    c.invalidate(sessionsProvider);
    expect((await c.read(sessionsProvider.future)).allSessions.map((s) => s.account), isNot(contains(snsA)));
    await c.read(sessionsProvider.notifier).add(login(snsB));
    await settle();
    expect(loggedIn(central.vaults['acc-b']![key]), [snsB.key]);
    expect(puts.where((p) => p.auth == 'Bearer tok-b' && p.body.contains('t-alice_sns')), isEmpty, reason: 'A の SNS の資格情報を B のトークンで送らない');

    // A に戻れば、A の保管庫の中身は A のもの(遅れた答えで失われていない)。
    failB = false;
    await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
    await settle();
    expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
  });

  test('[22] 保存の途中で切り替わったら、その保存の答えを切り替えた先の知った状態に入れない', () async {
    Completer<void>? holdA;
    final puts = <({String? auth, String body})>[];
    final central = fakeCentral(intercept: (req) async {
      if (!req.url.path.contains('/me/vault/')) return null;
      final auth = req.headers['authorization'];
      if (req.method == 'PUT') puts.add((auth: auth, body: req.body));
      if (auth == 'Bearer tok-a' && holdA != null) await holdA.future;
      return null;
    });
    final local = MemorySessionStorage();
    final c = containerWith(central.client, local, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
    c.listen(orgateAccountProvider, (_, _) {});
    await c.read(sessionsProvider.future);
    final accounts = c.read(orgateAccountProvider.notifier);
    List<String> loggedIn(String? raw) => raw == null ? const [] : SessionOps.parse(raw).loggedInKeys;
    const key = SessionsNotifier.storageKey;
    const snsC = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'carol_sns');
    String list(List<AccountId> l) => jsonEncode({'sessions': [for (final a in l) session(a).toJson()], 'current': l.firstOrNull?.key});

    await accounts.adoptLogin({'accountId': 'acc-b', 'accessToken': 'tok-b'});
    await accounts.adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
    await settle();
    await c.read(sessionsProvider.future);
    final storage = c.read(sessionStorageProvider);

    // A への保存が遅れているあいだに B へ切り替え、B から戻らないうちに、もう一度 A へ(切り替えて戻る)。
    holdA = Completer<void>();
    final lateWrite = storage.write(key, list([snsA]));
    await settle();
    await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
    await settle();
    // B の保管庫は空。B での保存は、遅れた A の保存の答えを元にしない。
    expect(await storage.read(key), isNot(contains('t-alice_sns')));
    await storage.write(key, list([snsB]));
    holdA.complete();
    holdA = null;
    await lateWrite;
    await settle();
    expect(loggedIn(central.vaults['acc-a']![key]), [snsA.key], reason: 'A の保存は A の保管庫へ(A のトークンで)');
    // 読み直さずに B で保存: B の知った状態は B のもの(A のログインとの差 = A の SNS のログアウトを B に起こさない)。
    await storage.write(key, list([snsB, snsC]));
    expect(loggedIn(central.vaults['acc-b']![key]), [snsB.key, snsC.key]);
    expect(SessionOps.parse(central.vaults['acc-b']![key]!).ops.keys, isNot(contains(snsA.key)));
    expect(await storage.read(key), isNot(contains('t-alice_sns')), reason: 'B のいまの読みに A の SNS は出ない');
    expect(puts.where((p) => p.auth == 'Bearer tok-b' && p.body.contains('t-alice_sns')), isEmpty);
  });

  testWidgets('アカウントの FOW / サイドバーは、アカウントごとの名前を出す。行を押すと、そのアカウントに切り替わる (D-316)', (tester) async {
    final central = fakeCentral();
    RasqAccountRecord rec(String id, String handle, String name) => RasqAccountRecord(id: 'central-$id', kind: RasqAccountKind.central, handle: handle, displayName: name, centralAccountId: id, sessionKeys: [id == 'acc-a' ? snsA.key : snsB.key], createdAt: DateTime(2026, 9, 1));
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [session(snsA).toJson(), session(snsB).toJson()], 'current': snsA.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'tokens': {'acc-a': 'tok-a', 'acc-b': 'tok-b'}, 'currentAccountId': 'acc-a'}),
      RasqAccountsNotifier.storageKey: jsonEncode({
        'accounts': [rec('acc-a', 'alice', 'アリス').toJson(), rec('acc-b', 'bob', 'ボブ').toJson()],
        'current': 'central-acc-a',
        'onboardingDone': true,
      }),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central.client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    // サイドバーの顔は A、横の小さいアイコンは B。
    expect(find.text('アリス'), findsWidgets);
    expect(find.byTooltip('ボブ に切り替える'), findsOneWidget);
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    final rows = find.byType(RasqUserRow);
    expect(rows, findsNWidgets(2));
    expect(find.descendant(of: rows.at(0), matching: find.text('アリス')), findsOneWidget);
    expect(find.descendant(of: rows.at(1), matching: find.text('ボブ')), findsOneWidget);
    expect(find.textContaining('ログインが必要'), findsNothing);

    // B の行を押す → B に切り替わる(名前 / トークン / SNS)。
    await tester.tap(find.descendant(of: rows.at(1), matching: find.text('ボブ')));
    await tester.pumpAndSettle();
    expect(c.read(rasqAccountsProvider).value!.current!.id, 'central-acc-b');
    expect(c.read(orgateAccountProvider).value!.id, 'acc-b');
    expect(c.read(orgateTokenHolderProvider).token, 'tok-b');
    expect(c.read(rasqAccountProvider).displayName, 'ボブ');
    expect(c.read(sessionsProvider).value!.sessions.map((s) => s.account), [snsB]);
    expect(find.byTooltip('アリス に切り替える'), findsOneWidget);
  });
}
