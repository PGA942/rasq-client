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
import 'package:rasq_client/backend/rasq_collections_api.dart';
import 'package:rasq_client/backend/server_info_api.dart';
import 'package:rasq_client/features/clips/host_clips.dart';
import 'package:rasq_client/features/collections/rasq_collection_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import 'support/fakes.dart';

/// 投稿詳細のブックマーク (D-342)、RASQ リスト / RASQ クリップの公開 (D-343/D-344、Central S-042)、
/// サーバー情報タイル (D-345、S-043)。Central は MockClient でまねる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  Post post(String id, {String body = 'ブックマークの確認', String? visibility = 'public'}) =>
      Post(id: id, account: viewer, author: author, createdAt: DateTime(2026, 9, 27, 10), body: body, visibility: visibility, url: Uri.parse('https://example.test/notes/$id'));

  group('リンクの見分け', () {
    test('コレクションの共有リンク(Base58 コード / uuid)', () {
      expect(rasqCollectionLinkIn('見て https://central.test/@taro/lists/3mJr7AoUXx2WqdzFBqLsKX です'), (kind: RasqCollectionKind.list, ref: '3mJr7AoUXx2WqdzFBqLsKX'));
      expect(rasqCollectionLinkIn('https://central.test/@taro/clips/0f8fad5b-d9cb-469f-a165-70867728950e')?.kind, RasqCollectionKind.clip);
      expect(rasqCollectionLinkIn('https://central.test/@taro/3mJr7AoUXx2WqdzFBqLsKX'), isNull); // AsTell の共有リンク
      expect(rasqCollectionLinkIn('https://central.test/@taro/lists/3mJr7AoUXx2WqdzFBqLsKX/x'), isNull);
    });

    test('サーバーそのものへのリンクだけ(投稿 / ユーザーへのリンクは拾わない)。除外するホストは飛ばす', () {
      expect(serverHostLinkIn('ここにいます https://Misskey.io/'), 'misskey.io');
      expect(serverHostLinkIn('https://mstdn.jp'), 'mstdn.jp');
      expect(serverHostLinkIn('https://mstdn.jp/about'), 'mstdn.jp');
      expect(serverHostLinkIn('https://misskey.io/notes/9abc'), isNull);
      expect(serverHostLinkIn('https://misskey.io/@taro'), isNull);
      expect(serverHostLinkIn('http://misskey.io/'), isNull);
      expect(serverHostLinkIn('https://central.test/ と https://misskey.io/', exclude: {'central.test'}), 'misskey.io');
    });
  });

  group('モデル', () {
    test('クリップの公開: フォロワー限定 / ローカルのみは載せない。公開範囲の無い古いスナップショットは載せる(Central が確かめる)', () {
      HostClipEntry e(Post p) => HostClipEntry(postKey: p.key, addedAt: DateTime(2026, 9, 27), snapshot: postSnapshot(p));
      final pub = e(post('p1'));
      final followers = e(post('p2', visibility: 'followers'));
      final local = HostClipEntry(postKey: 'x', addedAt: DateTime(2026, 9, 27), snapshot: {...postSnapshot(post('p3')), 'localOnly': true});
      final old = HostClipEntry(postKey: 'y', addedAt: DateTime(2026, 9, 27), snapshot: {...postSnapshot(post('p4'))}..remove('visibility'));
      final clip = HostClip(id: 'c1', name: 'まとめ', createdAt: DateTime(2026, 9, 27), entries: [pub, followers, local, old]);
      final items = publishItemsOf(clip);
      expect([for (final i in items) i['refId']], ['p1', 'p4']);
      final first = items.first;
      expect((first['kind'], first['instance'], first['url']), ('misskey', 'example.test', 'https://example.test/notes/p1'));
      final snap = first['snapshot']! as Map;
      expect(snap['visibility'], 'public');
      expect((snap['author'] as Map)['handle'], 'alice');
      // スナップショットは読み戻せる(公開範囲 / URL も)。
      final back = postFromSnapshot(pub.snapshot);
      expect((back.visibility, '${back.url}'), ('public', 'https://example.test/notes/p1'));
    });

    test('リストのメンバー: 足したアカウントのサーバーの id。よそのサーバーの人は handle に @host', () {
      final remote = UserSummary(id: 'u9', account: const AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'bob'), displayName: 'ボブ');
      final m = RasqCollectionItem.member(remote, via: viewer);
      expect((m.key, m.instance, m.refId, m.handle), ('misskey:example.test:u9', 'example.test', 'u9', 'bob@other.test'));
      expect(m.toJson()['snapshot'], isA<Map>());
      expect(RasqCollectionItem.member(author, via: viewer).handle, 'alice');
    });

    test('詳細: gone / pending の投稿は出さない。RAi は community のときだけ', () {
      final d = RasqCollectionDetail.fromJson({
        'collection': {'id': 'c1', 'kind': 'clip', 'name': 'x', 'visibility': 'public', 'owner': {'id': 'a', 'handle': 'taro'}},
        'items': [
          {'key': 'misskey:example.test:p1', 'kind': 'misskey', 'instance': 'example.test', 'refId': 'p1', 'state': 'gone'},
          {'key': 'misskey:example.test:p2', 'kind': 'misskey', 'instance': 'example.test', 'refId': 'p2', 'state': 'ok', 'snapshot': {'id': 'p2', 'author': {'id': 'u', 'handle': 'a'}, 'body': 'hi'}},
        ],
        'viewer': {'isOwner': false, 'following': true, 'eligible': true},
        'refresh': 'done',
      });
      expect(d.items.first.post(), isNull);
      expect(d.items.last.post()!.body, 'hi');
      expect((d.following, d.eligible, d.refresh), (true, true, 'done'));
      expect(const RaiServerProfile(host: 'h', community: false, summary: 'x').showable, isFalse);
      expect(const RaiServerProfile(host: 'h', community: true, summary: ' ').showable, isFalse);
      expect(const RaiServerProfile(host: 'h', community: true, summary: '内輪の話が多い').showable, isTrue);
    });
  });

  /// アプリを Central(MockClient)付きで立ち上げる。
  Future<ProviderContainer> pumpApp(WidgetTester tester, MockClient mock, {List<Post> posts = const [], bool bookmark = true, Map<String, String> storage = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      ...storage,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(store),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (v) => posts, bookmark: bookmark))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  MockClient centralWith(Future<http.Response?> Function(String route, http.Request req) handle) => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        final r = await handle('${req.method} $path', req);
        if (r != null) return r;
        if ('${req.method} $path' == 'GET /me') return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
        if (req.method != 'GET') return json(const <String, Object?>{});
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });

  testWidgets('投稿詳細のブックマーク: 短押しで SNS のブックマーク / 解除、長押しで SNS のクリップ + RASQ クリップへ', (tester) async {
    final p = post('p1');
    final c = await pumpApp(tester, centralWith((_, _) async => null), posts: [p]);
    c.read(routerProvider).push('/post/p1', extra: p);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('post.detail.bookmark'));
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.byIcon(Icons.bookmark_border)), findsOneWidget);

    // 短押し = その SNS のブックマーク(クリップには入れない)。
    await tester.tap(button);
    await tester.pumpAndSettle();
    final session = (c.read(pluginRegistryProvider).plugins.whereType<FakeSnsPlugin>().single).opened.last;
    expect(session.performed.last, 'favorite:p1:false');
    expect(c.read(actionStateProvider.notifier).of(p.key, 'favorite').done, isTrue);
    expect(find.descendant(of: button, matching: find.byIcon(Icons.bookmark)), findsOneWidget);
    expect(find.text('ブックマークしました'), findsOneWidget);
    // もう一度 = 解除。
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(session.performed.last, 'favorite:p1:true');
    expect(find.text('ブックマークを外しました'), findsOneWidget);

    // 長押し = 追加先: SNS のクリップと RASQ クリップ。
    await tester.runAsync(() => c.read(hostClipsProvider.future));
    await c.read(hostClipsProvider.notifier).createClip('横断まとめ');
    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(find.text('公開クリップ'), findsOneWidget); // SNS のクリップ
    expect(find.text('横断まとめ'), findsOneWidget); // RASQ クリップ
    await tester.tap(find.text('公開クリップ'));
    await tester.pumpAndSettle();
    expect(session.clipAdds, ['c-pub:p1']);
    await tester.longPress(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('横断まとめ'));
    await tester.pumpAndSettle();
    expect(c.read(hostClipsProvider).value!.single.entries.single.postKey, p.key);
    // 入っている RASQ クリップは「追加済み」で押せない。
    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('追加済み'), findsOneWidget);
  });

  testWidgets('ブックマークを持たない SNS: 短押しは案内だけ、長押しでクリップへ', (tester) async {
    final p = post('p1');
    final c = await pumpApp(tester, centralWith((_, _) async => null), posts: [p], bookmark: false);
    c.read(routerProvider).push('/post/p1', extra: p);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post.detail.bookmark')));
    await tester.pumpAndSettle();
    expect(find.textContaining('長押しでクリップに追加できます'), findsOneWidget);
  });

  testWidgets('RASQ クリップの公開: 作る → 載せられる投稿だけ送る → 足すと同期 → 公開をやめる', (tester) async {
    final sent = <List<Object?>>[];
    final calls = <String>[];
    final mock = centralWith((route, req) async {
      calls.add(route);
      switch (route) {
        case 'POST /me/rasq-collections':
          final b = jsonDecode(req.body) as Map;
          expect((b['kind'], b['visibility']), ('clip', 'public'));
          return json({'id': 'rc1', 'code': 'Code1111111111111111', 'kind': 'clip', 'name': b['name'], 'visibility': 'public', 'owner': {'id': 'acc-1', 'handle': 'tester'}, 'url': 'https://central.test/@tester/clips/Code1111111111111111'}, 201);
        case 'PUT /me/rasq-collections/rc1/items':
          final items = (jsonDecode(req.body) as Map)['items'] as List;
          sent.add(items);
          return json({
            'collection': {'id': 'rc1', 'kind': 'clip', 'name': 'まとめ', 'visibility': 'public', 'owner': {'id': 'acc-1', 'handle': 'tester'}, 'url': 'https://central.test/@tester/clips/Code1111111111111111'},
            'items': [for (final i in items) {...(i as Map), 'key': 'k${i['refId']}', 'state': 'ok'}],
          });
        case 'DELETE /me/rasq-collections/rc1':
          return http.Response('', 204);
      }
      return null;
    });
    final c = await pumpApp(tester, mock);
    await tester.runAsync(() => c.read(hostClipsProvider.future));
    final store = c.read(hostClipsProvider.notifier);
    final clip = await store.createClip('まとめ');
    await store.addPost(clip.id, post('p1'));
    await store.addPost(clip.id, post('p2', visibility: 'followers'));
    expect(calls.where((r) => r.contains('rasq-collections')), isEmpty); // 公開前は Central に送らない

    c.read(routerProvider).push('/clips/detail', extra: store.byId(clip.id)!.info);
    await tester.pumpAndSettle();
    expect(find.textContaining('フォロワー限定などの 1 件は載せません'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clip.publish')));
    await tester.pumpAndSettle();
    expect([for (final i in sent.single) (i! as Map)['refId']], ['p1']);
    expect(store.byId(clip.id)!.remoteId, 'rc1');
    expect(find.byKey(const ValueKey('clip.unpublish')), findsOneWidget);
    expect(find.byKey(const ValueKey('clip.publish.copy')), findsOneWidget);

    // 公開中に足すと、Central にも写る。
    await store.addPost(clip.id, post('p3'));
    expect([for (final i in sent.last) (i! as Map)['refId']], ['p1', 'p3']);

    await tester.tap(find.byKey(const ValueKey('clip.unpublish')));
    await tester.pumpAndSettle();
    expect(calls.last, 'DELETE /me/rasq-collections/rc1');
    expect(store.byId(clip.id)!.isPublished, isFalse);
    expect(store.byId(clip.id)!.entries.length, 3); // 端末のクリップは残る
  });

  testWidgets('RASQ リストのページ: 投稿 / メンバー / サーバー。フォロー。サーバー情報に RAi の解説(コミュニティの話があるときだけ)', (tester) async {
    var following = false;
    final followCalls = <String>[];
    final detailQueries = <String>[];
    Map<String, Object?> detail() => {
          'collection': {
            'id': 'rl1', 'code': 'ListCode111111111111', 'kind': 'list', 'name': '絵描きさん', 'description': 'SNS を跨いだ絵描き', 'visibility': 'public',
            'owner': {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'}, 'itemCount': 2, 'followerCount': following ? 1 : 0,
            'instances': ['example.test', 'bsky.social'], 'refreshedAt': DateTime.now().toUtc().toIso8601String(), 'url': 'https://central.test/@hanako/lists/ListCode111111111111',
          },
          'items': [
            {'key': 'misskey:example.test:alice', 'kind': 'misskey', 'instance': 'example.test', 'refId': 'alice', 'handle': 'alice', 'state': 'ok', 'snapshot': {'id': 'alice', 'kind': 'misskey', 'instance': 'example.test', 'handle': 'alice', 'displayName': 'アリス'}},
            {'key': 'bluesky:bsky.social:did:plc:x', 'kind': 'bluesky', 'instance': 'bsky.social', 'refId': 'did:plc:x', 'handle': 'bob.bsky.social', 'state': 'ok', 'snapshot': {'id': 'did:plc:x', 'kind': 'bluesky', 'instance': 'bsky.social', 'handle': 'bob.bsky.social', 'displayName': 'ボブ'}},
          ],
          'posts': [
            {'key': 'misskey:example.test:n1', 'memberKey': 'misskey:example.test:alice', 'createdAt': '2026-09-27T01:00:00Z', 'post': {'id': 'n1', 'author': {'id': 'alice', 'kind': 'misskey', 'instance': 'example.test', 'handle': 'alice', 'displayName': 'アリス'}, 'createdAt': '2026-09-27T01:00:00Z', 'body': '新しい絵を描きました', 'visibility': 'public'}},
          ],
          'viewer': {'isOwner': false, 'following': following, 'eligible': following},
          'refresh': following ? 'done' : 'not_eligible',
        };
    final mock = centralWith((route, req) async {
      switch (route) {
        case 'GET /rasq-collections/ListCode111111111111':
          detailQueries.add(req.url.query);
          return json(detail());
        case 'PUT /rasq-collections/rl1/follow':
          following = true;
          followCalls.add('on');
          return json(const <String, Object?>{});
        case 'GET /servers/example.test/info':
          return json({'host': 'example.test', 'software': 'misskey', 'version': '2025.9.0', 'name': 'れいのさーばー', 'description': '<p>絵描きが<b>多い</b>サーバー</p>', 'users': 12345, 'posts': 987654, 'registrationOpen': true});
        case 'GET /servers/example.test/rai':
          return json({'host': 'example.test', 'community': true, 'summary': '絵を描く人が多く、ローカルの企画でよく盛り上がります。', 'traits': ['創作'], 'topics': ['お絵描き'], 'sampleCount': 40});
        case 'GET /servers/bsky.social/info':
          return json({'error': {'code': '404', 'message': 'no nodeinfo'}}, 404);
      }
      return null;
    });
    final c = await pumpApp(tester, mock);
    c.read(routerProvider).push(Routes.rasqCollection('ListCode111111111111'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqCollectionScreen), findsOneWidget);
    expect(find.text('SNS を跨いだ絵描き'), findsOneWidget);
    expect(find.text('新しい絵を描きました'), findsOneWidget);
    expect(detailQueries.first, isEmpty); // ページを開いたら取り直してもらう(refresh の指定なし)

    await tester.tap(find.byKey(const ValueKey('rasqCollection.follow')));
    await tester.pumpAndSettle();
    expect(followCalls, ['on']);
    expect(find.text('フォロー中'), findsOneWidget);
    expect(find.text('見たときに新しくしました'), findsOneWidget);

    await tester.tap(find.text('メンバー'));
    await tester.pumpAndSettle();
    expect(find.text('アリス'), findsOneWidget);
    expect(find.text('ボブ'), findsOneWidget);

    await tester.tap(find.text('サーバー'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server.tile.example.test')), findsOneWidget);
    expect(find.text('れいのさーばー'), findsOneWidget);
    expect(find.text('絵描きが多いサーバー'), findsOneWidget); // HTML は文字だけに
    expect(find.textContaining('1.2万 人'), findsOneWidget);
    expect(find.byKey(const ValueKey('server.tile.rai.example.test')), findsOneWidget);
    expect(find.text('絵を描く人が多く、ローカルの企画でよく盛り上がります。'), findsOneWidget);
  });

  testWidgets('サーバー情報タイル: コミュニティの話が無ければ RAi の欄を出さない / インスタンスでなければ何も出さない。投稿のリンクから出る', (tester) async {
    final mock = centralWith((route, req) async {
      switch (route) {
        case 'GET /servers/mstdn.example/info':
          return json({'host': 'mstdn.example', 'software': 'mastodon', 'name': 'マストドン例'});
        case 'GET /servers/mstdn.example/rai':
          return json({'host': 'mstdn.example', 'community': false, 'summary': null, 'sampleCount': 40});
        case 'GET /servers/example.com/info':
          return json({'error': {'code': '404', 'message': 'no nodeinfo'}}, 404);
      }
      return null;
    });
    final c = await pumpApp(tester, mock, posts: [post('p1', body: 'ここにいます https://mstdn.example/'), post('p2', body: 'ふつうのサイト https://example.com/')]);
    await tester.pumpAndSettle();
    expect(c.read(serverInfoProvider('mstdn.example')).value?.name, 'マストドン例');
    expect(find.byKey(const ValueKey('server.tile.mstdn.example')), findsOneWidget);
    expect(find.text('マストドン例'), findsOneWidget);
    expect(find.byKey(const ValueKey('server.tile.rai.mstdn.example')), findsNothing);
    expect(find.byKey(const ValueKey('server.tile.example.com')), findsNothing);
  });

  testWidgets('投稿に RASQ リストの共有リンク: タイル(取り直さない refresh=false)→「見てみる」でページへ', (tester) async {
    final queries = <String>[];
    final mock = centralWith((route, req) async {
      if (route == 'GET /rasq-collections/ListCode111111111111') {
        queries.add(req.url.query);
        return json({
          'collection': {'id': 'rl1', 'code': 'ListCode111111111111', 'kind': 'list', 'name': '絵描きさん', 'visibility': 'public', 'owner': {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'}, 'itemCount': 5, 'instances': ['example.test']},
          'items': <Object>[],
          'viewer': {'isOwner': false, 'following': false, 'eligible': false},
        });
      }
      return null;
    });
    final c = await pumpApp(tester, mock, posts: [post('p1', body: 'リストを作りました https://central.test/@hanako/lists/ListCode111111111111')]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqCollection.tile.rl1')), findsOneWidget);
    expect(find.text('5人'), findsNothing); // 人数は「5人 ・ example.test」の 1 行
    expect(find.textContaining('5人'), findsOneWidget);
    expect(queries, ['refresh=false']);
    await tester.tap(find.byKey(const ValueKey('rasqCollection.tile.open.rl1')));
    await tester.pumpAndSettle();
    expect(find.byType(RasqCollectionScreen), findsOneWidget);
    expect(queries.last, isEmpty);
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.path, isNotEmpty);
  });
}
