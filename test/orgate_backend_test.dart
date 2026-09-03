import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/http_store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

/// orgate-server との境界。
///
/// **JSON はすべて実際に動いている orgate-server から採取したもの**
/// (`scripts/smoke.sh` が投入した掲載物への応答)。ワイヤ形が変わったら
/// このテストが落ちる = 契約テストとして機能する。
void main() {
  // ── openapi/store.yaml の応答(実採取) ───────────────────────────
  const homeJson = '''
{"trending":[{"id":"jp.rasq.misskey-wasm-sample","name":"Misskey コネクタ","summary":"Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。","version":"0.5.0","status":"published","origin":"official","rating":5.0,"downloads":1,"sizeMb":0.26,"hasAds":false,"price":0.0}],"bookmarks":[],"recent":[{"id":"jp.rasq.misskey-wasm-sample","name":"Misskey コネクタ","summary":"…","version":"0.5.0","status":"published","origin":"official","rating":5.0,"downloads":1,"sizeMb":0.26,"hasAds":false,"price":0.0}]}''';

  const detailJson = '''
{"id":"jp.rasq.misskey-wasm-sample","name":"Misskey コネクタ","summary":"Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。","version":"0.5.0","status":"published","origin":"official","rating":5.0,"downloads":1,"sizeMb":0.26,"hasAds":false,"price":0.0,"description":"rasq-sdk-sample の Rust 製 wasm プラグイン。","screenshots":[],"channel":"stable","updatedAt":"2026-09-03T05:46:26.584304Z","safety":{"crashFreeRate":0.998,"dataHandling":"投稿・トークンは端末内にのみ保存。","externalHosts":["<ログインした Misskey インスタンス>"],"permissions":[{"permission":"network","reason":"Misskey インスタンスの API を呼ぶため"},{"permission":"storage.safe","reason":"セッショントークンと TL 設定の保存"}],"rasqFeatures":["タイムライン描画 (RRL)","ノードグラフ (tl.sort)","投稿加工 (post.transform)"]},"compatibility":{"os":["ios","android","macos","windows","linux"],"rasqVersion":">=0.1.0"},"developer":{"name":"RASQ Project"}}''';

  // ── サーバー(Rust ed25519-dalek)が実際に作った署名 ────────────────
  //
  // 中身は固定のバイト列。**同梱 wasm ではなく専用のフィクスチャ**にして
  // あるのは、プラグインを 1 行直すたびにこの定数を採り直す羽目になるのを
  // 避けるため。検証したい性質(サーバーが作った署名を Dart 側が検証できる)
  // はどちらでも同じ。
  const fixtureBytes = 'rasq-artifact-fixture-v1\n';
  const fixtureSha512 =
      '55ba084367bde9c56e6a1b64ddca15bdd343ef21af28ad7e33a843683fe4e990645117ea36b77fa60cf75efaf17dc99648e7d6178a7d8a6553f7d827f774a636';
  const fixtureSignature = 'vOv3lLKaCO0PWXMkaB5pYdg1j7LbzssNKNBK/Ansi/2ILMp/3lAQ+5B0WhSoTbGYMi8jR2CWxg32laV8ybyRBQ==';
  const storePublicKey = 'MrtN8nNtaruCxzB0HN7q/zQzTj4Pj/fDiUURQ7xEz6E=';

  // manifest フィクスチャに載る配布物のハッシュ(採取時点の wasm)。
  // JSON の読み取りだけを確かめるので、実ファイルと一致している必要はない。
  const bundleSha512 =
      '2ee69e8aaefb2bd452ba3979f2804c8f92bcaad99000c74c45b22af26cd84c72c26c6407f9b7e43a84b36b1d7395ac2eadd0d9fb88938ad5af2f117ca5efa9fc';
  const bundleSignature = 'E9TWd8zgH8RAffL2GAUVZ/kSOgjvKjyOe//xllmALnOKEvpI3DcZ10PEl1y3qeA191HhzV65E3zr65NC8iQjCA==';

  const manifestJson = '''
{"pluginId":"jp.rasq.misskey-wasm-sample","version":"0.5.0","channel":"stable","manifest":{"id":"jp.rasq.misskey-wasm-sample","kind":"sns","name":"Misskey コネクタ","official":true,"permissions":["network","storage.safe","register_action","transform_content"],"supportedSns":["misskey"],"verified":true,"version":"0.5.0"},"permissionsAdded":[],"artifacts":[{"id":"bundle","kind":"bundle","sizeBytes":269990,"sha512":"$bundleSha512","signature":"$bundleSignature","lazy":false}],"storePublicKey":"$storePublicKey"}''';

  const reviewsJson = '''
{"items":[{"id":"738d3653-71eb-4b24-8688-2d2a3784d4fd","rating":5,"body":"wasm でここまで動くのすごい。","usedVersion":"0.5.0","verifiedUse":true,"helpfulCount":0,"developerReply":null,"createdAt":"2026-09-03T05:46:26.471149Z"}],"nextCursor":null}''';

  const releasesJson = '''
{"items":[{"version":"0.5.0","channel":"stable","notes":"sns.emojis / repostTargetId / reactionEmojis を追加。","permissionsAdded":[],"publishedAt":"2026-09-03T05:46:26.282148Z"}],"nextCursor":null}''';

  const meJson =
      '{"id":"c3446e59-b937-4a1b-9050-335da9dc346b","handle":"rasq_c3446e59b937","displayName":"RASQ ユーザー","avatarUrl":null,"createdAt":"2026-09-03T05:58:34.888445Z"}';

  /// リクエストを記録しつつ固定応答を返すサーバー。
  ({MockClient client, List<http.BaseRequest> seen}) fakeServer(
    Map<String, String> routes, {
    int Function(String path)? status,
  }) {
    final seen = <http.BaseRequest>[];
    final client = MockClient((req) async {
      seen.add(req);
      final key = '${req.method} ${req.url.path}';
      final body = routes[key];
      if (body == null) {
        return http.Response(jsonEncode({'error': {'code': '404', 'message': 'no such route: $key'}}), 404,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(body, status?.call(req.url.path) ?? 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    return (client: client, seen: seen);
  }

  OrgateClient clientFor(MockClient http_, {String? token}) =>
      OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: http_, tokenProvider: () => token);

  group('HttpStoreClient — store.yaml のワイヤをそのまま読む', () {
    test('home / search / detail / manifest / reviews / releases', () async {
      final server = fakeServer({
        'GET /api/v1/home': homeJson,
        'GET /api/v1/plugins': '{"items":[${detailJson.trim()}],"nextCursor":null}',
        'GET /api/v1/plugins/jp.rasq.misskey-wasm-sample': detailJson,
        'GET /api/v1/plugins/jp.rasq.misskey-wasm-sample/manifest': manifestJson,
        'GET /api/v1/plugins/jp.rasq.misskey-wasm-sample/reviews': reviewsJson,
        'GET /api/v1/plugins/jp.rasq.misskey-wasm-sample/releases': releasesJson,
      });
      final store = HttpStoreClient(clientFor(server.client));

      final home = await store.home();
      expect(home.trending.single.id, 'jp.rasq.misskey-wasm-sample');
      expect(home.trending.single.rating, 5.0);
      expect(home.trending.single.status, PluginStatus.published);
      expect(home.trending.single.origin, PluginOrigin.official);
      expect(home.bookmarks, isEmpty);
      expect(home.recent, hasLength(1));

      final found = await store.search('Misskey');
      expect(found.single.name, 'Misskey コネクタ');

      final d = (await store.plugin('jp.rasq.misskey-wasm-sample'))!;
      // allOf: PluginCard + detail が 1 つの平坦なオブジェクトで来る。
      expect(d.version, '0.5.0');
      expect(d.developerName, 'RASQ Project');
      expect(d.channel, 'stable');
      expect(d.safety.crashFreeRate, 0.998);
      expect(d.safety.permissions.map((p) => p.permission), ['network', 'storage.safe']);
      expect(d.safety.permissions.first.reason, contains('API を呼ぶため'));
      expect(d.compatibility.os, contains('ios'));
      expect(d.updatedAt, isNotNull);

      final m = (await store.manifest('jp.rasq.misskey-wasm-sample'))!;
      expect(m.bundle!.sha512, bundleSha512);
      expect(m.bundle!.signature, bundleSignature);
      expect(m.storePublicKey, storePublicKey);
      expect(m.manifest['kind'], 'sns');

      final reviews = await store.reviews('jp.rasq.misskey-wasm-sample');
      expect(reviews.single.verifiedUse, isTrue);
      expect(reviews.single.developerReply, isNull);

      final releases = await store.releases('jp.rasq.misskey-wasm-sample');
      expect(releases.single.version, '0.5.0');
      expect(releases.single.permissionsAdded, isEmpty);
    });

    test('未掲載プラグインの 404 は null(例外にしない)', () async {
      final server = fakeServer({});
      final store = HttpStoreClient(clientFor(server.client));
      expect(await store.plugin('net.example.nope'), isNull);
      expect(await store.manifest('net.example.nope'), isNull);
    });

    test('Bearer が付き、検索語はクエリに乗る', () async {
      final server = fakeServer({'GET /api/v1/plugins': '{"items":[],"nextCursor":null}'});
      await HttpStoreClient(clientFor(server.client, token: 'tok-123')).search('SigLIP');
      expect(server.seen.single.headers['authorization'], 'Bearer tok-123');
      expect(server.seen.single.url.queryParameters['q'], 'SigLIP');
    });

    test('停止中プラグインの 403 は CONTRACT §9 のコード付きで伝わる', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': {'code': '403', 'message': 'plugin ... is suspended and cannot be installed'}}),
            403,
            headers: {'content-type': 'application/json'},
          ));
      final store = HttpStoreClient(clientFor(client));
      await expectLater(
        store.downloadArtifact('x.y', 'bundle'),
        throwsA(isA<OrgateException>().having((e) => e.code.code, 'code', '403')),
      );
    });

    test('到達不能は B01 (Network Unreachable) になる', () async {
      final client = MockClient((_) async => throw const SocketException('nope'));
      await expectLater(
        HttpStoreClient(clientFor(client)).search('x'),
        throwsA(isA<OrgateException>().having((e) => e.code.code, 'code', 'B01')),
      );
    });
  });

  group('配布物の検証 (D-034)', () {
    final fixture = Uint8List.fromList(utf8.encode(fixtureBytes));
    const artifact = StoreArtifact(id: 'fixture', kind: 'asset', sizeBytes: 25, sha512: fixtureSha512, signature: fixtureSignature);

    test('サーバー(Rust ed25519-dalek)の署名を Dart 側が検証できる', () async {
      expect(sha512.convert(fixture).toString(), fixtureSha512);
      final r = await verifyArtifact(bytes: fixture, artifact: artifact, storePublicKey: storePublicKey);
      expect(r.ok, isTrue, reason: r.message);
      expect(r.signatureChecked, isTrue);
    });

    test('1 バイト違えば SHA-512 で落ちる', () async {
      final tampered = Uint8List.fromList([...fixture, 0]);
      final r = await verifyArtifact(bytes: tampered, artifact: artifact, storePublicKey: storePublicKey);
      expect(r.ok, isFalse);
      expect(r.message, contains('SHA-512'));
    });

    test('ハッシュは合っていても署名が別の鍵のものなら落ちる', () async {
      final bytes = Uint8List.fromList(utf8.encode('some artifact'));
      final digest = sha512.convert(bytes);

      // 攻撃者の鍵で署名した(= 正しい形をしているが、ストアの鍵ではない)。
      final attacker = await Ed25519().newKeyPair();
      final sig = await Ed25519().sign(digest.bytes, keyPair: attacker);

      final artifact = StoreArtifact(
        id: 'bundle',
        sizeBytes: bytes.length,
        sha512: digest.toString(),
        signature: base64Encode(sig.bytes),
      );
      final r = await verifyArtifact(bytes: bytes, artifact: artifact, storePublicKey: storePublicKey);
      expect(r.ok, isFalse);
      expect(r.message, contains('署名'));
    });

    test('署名なし(モックストア)はハッシュ照合だけで通す', () async {
      final bytes = Uint8List.fromList(utf8.encode('mock artifact'));
      final artifact = StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: sha512.convert(bytes).toString());
      final r = await verifyArtifact(bytes: bytes, artifact: artifact, storePublicKey: '');
      expect(r.ok, isTrue);
      expect(r.signatureChecked, isFalse);
    });
  });

  group('RASQ アカウント (D-087)', () {
    ProviderContainer containerWith(MockClient http_, {Map<String, String> seed = const {}}) {
      final storage = MemorySessionStorage({...seed});
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        // KV `backend.v1` に接続先を入れて「サーバーあり」の構成にする。
        settingsAreaProvider(backendSettingsArea).overrideWith(() => _FixedSettingsArea({'baseUrl': 'https://orgate.test'})),
        orgateClientProvider.overrideWith((ref) {
          final holder = ref.read(orgateTokenHolderProvider);
          return OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: http_, tokenProvider: () => holder.token);
        }),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('初回は端末登録 → /me。トークンはセキュアストレージに残る', () async {
      final server = fakeServer({
        'POST /api/v1/auth/device': '{"accountId":"c3446e59-b937-4a1b-9050-335da9dc346b","handle":"rasq_c3446e59b937","displayName":"RASQ ユーザー","token":"secret-token"}',
        'GET /api/v1/me': meJson,
      });
      final container = containerWith(server.client);

      final account = await container.read(orgateAccountProvider.future);
      expect(account!.handle, 'rasq_c3446e59b937');
      expect(account.displayName, 'RASQ ユーザー');

      // /me には発行されたトークンが付いている。
      final me = server.seen.firstWhere((r) => r.url.path.endsWith('/me'));
      expect(me.headers['authorization'], 'Bearer secret-token');

      // 端末 ID とトークンが残り、次回は登録をやり直さない。
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      expect(stored['token'], 'secret-token');
      expect(stored['deviceId'], isNotEmpty);
    });

    test('保存済みトークンが 401 なら 1 回だけ端末を登録し直す', () async {
      var meCalls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/device')) {
          return http.Response('{"accountId":"a","handle":"rasq_x","displayName":"X","token":"fresh"}', 200,
              headers: {'content-type': 'application/json'});
        }
        meCalls++;
        // 1 回目 = 古いトークンで 401、2 回目 = 新しいトークンで成功。
        if (meCalls == 1) {
          return http.Response(jsonEncode({'error': {'code': '401', 'message': 'expired'}}), 401, headers: {'content-type': 'application/json'});
        }
        return http.Response(meJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final container = containerWith(client, seed: {
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'token': 'stale', 'accountId': 'a'}),
      });

      final account = await container.read(orgateAccountProvider.future);
      expect(account, isNotNull);
      expect(meCalls, 2);
    });

    test('接続先が未設定なら何もしない(サーバー無しでも動く)', () async {
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
      ]);
      addTearDown(container.dispose);
      expect(container.read(orgateConfiguredProvider), isFalse);
      expect(await container.read(orgateAccountProvider.future), isNull);
    });

    test('バンドル同期は SNS アカウントの識別だけを送り、トークンは送らない', () async {
      final server = fakeServer({
        'POST /api/v1/auth/device': '{"accountId":"a","handle":"rasq_x","displayName":"X","token":"tok"}',
        'GET /api/v1/me': meJson,
        'GET /api/v1/me/sns-accounts': '[]',
        'PUT /api/v1/me/sns-accounts':
            '{"accountKey":"misskey:example.test:tester","kind":"misskey","instance":"example.test","handle":"tester","pluginId":"rasq.official.misskey","displayName":null,"avatarUrl":null,"linkedAt":"2026-09-03T00:00:00Z"}',
      });
      final container = containerWith(server.client);
      await container.read(orgateAccountProvider.future);

      await container.read(orgateAccountProvider.notifier).syncBundle([
        AccountSession(
          account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester'),
          pluginId: 'rasq.official.misskey',
          token: 'MUST-NOT-LEAK',
          createdAt: DateTime(2026, 9, 1),
        ),
      ]);

      final put = server.seen.firstWhere((r) => r.method == 'PUT');
      final body = jsonDecode((put as http.Request).body) as Map<String, Object?>;
      expect(body['accountKey'], isNull, reason: 'accountKey はサーバーが組み立てる');
      expect(body['kind'], 'misskey');
      expect(body['handle'], 'tester');
      expect(body['pluginId'], 'rasq.official.misskey');
      expect(put.body, isNot(contains('MUST-NOT-LEAK')), reason: 'アクセストークンは端末から出さない (CONTRACT §3)');
    });
  });
}

/// KV 設定領域の固定値オーバーライド。
class _FixedSettingsArea extends SettingsAreaStore {
  _FixedSettingsArea(this.values) : super('backend');
  final Map<String, Object?> values;
  @override
  Future<Map<String, Object?>> build() async => values;
}
