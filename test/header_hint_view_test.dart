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
import 'package:rasq_client/features/profile/header_hint/header_hint_codec.dart';
import 'package:rasq_client/features/profile/header_hint/header_hint_reader.dart';
import 'package:rasq_client/features/profile/profile_edit_screen.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// ヘッダーの手がかり (D-591): SNS のユーザーページで、ヘッダーから読めたら by-sns を呼ばずにチップ。押すとアカウントページ
/// (つないでいなければ注意)。読めない / 写したヘッダーなら今まで通り by-sns。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  const bob = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob');
  final bobUser = UserSummary(id: 'bob', account: bob, displayName: 'ボブ');
  final posts = [Post(id: 'p1', account: fakeSession().account, author: bobUser, createdAt: DateTime(2026, 9, 1), body: 'こんにちは')];
  final banner = Uri.parse('https://example.test/files/banner.jpg');

  setUp(() => fakeBanners['bob'] = banner);
  tearDown(fakeBanners.clear);

  Future<ProviderContainer> pump(WidgetTester tester, MockClient mock, HeaderHint? hint) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        headerHintProvider.overrideWith((ref, url) async => url == banner.toString() ? hint : null),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  MockClient central(List<String> asked, {List<Map<String, Object?>> tiles = const []}) => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        asked.add('${req.method} $path');
        if (path == '/accounts/by-sns') return json({'account': {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'}, 'snsAccounts': tiles});
        if (path == '/accounts/taro') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'snsAccounts': tiles});
        if (path == '/accounts/taro/posts') return json({'posts': [], 'limit': 3});
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });

  HeaderHint hintFor(String accountKey, {String handle = 'taro'}) => headerHintUnpack(headerHintPack(handle, accountKey))!;

  testWidgets('ヘッダーから読めた: by-sns を呼ばずに @handle のチップ。押すとアカウントページ(つないでいれば注意なし)', (tester) async {
    final asked = <String>[];
    final c = await pump(tester, central(asked, tiles: [{'kind': 'misskey', 'instance': 'example.test', 'handle': 'bob'}]), hintFor(bob.key));
    c.read(routerProvider).push('/user/bob', extra: bobUser);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    final chip = find.byKey(const ValueKey('snsProfile.rasq.header'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('@taro')), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('ヘッダーから')), findsOneWidget);
    expect(find.byKey(const ValueKey('snsProfile.rasq')), findsNothing);
    // 誰のページを見たかを Central へ送らない。
    expect(asked.where((a) => a.contains('/accounts/')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('snsProfile.rasq.header.open')));
    await tester.pumpAndSettle();
    expect(find.byType(RasqAccountPageScreen), findsOneWidget);
    expect(tester.widget<RasqAccountPageScreen>(find.byType(RasqAccountPageScreen)).fromSns, bob.key);
    expect(asked, contains('GET /accounts/taro'));
    expect(find.byKey(const ValueKey('rasqPage.headerHint.unlinked')), findsNothing);
    expect(asked.where((a) => a.contains('by-sns')), isEmpty);
  });

  testWidgets('ヘッダーの RASQ アカウントが、見ていた SNS アカウントをつないでいない → アカウントページに注意', (tester) async {
    final asked = <String>[];
    final c = await pump(tester, central(asked, tiles: [{'kind': 'mastodon', 'instance': 'masto.example', 'handle': 'someone'}]), hintFor(bob.key));
    c.read(routerProvider).push('/user/bob', extra: bobUser);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('snsProfile.rasq.header.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqPage.headerHint.unlinked')), findsOneWidget);
    expect(find.text('見ていた SNS アカウントとつながっていません'), findsOneWidget);
    expect(find.textContaining('@bob@example.test'), findsWidgets);
  });

  testWidgets('ほかの人のために書いたヘッダー(写したもの) / 手がかり無し: 今まで通り by-sns', (tester) async {
    for (final hint in [hintFor('misskey:example.test:alice'), null]) {
      final asked = <String>[];
      final c = await pump(tester, central(asked, tiles: [{'kind': 'misskey', 'instance': 'example.test', 'handle': 'bob'}]), hint);
      c.read(routerProvider).push('/user/bob', extra: bobUser);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('snsProfile.rasq.header')), findsNothing);
      expect(find.byKey(const ValueKey('snsProfile.rasq')), findsOneWidget);
      expect(asked.where((a) => a.contains('by-sns')), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('プロフィール編集(書く側)', () {
    Future<void> openEdit(WidgetTester tester, {required bool show, required bool linked}) async {
      final me = fakeSession().account;
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'Taro', 'displayName': 'タロ', 'showLinksOnSnsProfiles': show});
        if (req.method == 'GET' && path == '/me/sns-accounts') {
          return json([
            if (linked) {'accountKey': me.key, 'kind': me.kind.name, 'instance': me.instance, 'handle': me.handle, 'visibility': 'show', 'visible': true},
          ]);
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': me.key}),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'd', 'token': 't', 'accountId': 'acc-1'}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          // 自分のプロフィールを引けるように、自分の投稿を 1 つ。
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (a) => [Post(id: 'm1', account: a, author: UserSummary(id: 'me', account: a, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: 'やあ')]))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(RasqApp))).read(routerProvider).push(Routes.profileEdit);
      await tester.pumpAndSettle();
    }

    testWidgets('「アカウントを表示」がオンで、この SNS アカウントをつないで出している → 入れるかのスイッチ(既定オン)', (tester) async {
      await openEdit(tester, show: true, linked: true);
      final sw = find.byKey(const ValueKey('profileEdit.headerHint.switch'));
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      await tester.scrollUntilVisible(sw, 200, scrollable: find.descendant(of: find.byType(ProfileEditScreen), matching: find.byType(Scrollable)).first);
      expect(sw, findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: sw, matching: find.byType(Switch))).value, isTrue);
      expect(find.textContaining('@Taro'), findsWidgets);
    });

    testWidgets('オフ / つないでいない → 出さない', (tester) async {
      for (final (show, linked) in [(false, true), (true, false)]) {
        await openEdit(tester, show: show, linked: linked);
        expect(find.byType(ProfileEditScreen), findsOneWidget);
        // 欄があるはずの所(自己紹介の上)まで送ってから見る。
        await tester.drag(find.descendant(of: find.byType(ProfileEditScreen), matching: find.byType(Scrollable)).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profileEdit.headerHint')), findsNothing, reason: 'show $show / linked $linked');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
