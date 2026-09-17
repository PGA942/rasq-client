import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/notify_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/settings/notify_token_screen.dart';
import 'package:rasq_client/features/settings/settings_sections.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 通知専用のアクセストークン (D-239 / Central S-014): 発行 → 端末に保存 + プッシュ登録 → テスト通知を受信箱から
/// 通知トークンで読み戻す → 配下トークン → 失効。サーバーは MockClient で Central の口をまねる。
void main() {
  test('設定の行き先は通知トークンの画面、ダミーのプッシュ端末トークンは dummy: で始まる', () {
    expect(settingsSections['notifications']!.rows[1].route, Routes.settingsNotifyToken);
    expect(dummyPushToken(), startsWith('dummy:'));
    expect(dummyPushToken(), isNot(dummyPushToken()));
  });

  testWidgets('発行 → テスト通知 → 配下トークン → 失効', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Central のまね。
    final tokens = <Map<String, Object?>>[];
    final devices = <Map<String, Object?>>[];
    final outbox = <Map<String, Object?>>[];
    final auths = <String, String?>{};
    var seq = 0;
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      auths['${req.method} $path'] = req.headers['authorization'];
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'rasq_tester', 'displayName': 'テスター', 'createdAt': '2026-09-01T00:00:00Z'});
        case 'GET /me/notify/tokens':
          return json(tokens);
        case 'POST /me/notify/tokens':
          final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
          seq++;
          final t = {'id': 'tok-$seq', 'parentId': b['parentId'], 'label': b['label'], 'scopes': b['scopes'] ?? (b['parentId'] == null ? ['notify'] : ['macro']), 'createdAt': '2026-09-17T00:00:00Z', 'lastUsedAt': null};
          tokens.add(t);
          return json({...t, 'token': 'raw-$seq'}, 201);
        case 'GET /me/notify/devices':
          return json(devices);
        case 'PUT /me/notify/devices':
          final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
          devices
            ..removeWhere((d) => d['deviceId'] == b['deviceId'])
            ..add({'deviceId': b['deviceId'], 'platform': b['platform'], 'tokenId': b['tokenId'], 'createdAt': '2026-09-17T00:00:00Z', 'updatedAt': '2026-09-17T00:00:00Z', '_push': b['pushToken']});
          return json(devices.last);
        case 'POST /me/notify/test':
          outbox.insert(0, {'id': 'n-${outbox.length + 1}', 'kind': 'test', 'title': 'RASQ のテスト通知', 'body': '', 'payload': <String, Object?>{}, 'status': 'dummy', 'devices': devices.length, 'createdAt': '2026-09-17T00:00:01Z', 'deliveredAt': '2026-09-17T00:00:01Z'});
          return json(outbox.first, 201);
        case 'GET /notify/outbox':
          if (req.headers['authorization'] != 'Bearer raw-1') return json({'error': {'code': '401', 'message': 'valid notification token required'}}, 401);
          return json(outbox);
      }
      if (req.method == 'DELETE' && path.startsWith('/me/notify/tokens/')) {
        final id = path.split('/').last;
        tokens.removeWhere((t) => t['id'] == id || t['parentId'] == id);
        return http.Response('', 204);
      }
      if (req.method == 'DELETE' && path.startsWith('/me/notify/devices/')) {
        devices.removeWhere((d) => d['deviceId'] == Uri.decodeComponent(path.split('/').last));
        return http.Response('', 204);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
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
    c.read(routerProvider).push(Routes.settingsNotifyToken);
    await tester.pumpAndSettle();
    expect(find.byType(NotifyTokenScreen), findsOneWidget);
    expect(find.text('未発行'), findsOneWidget);
    // 発行 → 端末に保存 + この端末をプッシュ登録(ダミーの端末トークン、端末 id は RASQ アカウントと同じ)。
    await tester.tap(find.byKey(const ValueKey('notify.enable')));
    await tester.pumpAndSettle();
    expect(find.text('有効'), findsOneWidget);
    expect(jsonDecode((await storage.read(notifyTokenStorageKey))!), {'id': 'tok-1', 'token': 'raw-1'});
    expect(devices.single['deviceId'], 'device-abc');
    expect(devices.single['tokenId'], 'tok-1');
    expect('${devices.single['_push']}', startsWith('dummy:'));
    expect(auths['POST /me/notify/tokens'], 'Bearer device-token');
    // テスト通知 → 受信箱は**通知トークン**で読む。
    await tester.tap(find.byKey(const ValueKey('notify.test')));
    await tester.pumpAndSettle();
    expect(auths['GET /notify/outbox'], 'Bearer raw-1');
    expect(tester.widget<Text>(find.byKey(const ValueKey('notify.message'))).data, contains('受信箱で確認できました: 「RASQ のテスト通知」(dummy、端末 1 台)'));
    // 配下トークン(マクロ / AsTell 共用)。生の値はクリップボードへ。
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const ValueKey('notify.child.tok-1')));
    await tester.pumpAndSettle();
    expect(copied, 'raw-2');
    expect(tokens.length, 2);
    expect(tokens.last['parentId'], 'tok-1');
    expect(tokens.last['scopes'], ['macro', 'astell']);
    expect(find.byKey(const ValueKey('notify.token.tok-2')), findsOneWidget);
    // 失効 → 配下も消え、端末の控えも捨てる。
    await tester.ensureVisible(find.byKey(const ValueKey('notify.disable')));
    await tester.tap(find.byKey(const ValueKey('notify.disable')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('notify.message'))).data, 'この端末のトークンを失効しました');
    expect(tokens, isEmpty);
    expect(devices, isEmpty);
    expect(await storage.read(notifyTokenStorageKey), isNull);
    expect(find.text('未発行'), findsOneWidget);
  });

  testWidgets('RASQ アカウントが未作成なら、発行ボタンではなくアカウント作成の案内を出す(D-240)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final mock = MockClient((req) async => http.Response.bytes(utf8.encode(jsonEncode({'error': {'code': '401', 'message': 'valid bearer token required'}})), 401, headers: {'content-type': 'application/json'}));
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
    c.read(routerProvider).push(Routes.settingsNotifyToken);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notify.needAccount')), findsOneWidget);
    expect(find.byKey(const ValueKey('notify.enable')), findsNothing);
  });
}
