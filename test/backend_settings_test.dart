import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
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
}
