import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/session/central_vault_storage.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/session/sns_share.dart';
import 'package:rasq_client/session/sns_share_crypto.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-319: SNS のアクセストークンを、端末のあいだで E2E 暗号化して共有する。
void main() {
  // 取り込みのあとのお知らせ(ScaffoldMessenger の GlobalKey)がバインディングを見る。
  TestWidgetsFlutterBinding.ensureInitialized();
  const snsA = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice_sns');
  const snsB = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob_sns');
  AccountSession session(AccountId a, {DateTime? at, String? token}) =>
      AccountSession(account: a, pluginId: 'test.fake', token: token ?? 't-${a.handle}', createdAt: at ?? DateTime.utc(2026, 9, 1), displayName: a.handle);

  group('暗号', () {
    test('包む / 開く: 受け手の端末の鍵でだけ開く。別の端末の鍵・別の世代・別のアカウントでは開かない', () async {
      final seedA = SnsShareCrypto.newDeviceSeed();
      final seedB = SnsShareCrypto.newDeviceSeed();
      final pubA = await SnsShareCrypto.publicKeyOf(seedA);
      final k = SnsShareCrypto.newShareKey();
      final keyId = SnsShareCrypto.newKeyId();
      final wrapped = await SnsShareCrypto.wrap(shareKey: k, recipientPublicKey: pubA, accountId: 'acc', deviceId: 'dev-a', keyId: keyId);
      expect(wrapped.length, 92);
      expect(await SnsShareCrypto.unwrap(wrapped: wrapped, seed: seedA, accountId: 'acc', deviceId: 'dev-a', keyId: keyId), k);
      expect(await SnsShareCrypto.unwrap(wrapped: wrapped, seed: seedB, accountId: 'acc', deviceId: 'dev-a', keyId: keyId), isNull, reason: '別の端末の鍵では開けない');
      expect(await SnsShareCrypto.unwrap(wrapped: wrapped, seed: seedA, accountId: 'acc', deviceId: 'dev-b', keyId: keyId), isNull, reason: 'ほかの端末あての包みとして差し替えても開かない');
      expect(await SnsShareCrypto.unwrap(wrapped: wrapped, seed: seedA, accountId: 'acc', deviceId: 'dev-a', keyId: SnsShareCrypto.newKeyId()), isNull);
      expect(await SnsShareCrypto.unwrap(wrapped: wrapped, seed: seedA, accountId: 'other', deviceId: 'dev-a', keyId: keyId), isNull);
      final tampered = Uint8List.fromList(wrapped)..[50] ^= 1;
      expect(await SnsShareCrypto.unwrap(wrapped: tampered, seed: seedA, accountId: 'acc', deviceId: 'dev-a', keyId: keyId), isNull);
      // 毎回ちがう一時鍵で包む。
      expect(await SnsShareCrypto.wrap(shareKey: k, recipientPublicKey: pubA, accountId: 'acc', deviceId: 'dev-a', keyId: keyId), isNot(wrapped));
    });

    test('本体: K で閉じて開く。平文は暗号文に出ない。別の K / 別の世代 / 書き換えでは開かない', () async {
      final k = SnsShareCrypto.newShareKey();
      final keyId = SnsShareCrypto.newKeyId();
      const plain = '{"v":2,"ops":{"misskey:example.test:alice_sns":{"op":"login","session":{"token":"secret-token"}}}}';
      final body = await SnsShareCrypto.seal(shareKey: k, keyId: keyId, accountId: 'acc', plaintext: plain);
      expect(utf8.decode(body).contains('secret-token'), isFalse);
      expect(SnsShareCrypto.keyIdOf(body), keyId);
      expect(await SnsShareCrypto.open(shareKey: k, keyId: keyId, accountId: 'acc', body: body), plain);
      expect(await SnsShareCrypto.open(shareKey: SnsShareCrypto.newShareKey(), keyId: keyId, accountId: 'acc', body: body), isNull);
      expect(await SnsShareCrypto.open(shareKey: k, keyId: 'another-generation', accountId: 'acc', body: body), isNull);
      expect(await SnsShareCrypto.open(shareKey: k, keyId: keyId, accountId: 'other', body: body), isNull);
      final j = (jsonDecode(utf8.decode(body)) as Map).cast<String, Object?>();
      final ct = base64.decode(j['ct'] as String)..[0] ^= 1;
      final broken = utf8.encode(jsonEncode({...j, 'ct': base64.encode(ct)}));
      expect(await SnsShareCrypto.open(shareKey: k, keyId: keyId, accountId: 'acc', body: broken), isNull);
    });
  });

  group('本体との混ぜ方 (mergeSnsShare)', () {
    final now = DateTime.utc(2026, 9, 25, 12);
    String fp(AccountSession s) => snsShareFingerprint(s.toJson());

    test('初めて: この端末のログインを本体へ上げる', () {
      final m = mergeSnsShare(remote: SessionOps(), local: [session(snsA)], known: const {}, now: now);
      expect(m.upload, isTrue);
      expect(m.body.loggedInKeys, [snsA.key]);
      expect(m.logins, isEmpty);
      expect(m.logouts, isEmpty);
    });

    test('ほかの端末のログインを取り込む', () {
      final remote = SessionOps(ops: {snsB.key: SessionOp(at: DateTime.utc(2026, 9, 2), session: session(snsB).toJson())});
      final m = mergeSnsShare(remote: remote, local: const [], known: const {}, now: now);
      expect(m.upload, isFalse);
      expect([for (final s in m.logins) AccountSession.fromJson(s).account], [snsB]);
    });

    test('この端末でのログアウトは、ログアウトの記録として本体に残す(ほかの端末でもログアウトになる)', () {
      final a = session(snsA);
      final remote = SessionOps(ops: {snsA.key: SessionOp(at: a.createdAt, session: a.toJson())});
      final m = mergeSnsShare(remote: remote, local: const [], known: {snsA.key: fp(a)}, now: now);
      expect(m.upload, isTrue);
      expect(m.body.ops[snsA.key]!.session, isNull);
      expect(m.body.ops[snsA.key]!.at, now);
    });

    test('ほかの端末でのログアウトは、この端末でもログアウトにする', () {
      final a = session(snsA);
      final remote = SessionOps(ops: {snsA.key: SessionOp(at: DateTime.utc(2026, 9, 20))});
      final m = mergeSnsShare(remote: remote, local: [a], known: {snsA.key: fp(a)}, now: now);
      expect(m.logouts, [snsA.key]);
      expect(m.upload, isFalse);
    });

    test('ログアウトより前のログインを持った端末が、初めて揃えても蘇らせない / ログアウトのあとのログインは勝つ', () {
      final remote = SessionOps(ops: {snsA.key: SessionOp(at: DateTime.utc(2026, 9, 20))});
      final stale = mergeSnsShare(remote: remote, local: [session(snsA, at: DateTime.utc(2026, 9, 1))], known: const {}, now: now);
      expect(stale.logouts, [snsA.key]);
      expect(stale.body.loggedInKeys, isEmpty);
      expect(stale.upload, isFalse);
      final fresh = mergeSnsShare(remote: remote, local: [session(snsA, at: DateTime.utc(2026, 9, 24), token: 'new')], known: const {}, now: now);
      expect(fresh.logouts, isEmpty);
      expect(fresh.body.loggedInKeys, [snsA.key]);
      expect(fresh.upload, isTrue);
    });

    test('ログアウトの記録を捨てたあとも、同期したことのあるアカウントが本体から消えていれば外す', () {
      final a = session(snsA);
      final m = mergeSnsShare(remote: SessionOps(), local: [a], known: {snsA.key: fp(a)}, now: now);
      expect(m.logouts, [snsA.key]);
      expect(m.upload, isFalse);
    });

    test('ほかの端末の再ログイン(新しいトークン)で置き換える。同じものなら何もしない', () {
      final a = session(snsA);
      final again = session(snsA, at: DateTime.utc(2026, 9, 10), token: 'renewed');
      final remote = SessionOps(ops: {snsA.key: SessionOp(at: again.createdAt, session: again.toJson())});
      final m = mergeSnsShare(remote: remote, local: [a], known: {snsA.key: fp(a)}, now: now);
      expect([for (final s in m.logins) AccountSession.fromJson(s).token], ['renewed']);
      final same = mergeSnsShare(remote: remote, local: [again], known: {snsA.key: fp(again)}, now: now);
      expect(same.logins, isEmpty);
      expect(same.upload, isFalse);
    });
  });

  group('端末のあいだの流れ(偽の Central)', () {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 4; i++) {
        await c.read(snsShareProvider.notifier).check();
      }
    }

    /// 共有の口を持つ偽の Central(規則は rasq-central の `sns_share.rs` と同じもの)。トークン → 端末。
    ({MockClient client, _Share share}) fakeCentral() {
      const devices = {'tok-old': 'dev-old', 'tok-new': 'dev-new', 'tok-third': 'dev-third'};
      const labels = {'dev-old': 'laptop', 'dev-new': 'tablet', 'dev-third': 'phone'};
      final share = _Share();
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        final me = devices[req.headers['authorization']?.replaceFirst('Bearer ', '')];
        if (me == null) return json({'error': {'code': '401', 'message': 'no token'}}, 401);
        Map<String, Object?> body() => (jsonDecode(req.body) as Map).cast<String, Object?>();
        http.Response err(String code, String m) => json({'error': {'code': code, 'message': m}}, int.parse(code));
        http.Response status() => json(share.status(me, labels));
        if (path == '/me') return json({'id': 'acc-a', 'handle': 'alice', 'displayName': 'アリス'});
        if (path == '/me/sns-accounts' && req.method == 'GET') return json([{'accountKey': snsA.key}]);
        if (path == '/me/sns-share') return status();
        if (path == '/me/sns-share/device') {
          final b = body();
          final pub = b['publicKey'] as String;
          final d = share.devices[me];
          final same = d != null && d['publicKey'] == pub;
          final request = b['request'] as bool?;
          share.devices[me] = {
            'publicKey': pub,
            'requested': request ?? (same && d['requested'] == true),
            'wrapped': same && request != false ? d['wrapped'] : null,
            'by': same && request != false ? d['by'] : null,
          };
          return status();
        }
        if (path == '/me/sns-share/state') {
          final b = body();
          if (b['from'] != null && b['from'] != share.mode) return err('409', 'sharing is ${share.mode}');
          if (b['state'] != share.mode) {
            share.mode = b['state'] as String;
            share.keyId = null;
            if (share.mode != 'on') {
              for (final d in share.devices.values) {
                d['requested'] = false;
                d['wrapped'] = null;
              }
              share.body = null;
            }
          }
          return status();
        }
        final m = RegExp(r'^/me/sns-share/devices/([^/]+)(/key)?$').firstMatch(path);
        if (m != null) {
          final target = Uri.decodeComponent(m.group(1)!);
          final d = share.devices[target];
          if (d == null) return err('404', 'no device');
          if (req.method == 'DELETE') {
            if (target != me && share.devices[me]?['wrapped'] == null) return err('403', 'not a holder');
            d['requested'] = false;
            d['wrapped'] = null;
            return status();
          }
          final b = body();
          if (share.mode != 'on') return err('409', 'not on');
          if (d['requested'] != true) return err('409', 'not asked');
          final gen = share.holders > 0 ? share.keyId : null;
          if (gen == null) {
            if (target != me) return err('409', 'first key goes to the caller');
            share.keyId = b['keyId'] as String;
          } else if (gen != b['keyId']) {
            return err('409', 'keyId');
          } else if (share.devices[me]?['wrapped'] == null) {
            return err('403', 'not a holder');
          }
          d['wrapped'] = b['wrappedKey'];
          d['by'] = me;
          return status();
        }
        if (path == '/me/data/${SnsShareApi.bodyArea}') {
          if (req.method == 'GET') {
            return share.body == null ? err('404', 'none') : http.Response.bytes(share.body!, 200, headers: {'etag': '"${share.version}"'});
          }
          if (share.mode != 'on' || share.devices[me]?['wrapped'] == null) return err('403', 'not a holder');
          final ifMatch = req.headers['if-match'];
          if (ifMatch != null && ifMatch != '"${share.version}"') return err('409', 'stale');
          share.body = req.bodyBytes;
          share.version++;
          share.writes++;
          return http.Response('', 204, headers: {'etag': '"${share.version}"'});
        }
        return err('404', 'not found');
      });
      return (client: client, share: share);
    }

    /// 1 台の端末。[token] があれば、その Central のアカウントにログイン済み(台帳にも載せる)。
    ({ProviderContainer c, List<SnsShareQuestion> asked, List<bool?> answers, MemorySessionStorage storage}) device(MockClient mock, {String? token, List<AccountSession> sessions = const []}) {
      final storage = MemorySessionStorage({
        if (token != null) OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'local-$token', 'tokens': {'acc-a': token}, 'currentAccountId': 'acc-a'}),
        if (token != null)
          'rasq.accounts.v1': jsonEncode({
            'accounts': [
              {'id': 'central-acc-a', 'kind': 'central', 'handle': 'alice', 'displayName': 'アリス', 'centralAccountId': 'acc-a', 'sessionKeys': [for (final s in sessions) s.account.key], 'createdAt': '2026-09-01T00:00:00.000Z'},
            ],
            'current': 'central-acc-a',
            'onboardingDone': true,
          }),
        if (sessions.isNotEmpty) SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final s in sessions) s.toJson()], 'current': sessions.first.account.key}),
      });
      final asked = <SnsShareQuestion>[];
      final answers = <bool?>[];
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        snsSharePollIntervalProvider.overrideWithValue(Duration.zero),
        snsShareAskProvider.overrideWithValue((q) async {
          asked.add(q);
          return answers.isEmpty ? null : answers.removeAt(0);
        }),
      ]);
      addTearDown(c.dispose);
      c.listen(snsShareProvider, (_, _) {});
      return (c: c, asked: asked, answers: answers, storage: storage);
    }

    test('新しい端末でログイン → 元の端末に「共有して一斉ログインしますか?」→ はい → 新しい端末が SNS に一斉ログイン。ログアウトも伝わる', () async {
      final central = fakeCentral();
      final old = device(central.client, token: 'tok-old', sessions: [session(snsA)]);
      await old.c.read(sessionsProvider.future);
      await settle(old.c);
      expect(old.asked, isEmpty, reason: 'まだ誰も求めていない(アカウントを作ったときは off のまま)');
      expect(central.share.mode, 'off');
      expect(central.share.devices['dev-old']!['requested'], isFalse);

      // 新しい端末: RASQ アカウントにログインすると、共有を求める(D-316 ではログインボタンが出るだけだった)。
      final neu = device(central.client);
      final account = await neu.c.read(orgateAccountProvider.notifier).adoptLogin({'accountId': 'acc-a', 'token': 'tok-new'});
      expect(account!.id, 'acc-a');
      expect((await SnsShareStore(neu.storage).entry('acc-a'))['request'], isTrue);
      await settle(neu.c);
      expect(central.share.devices['dev-new']!['requested'], isTrue);
      expect(neu.c.read(snsShareWaitingProvider), isTrue, reason: 'SNS のログイン画面に「元の端末で共有を承認すると…」');
      expect(neu.asked, isEmpty, reason: '求めている端末自身には聞かない');
      expect((await neu.c.read(sessionsProvider.future)).sessions, isEmpty);

      // 元の端末: 最初の問い → はい。
      old.answers.add(true);
      await settle(old.c);
      expect(old.asked, hasLength(1));
      expect(old.asked.single.first, isTrue);
      expect(old.asked.single.title, 'アクセストークンを共有して、SNS アカウントに一斉ログインしますか?');
      expect(old.asked.single.devices.single.name, 'tablet');
      expect(central.share.mode, 'on');
      expect(central.share.devices['dev-old']!['wrapped'], isNotNull);
      expect(central.share.devices['dev-new']!['wrapped'], isNotNull);
      expect(central.share.body, isNotNull);
      expect(utf8.decode(central.share.body!).contains('t-alice_sns'), isFalse, reason: 'Central にはトークンの平文が無い');

      // 新しい端末: 包まれた K が届いた → 本体を開いて取り込む。
      await settle(neu.c);
      final got = await neu.c.read(sessionsProvider.future);
      expect(got.sessions.map((s) => s.account), [snsA]);
      expect(got.sessions.single.token, 't-alice_sns');
      expect(neu.c.read(rasqAccountsProvider).value!.centralRecord('acc-a')!.sessionKeys, [snsA.key]);
      expect(neu.c.read(snsShareWaitingProvider), isFalse);
      expect(neu.c.read(snsShareProvider).status!.holding, isTrue);

      // 新しい端末で別の SNS にログイン → 元の端末へ。
      await neu.c.read(sessionsProvider.notifier).add(AuthResult(session: session(snsB, at: DateTime.utc(2026, 9, 25)), me: UserSummary(id: 'u', account: snsB, displayName: 'bob_sns')));
      await settle(neu.c);
      await settle(old.c);
      expect((await old.c.read(sessionsProvider.future)).sessions.map((s) => s.account).toSet(), {snsA, snsB});

      // 元の端末で snsA をログアウト → 新しい端末でもログアウト(蘇らない)。
      await old.c.read(sessionsProvider.notifier).remove(snsA);
      await settle(old.c);
      await settle(neu.c);
      expect((await neu.c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsB]);
      await settle(old.c);
      expect((await old.c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsB]);
      expect(old.asked, hasLength(1), reason: '一度答えたら、同じ問いは出さない');
    });

    test('off で「いいえ」→ declined。以後は自動で聞かない', () async {
      final central = fakeCentral();
      final old = device(central.client, token: 'tok-old', sessions: [session(snsA)]);
      // 元の端末の最初の見回りを先に終える(新しい端末が求めている最中に走ると、答えの無い問いになる)。
      await settle(old.c);
      final neu = device(central.client, token: 'tok-new');
      await SnsShareStore(neu.storage).markRequest('acc-a');
      await settle(neu.c);
      old.answers.add(false);
      await settle(old.c);
      expect(old.asked.single.first, isTrue);
      expect(central.share.mode, 'declined');
      expect(central.share.devices['dev-new']!['requested'], isFalse);
      expect(central.share.body, isNull);

      // もう一台が求めても、declined のあいだは聞かない。
      final third = device(central.client, token: 'tok-third');
      await SnsShareStore(third.storage).markRequest('acc-a');
      await settle(third.c);
      await settle(old.c);
      expect(old.asked, hasLength(1));
      expect(third.c.read(snsShareWaitingProvider), isFalse, reason: 'declined のあいだは、ログイン画面に案内を出さない');
      expect((await neu.c.read(sessionsProvider.future)).sessions, isEmpty);
    });

    test('on のあいだは、新しい端末ごとに「新しい端末(名前)にも共有しますか?」。いいえ = その端末を外す', () async {
      final central = fakeCentral();
      final old = device(central.client, token: 'tok-old', sessions: [session(snsA)]);
      await old.c.read(sessionsProvider.future);
      await settle(old.c);
      // 設定のスイッチでオン(求めている端末が無くても始められる)。
      await old.c.read(snsShareProvider.notifier).setEnabled(true);
      expect(central.share.mode, 'on');
      expect(old.c.read(snsShareProvider).status!.holding, isTrue);
      expect(central.share.body, isNotNull);
      expect(old.asked, isEmpty);

      final third = device(central.client, token: 'tok-third');
      await SnsShareStore(third.storage).markRequest('acc-a');
      await settle(third.c);
      old.answers.add(false);
      await settle(old.c);
      expect(old.asked.single.first, isFalse);
      expect(old.asked.single.title, '新しい端末(phone)にも SNS のアクセストークンを共有しますか?');
      expect(central.share.devices['dev-third']!['requested'], isFalse);
      expect(central.share.devices['dev-third']!['wrapped'], isNull);
      await settle(third.c);
      expect((await third.c.read(sessionsProvider.future)).sessions, isEmpty, reason: '承認しなければ、トークンは渡らない');

      // 求め直した端末に「はい」→ 取り込む。
      await third.c.read(snsShareProvider.notifier).setEnabled(true);
      expect(third.c.read(snsShareWaitingProvider), isTrue);
      old.answers.add(true);
      await settle(old.c);
      expect(old.asked, hasLength(2));
      await settle(third.c);
      expect((await third.c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);

      // 設定でオフ → Central の本体と包んだ K が消える。
      await old.c.read(snsShareProvider.notifier).setEnabled(false);
      expect(central.share.mode, 'declined');
      expect(central.share.body, isNull);
      expect(central.share.devices.values.where((d) => d['wrapped'] != null), isEmpty);
      // 端末の SNS のログインはそのまま。
      expect((await third.c.read(sessionsProvider.future)).sessions.map((s) => s.account), [snsA]);
    });

    test('K を持たない端末は、ほかの端末に共有できない(問いも出ない)', () async {
      final central = fakeCentral();
      final old = device(central.client, token: 'tok-old', sessions: [session(snsA)]);
      await settle(old.c);
      await old.c.read(snsShareProvider.notifier).setEnabled(true);
      final neu = device(central.client, token: 'tok-new');
      await settle(neu.c);
      final third = device(central.client, token: 'tok-third');
      await SnsShareStore(third.storage).markRequest('acc-a');
      await settle(third.c);
      await settle(neu.c);
      expect(neu.asked, isEmpty, reason: '共有していない端末には、承認の問いを出さない');
      expect(central.share.devices['dev-third']!['wrapped'], isNull);
    });
  });
}

class _Share {
  String mode = 'off';
  String? keyId;
  final devices = <String, Map<String, Object?>>{};
  Uint8List? body;
  int version = 0;
  int writes = 0;

  int get holders => devices.values.where((d) => d['wrapped'] != null).length;

  Map<String, Object?> status(String me, Map<String, String> labels) => {
        'state': mode,
        'keyId': mode == 'on' && holders > 0 ? keyId : null,
        'deviceId': me,
        'wrappedKey': devices[me]?['wrapped'],
        'devices': [
          for (final e in devices.entries)
            {
              'deviceId': e.key,
              'label': labels[e.key],
              'publicKey': e.value['publicKey'],
              'requested': e.value['requested'] == true,
              'approved': e.value['wrapped'] != null,
              'current': e.key == me,
              'approvedBy': e.value['by'],
            },
        ],
      };
}
