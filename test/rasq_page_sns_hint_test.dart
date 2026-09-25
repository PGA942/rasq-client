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
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ アカウントページの「投稿」タブ (D-316): SNS の投稿は、本人がその SNS のトークンを預けたときだけ出る (S-027)。
/// 自分のページで、SNS アカウントはつないであるのに SNS の投稿が 1 件も無ければ、預ける画面への入口を出す。
/// ほかの人が見るときは出さない。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  const tile = {'accountKey': 'misskey:mk.example:taro', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'displayName': 'タロ@みすきー', 'visibility': 'auto', 'autoVisible': true, 'visible': true};
  Map<String, Object?> snsPost(String id, String body) => {
        'accountKey': 'misskey:mk.example:taro',
        'kind': 'misskey',
        'instance': 'mk.example',
        'createdAt': '2026-09-20T00:00:00Z',
        'post': {
          'id': id,
          'author': {'id': 'u1', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'displayName': 'タロ'},
          'createdAt': '2026-09-20T00:00:00Z',
          'body': body,
          'visibility': 'public',
          'url': 'https://mk.example/notes/$id',
        },
      };

  /// [viewer] = 見ている人の RASQ アカウント(taro = 本人)。
  Future<ProviderContainer> pump(WidgetTester tester, {required String viewer, bool linked = true, List<Map<String, Object?>> sns = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-$viewer', 'handle': viewer, 'displayName': viewer});
        case 'GET /accounts/taro':
          return json({'id': 'acc-taro', 'handle': 'taro', 'displayName': 'タロ', 'snsAccounts': [if (linked) tile]});
        case 'GET /accounts/taro/posts':
          return json({
            'source': 'rasq',
            'limit': 3,
            'posts': [
              {'id': 'p1', 'author': {'id': 'acc-taro', 'handle': 'taro', 'displayName': 'タロ'}, 'body': 'RASQ の投稿', 'createdAt': '2026-09-19T00:00:00Z'},
            ],
            'snsPosts': sns,
          });
        case 'GET /me/sns-accounts':
          return json([if (linked) tile]);
      }
      if (req.method == 'GET' && path.endsWith('/token')) return json({'accountKey': tile['accountKey'], 'hasToken': false, 'postCount': 0});
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'd', 'tokens': {'acc-$viewer': 'tok'}, 'currentAccountId': 'acc-$viewer'}),
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
    c.read(routerProvider).push(Routes.rasqAccount('taro'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqAccountPageScreen), findsOneWidget);
    return c;
  }

  const hint = ValueKey('rasqPage.posts.snsHint');

  testWidgets('自分のページ: SNS をつないでいて SNS の投稿が無い → 案内と、預ける画面への入口。案内の文も「今後の対応」ではない', (tester) async {
    await pump(tester, viewer: 'taro');
    expect(find.text('RASQ の投稿'), findsOneWidget);
    final note = tester.widget<Text>(find.byKey(const ValueKey('rasqPage.posts.note')));
    expect(note.data, isNot(contains('今後の対応')));
    expect(note.data, contains('預けると'));
    expect(find.byKey(hint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rasqPage.posts.snsHint.open')));
    await tester.pumpAndSettle();
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    // 預けるスイッチ(S-027)がある画面。
    expect(find.text('投稿もアカウントページに出す', skipOffstage: false), findsOneWidget);
  });

  testWidgets('自分のページ: SNS の投稿が出ていれば、案内は出さない', (tester) async {
    await pump(tester, viewer: 'taro', sns: [snsPost('s1', 'みすきーの投稿')]);
    expect(find.text('みすきーの投稿'), findsOneWidget);
    expect(find.text('RASQ の投稿'), findsOneWidget);
    expect(find.byKey(hint), findsNothing);
  });

  testWidgets('自分のページ: SNS をつないでいなければ、案内は出さない', (tester) async {
    await pump(tester, viewer: 'taro', linked: false);
    expect(find.byKey(const ValueKey('rasqPage.posts.note')), findsOneWidget);
    expect(find.byKey(hint), findsNothing);
  });

  testWidgets('ほかの人が見るとき: 案内も上限の注記も出さない(RASQ の投稿は出る)', (tester) async {
    await pump(tester, viewer: 'hanako');
    expect(find.text('RASQ の投稿'), findsOneWidget);
    expect(find.byKey(hint), findsNothing);
    expect(find.byKey(const ValueKey('rasqPage.posts.note')), findsNothing);
  });
}
