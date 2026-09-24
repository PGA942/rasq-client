import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_links.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/child_safe/guardian_screen.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/notify/central_inbox.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';

import 'support/child_safe_fakes.dart';

/// チャイルドセーフ v2 の残り (D-309): QR / リンク、受信箱の `child_safe`、RAi の案内の絞り込み。
ChildGate gateOf(Map<String, Object?> settings, {DateTime? now}) =>
    ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson(settings)), now: now ?? DateTime(2026, 9, 24, 12));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('リンク (QR の中身)', () {
    test('つなぐ / ログインのリンクは Central と同じ形', () {
      expect(childSafePairLink('ABCD-EFGH'), 'rasq://child-safe/pair?code=ABCD-EFGH');
      expect(childSafeLoginLink('ABCD-EFGH-JKLM'), 'rasq://child-safe/login?code=ABCD-EFGH-JKLM');
    });

    test('外から来たリンク → アプリの中の場所(コードは形をそろえるだけ。ほかのリンクは null)', () {
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/pair?code=abcd-efgh')), '/child-safe/pair?code=ABCD-EFGH');
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/login?code=ABCD-EFGH-JKLM')), '/child-safe/login?code=ABCD-EFGH-JKLM');
      // 余計な文字は落とす / 長すぎるコードは入れない / コード無しでも画面は開く。
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/pair?code=AB%3Cscript%3E')), '/child-safe/pair?code=ABSCRIPT');
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/pair?code=${'A' * 40}')), '/child-safe/pair');
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/pair')), '/child-safe/pair');
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://child-safe/other')), '/child-safe');
      expect(childSafeDeepLinkLocation(Uri.parse('rasq://astell/room-1')), isNull);
      expect(childSafeDeepLinkLocation(Uri.parse('https://child-safe/pair?code=X')), isNull);
      // 貼り付けたリンクからもコードだけを取る(これまでどおり)。
      expect(childSafeCodeFromInput('rasq://child-safe/pair?code=abcd-efgh'), 'ABCD-EFGH');
    });
  });

  group('RAi の案内の絞り込み', () {
    Future<RaiReferenceIndex> load() async => RaiReferenceIndex.fromJsonl(
          functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
          operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
          embedder: const NgramRaiEmbedder(),
        );
    RaiReferenceIndex restrict(RaiReferenceIndex i, ChildGate g) => i.restrictTo(allowFunction: (f) => g.raiGuideAllowed(f.id, f.group, f.route), allowRoute: g.raiGuideRouteAllowed);

    test('関数ごとの判定: まとまり / 機能 / 検索 / 画面。見守られていなければ全部', () {
      final g = gateOf(v2()); // strict の例: rai = guide / read / compose、DM・AsTell・ユーザー検索・ストア・追加を止める
      expect(g.raiGuideAllowed('post.create', 'rai.compose', '/home'), isTrue);
      expect(g.raiGuideAllowed('search.posts', 'rai.read', '/search'), isTrue);
      expect(g.raiGuideAllowed('post.repost', 'rai.act', '/home'), isFalse); // rai.act を許していない
      expect(g.raiGuideAllowed('settings.theme', 'rai.settings', '/settings'), isFalse);
      expect(g.raiGuideAllowed('dm.send', 'rai.compose', '/dm'), isFalse); // DM を止めている
      expect(g.raiGuideAllowed('post.shareDm', 'rai.compose', '/home'), isFalse); // 機能 dm(表)
      expect(g.raiGuideAllowed('search.users', 'rai.read', '/search'), isFalse); // 検索 users
      expect(g.raiGuideAllowed('bookmarks.open', 'rai.read', '/vc'), isFalse); // 画面 /vc(AsTell を止めている)
      expect(g.raiGuideAllowed('mystery', null, null), isFalse); // まとまりの分からない関数は案内しない
      expect(g.raiGuideRouteAllowed('/login'), isFalse); // SNS アカウントの追加を止めている
      expect(g.raiGuideRouteAllowed('/login/misskey'), isFalse);
      expect(g.raiGuideRouteAllowed('/home'), isTrue);
      expect(g.raiGuideRouteAllowed('/dm'), isFalse);
      expect(ChildGate.off.raiGuideAllowed('mystery', null, '/dm'), isTrue);
      // 実行の判定([raiBlockReason])は変わらない。
      expect(g.raiBlockReason('post.compose'), isNull);
      expect(g.raiBlockReason('follow.set'), contains(childSafeBlockedText));
    });

    test('索引: 止めた関数と、それを手順に使う操作(と止めた画面の操作)を隠す', () async {
      final base = await load();
      final g = gateOf(v2());
      final idx = restrict(base, g);
      expect(idx.restricted, isTrue);
      expect(idx.functions.length, lessThan(base.functions.length));
      expect(idx.functions.length, greaterThan(10)); // 案内は残る
      for (final f in idx.functions) {
        expect({'rai.guide', 'rai.read', 'rai.compose'}, contains(f.group), reason: f.id);
        expect(f.id.startsWith('dm.') || f.id.startsWith('login.') || f.route == '/vc' || f.route == '/dm', isFalse, reason: f.id);
      }
      for (final op in idx.operations) {
        for (final s in idx.resolvedSteps(op)) {
          if (s.fn != null) expect(idx.function(s.fn!), isNotNull, reason: '${op.id}: ${s.fn}');
          final route = s.route ?? (s.fn == null ? null : idx.function(s.fn!)?.route);
          if (route != null) expect(g.raiGuideRouteAllowed(route), isTrue, reason: '${op.id}: $route');
        }
        expect(idx.expand(op), isNotEmpty, reason: op.id);
      }
      // ログイン(SNS の追加)/ DM / AsTell の操作は隠れる。投稿の操作は残る。
      expect(base.operation('login-bluesky'), isNotNull);
      expect(idx.operation('login-bluesky'), isNull);
      expect(idx.operation('post'), isNotNull);
      expect(idx.function('dm.send'), isNull);
      final dmOps = [for (final o in base.operations) if (base.resolvedSteps(o).any((s) => s.fn?.startsWith('dm.') == true || s.route == '/dm')) o.id];
      expect(dmOps, isNotEmpty);
      for (final id in dmOps) {
        expect(idx.operation(id), isNull, reason: id);
      }
      // 検索の結果にも出ない。
      final hits = await idx.searchOperations('Blueskyでログインしたい', k: 5, threshold: 0);
      expect(hits.map((h) => h.item.id), isNot(contains('login-bluesky')));
      final fns = await idx.searchFunctions('DM を送る', k: 10, threshold: 0);
      expect(fns.map((h) => h.item.id).where((id) => id.startsWith('dm.')), isEmpty);
      // 見守られていなければ絞らない。
      expect(restrict(base, ChildGate.off).operations.length, base.operations.length);
      // 記録は元の索引と同じ所に書く。
      expect(identical(idx.traces, base.traces), isTrue);
    });

    test('分岐: 元の操作が隠れても、共有の手順は解ける(手順に止めた関数が無ければ枝は残る)', () async {
      final idx = await RaiReferenceIndex.build(
        functions: const [RaiFunction(id: 'ok.fn', does: 'ok', group: 'rai.read', route: '/home'), RaiFunction(id: 'act.fn', does: 'act', group: 'rai.act', route: '/home')],
        operations: const [
          RaiOperation(id: 'base', index: 'base', steps: [RaiOperationStep(say: 'shared', fn: 'ok.fn'), RaiOperationStep(say: 'blocked', fn: 'act.fn')]),
          RaiOperation(id: 'branch', index: 'branch', base: 'base', branchAt: 1, steps: [RaiOperationStep(say: 'own')]),
          RaiOperation(id: 'unknown', index: 'unknown', steps: [RaiOperationStep(say: 'x', fn: 'nope.fn')]),
          RaiOperation(id: 'dm', index: 'dm', steps: [RaiOperationStep(say: 'x', route: '/dm')]),
        ],
        embedder: const NgramRaiEmbedder(),
      );
      final r = restrict(idx, gateOf(v2()));
      expect([for (final o in r.operations) o.id], ['branch']);
      expect([for (final s in r.expand(r.operation('branch')!)) s.text], ['shared', 'own']);
      expect(r.function('act.fn'), isNull);
    });

    test('provider: 見守り中は絞った索引、見守られていなければ元の索引そのもの', () async {
      final base = await load();
      final c = ProviderContainer(overrides: [
        raiReferenceBaseProvider.overrideWith((ref) async => base),
        childGateProvider.overrideWithValue(gateOf(v2())),
      ]);
      addTearDown(c.dispose);
      final idx = await c.read(raiReferenceProvider.future);
      expect(idx.restricted, isTrue);
      expect(idx.operation('login-bluesky'), isNull);

      final c2 = ProviderContainer(overrides: [raiReferenceBaseProvider.overrideWith((ref) async => base), childGateProvider.overrideWithValue(ChildGate.off)]);
      addTearDown(c2.dispose);
      expect(identical(await c2.read(raiReferenceProvider.future), base), isTrue);
    });
  });

  group('受信箱の child_safe', () {
    late TestSigner signer;
    setUpAll(() async => signer = await TestSigner.create());
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    ({ProviderContainer c, List<String> calls, MemorySessionStorage storage}) setup({required List<Map<String, Object?>> Function() inbox, required Future<Map<String, Object?>> Function() status, String accountId = 'kid-1', Map<String, String>? seed, Map<String, CentralNoticeHandler>? handlers}) {
      final calls = <String>[];
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-1', 'token': 'tok', 'accountId': accountId}),
        ...?seed,
      });
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        calls.add('${req.method} $path');
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': accountId, 'handle': accountId, 'displayName': 'X', 'roles': <String>[]});
          case 'GET /me/notifications':
            expect(req.url.queryParameters['limit'], '${CentralInbox.limit}');
            return json(inbox());
          case 'GET /me/child-safe':
            return json(await status());
          case 'GET /store-key':
            return json({'algorithm': 'ed25519', 'publicKey': signer.publicKey});
          case 'GET /me/child-safe/guardian':
            return json({'verified': true, 'method': 'jpki', 'children': <Object?>[]});
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
        if (handlers != null) centralNoticeHandlersProvider.overrideWithValue(handlers),
      ]);
      addTearDown(c.dispose);
      return (c: c, calls: calls, storage: storage);
    }

    Map<String, Object?> notice(String id, String at, {String kind = 'child_safe', String title = 'チャイルドセーフ: 設定が変わりました'}) =>
        {'id': id, 'kind': kind, 'title': title, 'body': '…', 'payload': {'revision': 2}, 'status': 'dummy', 'devices': 0, 'createdAt': at, 'deliveredAt': null};

    Future<Map<String, Object?>> active(int revision) async {
      final s = v2();
      return {
        'managed': true,
        'state': 'active',
        'parent': {'handle': 'mama'},
        'revision': revision,
        'appliedRevision': revision - 1,
        'settings': s,
        'signature': await signer.sign('kid-1', revision, s, '2026-09-24T00:00:00Z'),
        'issuedAt': '2026-09-24T00:00:00Z',
        'guardian': {'verified': false},
      };
    }

    test('はじめて読むアカウントは印だけ付ける。次から、新しい項目だけを種類ごとの受け手へ(古い順)', () async {
      var items = [notice('n1', '2026-09-24T01:00:00Z')];
      final got = <List<String>>[];
      final t = setup(inbox: () => items, status: () async => {'managed': false, 'guardian': {'verified': false}}, handlers: {'child_safe': (ref, ns) async => got.add([for (final n in ns) n.id])});
      final c = t.c;
      await c.read(centralInboxProvider.notifier).poll();
      expect(got, isEmpty);
      final mark = (jsonDecode((await t.storage.read(CentralInbox.storageKey))!) as Map)['kid-1'] as Map;
      expect(mark['ids'], ['n1']);

      items = [notice('n3', '2026-09-24T03:00:00Z'), notice('m1', '2026-09-24T02:30:00Z', kind: 'post.mention'), notice('n2', '2026-09-24T02:00:00Z'), notice('n1', '2026-09-24T01:00:00Z')];
      await c.read(centralInboxProvider.notifier).poll();
      expect(got, [
        ['n2', 'n3'],
      ]);
      expect(c.read(centralInboxProvider), 3); // 受け手の無い種類も数える(渡さないだけ)
      // 同じものは 2 度渡さない。同じ時刻の新しい id は渡す。
      items = [notice('n4', '2026-09-24T03:00:00Z'), ...items];
      await c.read(centralInboxProvider.notifier).poll();
      expect(got.last, ['n4']);
      await c.read(centralInboxProvider.notifier).poll();
      expect(got.length, 2);
    });

    test('子: child_safe の知らせで制限を取り直し、署名を確かめて ack する', () async {
      var revision = 1;
      var items = <Map<String, Object?>>[];
      final t = setup(inbox: () => items, status: () => active(revision), seed: {
        CentralInbox.storageKey: jsonEncode({'kid-1': {'at': '2026-09-24T00:00:00Z', 'ids': <String>[]}}),
      });
      await t.c.read(childSafeProvider.future);
      await t.c.read(childSafeProvider.notifier).refresh();
      expect(t.c.read(childSafeProvider).value!.revision, 1);
      await t.c.read(centralInboxProvider.notifier).poll();
      t.calls.clear();

      revision = 2;
      items = [notice('n1', '2026-09-24T05:00:00Z')];
      await t.c.read(centralInboxProvider.notifier).poll();
      expect(t.calls, containsAllInOrder(['GET /me/notifications', 'GET /me/child-safe', 'POST /me/child-safe/ack']));
      expect(t.c.read(childSafeProvider).value!.revision, 2);
      expect(t.c.read(childGateProvider).supervised, isTrue);
    });

    test('保護者: child_safe の知らせで子の一覧を取り直す', () async {
      var items = <Map<String, Object?>>[];
      final t = setup(accountId: 'mama-1', inbox: () => items, status: () async => {'managed': false, 'guardian': {'verified': true, 'method': 'jpki'}}, seed: {
        CentralInbox.storageKey: jsonEncode({'mama-1': {'at': '2026-09-24T00:00:00Z', 'ids': <String>[]}}),
      });
      final sub = t.c.listen(childSafeGuardianProvider, (_, _) {});
      addTearDown(sub.close);
      await t.c.read(childSafeGuardianProvider.future);
      await t.c.read(centralInboxProvider.notifier).poll();
      final before = t.calls.where((c) => c == 'GET /me/child-safe/guardian').length;

      items = [notice('p1', '2026-09-24T06:00:00Z', title: 'チャイルドセーフ: 設定がまだ届いていません')];
      await t.c.read(centralInboxProvider.notifier).poll();
      await t.c.read(childSafeGuardianProvider.future);
      expect(t.calls.where((c) => c == 'GET /me/child-safe/guardian').length, before + 1);
      expect(t.calls, contains('GET /me/child-safe')); // 自分の確認の状態も取り直す
      expect(t.c.read(childSafeProvider).value!.managed, isFalse);
    });
  });
}
