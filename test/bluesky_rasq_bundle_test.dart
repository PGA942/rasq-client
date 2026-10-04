import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/bluesky_auth.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart' show RasqTogglePillButton;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

import 'support/fakes.dart';

/// D-423: RASQ アカウント(総合表示)とアカウントページに Bluesky のアカウントが入っているとき。
/// - 自分かどうかは、Bluesky どうしならハンドルだけ(サーバーの欄は見ているアカウントの PDS)と DID で比べる。
/// - 人のページ / 操作は、作者の `AccountId.key` にログインが無くても、Bluesky のアカウントで開く(DID は全体で通じる)。
/// - アカウントページの SNS の投稿は、同じサーバーでなくても Bluesky のアカウントがあれば操作できる。
/// - 固定する / 固定を外すは、投稿の … のメニュー(前は投稿の上の行のボタン)。
const misskey = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
const bsky = AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.bsky.social');
const aliceDid = 'did:plc:alice';
const bob = UserSummary(id: 'did:plc:bob', account: AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'bob.bsky.social'), displayName: 'ボブ');

String bskyToken(String did, String handle) => jsonEncode({'did': did, 'handle': handle, 'accessJwt': 'a', 'refreshJwt': 'r'});

class _RecSession extends FakeSnsSession {
  _RecSession(super.session, super.posts, {super.kind});
  final deleted = <String>[];
  final followed = <String>[];
  final userRequests = <String>[];

  @override
  Future<void> deletePost(String id) async => deleted.add(id);
  @override
  Future<FollowState> setFollowing(String userId, bool following) async {
    followed.add('$userId:$following');
    return FollowState(following: following);
  }

  @override
  Future<UserProfile> user(String id) {
    userRequests.add(id);
    return super.user(id);
  }
}

class _RecPlugin extends FakeSnsPlugin {
  _RecPlugin({required super.posts, super.kind, super.id});
  final sessions = <String, _RecSession>{};
  @override
  SnsSession open(AccountSession session) => sessions[session.account.key] = _RecSession(session, posts(session.account), kind: kind);
}

