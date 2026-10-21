import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/session/central_vault_storage.dart';
import 'package:rasq_client/session/rasq_login_carry.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
http.Response _unauthorized([String code = '401']) => _json({'error': {'code': code, 'message': 'expired'}}, 401);

/// 2 つのアカウントの偽の ORGATE / Central(同じ接続先)。アクセストークンでアカウントを見分ける。
/// リフレッシュトークンは使うたびに回り、古いものを出すとセッションごと消える(ORGATE O-012 と同じ)。
/// [hold] に入れたアカウントの取り直しは、[release] されるまで答えない。
class _FakeServer {
  final access = <String, String>{'tok-a1': 'acc-a', 'tok-b1': 'acc-b'};
  final refresh = <String, String>{'acc-a': 'ref-a1', 'acc-b': 'ref-b1'};
  final expired = <String>{};
  final generation = <String, int>{'acc-a': 1, 'acc-b': 1};
  final vaults = <String, Map<String, String>>{'acc-a': {}, 'acc-b': {}};
  final seen = <({String method, String path, String? auth, String body})>[];
  final hold = <String, Completer<void>>{};
  final revoked = <String>{};

  void release(String id) => hold.remove(id)?.complete();

  late final MockClient client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/api/v1', '');
    final auth = req.headers['authorization'];
    seen.add((method: req.method, path: path, auth: auth, body: req.body));
    if (path == '/auth/refresh') {
      final r = (jsonDecode(req.body) as Map)['refreshToken'];
      final id = refresh.entries.where((e) => e.value == r).firstOrNull?.key;
      if (id == null || revoked.contains(id)) return _unauthorized('session_revoked');
      await hold[id]?.future;
      final n = generation[id]! + 1;
      generation[id] = n;
      final letter = id.substring(4);
      access['tok-$letter$n'] = id;
      refresh[id] = 'ref-$letter$n';
      return _json({'accessToken': 'tok-$letter$n', 'refreshToken': 'ref-$letter$n'});
    }
    final token = auth?.replaceFirst('Bearer ', '');
    if (path == '/auth/logout') {
      final id = access[token];
      if (id != null) revoked.add(id);
      return http.Response('', 204);
    }
    final id = access[token];
    if (id == null || expired.contains(token)) return _unauthorized();
    if (path == '/me' && req.method == 'GET') return _json({'id': id, 'handle': id == 'acc-a' ? 'alice' : 'bob', 'displayName': id});
    if (path == '/me/sns-accounts' && req.method == 'GET') return _json(const []);
    if (path.startsWith('/me/vault/')) {
      final name = path.substring('/me/vault/'.length);
      if (req.method == 'GET') return vaults[id]![name] == null ? _json({'error': {'code': '404', 'message': 'nothing'}}, 404) : _json({'value': vaults[id]![name]});
      if (req.method == 'PUT') {
        vaults[id]![name] = (jsonDecode(req.body) as Map)['value'] as String;
        return http.Response('', 204);
      }
    }
    return _json({'error': {'code': '404', 'message': 'not found'}}, 404);
  });

  /// [id] のトークンで送った要求。
  Iterable<({String method, String path, String? auth, String body})> sentAs(String id) =>
      seen.where((r) => r.auth != null && access[r.auth!.replaceFirst('Bearer ', '')] == id);
}

