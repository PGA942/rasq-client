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
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/profile/rasq_links_on_sns_profile.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// SNS のプロフィールにも、つないだアカウントを出す (D-312)。サーバーは MockClient で Central の口をまねる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  Map<String, Object?> tile(String kind, String instance, String handle, {String? name, String? url}) =>
      {'kind': kind, 'instance': instance, 'handle': handle, 'displayName': ?name, 'profileUrl': ?url};

  const bob = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob');

  group('省く規則', () {
    RasqSnsOwner owner(List<Map<String, Object?>> tiles) => RasqSnsOwner.fromJson({'account': {'id': 'a', 'handle': 'taro', 'displayName': 'タロ'}, 'snsAccounts': tiles})!;
    List<String> keep(List<Map<String, Object?>> tiles, {String? bio, List<String> extra = const []}) =>
        [for (final t in snsProfileOtherAccounts(owner(tiles), viewing: bob, bio: bio, extraTexts: extra)) '${t.kind}:${t.instance}:${t.handle}'];

    test('見ているアカウント自身は出さない(大小文字は区別しない)', () {
      expect(keep([tile('misskey', 'Example.test', 'Bob'), tile('mastodon', 'masto.example', 'bob')]), ['mastodon:masto.example:bob']);
    });

    test('自己紹介に書いてあるアカウントは出さない: @handle@instance / URL / ドメイン形 / 同じサーバーの @handle', () {
      final tiles = [
        tile('mastodon', 'masto.example', 'bob'),
        tile('mastodon', 'other.example', 'bob2', url: 'https://other.example/@bob2'),
        tile('bluesky', 'bsky.social', 'bob.bsky.social'),
        tile('misskey', 'example.test', 'bobsub'),
        tile('misskey', 'far.example', 'bobby'),
      ];
      expect(keep(tiles), hasLength(5));
      expect(keep(tiles, bio: 'Mastodon は @BOB@masto.example です'), isNot(contains('mastodon:masto.example:bob')));
      expect(keep(tiles, bio: 'こっちも https://other.example/@bob2/'), isNot(contains('mastodon:other.example:bob2')));
      expect(keep(tiles, bio: 'Bluesky: bob.bsky.social'), isNot(contains('bluesky:bsky.social:bob.bsky.social')));
      expect(keep(tiles, bio: 'サブ垢は@bobsubです'), isNot(contains('misskey:example.test:bobsub')));
      // 補足の項目(fields)も自己紹介と同じに見る。
      expect(keep(tiles, extra: ['Misskey https://far.example/@bobby']), isNot(contains('misskey:far.example:bobby')));
    });

    test('似ているだけのものは省かない', () {
      final tiles = [tile('mastodon', 'masto.example', 'bob'), tile('misskey', 'far.example', 'bobby'), tile('misskey', 'example.test', 'bobsub')];
      // 別のサーバーの同じ名前 / 長い名前の頭 / 別のサーバーでの @handle。
      expect(keep(tiles, bio: '@bob@masto.example.jp と @bobbyx@far.example、@bobsub@elsewhere.example'), ['mastodon:masto.example:bob', 'misskey:far.example:bobby', 'misskey:example.test:bobsub']);
      // よそのサーバーのアカウントは、@handle だけでは決められない。
      expect(keep(tiles, bio: '@bobby'), contains('misskey:far.example:bobby'));
    });

    test('モデル: account が無ければ null、http(s) でない URL は捨てる', () {
      expect(RasqSnsOwner.fromJson(const {'snsAccounts': []}), isNull);
      final o = RasqSnsOwner.fromJson({'account': {'id': 'a', 'handle': 'taro', 'displayName': '', 'avatarUrl': 'javascript:x'}, 'snsAccounts': [tile('misskey', 'a.example', 'x', url: 'ftp://x')]})!;
      expect((o.account.label, o.account.avatarUrl, o.snsAccounts.single.profileUrl), ('taro', null, null));
    });

    test('RasqAccount: 設定は既定で出す', () {
      expect(RasqAccount.fromJson(const {'id': 'a', 'handle': 'x', 'displayName': ''}).showLinksOnSnsProfiles, isTrue);
      expect(RasqAccount.fromJson(const {'id': 'a', 'handle': 'x', 'displayName': '', 'showLinksOnSnsProfiles': false}).showLinksOnSnsProfiles, isFalse);
    });
  });

  group('ユーザーページ', () {
    final bobUser = UserSummary(id: 'bob', account: bob, displayName: 'ボブ', bio: 'Mastodon は @bob@masto.example にいます');
    final posts = [Post(id: 'p1', account: fakeSession().account, author: bobUser, createdAt: DateTime(2026, 9, 1), body: 'こんにちは')];

    Future<ProviderContainer> pump(WidgetTester tester, MockClient mock, {Map<String, String> extraStorage = const {}}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        ...extraStorage,
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    testWidgets('つないでいる人: 「RASQ アカウント」と、ほかのアカウント(見ているもの / 自己紹介にあるものは省く)。トークンなしで聞き、2 度目は控えから', (tester) async {
      final lookups = <http.BaseRequest>[];
      String? meAuth;
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        if (req.method == 'GET' && path == '/me') {
          meAuth = req.headers['authorization'];
          return json({'id': 'viewer', 'handle': 'viewer', 'displayName': '見る人'});
        }
        if (req.method == 'GET' && path == '/accounts/by-sns') {
          lookups.add(req);
          if (req.url.queryParameters['key'] != 'misskey:example.test:bob') return json({'error': {'code': '404', 'message': 'no'}}, 404);
          return json({
            'account': {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'},
            'snsAccounts': [
              tile('misskey', 'example.test', 'bob', name: 'ボブ本人'),
              tile('mastodon', 'masto.example', 'bob', name: 'ボブのマストドン'),
              tile('bluesky', 'bsky.social', 'bob.bsky.social', name: 'ボブ空', url: 'https://bsky.app/profile/bob.bsky.social'),
            ],
          });
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final c = await pump(tester, mock, extraStorage: {OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'd', 'token': 'viewer-token', 'accountId': 'viewer'})});
      c.read(routerProvider).push('/user/bob', extra: bobUser);
      await tester.pumpAndSettle();
      expect(find.byType(UserPageScreen), findsOneWidget);
      final section = find.byKey(const ValueKey('snsProfile.rasq'));
      expect(section, findsOneWidget);
      expect(find.descendant(of: section, matching: find.text('RASQ アカウント')), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text('タロ')), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text('@taro')), findsOneWidget);
      // 見ているアカウント自身と、自己紹介にある Mastodon は出さない。Bluesky だけ。
      expect(find.byKey(const ValueKey('rasqPage.tile.bluesky:bsky.social:bob.bsky.social')), findsOneWidget);
      expect(find.byKey(const ValueKey('rasqPage.tile.misskey:example.test:bob')), findsNothing);
      expect(find.byKey(const ValueKey('rasqPage.tile.mastodon:masto.example:bob')), findsNothing);
      // 見ている人のトークンは付けない(ほかの口には付いている)。
      expect(meAuth, 'Bearer viewer-token');
      expect(lookups.single.headers['authorization'], isNull);

      // タップ → アカウントページ。戻ってもう一度開いても、聞き直さない(控え)。
      await tester.tap(find.byKey(const ValueKey('snsProfile.rasq.open')));
      await tester.pumpAndSettle();
      expect(find.byType(RasqAccountPageScreen), findsOneWidget);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/user/bob', extra: bobUser);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('snsProfile.rasq')), findsOneWidget);
      expect(lookups, hasLength(1));
    });

    testWidgets('つないでいない / 出していない(404)、Central が落ちている: 何も出さない', (tester) async {
      for (final fail in [() => json({'error': {'code': '404', 'message': 'no'}}, 404), () => throw http.ClientException('down')]) {
        var asked = 0;
        final mock = MockClient((req) async {
          if (req.url.path.endsWith('/accounts/by-sns')) {
            asked++;
            return fail();
          }
          return json({'error': {'code': '404', 'message': 'not found'}}, 404);
        });
        final c = await pump(tester, mock);
        c.read(routerProvider).push('/user/bob', extra: bobUser);
        await tester.pumpAndSettle();
        expect(find.byType(UserPageScreen), findsOneWidget);
        expect(find.text('ボブ'), findsWidgets);
        expect(asked, 1);
        expect(find.byType(RasqLinksOnSnsProfile), findsOneWidget);
        expect(find.byKey(const ValueKey('snsProfile.rasq')), findsNothing);
        expect(find.text('RASQ アカウント'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('プロフィール編集: 「SNS のプロフィールにも、つないだアカウントを出す」を切る → すぐ PATCH /me', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'showLinksOnSnsProfiles': true};
    final patches = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json(me);
      if (req.method == 'PATCH' && path == '/me') {
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        // 表示の言語の同期 (D-484: ORGATE へ PATCH /me {locale}。このテストは 1 つの URL で兼ねる)は数えない。
        if (body.keys.toSet().difference({'locale'}).isNotEmpty) patches.add(body);
        me.addAll(body);
        return json(me);
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
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
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
    final toggle = find.byKey(const ValueKey('rasqProfile.showOnSns'));
    await tester.scrollUntilVisible(toggle, 200, scrollable: find.descendant(of: find.byType(RasqProfileEditScreen), matching: find.byType(Scrollable)).first);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isTrue);
    await tester.tap(find.descendant(of: toggle, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(patches.single, {'showLinksOnSnsProfiles': false});
    expect(c.read(orgateAccountProvider).value!.showLinksOnSnsProfiles, isFalse);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isFalse);
  });
}
