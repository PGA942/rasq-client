import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/session/central_vault_storage.dart';
import 'package:rasq_client/session/rasq_accounts.dart';
import 'package:rasq_client/session/rasq_login_carry.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-461: Web コンソール (S-097) の「つないでいる SNS アカウント」と、アプリでログインしている SNS アカウントを揃える。
///
/// - (A) 同期がサーバーのバンドルから外さなかった: ログインで入ったアカウント(`pruneBundle: false`)はこの端末で
///   ログアウトしても残り、最後の 1 件のログアウトは送られず、1 件が断られると残りも送られなかった。
/// - (B) 既存の RASQ アカウントへのログインで、この端末で開いていた SNS アカウントが黙ってそのアカウントに入った
///   (そのアカウントのバンドルにあれば = 消えずに残っていた行でも。Web 版はログイン前のぶん全部を保管庫へ上書きした)。
void main() {
  const snsA = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice_sns');
  const snsB = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob_sns');
  const snsC = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'carol_sns');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't-${a.handle}', createdAt: DateTime(2026, 9, 1), displayName: a.handle);
  AuthResult login(AccountId a) => AuthResult(session: session(a), me: UserSummary(id: 'u', account: a, displayName: a.handle));
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  /// 偽の Central / ORGATE(トークン tok-a = acc-a)。バンドル (`sns_links`) と保管庫を持つ。[refuse] のキーの PUT は 403。
  ({MockClient client, Set<String> bundle, Map<String, String> vault, List<String> calls}) fakeCentral({Set<String>? bundle, Set<String> refuse = const {}}) {
    final b = bundle ?? <String>{};
    final vault = <String, String>{};
    final calls = <String>[];
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path');
      if (req.headers['authorization'] != 'Bearer tok-a') return json({'error': {'code': '401', 'message': 'no token'}}, 401);
      if (path == '/me' && req.method == 'GET') return json({'id': 'acc-a', 'handle': 'alice', 'displayName': 'アリス'});
      if (path == '/me/sns-accounts' && req.method == 'GET') return json([for (final k in b) {'accountKey': k}]);
      if (path == '/me/sns-accounts' && req.method == 'PUT') {
        final m = (jsonDecode(req.body) as Map).cast<String, Object?>();
        final key = '${m['kind']}:${m['instance']}:${m['handle']}';
        if (refuse.contains(key)) return json({'error': {'code': '403', 'message': 'not allowed'}}, 403);
        b.add(key);
        return json({'accountKey': key});
      }
      if (path.startsWith('/me/sns-accounts/') && req.method == 'DELETE') {
        final key = Uri.decodeComponent(path.substring('/me/sns-accounts/'.length));
        if (!b.remove(key)) return json({'error': {'code': '404', 'message': 'not found'}}, 404);
        return http.Response('', 204);
      }
      if (path.startsWith('/me/vault/')) {
        final name = path.substring('/me/vault/'.length);
        if (req.method == 'GET') return vault[name] == null ? json({'error': {'code': '404', 'message': 'nothing'}}, 404) : json({'value': vault[name]});
        if (req.method == 'PUT') {
          vault[name] = (jsonDecode(req.body) as Map)['value'] as String;
          return http.Response('', 204);
        }
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    return (client: client, bundle: b, vault: vault, calls: calls);
  }

  /// [asked] に問いを残し、[answer] を返す問いの口。
  ProviderContainer containerWith(MockClient mock, SessionStorage storage, {List<RasqLoginCarryQuestion>? asked, Set<String>? answer, SessionStorage Function(Ref ref)? storageFor}) {
    final c = ProviderContainer(overrides: [
      if (storageFor != null) sessionStorageProvider.overrideWith(storageFor) else sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      rasqLoginCarryAskProvider.overrideWithValue((q) async {
        asked?.add(q);
        return answer;
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  String sessionsJson(List<AccountId> l) => jsonEncode({'sessions': [for (final a in l) session(a).toJson()], 'current': l.firstOrNull?.key});

  group('(A) アプリでのログアウトがバンドル(Web コンソール)に届く', () {
    /// ログインで入ったアカウント(pruneBundle: false)に、この端末で A / B を入れて同期まで済ませた状態。
    Future<ProviderContainer> loggedInWith(({MockClient client, Set<String> bundle, Map<String, String> vault, List<String> calls}) central) async {
      final c = containerWith(central.client, MemorySessionStorage());
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      expect(c.read(rasqAccountsProvider).value!.current!.pruneBundle, isFalse);
      await c.read(sessionsProvider.notifier).add(login(snsA));
      await settle();
      await c.read(sessionsProvider.notifier).add(login(snsB));
      await settle();
      return c;
    }

    test('ログインで入ったアカウントでも、この端末でログアウトした SNS はバンドルから外れる。ほかの端末でつないだものは残る', () async {
      final central = fakeCentral(bundle: {snsC.key});
      final c = await loggedInWith(central);
      expect(central.bundle, {snsA.key, snsB.key, snsC.key});

      await c.read(sessionsProvider.notifier).remove(snsB);
      await settle();
      expect(central.bundle, {snsA.key, snsC.key}, reason: 'この端末でログアウトした B は外れ、ほかの端末の C は残る');
      expect(c.read(rasqAccountsProvider).value!.current!.bundleRemovals, isEmpty, reason: '外せたら控えは消す');
    });

    test('最後の 1 件をログアウトしても、バンドルから外れる', () async {
      final central = fakeCentral();
      final c = await loggedInWith(central);
      await c.read(sessionsProvider.notifier).remove(snsA);
      await settle();
      await c.read(sessionsProvider.notifier).remove(snsB);
      await settle();
      expect((await c.read(sessionsProvider.future)).sessions, isEmpty);
      expect(central.bundle, isEmpty);
    });

    test('外せなかった(オフライン)ログアウトは控えに残り、次の同期で外す。もう一度ログインしたら控えから消える', () async {
      final central = fakeCentral();
      final c = await loggedInWith(central);
      final ledger = c.read(rasqAccountsProvider.notifier);
      // サーバーに届かないあいだにログアウトした、を台帳だけで作る(同期はトークンが無いと送らない)。
      await ledger.removeSessionKey(snsB.key, unlink: true);
      expect(c.read(rasqAccountsProvider).value!.current!.bundleRemovals, [snsB.key]);
      await settle();
      expect(central.bundle, {snsA.key});
      expect(c.read(rasqAccountsProvider).value!.current!.bundleRemovals, isEmpty);
      // ログアウトの控えが残っていても、もう一度ログインすれば控えは消え、バンドルにも載る。
      await ledger.removeSessionKey(snsA.key, unlink: true);
      await c.read(sessionsProvider.notifier).add(login(snsA));
      await settle();
      expect(c.read(rasqAccountsProvider).value!.current!.bundleRemovals, isEmpty);
      expect(central.bundle, contains(snsA.key));
    });

    test('1 件が断られても(見守りで止めている SNS など)、残りは送る', () async {
      final central = fakeCentral(refuse: {snsA.key});
      final c = await loggedInWith(central);
      expect(central.bundle, {snsB.key}, reason: '前は A の 403 で止まり、B が載らなかった');
      expect(c.read(rasqAccountsProvider).value!.current!.sessionKeys, containsAll([snsA.key, snsB.key]));
    });

    test('RASQ アカウントからのログアウト(SNS もログアウト)では、アカウントのバンドルは変えない', () async {
      final central = fakeCentral();
      final c = await loggedInWith(central);
      final ledger = c.read(rasqAccountsProvider.notifier);
      await ledger.removeSessionKey(snsA.key);
      await settle();
      expect(c.read(rasqAccountsProvider).value!.current!.bundleRemovals, isEmpty);
      expect(central.bundle, {snsA.key, snsB.key});
    });

    test('「この端末のみ」を選んでいるあいだは送らない / 台帳に Central の行が無いあいだも送らない', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson([snsA])});
      final c = containerWith(central.client, storage);
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      // 登録の途中と同じ: 端末にトークンはあるが、台帳はまだ「この端末のみ」だけ。
      await storage.write(OrgateAccountNotifier.storageKey, jsonEncode({'deviceId': 'dev-1', 'tokens': {'acc-a': 'tok-a'}, 'currentAccountId': 'acc-a'}));
      c.invalidate(orgateAccountProvider);
      expect((await c.read(orgateAccountProvider.future))?.id, 'acc-a');
      await settle();
      expect(central.calls.where((x) => x.startsWith('PUT /me/sns-accounts')), isEmpty, reason: '端末だけのアカウントを送らない');
      expect(central.bundle, isEmpty);
    });
  });

  group('(B) 既存の RASQ アカウントへのログインで、この端末の SNS アカウントを黙って入れない', () {
    test('開いていた A(そのアカウントのバンドルに残っていた)と C は、聞いて、選ばなければ入れない。送りもしない', () async {
      final central = fakeCentral(bundle: {snsA.key});
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson([snsA, snsC])});
      final asked = <RasqLoginCarryQuestion>[];
      final c = containerWith(central.client, storage, asked: asked, answer: null);
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      final account = await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      expect(account!.handle, 'alice');
      await settle();

      expect(asked, hasLength(1));
      expect(asked.single.accountHandle, 'alice');
      expect({for (final x in asked.single.candidates) x.key: x.inBundle}, {snsA.key: true, snsC.key: false});
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.current!.id, 'central-acc-a');
      expect(ledger.current!.sessionKeys, isEmpty, reason: '前はバンドルにある A を黙って入れていた');
      expect(ledger.accounts.firstWhere((a) => !a.isCentral).sessionKeys, containsAll([snsA.key, snsC.key]), reason: '「この端末のみ」に残る');
      expect((await c.read(sessionsProvider.future)).sessions, isEmpty);
      expect(central.calls.where((x) => x.startsWith('PUT /me/sns-accounts')), isEmpty);
      expect(central.bundle, {snsA.key}, reason: 'サーバーのバンドルは変えない(ほかの端末のぶんかもしれない)');
    });

    test('選んだものだけを入れ(「この端末のみ」からは外す)、バンドルへ送る', () async {
      final central = fakeCentral();
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson([snsA, snsC])});
      final c = containerWith(central.client, storage, answer: {snsC.key});
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.current!.sessionKeys, [snsC.key]);
      expect(ledger.accounts.firstWhere((a) => !a.isCentral).sessionKeys, [snsA.key]);
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsC]);
      expect(central.bundle, {snsC.key});
    });

    test('保護者からのコードでのログインは聞かずに入れない', () async {
      final central = fakeCentral(bundle: {snsA.key});
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson([snsA])});
      final asked = <RasqLoginCarryQuestion>[];
      final c = containerWith(central.client, storage, asked: asked, answer: {snsA.key});
      await c.read(sessionsProvider.future);
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'}, offerCarry: false);
      await settle();
      expect(asked, isEmpty);
      expect(c.read(rasqAccountsProvider).value!.current!.sessionKeys, isEmpty);
    });

    test('同じアカウントへのログインし直し: その行にもうある SNS は聞かない', () async {
      final central = fakeCentral();
      final asked = <RasqLoginCarryQuestion>[];
      final c = containerWith(central.client, MemorySessionStorage(), asked: asked);
      await c.read(sessionsProvider.future);
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await c.read(sessionsProvider.notifier).add(login(snsA));
      await settle();
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      expect(asked, isEmpty);
      expect(c.read(rasqAccountsProvider).value!.current!.sessionKeys, [snsA.key]);
    });

    test('Web 版: ログイン前にメモリにだけ持っていた SNS は、選ばなければ保管庫へ預けない。保管庫のほかのログインは消さない', () async {
      final central = fakeCentral(bundle: {snsB.key});
      // 保管庫には、ほかの端末で B にログインした記録がある。
      central.vault[SessionsNotifier.storageKey] = SessionOps().applying(sessionsJson([snsB]), at: DateTime(2026, 9, 1)).encode();
      final local = MemorySessionStorage();
      final asked = <RasqLoginCarryQuestion>[];
      final c = containerWith(central.client, local, asked: asked, answer: const {}, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
      c.listen(orgateAccountProvider, (_, _) {});
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      // ログイン前に A へログイン(メモリにだけある)。
      await c.read(sessionsProvider.notifier).add(login(snsA));
      await settle();
      expect(central.vault[SessionsNotifier.storageKey], isNot(contains('alice_sns')));

      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      await c.read(sessionsProvider.future);
      await settle();
      expect(asked.single.candidates.map((x) => x.key), [snsA.key]);
      final loggedIn = SessionOps.parse(central.vault[SessionsNotifier.storageKey]!).loggedInKeys;
      expect(loggedIn, [snsB.key], reason: '前はログイン前の一覧で保管庫を上書きし、A が入って B が消えていた');
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsB]);
      expect(central.bundle, {snsB.key});
    });

    test('Web 版: 選んだものは、保管庫の台帳に重ねて預ける', () async {
      final central = fakeCentral();
      central.vault[SessionsNotifier.storageKey] = SessionOps().applying(sessionsJson([snsB]), at: DateTime(2026, 9, 1)).encode();
      final local = MemorySessionStorage();
      final c = containerWith(central.client, local, answer: {snsA.key}, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
      c.listen(orgateAccountProvider, (_, _) {});
      c.listen(orgateBundleSyncProvider, (_, _) {});
      await c.read(sessionsProvider.future);
      await c.read(sessionsProvider.notifier).add(login(snsA));
      await c.read(sessionsProvider.notifier).add(login(snsC));
      await settle();
      await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a'});
      await settle();
      await c.read(sessionsProvider.future);
      await settle();
      final loggedIn = SessionOps.parse(central.vault[SessionsNotifier.storageKey]!).loggedInKeys;
      expect(loggedIn.toSet(), {snsA.key, snsB.key});
      expect(central.bundle, {snsA.key, snsB.key});
    });
  });
}
