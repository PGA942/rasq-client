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
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ アカウントのプロフィール編集 (D-269 / S-020)。サーバーは MockClient で Central の口をまねる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  test('モデル: 追加の項目を読む / エラーの言い換え / content-type の目安', () {
    final a = RasqAccount.fromJson({'id': 'a', 'handle': 'taro', 'displayName': 'タロ', 'bio': 'こんにちは', 'bannerUrl': 'https://c.test/b.jpg', 'location': '東京', 'birthday': '04-01', 'links': [{'label': 'サイト', 'url': 'https://example.com/'}]});
    expect((a.bio, a.bannerUrl.toString(), a.location, a.birthday), ('こんにちは', 'https://c.test/b.jpg', '東京', '04-01'));
    expect(a.links.single, (label: 'サイト', url: 'https://example.com/'));
    expect(RasqAccount.fromJson(const {'id': 'a', 'handle': 'x', 'displayName': ''}).links, isEmpty);
    expect(rasqProfileMessage(OrgateException(ErrorCode.tryParse('409')!, 'that handle is taken')), 'そのハンドルは使われています');
    expect(rasqProfileMessage(OrgateException(ErrorCode.tryParse('400')!, 'birthday must be YYYY-MM-DD or MM-DD')), contains('誕生日'));
    expect(profileImageContentType('a.PNG', null), 'image/png');
    expect(profileImageContentType('photo', 'image/webp'), 'image/webp');
    expect(profileImageContentType('photo.heic', 'application/octet-stream'), 'image/jpeg');
  });

  testWidgets('いまの値が入った状態で開く → 項目を直して「決定」→ PATCH /me(空 = 消す、リンクは置き換え)→ 戻る。サーバーの 400 は言い換えて出す', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'bio': '前の自己紹介', 'location': '大阪', 'birthday': '1990-04-01', 'links': [{'label': '旧サイト', 'url': 'https://old.example/'}], 'createdAt': '2026-09-01T00:00:00Z'};
    final patches = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json(me);
      if (req.method == 'PATCH' && path == '/me') {
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        patches.add(body);
        if (body['birthday'] == '13-99') return json({'error': {'code': '400', 'message': 'birthday must be YYYY-MM-DD or MM-DD'}}, 400);
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
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    // いまの値が入っている。
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('rasqProfile.name')), matching: find.byType(TextField))).controller!.text, 'タロ');
    expect(find.text('前の自己紹介'), findsOneWidget);
    expect(find.text('2026年9月'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rasqProfile.link.0.label'))).controller!.text, '旧サイト');

    // おかしな誕生日 → サーバーの 400 を言い換えて出し、画面に留まる。
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('rasqProfile.birthday')), matching: find.byType(TextField)), '13-99');
    await tester.tap(find.byKey(const ValueKey('rasqProfile.save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqProfile.error')), findsOneWidget);
    expect(find.textContaining('誕生日は'), findsOneWidget);
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);

    // 直す: 誕生日を消す(空)、場所を変える、リンクを差し替える。ハンドルは変えていないので送らない。
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('rasqProfile.birthday')), matching: find.byType(TextField)), '');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('rasqProfile.location')), matching: find.byType(TextField)), '東京');
    await tester.enterText(find.byKey(const ValueKey('rasqProfile.link.0.label')), 'サイト');
    await tester.enterText(find.byKey(const ValueKey('rasqProfile.link.0.url')), 'https://example.com/');
    await tester.tap(find.byKey(const ValueKey('rasqProfile.save')));
    await tester.pumpAndSettle();
    expect(patches.last, {'displayName': 'タロ', 'bio': '前の自己紹介', 'location': '東京', 'birthday': '', 'links': [{'label': 'サイト', 'url': 'https://example.com/'}]});
    expect(find.byType(RasqProfileEditScreen), findsNothing);
    expect(c.read(orgateAccountProvider).value!.location, '東京');
  });
}