void main() {
  group('Bluesky の自分 (D-423)', () {
    test('Bluesky どうしはハンドルだけで比べる(サーバーの欄は PDS の違いがある)', () {
      expect(sameAccountIdentity(bsky, const AccountId(kind: SnsKind.bluesky, instance: 'pds.example', handle: '@Alice.bsky.social')), isTrue);
      expect(sameAccountIdentity(bsky, bob.account), isFalse);
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.bluesky, instance: 'x', handle: ''), const AccountId(kind: SnsKind.bluesky, instance: 'x', handle: '')), isFalse);
      // Misskey は従来どおりサーバーも見る。
      expect(sameAccountIdentity(misskey, const AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'tester')), isFalse);
    });

    test('DID が分かれば、ハンドルを変えたあとの自分も自分', () {
      const renamed = UserSummary(id: aliceDid, account: AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.example.com'), displayName: 'アリス');
      expect(isViewerSelf(renamed, bsky), isFalse);
      expect(isViewerSelf(renamed, bsky, viewerId: aliceDid), isTrue);
      expect(isViewerSelf(bob, bsky, viewerId: aliceDid), isFalse);
      final s = AccountSession(account: bsky, pluginId: blueskyPluginId, token: bskyToken(aliceDid, bsky.handle), createdAt: DateTime(2026));
      expect(blueskyDidOf(s), aliceDid);
      expect(blueskyDidOf(AccountSession(account: misskey, pluginId: 'x', token: 'tok', createdAt: DateTime(2026))), isNull);
      expect(blueskyDidOf(AccountSession(account: bsky, pluginId: 'x', token: 'not json', createdAt: DateTime(2026))), isNull);
      expect(isOwnBlueskyId([s], aliceDid), isTrue);
      expect(isOwnBlueskyId([s], 'did:plc:bob'), isFalse);
    });

    test('投稿に操作できるアカウント: Misskey / Mastodon は同じサーバー、Bluesky は種類だけ(本人のアカウントを先に)', () {
      AccountSession sess(AccountId a) => AccountSession(account: a, pluginId: 'x', token: 't', createdAt: DateTime(2026));
      const other = AccountId(kind: SnsKind.bluesky, instance: 'pds.example', handle: 'carol.example');
      final list = [sess(misskey), sess(other), sess(bsky)];
      expect(accountServes(other, 'bluesky', 'bsky.social'), isTrue);
      expect(accountServes(misskey, 'misskey', 'other.test'), isFalse);
      expect(sessionServing(list, 'bluesky', 'bsky.social')?.account, bsky, reason: '同じサーバーを先に');
      expect(sessionServing(list, 'bluesky', 'elsewhere.example')?.account, other);
      expect(sessionServing(list, 'bluesky', 'elsewhere.example', preferKey: bsky.key)?.account, bsky, reason: '本人のアカウント');
      expect(sessionServing(list, 'misskey', 'other.test'), isNull);
    });
  });

  Post bskyPost(String rkey, UserSummary author, String body) => Post(id: 'at://${author.id}/app.bsky.feed.post/$rkey', account: bsky, author: author, createdAt: DateTime(2026, 10, 3, 9), body: body, url: Uri.parse('https://bsky.app/profile/${author.handle}/post/$rkey'));
  const alice = UserSummary(id: aliceDid, account: bsky, displayName: 'アリス');
  const aliceRenamed = UserSummary(id: aliceDid, account: AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.example.com'), displayName: 'アリス(新)');

  Future<(ProviderContainer, _RecPlugin, _RecPlugin)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [
          AccountSession(account: misskey, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: 'tester').toJson(),
          AccountSession(account: bsky, pluginId: 'test.bsky', token: bskyToken(aliceDid, bsky.handle), createdAt: DateTime(2026), displayName: 'アリス').toJson(),
        ],
        // 現在は Misskey、RASQ アカウント(バンドルタイル)を選んでいる = 総合表示。
        'current': misskey.key,
        'bundle': true,
      }),
    });
    final mk = _RecPlugin(posts: (v) => [Post(id: 'm1', account: v, author: UserSummary(id: 'u-tester', account: v, displayName: 'tester'), createdAt: DateTime(2026, 10, 3, 8), body: 'Misskey の投稿')]);
    final bs = _RecPlugin(
      kind: SnsKind.bluesky,
      id: 'test.bsky',
      posts: (v) => [
        bskyPost('3own', alice, 'Bluesky の自分の投稿'),
        bskyPost('3ren', aliceRenamed, 'ハンドルを変えたあとの投稿'),
        bskyPost('3bob', bob, 'ボブの投稿'),
      ],
    );
    final registry = PluginRegistry()
      ..register(mk)
      ..register(bs);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), mk, bs);
  }

  Future<void> openMenu(WidgetTester tester, String body) async {
    final row = find.ancestor(of: find.text(body), matching: find.byType(PostRow)).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
  }

  testWidgets('総合表示: Bluesky の投稿が合流し、自分の投稿(ハンドルを変えたあとも)は自分のメニュー。削除・フォローは Bluesky のセッションへ', (tester) async {
    final (c, mk, bs) = await pump(tester);
    expect(c.read(bundleViewProvider), isTrue);
    expect(c.read(currentAccountProvider), misskey);
    for (final body in ['Misskey の投稿', 'Bluesky の自分の投稿', 'ハンドルを変えたあとの投稿', 'ボブの投稿']) {
      expect(find.text(body), findsOneWidget, reason: body);
    }

    await openMenu(tester, 'Bluesky の自分の投稿');
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('フォロー'), findsNothing);
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(bs.sessions[bsky.key]!.deleted, ['at://did:plc:alice/app.bsky.feed.post/3own']);
    expect(mk.sessions[misskey.key]!.deleted, isEmpty);

    // ハンドルを変えた(DID は同じ)。
    await openMenu(tester, 'ハンドルを変えたあとの投稿');
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('報告'), findsNothing);
    c.read(overlayManagerProvider).close('post.menu');
    await tester.pumpAndSettle();

    // 他人(ボブ)の投稿: フォローは DID で、Bluesky のセッションへ。
    await openMenu(tester, 'ボブの投稿');
    expect(find.text('削除'), findsNothing);
    await tester.tap(find.text('フォロー'));
    await tester.pumpAndSettle();
    expect(bs.sessions[bsky.key]!.followed, ['did:plc:bob:true']);
    expect(mk.sessions[misskey.key]!.followed, isEmpty);
  });

  testWidgets('総合表示: Bluesky の人のページは、現在のアカウント(Misskey)ではなく Bluesky のアカウントで開く。自分のページは「自分」', (tester) async {
    final (c, mk, bs) = await pump(tester);
    // 作者の AccountId.key(bluesky:bsky.social:bob.bsky.social)はログイン中のアカウントではない。
    c.read(routerProvider).push('/user/${Uri.encodeComponent(bob.id)}', extra: bob);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    expect(bs.sessions[bsky.key]!.userRequests, contains(bob.id));
    expect(mk.sessions[misskey.key]!.userRequests, isEmpty, reason: 'Misskey のセッションで DID を引かない');
    expect(find.widgetWithText(RasqTogglePillButton, 'フォロー'), findsOneWidget);

    c.read(routerProvider).push('/user/${Uri.encodeComponent(aliceDid)}', extra: aliceRenamed);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RasqTogglePillButton, 'フォロー'), findsNothing, reason: 'DID が同じ = 自分');
  });

  group('アカウントページ (D-423)', () {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    testWidgets('Bluesky の投稿: PDS が違っても Bluesky のアカウントで操作できる。固定は … のメニューで、印は残る', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const author = {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'};
      // 連携はログインしたサーバー(bsky.social)で、ORGATE が渡す投稿の作者もそう。この端末のログインは自前の PDS。
      const linkKey = 'bluesky:bsky.social:alice.bsky.social';
      const viewer = AccountId(kind: SnsKind.bluesky, instance: 'pds.example', handle: 'alice.bsky.social');
      Map<String, Object?> wire(String rkey, String body) => {
            'id': 'at://did:plc:alice/app.bsky.feed.post/$rkey',
            'author': {'id': aliceDid, 'kind': 'bluesky', 'instance': 'bsky.social', 'handle': 'alice.bsky.social', 'displayName': 'アリス'},
            'createdAt': '2026-09-20T00:00:00Z',
            'body': body,
            'bodyFormat': 'plain',
            'visibility': 'public',
            'url': 'https://bsky.app/profile/alice.bsky.social/post/$rkey',
          };
      var pins = <Map<String, Object?>>[
        {'source': 'sns', 'ref': '$linkKey|at://did:plc:alice/app.bsky.feed.post/3a'},
      ];
      final puts = <Object?>[];
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        switch ('${req.method} $path') {
          case 'GET /me':
            return json(author);
          case 'GET /accounts/taro':
            return json({
              'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ',
              'snsAccounts': [{'kind': 'bluesky', 'instance': 'bsky.social', 'handle': 'alice.bsky.social', 'displayName': 'アリス', 'profileUrl': 'https://bsky.app/profile/alice.bsky.social'}],
            });
          case 'GET /accounts/taro/posts':
            return json({
              'source': 'rasq', 'limit': 3,
              'posts': [{'id': 'p1', 'author': author, 'body': 'RASQ の投稿', 'images': <Object>[], 'createdAt': '2026-09-21T00:00:00Z', 'queues': <Object>[]}],
              'snsPosts': [
                {'accountKey': linkKey, 'kind': 'bluesky', 'instance': 'bsky.social', 'createdAt': '2026-09-20T00:00:00Z', 'post': wire('3a', '固定した Bluesky の投稿')},
                {'accountKey': linkKey, 'kind': 'bluesky', 'instance': 'bsky.social', 'createdAt': '2026-09-19T00:00:00Z', 'post': wire('3b', 'ふつうの Bluesky の投稿')},
              ],
              'pins': pins,
            });
          case 'PUT /me/pins':
            final body = (jsonDecode(req.body) as Map)['pins'] as List;
            puts.add(body);
            pins = [for (final p in body) (p as Map).cast<String, Object?>()];
            return json({'pins': pins});
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({
          'sessions': [AccountSession(account: viewer, pluginId: 'test.bsky', token: bskyToken(aliceDid, viewer.handle), createdAt: DateTime(2026)).toJson()],
          'current': viewer.key,
        }),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(kind: SnsKind.bluesky, id: 'test.bsky', posts: (_) => const []))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push(Routes.rasqAccount('taro'));
      await tester.pumpAndSettle();
      expect(find.byType(RasqAccountPageScreen), findsOneWidget);

      // 行の固定のボタンは無い。固定した投稿の印は残る。
      expect(find.text('固定する'), findsNothing);
      expect(find.text('固定を外す'), findsNothing);
      expect(find.text('固定された投稿'), findsOneWidget);
      expect(find.byKey(const ValueKey('rasqPage.pinned.sns.$linkKey|at://did:plc:alice/app.bsky.feed.post/3a')), findsOneWidget);

      // PDS が違っても、Bluesky のアカウントで操作できる(アクションバーが出る)。
      final row = find.ancestor(of: find.text('ふつうの Bluesky の投稿'), matching: find.byType(PostRow)).first;
      expect(tester.widget<PostRow>(row).actions, isNotEmpty);
      expect(tester.widget<PostRow>(row).post.account, viewer);

      // … のメニュー: 自分の投稿(削除)と「固定する」。
      await openMenu(tester, 'ふつうの Bluesky の投稿');
      expect(find.text('削除'), findsOneWidget, reason: '本人の投稿');
      expect(find.text('フォロー'), findsNothing);
      await tester.tap(find.text('固定する'));
      await tester.pumpAndSettle();
      expect(puts.single, [
        {'source': 'sns', 'ref': '$linkKey|at://did:plc:alice/app.bsky.feed.post/3b'},
        {'source': 'sns', 'ref': '$linkKey|at://did:plc:alice/app.bsky.feed.post/3a'},
      ]);
      expect(find.text('固定された投稿'), findsNWidgets(2));

      // 固定した投稿の … は「固定を外す」。
      await openMenu(tester, '固定した Bluesky の投稿');
      await tester.tap(find.text('固定を外す'));
      await tester.pumpAndSettle();
      expect(puts.last, [
        {'source': 'sns', 'ref': '$linkKey|at://did:plc:alice/app.bsky.feed.post/3b'},
      ]);

      // RASQ の投稿も … のメニューで固定する。
      final rasqMenu = find.descendant(of: find.byKey(const ValueKey('rasqPost.p1')), matching: find.byTooltip('メニュー'));
      await tester.ensureVisible(rasqMenu);
      await tester.pumpAndSettle();
      await tester.tap(rasqMenu);
      await tester.pumpAndSettle();
      expect(find.text('削除'), findsOneWidget);
      await tester.tap(find.text('固定する'));
      await tester.pumpAndSettle();
      expect((puts.last as List).first, {'source': 'rasq', 'ref': 'p1'});
    });

    testWidgets('Bluesky の投稿をアカウントページに出す: ログインの鍵(JWT)は送らず、DID とハンドルだけ。RASQ リストに使うスイッチは出ない', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const key = 'bluesky:bsky.social:alice.bsky.social';
      final deposits = <Map<String, Object?>>[];
      var has = false;
      final mock = MockClient((req) async {
        final path = Uri.decodeComponent(req.url.path.replaceFirst('/api/v1', ''));
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
          case 'GET /me/sns-accounts':
            return json([
              {'accountKey': key, 'kind': 'bluesky', 'instance': 'bsky.social', 'handle': 'alice.bsky.social', 'displayName': 'アリス', 'visibility': 'auto', 'autoVisible': true, 'visible': true, 'verified': true, 'verifiedMethod': 'profile'},
            ]);
          case 'GET /me/sns-accounts/$key/token':
            return json({'accountKey': key, 'hasToken': has, 'postCount': has ? 2 : 0, 'collectionsAllowed': false});
          case 'PUT /me/sns-accounts/$key/token':
            deposits.add((jsonDecode(req.body) as Map).cast<String, Object?>());
            has = true;
            return json({'accountKey': key, 'hasToken': true, 'postCount': 2, 'collectionsAllowed': false});
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({
          'sessions': [AccountSession(account: bsky, pluginId: 'test.bsky', token: bskyToken(aliceDid, bsky.handle), createdAt: DateTime(2026)).toJson()],
          'current': bsky.key,
        }),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(kind: SnsKind.bluesky, id: 'test.bsky', posts: (_) => const []))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push('${Routes.settings}/rasq-profile');
      await tester.pumpAndSettle();
      final sw = find.byKey(const ValueKey('rasqProfile.snsPosts.$key'));
      expect(find.byType(RasqProfileEditScreen), findsOneWidget);
      await tester.scrollUntilVisible(sw, 200, scrollable: find.descendant(of: find.byType(RasqProfileEditScreen), matching: find.byType(Scrollable)).first);
      expect(find.descendant(of: sw, matching: find.textContaining('鍵は預けません')), findsOneWidget);
      await Scrollable.ensureVisible(tester.element(find.descendant(of: sw, matching: find.byType(Switch))), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: sw, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.text('Bluesky の投稿をアカウントページに出します'), findsOneWidget);
      await tester.tap(find.text('同意して出す'));
      await tester.pumpAndSettle();
      expect(deposits, hasLength(1));
      final sent = jsonDecode(deposits.single['token']! as String) as Map;
      expect(sent, {'did': aliceDid, 'handle': 'alice.bsky.social'});
      expect(deposits.single['token'], isNot(contains('Jwt')));
      expect(find.byKey(const ValueKey('rasqProfile.snsPosts.collections.$key')), findsNothing);
    });

    testWidgets('ほかの人のページ: 固定の項目は出ない', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const author = {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'};
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
          case 'GET /accounts/hanako':
            return json({...author, 'snsAccounts': <Object>[]});
          case 'GET /accounts/hanako/posts':
            return json({
              'source': 'rasq', 'limit': 3,
              'posts': [{'id': 'h1', 'author': author, 'body': 'ハナコの投稿', 'images': <Object>[], 'createdAt': '2026-09-21T00:00:00Z', 'queues': <Object>[]}],
              'pins': [{'source': 'rasq', 'ref': 'h1'}],
            });
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push(Routes.rasqAccount('hanako'));
      await tester.pumpAndSettle();
      expect(find.text('固定された投稿'), findsOneWidget, reason: '印はほかの人にも見える');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.h1')), matching: find.byTooltip('メニュー')));
      await tester.pumpAndSettle();
      expect(find.text('リンクをコピー'), findsOneWidget);
      expect(find.text('固定する'), findsNothing);
      expect(find.text('固定を外す'), findsNothing);
    });
  });
}
