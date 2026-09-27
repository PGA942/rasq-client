import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/nodeprog/tl_config_store.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ リストのタイムライン化 (D-346)、インポート / 取り込み (D-347)。Central(S-044)は MockClient でまねる。
/// 選べるのは、リスト内の人の情報を取れる(canFetch)リストだけ。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  Map<String, Object?> summary(String id, String name, {bool owner = false, bool? canFetch, bool checked = true, bool following = false}) => {
        'id': id,
        'kind': 'list',
        'name': name,
        'visibility': 'public',
        'owner': owner ? {'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'} : {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'},
        'itemCount': 2,
        'instances': ['example.test'],
        'viewer': {'canFetch': canFetch ?? owner, 'canFetchChecked': checked, 'following': following, 'isOwner': owner},
      };

  test('コンパイル: RASQ リストはアカウント無しの tl.rasqlist。kind は rasqlist:<id>', () {
    final g = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: 'rasqlist:rl1', label: '絵描き')], algorithms: [TlAlgorithmComponent(type: 'chrono')]), scope: 'tl.home');
    final n = g.nodes.singleWhere((n) => n.type == 'tl.rasqlist');
    expect(n.inputs.single.value, 'rl1');
    expect(defaultTlConfig('tl.rasqlist:rl1').sources.single.tl, 'rasqlist:rl1');
    expect(const TlSourceComponent(tl: 'rasqlist:rl1').isRasqList, isTrue);
  });

  test('resolveNodeFetch: rasqlist: は Central のリストに解決(acct: で包まれていても)、続きを報告', () async {
    final session = FakeSnsSession(fakeSession(), const []);
    String? next;
    final calls = <String>[];
    Future<(List<Post>, String?)> list(String id, String? until) async {
      calls.add('$id:$until');
      return (<Post>[Post(id: 'n1', account: fakeSession().account, author: UserSummary(id: 'u', account: fakeSession().account, displayName: 'u'), createdAt: DateTime(2026, 9, 27), body: 'x')], 'c2');
    }

    final a = await resolveNodeFetch(session, 'rasqlist:rl1', rasqList: list, onCursor: (n) => next = n);
    expect((a.single.id, next), ('n1', 'c2'));
    await resolveNodeFetch(session, 'acct:@tester@example.test|rasqlist:rl1', cursor: 'c2', rasqList: list);
    expect(calls, ['rl1:null', 'rl1:c2']);
    expect(await resolveNodeFetch(session, 'rasqlist:rl1'), isEmpty); // 取り方が無ければ空
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester, MockClient mock) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(store),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (v) => const []))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  /// Central のまね: 自分のリスト rl1、フォロー中 fl2、検索で pub3(一覧では未確認 → 詳細で取れると分かる)/ pub4(取れない)。
  (MockClient, List<String>) central() {
    final calls = <String>[];
    final followed = <String>{};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final route = '${req.method} $path';
      calls.add(req.url.query.isEmpty ? route : '$route?${req.url.query}');
      switch (route) {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
        case 'GET /me/rasq-collections':
          return json([summary('rl1', '自分のリスト', owner: true)]);
        case 'GET /me/rasq-collections/following':
          return json([summary('fl2', 'フォロー中のリスト', canFetch: true, following: true)]);
        case 'GET /rasq-collections/search':
          return json([summary('pub3', 'ねこ好き', canFetch: false, checked: false), summary('pub4', 'ねこ遠い', canFetch: false)]);
        case 'GET /rasq-collections/pub3':
          return json({'collection': summary('pub3', 'ねこ好き'), 'items': <Object>[], 'viewer': {'isOwner': false, 'following': followed.contains('pub3'), 'eligible': false, 'canFetch': true}});
        case 'GET /rasq-collections/pub4':
          return json({'collection': summary('pub4', 'ねこ遠い'), 'items': <Object>[], 'viewer': {'isOwner': false, 'following': false, 'eligible': false, 'canFetch': false}});
        case 'PUT /rasq-collections/pub3/follow':
          followed.add('pub3');
          return json(summary('pub3', 'ねこ好き', canFetch: true, following: true));
        case 'GET /rasq-collections/rl1/timeline':
          return json({
            'posts': [
              {'key': 'misskey:example.test:n1', 'memberKey': 'misskey:example.test:alice', 'createdAt': '2026-09-27T01:00:00Z', 'post': {'id': 'n1', 'author': {'id': 'alice', 'kind': 'misskey', 'instance': 'example.test', 'handle': 'alice', 'displayName': 'アリス'}, 'createdAt': '2026-09-27T01:00:00Z', 'body': 'RASQ リストから来た投稿', 'visibility': 'public'}},
            ],
            'members': [{'key': 'misskey:example.test:alice', 'kind': 'misskey', 'instance': 'example.test', 'refId': 'alice', 'handle': 'alice', 'state': 'ok'}],
            'next': null,
          });
      }
      if (req.method != 'GET') return json(const <String, Object?>{});
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    return (mock, calls);
  }

  testWidgets('TL カスタマイズ: 「RASQ リスト」→ ノードの FOW で自分 / フォロー中 / 検索。取れないリストは選べない、未確認は詳細で確かめてフォローして選ぶ', (tester) async {
    final (mock, calls) = central();
    final c = await pumpApp(tester, mock);
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RASQ リスト'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('RASQ リスト: 未選択')), findsOneWidget);
    await tester.tap(inScreen(find.text('RASQ リストを取得')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tlcfg.rasqlist.search')), findsOneWidget);
    expect(find.text('自分のリスト'), findsOneWidget);
    expect(find.text('フォロー中のリスト'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('tlcfg.rasqlist.search')), 'ねこ');
    await tester.pumpAndSettle();
    expect(calls, contains(predicate<String>((r) => r.startsWith('GET /rasq-collections/search?') && r.contains('q=%E3%81%AD%E3%81%93'))));
    // 取れないと分かっているリスト: 選べない(フォローもしない)。
    await tester.tap(find.byKey(const ValueKey('rasqList.pick.pub4')));
    await tester.pumpAndSettle();
    expect(find.textContaining('リスト内の人の情報を取れるアカウントがありません'), findsOneWidget);
    expect(calls.where((r) => r.contains('pub4/follow')), isEmpty);
    // 一覧では未確認: 詳細(refresh の指定なし = 確かめる)→ 取れる → フォロー → 選ぶ。
    await tester.tap(find.byKey(const ValueKey('rasqList.pick.pub3')));
    await tester.pumpAndSettle();
    expect(calls, containsAllInOrder(['GET /rasq-collections/pub3', 'PUT /rasq-collections/pub3/follow']));
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('RASQ リスト: ねこ好き')), findsOneWidget);
    final area = await tester.runAsync(() => c.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future));
    final graph = NodeGraph.fromJson((jsonDecode(area!['graph']! as String) as Map).cast<String, Object?>());
    expect(graph.nodes.singleWhere((n) => n.type == 'tl.rasqlist').inputs.single.value, 'pub3');
  });

  testWidgets('ホームの TL に取り込んだ RASQ リストの投稿が流れる(同じサーバーのアカウントの投稿として)', (tester) async {
    final (mock, calls) = central();
    final c = await pumpApp(tester, mock);
    await tester.runAsync(() => addTlSource(c, fakeSession().account.key, 'tl.home', const TlSourceComponent(tl: 'rasqlist:rl1', label: '自分のリスト')));
    c.invalidate(timelineProvider(TimelineKind.home));
    // 設定の読み込みは実時間で待つ(FakeAsync の中では読み終えた future が戻らない)。
    await tester.runAsync(() => c.read(timelineProvider(TimelineKind.home).future));
    await tester.pumpAndSettle();
    expect(calls, contains('GET /rasq-collections/rl1/timeline?limit=40'));
    // TL に出るのは取れる投稿だけ(本文は Central のスナップショット、公開 / ホームのみ)。
    final post = c.read(timelineProvider(TimelineKind.home)).value!.posts.singleWhere((p) => p.id == 'n1');
    expect(post.body, 'RASQ リストから来た投稿');
    expect(post.account, fakeSession().account);
  });

  testWidgets('リストのインポート: RASQ リストを検索 →「取り込む」でホームの TL へ(取れないものは押せない)。リストのページにも「タイムラインに取り込む」', (tester) async {
    final (mock, calls) = central();
    final c = await pumpApp(tester, mock);
    c.read(routerProvider).push('/lists/import');
    await tester.pumpAndSettle();
    expect(find.text('RASQ リスト(自分 / フォロー中)'), findsOneWidget);
    expect(find.text('自分のリスト'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('lists.import.search')), 'ねこ');
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('lists.import.rasq.pub4'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('lists.import.rasq.pub3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('「ねこ好き」をホームのタイムラインに取り込みました'), findsOneWidget);
    expect(calls, contains('PUT /rasq-collections/pub3/follow'));
    final cfg = await tester.runAsync(() => readTlConfig(c, fakeSession().account.key, 'tl.home'));
    expect(cfg!.sources.where((s) => s.tl == 'rasqlist:pub3').single.label, 'ねこ好き');

    // リストのページ: 取れるリストだけ「タイムラインに取り込む」。
    c.read(routerProvider).push(Routes.rasqCollection('pub4'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqCollection.import')), findsNothing);
    c.read(routerProvider).push(Routes.rasqCollection('pub3'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqCollection.import')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rasqCollection.import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('もうホームのタイムラインに入っています'), findsOneWidget);
  });
}
