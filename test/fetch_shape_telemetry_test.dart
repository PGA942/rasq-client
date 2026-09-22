import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/plugins/fetch_shape_telemetry.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 通信の形の報告: 同意が無ければ送らない / 初めて見た形だけ / 404 の版は覚えて二度と送らない / 同意は 1 度だけ記録。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final shape = {'hash': '0123456789abcdef', 'shape': {'host': 'misskey.example', 'method': 'POST', 'path': '/api/notes', 'query': [], 'headers': ['content-type'], 'body': {'i': 's'}}};

  ProviderContainer containerWith(MockClient mock, {bool consent = true}) {
    final client = OrgateClient(baseUrl: Uri.parse('http://central.test'), httpClient: mock, tokenProvider: () => 'tok');
    final c = ProviderContainer(overrides: [
      // 設定 KV は端末の secure storage に載る。テストはメモリに。
      sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()),
      centralClientProvider.overrideWithValue(client),
      orgateClientProvider.overrideWithValue(client),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> setConsent(ProviderContainer c, bool on) async {
    await c.read(settingsAreaProvider(FetchShapeTelemetry.settingsArea).future);
    await c.read(settingsAreaProvider(FetchShapeTelemetry.settingsArea).notifier).set('fetchShapes', on);
    await c.read(settingsAreaProvider(FetchShapeTelemetry.seenArea).future);
  }

  test('同意が無ければ何も送らない', () async {
    final calls = <String>[];
    final c = containerWith(MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      return http.Response('{}', 202);
    }));
    await setConsent(c, false);
    final t = c.read(fetchShapeTelemetryProvider);
    t.report('jp.rasq.sample', '1.1.0', shape);
    await t.flush();
    expect(calls, isEmpty);
  });

  test('初めて見た形だけを送り、覚えたものは二度と送らない。同意は 1 度だけ Central に残す', () async {
    final calls = <String>[];
    final bodies = <Map<String, Object?>>[];
    final c = containerWith(MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path');
      if (req.body.isNotEmpty) bodies.add((jsonDecode(req.body) as Map).cast<String, Object?>());
      if (path.endsWith('/fetch-shapes')) return http.Response(jsonEncode({'added': 1, 'overflow': false}), 202);
      return http.Response('{}', 200);
    }));
    await setConsent(c, true);
    final t = c.read(fetchShapeTelemetryProvider);
    t.report('jp.rasq.sample', '1.1.0', shape);
    t.report('jp.rasq.sample', '1.1.0', shape); // 溜まっている間の重複
    await t.flush();
    expect(calls.where((x) => x.startsWith('POST /plugins/jp.rasq.sample/versions/1.1.0/fetch-shapes')), hasLength(1));
    expect((bodies.first['shapes'] as List), hasLength(2)); // 溜めた分はそのまま(Central 側が重複を数える)
    expect(calls.where((x) => x == 'PUT /me/consents/fetchShapes'), hasLength(1));
    expect(bodies.last['granted'], true);

    // 覚えたので、次に同じ形が来ても送らない。同意の記録も増えない。
    t.report('jp.rasq.sample', '1.1.0', shape);
    await t.flush();
    expect(calls.where((x) => x.contains('/fetch-shapes')), hasLength(1));
    expect(calls.where((x) => x == 'PUT /me/consents/fetchShapes'), hasLength(1));

    // 別の版は別枠。
    t.report('jp.rasq.sample', '2.0.0', shape);
    await t.flush();
    expect(calls.where((x) => x.contains('/versions/2.0.0/fetch-shapes')), hasLength(1));
  });

  test('ストアに無い版 (404) は覚えて、以後は送らない', () async {
    var posts = 0;
    final c = containerWith(MockClient((req) async {
      if (req.url.path.endsWith('/fetch-shapes')) {
        posts++;
        return http.Response(jsonEncode({'error': {'code': '404', 'message': 'no approved version'}}), 404);
      }
      return http.Response('{}', 200);
    }));
    await setConsent(c, true);
    final t = c.read(fetchShapeTelemetryProvider);
    t.report('dev.local.thing', '0.1.0', shape);
    await t.flush();
    t.report('dev.local.thing', '0.1.0', shape);
    await t.flush();
    expect(posts, 1);
  });

  test('overflow は Central が数えるので送らない', () async {
    var posts = 0;
    final c = containerWith(MockClient((req) async {
      if (req.url.path.endsWith('/fetch-shapes')) posts++;
      return http.Response('{}', 202);
    }));
    await setConsent(c, true);
    final t = c.read(fetchShapeTelemetryProvider);
    t.report('jp.rasq.sample', '1.1.0', {'overflow': true});
    await t.flush();
    expect(posts, 0);
  });
}
