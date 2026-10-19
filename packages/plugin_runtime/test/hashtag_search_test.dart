import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// ハッシュタグの候補 (D-475): `sns.search {kind: hashtags}` → `{tags: [{tag, count?}]}`。
/// 同梱の SNS プラグイン(assets/plugins、tool/build_bundled_plugins.sh で rasq-sdk-sample から作る)を実物で叩き、
/// 持たない / 古いプラグインでは「候補なし」に倒れる(例外 → コンポーザーが握る)ことを確かめる。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.example', handle: 'me');

  group('WasmSnsSession.searchHashtags の写し', () {
    WasmSnsSession stub(Map<String, Object?> Function(String fn, Map<String, Object?> args) reply) =>
        WasmSnsSession(account: viewer, extraArgs: const {'host': 'misskey.example'}, invoke: (fn, args) async => reply(fn, args));

    test('tags を TrendTag に(# は外す、空は捨てる)', () async {
      late Map<String, Object?> sent;
      final s = stub((fn, args) {
        sent = {'fn': fn, ...args};
        return {
          'ok': true,
          'value': {
            'tags': [
              {'tag': '打上会', 'count': 3},
              {'tag': '#rocket'},
              {'tag': ''},
              {'name': 'x'},
            ],
          },
        };
      });
      final tags = await s.searchHashtags('打', limit: 5);
      expect([for (final t in tags) (t.tag, t.usersCount)], [('打上会', 3), ('rocket', null)]);
      expect((sent['fn'], sent['kind'], sent['q'], sent['limit']), ('sns.search', 'hashtags', '打', 5));
    });

    test('この kind を知らない古いプラグイン(posts の page を返す)は非対応', () async {
      final s = stub((_, _) => {'ok': true, 'value': {'page': {'items': <Object?>[]}}});
      expect(s.searchHashtags('打'), throwsUnsupportedError);
    });

    test('C01 はそのまま SnsApiException(コンポーザーは候補を出さないだけ)', () async {
      final s = stub((_, _) => {'ok': false, 'error': {'code': 'C01', 'message': 'unsupported: sns.search kind=hashtags'}});
      expect(s.searchHashtags('打'), throwsA(isA<SnsApiException>()));
    });

    test('SnsSessionBase の既定は非対応', () {
      expect(() => _Bare().searchHashtags('a'), throwsUnsupportedError);
    });
  });

  group('同梱の SNS プラグイン(実物の wasm)', () {
    final requests = <Uri>[];
    WasmSnsSession load(String asset, {required String host, required Map<String, String> routes}) {
      final env = RasqHostEnvironment(
        permissions: const {RasqPermissions.network, RasqPermissions.storageSafe},
        fetchHosts: {host},
        fetch: (req) {
          requests.add(req.url);
          final body = routes[req.url.path];
          return body == null ? const SyncFetchResponse(status: 404, bodyText: '{}') : SyncFetchResponse(status: 200, bodyText: body);
        },
      );
      final controller = WasmPluginController(wasmBytes: File('../../assets/plugins/$asset').readAsBytesSync(), env: env);
      addTearDown(controller.dispose);
      controller.load();
      return WasmSnsSession(account: viewer, extraArgs: {'host': host, 'token': 'tok'}, invoke: (fn, args) async => controller.invoke(fn, args));
    }

    setUp(requests.clear);

    test('Misskey: hashtags/search', () async {
      final s = load('misskey_wasm_sample.wasm', host: 'misskey.example', routes: {'/api/hashtags/search': jsonEncode(['打上会', '打ち上げ'])});
      final tags = await s.searchHashtags('打');
      expect(tags.map((t) => t.tag), ['打上会', '打ち上げ']);
      expect(requests.single.toString(), 'https://misskey.example/api/hashtags/search');
    });

    test('Mastodon: /api/v2/search?type=hashtags(件数は直近の日の accounts)', () async {
      final s = load('mastodon_wasm.wasm', host: 'mastodon.example', routes: {
        '/api/v2/search': jsonEncode({
          'accounts': <Object?>[],
          'statuses': <Object?>[],
          'hashtags': [
            {'name': 'rocket', 'history': [{'day': '1', 'uses': '9', 'accounts': '4'}]},
            {'name': 'rocketry', 'history': <Object?>[]},
          ],
        }),
      });
      final tags = await s.searchHashtags('#roc');
      expect([for (final t in tags) (t.tag, t.usersCount)], [('rocket', 4), ('rocketry', null)]);
      expect(requests.single.queryParameters['type'], 'hashtags');
      expect(requests.single.queryParameters['q'], 'roc');
    });
  });
}

class _Bare extends SnsSessionBase {
  @override
  AccountId get account => const AccountId(kind: SnsKind.misskey, instance: 'x', handle: 'y');
  @override
  String get pluginId => 'bare';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
