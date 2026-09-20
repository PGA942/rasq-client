import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// コンポーザーの RASQ 指定 (D-271): バンドルタイルの RASQ アカウントの行を長押し → RASQ アカウントとして投稿。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  testWidgets('長押しで RASQ 指定 → 送信は POST /me/posts(SNS には投稿しない)。SNS の行を選ぶと解除', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'POST' && path == '/me/posts') {
        sent.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        return json({'id': 'p1', 'body': 'x'}, 201);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final plugin = FakeSnsPlugin(posts: MockData.timeline);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.sns')), findsOneWidget);
    // ピル → バンドルタイル → RASQ アカウントの行を長押し。
    await tester.tap(find.byKey(const ValueKey('composer.pill.sns')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('composer.rasqRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'RASQ からこんにちは');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(sent.single, {'body': 'RASQ からこんにちは'});
    expect(find.text('RASQ に投稿しました'), findsOneWidget);
  });
}
