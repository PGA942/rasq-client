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
import 'package:rasq_design/rasq_design.dart' show RasqSwitchListTile;
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 預けた鍵の目的を分ける (D-373 / S-054、規約案 02 第 4 項 / PRIV-02): 投稿の表示のために預けた鍵を RASQ リストにも使うのは、
/// 別のスイッチで、確認のあとだけ(既定はオフ)。預けていなければスイッチは出ない。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  const tile = {'accountKey': 'misskey:mk.example:taro', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'displayName': 'タロ@みすきー', 'visibility': 'auto', 'autoVisible': true, 'visible': true};

  Future<List<Object?>> pump(WidgetTester tester, {required bool hasToken}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final puts = <Object?>[];
    var allowed = false;
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-taro', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'GET' && path == '/me/sns-accounts') return json([tile]);
      if (req.method == 'PUT' && path.endsWith('/token/collections')) {
        final b = jsonDecode(req.body) as Map;
        puts.add(b['allowed']);
        allowed = b['allowed'] == true;
        return json({'accountKey': tile['accountKey'], 'hasToken': true, 'postCount': 3, 'collectionsAllowed': allowed});
      }
      if (req.method == 'GET' && path.endsWith('/token')) return json({'accountKey': tile['accountKey'], 'hasToken': hasToken, 'postCount': hasToken ? 3 : 0, 'collectionsAllowed': allowed});
      if (req.method == 'GET') return json([]);
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'd', 'tokens': {'acc-taro': 'tok'}, 'currentAccountId': 'acc-taro'}),
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
    c.read(routerProvider).push('/settings/rasq-profile');
    await tester.pumpAndSettle();
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    return puts;
  }

  const key = ValueKey('rasqProfile.snsPosts.collections.misskey:mk.example:taro');

  testWidgets('預けていなければ、RASQ リストに使うスイッチは出ない', (tester) async {
    await pump(tester, hasToken: false);
    expect(find.byKey(key, skipOffstage: false), findsNothing);
  });

  testWidgets('預けていれば別のスイッチ(既定オフ)。入れるときは確認のあとだけ、切るのはすぐ', (tester) async {
    final puts = await pump(tester, hasToken: true);
    await tester.scrollUntilVisible(find.byKey(key), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.widget<RasqSwitchListTile>(find.byKey(key)).value, isFalse);
    // 確認で「やめる」なら送らない。
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.text('預けた鍵を RASQ リストにも使います'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(puts, isEmpty);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して使う'));
    await tester.pumpAndSettle();
    expect(puts, [true]);
    expect(tester.widget<RasqSwitchListTile>(find.byKey(key)).value, isTrue);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(puts, [true, false]);
  });
}
