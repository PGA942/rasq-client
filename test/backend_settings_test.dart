import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/developer_mode.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ サーバーの接続先 (D-239): 入力を正す、接続テストは入力中の値で試す(保存前でも「未設定」にならない)。
void main() {
  test('normalizeServerUrl: スキームの補完(IP / localhost / ポート付きは http、ドメインは https)、全角と末尾の / を直す', () {
    expect(normalizeServerUrl('http://192.168.3.14:8080').toString(), 'http://192.168.3.14:8080');
    expect(normalizeServerUrl(' http://192.168.3.14:8080/ ').toString(), 'http://192.168.3.14:8080');
    expect(normalizeServerUrl('192.168.3.14:8080').toString(), 'http://192.168.3.14:8080');
    expect(normalizeServerUrl('localhost:8080').toString(), 'http://localhost:8080');
    expect(normalizeServerUrl('central.rasq.example').toString(), 'https://central.rasq.example');
    expect(normalizeServerUrl('http：／／192．168.3.14:8080').toString(), 'http://192.168.3.14:8080');
    expect(normalizeServerUrl('https://central.example/api/').toString(), 'https://central.example/api');
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://x.example'), isNull);
    expect(normalizeServerUrl('://'), isNull);
  });

  testWidgets('接続テストは保存前の入力でも試す: スキーム無しの入力は補って保存、「未設定」にはならない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push('/settings/server');
    await tester.pumpAndSettle();
    expect(c.read(centralBaseUrlProvider), isNull);
    await tester.enterText(find.byKey(const ValueKey('backend.central')), '192.168.3.14:8080');
    await tester.tap(find.byKey(const ValueKey('backend.test')));
    await tester.pumpAndSettle();
    // 入力は正されて保存され、接続先として有効になる(テスト環境の HTTP は 400 なので「接続できませんでした」)。
    expect(c.read(centralBaseUrlProvider).toString(), 'http://192.168.3.14:8080');
    expect((await storage.read('backend.v1'))!, contains('http://192.168.3.14:8080'));
    final probe = tester.widget<Text>(find.byKey(const ValueKey('backend.probe'))).data!;
    expect(probe, isNot(contains('設定されていません')));
    expect(probe, contains('http://192.168.3.14:8080'));
    // 解釈できない入力は保存しない。
    await tester.enterText(find.byKey(const ValueKey('backend.central')), 'ftp://x');
    await tester.tap(find.byKey(const ValueKey('backend.save')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('backend.probe'))).data, contains('接続先を解釈できません'));
    expect(c.read(centralBaseUrlProvider).toString(), 'http://192.168.3.14:8080');
  });

  testWidgets('接続テスト: RASQ アカウントが未作成(/me が 401)でも、サーバーへ届いていれば「接続 OK」(D-240)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    var storeKeyOk = true;
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (path == '/store-key') return storeKeyOk ? json({'algorithm': 'ed25519', 'publicKey': 'AAAABBBBCCCCDDDDEEEE'}) : json({'error': {'code': '500', 'message': 'boom'}}, 500);
      return json({'error': {'code': '401', 'message': 'valid bearer token required'}}, 401);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push('/settings/server');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backend.test')));
    await tester.pumpAndSettle();
    var probe = tester.widget<Text>(find.byKey(const ValueKey('backend.probe'))).data!;
    expect(probe, contains('接続 OK'));
    expect(probe, contains('未作成'));
    expect(probe, isNot(contains('接続できませんでした')));
    // 未作成のときは、この画面から RASQ アカウントを開ける。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('backend.account')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('backend.account')), findsOneWidget);
    // 公開の口が落ちているときだけ「接続できませんでした」。
    storeKeyOk = false;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('backend.test')), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('backend.test')));
    await tester.pumpAndSettle();
    probe = tester.widget<Text>(find.byKey(const ValueKey('backend.probe'))).data!;
    expect(probe, contains('接続できませんでした'));
  });

  testWidgets('テスト用の接続先 (D-360 / D-398): 入れると SNS の差し替えと Central / ORGATE が変わり、外すと元に戻る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(() => setRuntimeDevSnsBase(''));
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      'backend.v1': jsonEncode({'centralUrl': 'https://central.example', 'baseUrl': 'https://orgate.example'}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    // テスト用の接続先は開発者モードのときだけ出す (D-393)。
    await c.read(settingsAreaProvider(developerModeArea).notifier).set('enabled', true);
    c.read(routerProvider).push('/settings/server');
    await tester.pumpAndSettle();
    expect(devSnsBaseFor('misskey.rasq.test'), isNull);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('backend.testAddress')), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('backend.testAddress')), '100.64.1.2');
    await tester.tap(find.byKey(const ValueKey('backend.testEndpoints')));
    await tester.pumpAndSettle();
    expect(devSnsBaseFor('misskey.rasq.test').toString(), 'http://100.64.1.2:9101');
    expect(devSnsBaseFor('bsky.rasq.test').toString(), 'http://100.64.1.2:9103');
    expect(snsUri('mstdn.rasq.test', '/api/v1/instance').toString(), 'http://100.64.1.2:9102/api/v1/instance');
    expect(c.read(centralBaseUrlProvider).toString(), 'http://100.64.1.2:8080');
    // ログインは ORGATE (D-398): デモの ORGATE は 8081。
    expect(c.read(orgateBaseUrlProvider).toString(), 'http://100.64.1.2:8081');
    await tester.tap(find.byKey(const ValueKey('backend.testEndpoints')));
    await tester.pumpAndSettle();
    expect(devSnsBaseFor('misskey.rasq.test'), isNull);
    expect(c.read(centralBaseUrlProvider).toString(), 'https://central.example');
    expect(c.read(orgateBaseUrlProvider).toString(), 'https://orgate.example');
  });
}
