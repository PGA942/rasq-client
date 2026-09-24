import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_api.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/sanctions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

import 'support/child_safe_fakes.dart';

/// チャイルドセーフ v2 (D-307): 制限の解釈 / 署名 / 関所 / 子の端末の控え(フェイクの Central)。
Post post(String id, String body) => Post(
      id: id,
      account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'kid'),
      author: const UserSummary(id: 'u', account: AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'someone'), displayName: 'someone'),
      createdAt: DateTime(2026, 9, 24, 12),
      body: body,
    );

ChildGate gateOf(Map<String, Object?> settings, {DateTime? now, String state = 'active'}) =>
    ChildGate(state: ChildSafeState(managed: true, state: state, policy: ChildSafePolicy.fromJson(settings)), now: now ?? DateTime(2026, 9, 24, 12));

void main() {
  group('制限 (rasq.child-safe/2)', () {
    test('v2 を読む: 面ごとの値と allow', () {
      final p = ChildSafePolicy.fromJson(v2());
      expect(p.schema, ChildSafePolicy.schemaV2);
      expect(p.timeline.level, ChildSafeLevel.strict);
      expect(p.timeline.blockedTopics, ['ホラー']);
      expect(p.postsPerDay, 10);
      expect(p.time.contains(DateTime(2026, 9, 24, 22)), isTrue);
      expect(p.time.contains(DateTime(2026, 9, 24, 5, 59)), isTrue);
      expect(p.time.contains(DateTime(2026, 9, 24, 6)), isFalse);
      expect(p.time.contains(DateTime(2026, 9, 24, 12)), isFalse);
      expect(p.time.nextBoundary(DateTime(2026, 9, 24, 12)), DateTime(2026, 9, 24, 21));
      expect(p.time.nextBoundary(DateTime(2026, 9, 24, 22)), DateTime(2026, 9, 25, 6));
      final a = p.allow!;
      expect(a.sns!.permits('misskey', 'misskey.io'), isTrue);
      expect(a.sns!.permits('misskey', 'misskey.example'), isFalse);
      expect(a.sns!.permits('bluesky', 'bsky.social'), isFalse);
      expect(a.plugins!.permits('jp.rasq.sample', 'composer.text'), isTrue);
      expect(a.plugins!.permits('jp.rasq.sample', 'post.action'), isFalse);
      expect(a.plugins!.install, ChildSafeInstall.none);
      expect(a.features, {'dm': false, 'astell.join': false});
      expect(a.rai!.groups, ['rai.guide', 'rai.read', 'rai.compose']);
      expect(p.catalogVersion, 1);
      // 書き戻しても同じ形。
      expect(ChildSafePolicy.fromJson(p.toJson()).toJson(), p.toJson());
    });

    test('v1(schema も allow も無い)= ほかの面は止めない。既定は止めない側', () {
      final p = ChildSafePolicy.fromJson({'timeline': {'enabled': true, 'level': 'mild', 'blockedTopics': []}, 'composer': {'enabled': false, 'level': 'mild'}, 'time': {'enabled': false, 'start': '21:00', 'end': '06:00'}, 'postsPerDay': null});
      expect(p.allow, isNull);
      expect(p.postsPerDay, isNull);
      expect(p.timeline.level, ChildSafeLevel.mild);
      final g = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: p));
      expect(g.routeBlockReason('/dm'), isNull);
      expect(g.pluginAllowed('any.plugin', 'tl'), isTrue);
      expect(g.installBlockReason('any.plugin'), isNull);
      expect(g.sessionVisible(const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'x')), isTrue);
      expect(g.raiAutomation, isTrue);
      // 知らない強さはきびしめ、壊れた時刻は「時間なし」、上限は 0〜1000。
      expect(ChildSafeLevel.fromWire('??'), ChildSafeLevel.strict);
      expect(const ChildSafeTime(enabled: true, start: '25:00', end: '06:00').contains(DateTime(2026, 1, 1, 23)), isFalse);
      expect(ChildSafePolicy.fromJson({'postsPerDay': 5000}).postsPerDay, 1000);
    });

    test('強さを選ぶと TL と投稿がそろう。カタログの帯の既定(控え)', () {
      final p = ChildSafeCatalog.fallback.presetFor('16-17');
      expect(p.preset, 'standard');
      expect(p.timeline.level, ChildSafeLevel.standard);
      expect(p.allow!.plugins!.install, ChildSafeInstall.listed);
      final m = p.withPreset(ChildSafeLevel.mild);
      expect((m.timeline.level, m.composer.level, m.preset), (ChildSafeLevel.mild, ChildSafeLevel.mild, 'mild'));
      final c = ChildSafeCatalog.fromJson({'version': 3, 'presets': {'13-15': v2()}, 'raiGroups': [{'id': 'rai.macro', 'label': 'マクロ', 'phase': 2}]});
      expect(c.presetFor('13-15').catalogVersion, 3);
      expect(c.raiGroups.single.phase, 2);
    });
  });

  group('署名 (ストアの鍵の ed25519、sha512(canonical JSON))', () {
    test('canonical JSON: キーを再帰的に並べ、空白なし、UTF-8 のまま', () {
      expect(canonicalJson({'b': 1, 'a': {'d': [true, null], 'c': 'あ"'}}), '{"a":{"c":"あ\\"","d":[true,null]},"b":1}');
    });

    // Central `docs/API.md`「署名」の参照のベクトル(Central `policy::tests::reference_vector_matches_the_contract` と同じ値)。
    test('参照のベクトル: Central と同じ決まった形 / SHA-512 / 署名', () async {
      final settings = jsonDecode(referenceSettingsJson);
      final canonical = canonicalJson({'childAccountId': '00000000-0000-4000-8000-000000000001', 'revision': 7, 'settings': settings, 'issuedAt': '2026-09-24T12:34:56Z'});
      expect(canonical, referenceCanonical);
      expect(sha512.convert(utf8.encode(canonical)).toString(), referenceSha512);
      final digest = childSafeSigningDigest(childAccountId: '00000000-0000-4000-8000-000000000001', revision: 7, settings: settings, issuedAt: '2026-09-24T12:34:56Z');
      expect(digest, hasLength(64));
      expect(digest, sha512.convert(utf8.encode(referenceCanonical)).bytes);
      // 試験の鍵(秘密鍵 = 32 バイトすべて 0x07)。Central が作った署名を、アプリの検証の道(SHA-512 の生 64 バイトに ed25519)で確かめる。
      final signer = await TestSigner.create(7);
      expect(signer.publicKey, referencePublicKey);
      expect(await signer.sign('00000000-0000-4000-8000-000000000001', 7, settings, '2026-09-24T12:34:56Z'), referenceSignature);
      Future<bool> check(Object? set, {int revision = 7}) => verifyChildSafeSignature(
          publicKey: referencePublicKey, signature: referenceSignature, childAccountId: '00000000-0000-4000-8000-000000000001', revision: revision, settings: set, issuedAt: '2026-09-24T12:34:56Z');
      expect(await check(settings), isTrue);
      expect(await check(settings, revision: 8), isFalse);
      expect(await check({...(settings as Map).cast<String, Object?>(), 'é': 2}), isFalse);
    });

    test('canonical JSON: UTF-8 のバイト順 / 決めていない値は断る(検証は false)', () async {
      // UTF-16 の順なら 😀 (D83D) が ｚ (FF5A) より前。UTF-8 の順(Central)では後。
      expect(canonicalJson({'😀': 1, 'ｚ': 2, 'é': 3, 'Z': 4}), '{"Z":4,"é":3,"ｚ":2,"😀":1}');
      expect(canonicalJson({'s': '\u007f /\u0001'}), '{"s":"\u007f /\\u0001"}');
      expect(canonicalJson(10.0), '10'); // Web では整数も double
      expect(() => canonicalJson(1.5), throwsArgumentError);
      expect(() => canonicalJson('\ud800'), throwsArgumentError);
      expect(() => canonicalJson({1: 'x'}), throwsArgumentError);
      final s = await TestSigner.create();
      expect(await verifyChildSafeSignature(publicKey: s.publicKey, signature: await s.sign('k', 1, {'a': 1}, 't'), childAccountId: 'k', revision: 1, settings: {'a': 1.5}, issuedAt: 't'), isFalse);
    });

    test('正しい署名だけ通る(別のアカウント / 版 / 中身 / 鍵は落ちる)', () async {
      final s = await TestSigner.create();
      final settings = v2();
      final sig = await s.sign('kid-1', 3, settings, '2026-09-24T00:00:00Z');
      Future<bool> check({String acc = 'kid-1', int rev = 3, Object? set, String? key, String? signature}) =>
          verifyChildSafeSignature(publicKey: key ?? s.publicKey, signature: signature ?? sig, childAccountId: acc, revision: rev, settings: set ?? settings, issuedAt: '2026-09-24T00:00:00Z');
      expect(await check(), isTrue);
      // キーの順が違っても同じ(canonical)。
      expect(await check(set: (jsonDecode(jsonEncode(Map.fromEntries(settings.entries.toList().reversed))) as Map).cast<String, Object?>()), isTrue);
      expect(await check(acc: 'kid-2'), isFalse);
      expect(await check(rev: 4), isFalse);
      expect(await check(set: {...settings, 'postsPerDay': 1000}), isFalse);
      expect(await check(key: (await TestSigner.create(9)).publicKey), isFalse);
      expect(await check(signature: 'not-base64!'), isFalse);
    });
  });

  group('関所 (ChildGate)', () {
    test('見守られていなければ素通し', () {
      final g = ChildGate.off;
      expect(g.routeBlockReason('/vc'), isNull);
      expect(g.filterPosts([post('a', 'バカ')]), hasLength(1));
      expect(g.raiBlockReason('whatever.fn'), isNull);
      expect(g.blockedMessage('dm'), isNull);
    });

    test('ルート: /vc /dm /rai /store /search と SNS の追加', () {
      final g = gateOf(v2());
      expect(g.routeBlockReason('/vc'), contains('AsTell'));
      expect(g.routeBlockReason('/dm/room/x'), contains('DM'));
      expect(g.routeBlockReason('/store'), contains('ストア'));
      expect(g.routeBlockReason('/store/installed'), isNull);
      expect(g.routeBlockReason('/search'), isNull); // 投稿 / トレンドは許している
      expect(g.routeBlockReason('/login/misskey'), contains('追加'));
      expect(g.routeBlockReason('/home'), isNull);
      final noSearch = v2();
      ((noSearch['allow'] as Map)['search'] as Map).updateAll((_, _) => false);
      ((noSearch['allow'] as Map)['rai'] as Map)['enabled'] = false;
      final g2 = gateOf(noSearch);
      expect(g2.routeBlockReason('/search/trend/x'), contains('検索'));
      expect(g2.routeBlockReason('/rai'), contains('RAi'));
      // 設定待ちは、どれも止める。
      expect(gateOf(v2(), state: 'pending_setup').locked, isTrue);
    });

    test('TL: 強さ(刺激性の閾値)と止める話題、見守りの時間は許した話題だけ', () {
      final g = gateOf(v2());
      final posts = [post('ok', '今日は晴れ'), post('bad', 'お前バカだな'), post('topic', 'ホラー映画を見た')];
      expect([for (final p in g.filterPosts(posts)) p.id], ['ok']);
      // 強さの閾値: 怒りの語 1 つ(0.5)はきびしめ / ふつうで落ち、ゆるめでは残る。
      final mild = v2()..['timeline'] = {'enabled': true, 'level': 'mild', 'blockedTopics': <String>[]};
      expect([for (final p in gateOf(mild).filterPosts(posts)) p.id], ['ok', 'bad', 'topic']);
      expect(ChildGate.stimulusOfText('お前バカだな'), greaterThanOrEqualTo(ChildSafeLevel.standard.stimulusThreshold));
      // 22 時 = 見守りの時間: 「宿題」の話題だけ。
      final night = gateOf(v2(), now: DateTime(2026, 9, 24, 22));
      expect(night.inTimeWindow, isTrue);
      expect([for (final p in night.filterPosts([...posts, post('hw', '宿題おわった')])) p.id], ['hw']);
      expect(night.routeBlockReason('/notifications'), contains('通知'));
      expect(night.blockedMessage('dm'), isNotNull);
      expect(night.postDetailBlockReason(post('hw', '宿題')), isNull); // hidePostDetail = false
      expect(g.postDetailBlockReason(post('bad', 'バカ')), 'この投稿は表示できません');
    });

    test('コンポーザー: 当たった語の範囲に印を付けて止める / 1 日の数', () async {
      final g = gateOf(v2());
      final v = g.judgeText('明日の宿題、あいつバカすぎ');
      expect(v, isNotNull);
      expect('明日の宿題、あいつバカすぎ'.substring(v!.start!, v.end!), 'バカ');
      expect(v.message, contains('「バカ」'));
      expect(g.judgeText('明日の宿題がんばる'), isNull);
      final storage = MemorySessionStorage();
      final daily = ChildSafeDaily(storage);
      final now = DateTime(2026, 9, 24, 12);
      for (var i = 0; i < 10; i++) {
        await daily.recordSent('宿題 $i', now: now);
      }
      final limited = await childComposeVerdictFor(g, daily, now, text: '宿題おわり');
      expect(limited?.message, contains('10 件'));
      expect(await childComposeVerdictFor(g, daily, now.add(const Duration(days: 1)), text: '宿題おわり'), isNull);
      expect((await childComposeVerdictFor(g, daily, now.add(const Duration(days: 1)), text: 'dm', dm: true))?.message, contains('DM'));
      // アカウントの処置 (sanctions) が先に出る。
      expect(g.blockedMessage('post', RasqSanctionsStub.post), contains('アカウントの処置'));
    });

    test('プラグイン / インストール / SNS', () {
      final g = gateOf(v2());
      expect(g.pluginAllowed('jp.rasq.sample', 'composer.text'), isTrue);
      expect(g.pluginAllowed('jp.rasq.sample', 'post.action'), isFalse);
      expect(g.pluginAllowed('other.plugin', 'composer.text'), isFalse);
      expect(g.installBlockReason('jp.rasq.sample'), contains('インストール'));
      final listed = v2();
      ((listed['allow'] as Map)['plugins'] as Map)['install'] = 'listed';
      expect(gateOf(listed).installBlockReason('jp.rasq.sample'), isNull);
      expect(gateOf(listed).installBlockReason('other.plugin'), contains('選んだ'));
      expect(g.sessionVisible(const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'k')), isTrue);
      expect(g.sessionVisible(const AccountId(kind: SnsKind.mastodon, instance: 'mstdn.jp', handle: 'k')), isFalse);
      expect(g.canAddAccounts, isFalse);
      expect(g.forceHideSensitive, isTrue);
    });
  });

  group('RAi のまとまり', () {
    test('許したまとまりだけ。まとまりの分からない関数は止める。自動化と web も', () async {
      final g = gateOf(v2());
      expect(g.raiBlockReason('posts.fetch'), isNull);
      expect(g.raiBlockReason('post.compose'), isNull);
      expect(g.raiBlockReason('follow.set'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('settings.set'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('web.search'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('dm.compose'), contains(childSafeBlockedText)); // DM を止めている
      expect(g.raiBlockReason('brand.new.fn'), contains(childSafeBlockedText));
      expect(g.raiAutomation, isFalse);
      expect(g.raiWeb, isFalse);
      final usage = raiFunctionUsageFor(g);
      expect(usage.any((u) => u.startsWith('follow.set(')), isFalse);
      expect(usage.any((u) => u.startsWith('posts.fetch(')), isTrue);
      expect(raiFunctionUsageFor(ChildGate.off), raiFunctionUsage);

      // 実行: RaiFunctionRunner.run が断る。
      final runner = Provider((ref) => RaiFunctionRunner(ref));
      final c = ProviderContainer(overrides: [childGateProvider.overrideWithValue(g)]);
      addTearDown(c.dispose);
      final r = await c.read(runner).run(const RaiFunctionCall(name: 'follow.set', args: {'user': 'x', 'on': 'true'}));
      expect(r.ok, isFalse);
      expect(r.text, contains('保護者が止めています'));
    });

    test('実行できる関数はどれもまとまりを持つ / functions.jsonl の全行が既知のまとまり', () {
      final src = File('lib/features/rai/rai_functions.dart').readAsStringSync();
      final body = src.substring(src.indexOf('Future<RaiFunctionResult> run(RaiFunctionCall c)'), src.indexOf("return RaiFunctionResult(name: c.name, text: '知らない関数です"));
      final cases = [for (final m in RegExp(r"case '([\w.]+)':").allMatches(body)) m.group(1)!];
      expect(cases.length, greaterThan(40));
      for (final fn in [...cases, ...raiNonAutomatable.keys]) {
        expect(raiFunctionGroups[fn], isNotNull, reason: fn);
      }
      final known = {...childSafeRaiGroups, ...childSafeRaiPhase2Groups};
      final lines = File('assets/rai/functions.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty);
      expect(lines.length, greaterThan(150));
      for (final l in lines) {
        final f = RaiFunction.fromJson((jsonDecode(l) as Map).cast<String, Object?>());
        expect(known, contains(f.group), reason: f.id);
      }
    });
  });

  group('子の端末 (childSafeProvider、フェイクの Central)', () {
    late TestSigner signer;
    setUpAll(() async => signer = await TestSigner.create());

    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    ({ProviderContainer c, List<String> calls, List<Map<String, Object?>> bodies, MemorySessionStorage storage}) setup(Map<String, Object?>? Function() status, {Map<String, String>? seed, String accountId = 'kid-1', bool offline = false}) {
      final calls = <String>[];
      final bodies = <Map<String, Object?>>[];
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-kid', 'token': 'kid-token', 'accountId': accountId}),
        ...?seed,
      });
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        calls.add('${req.method} $path');
        if (req.body.isNotEmpty) bodies.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        if (offline && path != '/me') throw const SocketException('offline');
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': accountId, 'handle': 'kid', 'displayName': 'キッド', 'roles': <String>[]});
          case 'GET /me/child-safe':
            final s = status();
            return s == null ? json({'error': {'code': '503', 'message': 'down'}}, 503) : json(s);
          case 'GET /store-key':
            return json({'algorithm': 'ed25519', 'publicKey': signer.publicKey});
          case 'POST /me/child-safe/ack':
          case 'POST /me/child-safe/report':
            return http.Response('', 204);
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        childSafeNowProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
      ]);
      addTearDown(c.dispose);
      return (c: c, calls: calls, bodies: bodies, storage: storage);
    }

    Future<ChildSafeState> sync(ProviderContainer c) async {
      await c.read(childSafeProvider.future);
      await c.read(childSafeProvider.notifier).refresh();
      return c.read(childSafeProvider).value!;
    }

    Future<Map<String, Object?>> active({int revision = 2, int applied = 1, Map<String, Object?>? settings, String accountId = 'kid-1'}) async {
      final s = settings ?? v2();
      return {
        'managed': true,
        'state': 'active',
        'parent': {'handle': 'mama', 'displayName': 'ママ'},
        'revision': revision,
        'appliedRevision': applied,
        'settings': s,
        'signature': await signer.sign(accountId, revision, s, '2026-09-24T00:00:00Z'),
        'issuedAt': '2026-09-24T00:00:00Z',
        'guardian': {'verified': false},
      };
    }

    test('署名を確かめて当てはめ、控えて ack する', () async {
      final st = await active();
      final t = setup(() => st);
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.locked, isFalse);
      expect(s.policy!.postsPerDay, 10);
      expect(s.parentDisplayName, 'ママ');
      expect(t.calls, contains('POST /me/child-safe/ack'));
      expect(t.bodies.any((b) => b['revision'] == 2), isTrue);
      final cache = (jsonDecode((await t.storage.read(childSafePolicyStorageKey))!) as Map).cast<String, Object?>();
      expect((cache['accountId'], cache['revision'], cache['state']), ('kid-1', 2, 'active'));
      expect(t.c.read(childGateProvider).routeBlockReason('/vc'), isNotNull);
    });

    test('署名が合わなければ前の制限のまま(無ければ使わせない)', () async {
      final bad = {...await active(), 'signature': base64Encode(List<int>.filled(64, 1))};
      final t = setup(() => bad);
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.locked, isTrue);
      expect(s.state, 'unverified');
      expect(s.error, contains('署名'));
      expect(t.calls, isNot(contains('POST /me/child-safe/ack')));

      // 前の良い制限があれば、それを使い続ける。
      final good = await active(revision: 2);
      var current = good;
      final t2 = setup(() => current);
      expect((await sync(t2.c)).policy, isNotNull);
      current = {...await active(revision: 3), 'signature': base64Encode(List<int>.filled(64, 2))};
      final s2 = await sync(t2.c);
      expect(s2.locked, isFalse);
      expect(s2.revision, 2);
      expect(s2.error, contains('前の設定のまま'));
    });

    test('設定待ち = 鍵。一度見守られた端末はオフラインでも制限を外さない。終わりはオンラインで確かめてから', () async {
      Map<String, Object?>? current = {'managed': true, 'state': 'pending_setup', 'parent': {'handle': 'mama'}, 'revision': 0, 'settings': null};
      final t = setup(() => current);
      expect((await sync(t.c)).locked, isTrue);
      current = await active();
      expect((await sync(t.c)).locked, isFalse);

      // オフライン(Central が落ちている): 控えのまま。
      current = null;
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.offline, isTrue);
      expect(s.policy, isNotNull);

      // 起動し直してもオフライン: 控えから(署名を確かめ直して)当てはめる。
      final t2 = setup(() => null, seed: {childSafePolicyStorageKey: (await t.storage.read(childSafePolicyStorageKey))!}, offline: true);
      final s2 = await sync(t2.c);
      expect(s2.managed, isTrue);
      expect(s2.policy!.postsPerDay, 10);

      // 控えが書き換えられていたら当てはめない。
      final tampered = (jsonDecode((await t.storage.read(childSafePolicyStorageKey))!) as Map).cast<String, Object?>();
      (tampered['settings'] as Map)['postsPerDay'] = 1000;
      final t3 = setup(() => null, seed: {childSafePolicyStorageKey: jsonEncode(tampered)}, offline: true);
      expect((await sync(t3.c)).locked, isTrue);

      // 別のアカウントでは「見守られていない」でも外さない。
      final t4 = setup(() => {'managed': false, 'guardian': {'verified': true, 'method': 'jpki'}}, seed: {childSafePolicyStorageKey: (await t.storage.read(childSafePolicyStorageKey))!}, accountId: 'other');
      final s4 = await sync(t4.c);
      expect(s4.managed, isTrue);
      expect(s4.guardian.verified, isTrue);

      // 同じアカウントでオンラインで終わりを確かめたら外す。
      current = {'managed': false, 'guardian': {'verified': false}};
      final s5 = await sync(t.c);
      expect(s5.managed, isFalse);
      expect(await t.storage.read(childSafePolicyStorageKey), isNull);
    });

    test('1 日の報告: 終わった日の数と話題の見出しだけ(本文は送らない)', () async {
      final st = await active();
      final t = setup(() => st);
      final daily = t.c.read(childSafeDailyProvider);
      await daily.recordSent('宿題の数学がむずかしい #宿題', now: DateTime(2026, 9, 23, 20));
      await daily.recordSent('宿題おわった #宿題', now: DateTime(2026, 9, 23, 21));
      await daily.recordBlocked(now: DateTime(2026, 9, 23, 22));
      await daily.recordSent('今日の分(まだ送らない)', now: DateTime(2026, 9, 24, 9));
      await sync(t.c);
      final reports = [for (final b in t.bodies) if (b.containsKey('date')) b];
      expect(reports, hasLength(1));
      expect(reports.single.keys.toSet(), {'date', 'posts', 'blocked', 'topics'});
      expect((reports.single['date'], reports.single['posts'], reports.single['blocked']), ('2026-09-23', 2, 1));
      expect(reports.single['topics'], contains('宿題'));
      expect(jsonEncode(reports.single), isNot(contains('むずかしい')));
      // 2 回目は送らない(1 日 1 回)。
      await t.c.read(childSafeProvider.notifier).refresh();
      expect([for (final b in t.bodies) if (b.containsKey('date')) b], hasLength(1));
    });
  });

  test('API のエラーの言い換え', () {
    OrgateException e(String code, String m) => OrgateException(ErrorCode.tryParse(code)!, m);
    expect(childSafeErrorMessage(e('410', 'gone')), contains('期限'));
    expect(childSafeErrorMessage(e('409', 'handle taken')), contains('ハンドル'));
    expect(childSafeErrorMessage(e('404', 'no')), contains('コード'));
  });
}

/// 投稿が止まっている処置(blockedMessage の順の確かめ用)。
abstract final class RasqSanctionsStub {
  static final post = RasqSanctions.fromJson({'level': 'light', 'restrictedFeatures': ['post']});
}