/// トークンの取り直しは、アカウント(のセッション)ごと(セキュリティ確認 2026-10-21 の #9)。
///
/// 前は取り直しの途中のものが端末に 1 本で、A の取り直しを待つあいだに B へ切り替え、B の要求も取り直しになると、
/// B の要求が A の答えを受け取り、B の URL / 中身のまま A のトークンで送られた。いまは送ったトークンごとに取り直し、
/// 答えは始めたアカウントの要求にだけ付く。待つあいだにログアウト / ログインし直したら、古い答えは捨てる。
void main() {
  RasqAccountRecord rec(String id, String handle) =>
      RasqAccountRecord(id: 'central-$id', kind: RasqAccountKind.central, handle: handle, displayName: handle, centralAccountId: id, createdAt: DateTime(2026, 10, 1));

  Map<String, String> seed() => {
        OrgateAccountNotifier.storageKey: jsonEncode({
          'deviceId': 'dev-1',
          'tokens': {'acc-a': 'tok-a1', 'acc-b': 'tok-b1'},
          'refresh': {'acc-a': 'ref-a1', 'acc-b': 'ref-b1'},
          'currentAccountId': 'acc-a',
        }),
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [rec('acc-a', 'alice').toJson(), rec('acc-b', 'bob').toJson()],
          'current': 'central-acc-a',
          'onboardingDone': true,
        }),
      };

  /// 本番と同じ [TokenRefreshingClient] を挟んだ口。
  ProviderContainer containerWith(_FakeServer server, {SessionStorage? storage, SessionStorage Function(Ref ref)? storageFor}) {
    final c = ProviderContainer(overrides: [
      if (storageFor != null) sessionStorageProvider.overrideWith(storageFor) else sessionStorageProvider.overrideWithValue(storage!),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
      orgateClientProvider.overrideWith((ref) {
        final holder = ref.read(orgateTokenHolderProvider);
        return OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: TokenRefreshingClient(server.client, holder), tokenProvider: () => holder.token);
      }),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      rasqLoginCarryAskProvider.overrideWithValue((q) async => {for (final x in q.candidates) if (x.inBundle) x.key}),
    ]);
    addTearDown(c.dispose);
    // 画面が見ているのと同じく、アカウントと台帳を見張っておく(見張りが無いと、台帳の読み込みのあとに作り直されない)。
    c.listen(rasqAccountsProvider, (_, _) {});
    c.listen(orgateAccountProvider, (_, _) {});
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> until(bool Function() cond) async {
    for (var i = 0; i < 200 && !cond(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cond(), isTrue);
  }

  Future<Map<String, Object?>> stored(SessionStorage s) async => (jsonDecode((await s.read(OrgateAccountNotifier.storageKey))!) as Map).cast<String, Object?>();

  bool refreshing(_FakeServer server, String refreshToken) => server.seen.any((r) => r.path == '/auth/refresh' && r.body.contains(refreshToken));

  test('A の取り直しを待つあいだに B へ切り替え、B の GET / PUT が取り直しになっても、A のトークンは付かない。B の中身は A へ行かない', () async {
    final server = _FakeServer();
    final storage = MemorySessionStorage(seed());
    final c = containerWith(server, storage: storage);
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');

    // A のトークンが切れ、A の要求が取り直しを始める(答えは止めておく)。
    server.expired.add('tok-a1');
    server.hold['acc-a'] = Completer<void>();
    final aMe = c.read(centralClientProvider)!.getJson('/me');
    await until(() => refreshing(server, 'ref-a1'));

    // B へ切り替える。
    await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
    expect(c.read(orgateTokenHolderProvider).token, 'tok-b1');

    // B のトークンも切れる。B の GET と PUT(秘密の中身)が、同時に取り直しになる。
    server.expired.add('tok-b1');
    final central = c.read(centralClientProvider)!;
    final bMe = central.getJson('/me');
    final bPut = central.putJson('/me/vault/notes', {'value': 'b-secret'});
    expect((await bMe)['id'], 'acc-b', reason: 'A の取り直しの答えに相乗りしない(前は A の /me が返った)');
    await bPut;
    expect(server.vaults['acc-b'], {'notes': 'b-secret'});
    expect(server.vaults['acc-a'], isEmpty, reason: 'B の中身を A へ送らない');
    expect(server.seen.where((r) => r.body.contains('b-secret')).map((r) => r.auth).toSet(), {'Bearer tok-b1', 'Bearer tok-b2'});
    expect(server.seen.where((r) => r.path == '/auth/refresh' && r.body.contains('ref-b1')), hasLength(1), reason: 'B の取り直しは、GET と PUT で 1 回にまとまる(回るリフレッシュトークンを並べて送らない)');
    expect(c.read(orgateTokenHolderProvider).token, 'tok-b2');

    // A に縛った口の要求(切り替えの前に A で始めたものと同じ): A のトークンが切れていても、B のトークンでは送り直さない。
    final account = c.read(orgateAccountProvider.notifier);
    await expectLater(c.read(orgateClientProvider)!.withToken(() => account.tokenFor('acc-a')).putJson('/me/vault/notes', {'value': 'a-secret'}), throwsA(isA<OrgateException>()));
    expect(server.seen.where((r) => r.body.contains('a-secret')).map((r) => r.auth).toSet(), {'Bearer tok-a1'});

    // A の取り直しが、いまごろ戻る: 待っていた A の要求は A のトークンで送り直され、A の答えになる。B の箱のトークンは替えない。
    final bSentBefore = server.sentAs('acc-b').length;
    server.release('acc-a');
    expect((await aMe)['id'], 'acc-a');
    await settle();
    expect(c.read(orgateTokenHolderProvider).token, 'tok-b2', reason: '戻った A の取り直しが、B のあいだに A のトークンを出さない');
    expect(server.sentAs('acc-b').length, bSentBefore);
    expect(server.sentAs('acc-a').where((r) => r.path.startsWith('/me/vault')).map((r) => r.body), [contains('a-secret')]);

    // 回ったリフレッシュトークンは、両方とも残る(遅れて戻った A の保存が、B の回ったものを巻き戻さない)。
    final s = await stored(storage);
    expect(s['tokens'], {'acc-a': 'tok-a2', 'acc-b': 'tok-b2'});
    expect(s['refresh'], {'acc-a': 'ref-a2', 'acc-b': 'ref-b2'});
    expect(s['currentAccountId'], 'acc-b');

    // A に戻ってまた切れても、回ったリフレッシュトークンで取り直せる(古い世代を出してセッションを消されない)。
    await c.read(rasqAccountsProvider.notifier).select('central-acc-a');
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');
    expect(c.read(orgateTokenHolderProvider).token, 'tok-a2');
    server.expired.add('tok-a2');
    expect((await c.read(centralClientProvider)!.getJson('/me'))['id'], 'acc-a');
    expect(server.revoked, isEmpty);
    expect((await stored(storage))['refresh'], {'acc-a': 'ref-a3', 'acc-b': 'ref-b2'});
  });

  test('Web 版の保管庫(アカウントに縛った口)も: A の取り直しを待つあいだに B で預けると、B の保管庫へ B のトークンで届く', () async {
    final server = _FakeServer();
    final local = MemorySessionStorage(seed());
    final c = containerWith(server, storageFor: (ref) => CentralVaultSessionStorage(ref, local, pollInterval: Duration.zero));
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');
    await settle();

    server.expired.add('tok-a1');
    server.hold['acc-a'] = Completer<void>();
    final aMe = c.read(centralClientProvider)!.getJson('/me');
    await until(() => refreshing(server, 'ref-a1'));

    await c.read(rasqAccountsProvider.notifier).select('central-acc-b');
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-b');
    await settle();

    server.expired.add('tok-b1');
    const sns = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob_sns');
    final session = AccountSession(account: sns, pluginId: 'test.fake', token: 'sns-secret-b', createdAt: DateTime(2026, 10, 1), displayName: 'bob_sns');
    await c.read(sessionStorageProvider).write(SessionsNotifier.storageKey, jsonEncode({'sessions': [session.toJson()], 'current': sns.key}));
    expect(server.vaults['acc-b']![SessionsNotifier.storageKey], contains('sns-secret-b'));
    expect(server.vaults['acc-a'], isEmpty);
    expect(server.seen.where((r) => r.body.contains('sns-secret-b')).map((r) => r.auth).toSet(), {'Bearer tok-b2'});

    server.release('acc-a');
    expect((await aMe)['id'], 'acc-a');
    await settle();
    expect(server.vaults['acc-a'], isEmpty);
    expect(server.sentAs('acc-a').where((r) => r.body.contains('sns-secret-b')), isEmpty);
  });

  test('取り直しを待つあいだにログアウトしたら、戻った答えは捨てる(トークンを戻さない / 送り直さない)。ログインし直したら、新しいセッションを残す', () async {
    final server = _FakeServer();
    final storage = MemorySessionStorage(seed());
    final c = containerWith(server, storage: storage);
    expect((await c.read(orgateAccountProvider.future))!.id, 'acc-a');

    server.expired.add('tok-a1');
    server.hold['acc-a'] = Completer<void>();
    final aPut = expectLater(c.read(centralClientProvider)!.putJson('/me/vault/notes', {'value': 'a-secret'}), throwsA(isA<OrgateException>()));
    await until(() => refreshing(server, 'ref-a1'));

    await c.read(orgateAccountProvider.notifier).signOut(accountId: 'acc-a');
    server.release('acc-a');
    await aPut;
    await settle();
    expect(server.seen.where((r) => r.body.contains('a-secret')).map((r) => r.auth).toList(), ['Bearer tok-a1'], reason: '取り直した A のトークンで送り直さない');
    expect(server.vaults['acc-a'], isEmpty);
    expect(c.read(orgateTokenHolderProvider).token, isNull);
    final s = await stored(storage);
    expect(s['tokens'], {'acc-b': 'tok-b1'}, reason: 'ログアウトしたアカウントのトークンを戻さない');
    expect(s['refresh'], {'acc-b': 'ref-b1'});

    // ログインし直し(新しいセッション)のあとに古い取り直しが戻っても、新しいセッションは消さない / 書き換えない。
    server.revoked.clear();
    server.access['tok-a8'] = 'acc-a';
    server.refresh['acc-a'] = 'ref-a8';
    await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a8', 'refreshToken': 'ref-a8'});
    await settle();
    expect(c.read(orgateTokenHolderProvider).token, 'tok-a8');
    // tok-a8 が切れて取り直しを始める(答えは止める)。待つあいだに、もう一度ログインする(新しいセッション tok-a9)。
    server.expired.add('tok-a8');
    server.hold['acc-a'] = Completer<void>();
    final again = expectLater(c.read(centralClientProvider)!.withToken(() => 'tok-a8').getJson('/me'), throwsA(isA<OrgateException>()));
    await until(() => refreshing(server, 'ref-a8'));
    server.access['tok-a9'] = 'acc-a';
    await c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'accessToken': 'tok-a9', 'refreshToken': 'ref-a9-new'});
    server.release('acc-a');
    await again;
    await settle();
    final s2 = await stored(storage);
    expect((s2['tokens'] as Map)['acc-a'], 'tok-a9');
    expect((s2['refresh'] as Map)['acc-a'], 'ref-a9-new');
    expect(c.read(orgateTokenHolderProvider).token, 'tok-a9');
  });

  test('OrgateTokenHolder: 取り直しは送ったトークンごと。同じトークンは 1 回にまとめ、別のトークンの答えには相乗りしない(期限前の取り直しも)', () async {
    String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    String jwt(String sub) => '${b64({'alg': 'EdDSA'})}.${b64({'sub': sub, 'exp': DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch ~/ 1000})}.sig';
    final a1 = jwt('a'), b1 = jwt('b');
    final holder = OrgateTokenHolder()..token = a1;
    final calls = <String>[];
    final gateA = Completer<void>();
    holder.refresher = (stale) async {
      calls.add(stale);
      if (stale == a1) {
        await gateA.future;
        return 'a2';
      }
      return stale == b1 ? 'b2' : null;
    };
    final sent = <String?>[];
    final inner = MockClient((req) async {
      sent.add(req.headers['authorization']);
      return http.Response('{"ok":true}', 200);
    });
    final c = OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: TokenRefreshingClient(inner, holder), tokenProvider: () => holder.token);
    // A の期限前の取り直し(答えを止める)。同じトークンの 2 本目は相乗り。
    final a = c.getJson('/a');
    final a2 = c.getJson('/a2');
    await Future<void>.delayed(Duration.zero);
    // B へ切り替える: B の期限前の取り直しは、B のトークンで別に走る。
    holder.token = b1;
    expect(await c.getJson('/b'), {'ok': true});
    expect(sent, ['Bearer b2']);
    gateA.complete();
    await a;
    await a2;
    expect(sent, ['Bearer b2', 'Bearer a2', 'Bearer a2']);
    expect(calls, [a1, b1]);
  });
}
