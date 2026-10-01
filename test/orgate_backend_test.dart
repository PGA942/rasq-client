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
import 'package:rasq_client/backend/sns_oauth.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession, BrowserAuthFlow, SnsApiException;

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

  group('Mastodon ログイン — OAuth ブローカー (D-135)', () {
    ProviderContainer brokered(MockClient http_) {
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        settingsAreaProvider(backendSettingsArea).overrideWith(() => _FixedSettingsArea({'baseUrl': 'https://orgate.test'})),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: http_)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('begin → ブラウザ URL、complete → セッション(トークンは端末へ)', () async {
      final server = fakeServer({
        'POST /api/v1/auth/sns/mastodon/begin':
            '{"state":"st-1","authorizeUrl":"https://mastodon.example/oauth/authorize?client_id=abc&state=st-1","hint":"許可したら戻ってきてください","host":"mastodon.example"}',
        'POST /api/v1/auth/sns/mastodon/complete':
            '{"token":"mastodon-access-token","tokenType":"Bearer","scope":"read write follow","host":"mastodon.example",'
            '"me":{"id":"u1","handle":"yamada","displayName":"タロ・ヤマダ","avatarUrl":"https://x.test/a.png","instance":"mastodon.example"}}',
      });
      final container = brokered(server.client);
      final factory = brokeredAuthFactory(
        container.read(_refProvider),
        provider: 'mastodon',
        pluginId: 'rasq.official.mastodon',
        kind: SnsKind.mastodon,
      );

      final flow = await factory('mastodon.example') as BrowserAuthFlow;
      expect(flow.url.host, 'mastodon.example');
      expect(flow.url.path, '/oauth/authorize');
      expect(flow.hint, contains('戻ってきて'));

      final result = await flow.complete();
      expect(result.session.token, 'mastodon-access-token');
      expect(result.session.pluginId, 'rasq.official.mastodon');
      expect(result.session.account.kind, SnsKind.mastodon);
      expect(result.session.account.instance, 'mastodon.example');
      expect(result.session.account.handle, 'yamada');
      expect(result.session.account.key, 'mastodon:mastodon.example:yamada');
      expect(result.me.displayName, 'タロ・ヤマダ');

      // complete は state だけを送る(code はサーバーが保持している)。
      final complete = server.seen.firstWhere((r) => r.url.path.endsWith('/complete')) as http.Request;
      expect(jsonDecode(complete.body), {'state': 'st-1'});
    });

    test('サーバー未設定ならログインを始める前に理由付きで断る', () async {
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
      ]);
      addTearDown(container.dispose);
      final factory = brokeredAuthFactory(
        container.read(_refProvider),
        provider: 'mastodon',
        pluginId: 'rasq.official.mastodon',
        kind: SnsKind.mastodon,
      );
      await expectLater(
        factory('mastodon.example'),
        throwsA(isA<SnsApiException>().having((e) => e.code.message, 'message', contains('RASQ サーバー'))),
      );
    });

    test('ブローカーのエラー(未許可・state 切れ)は CONTRACT §9 のコードで届く', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/begin')) {
          return http.Response(
            '{"state":"st-1","authorizeUrl":"https://mastodon.example/oauth/authorize","hint":"h","host":"mastodon.example"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'error': {'code': '404', 'message': 'unknown, expired or already used state'}}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });
      final container = brokered(client);
      final factory = brokeredAuthFactory(container.read(_refProvider), provider: 'mastodon', pluginId: 'p', kind: SnsKind.mastodon);
      final flow = await factory('mastodon.example') as BrowserAuthFlow;
      await expectLater(
        flow.complete(),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', '404')),
      );
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

    test('作成 (D-138) = 端末登録 → /me。トークンはセキュアストレージに残る。作るまでは null', () async {
      final server = fakeServer({
        'POST /api/v1/auth/device': '{"accountId":"c3446e59-b937-4a1b-9050-335da9dc346b","handle":"rasq_c3446e59b937","displayName":"RASQ ユーザー","accessToken":"secret-token","refreshToken":"secret-refresh"}',
        'GET /api/v1/me': meJson,
      });
      final container = containerWith(server.client);

      // 端末登録は自動では走らない(オンボーディング/FOW の「作成」で明示)。
      expect(await container.read(orgateAccountProvider.future), isNull);
      expect(server.seen.where((r) => r.url.path.endsWith('/auth/device')), isEmpty);

      final account = await container.read(orgateAccountProvider.notifier).createAccount();
      expect(account!.handle, 'rasq_c3446e59b937');
      expect(account.displayName, 'RASQ ユーザー');

      // /me には発行されたトークンが付いている。
      final me = server.seen.firstWhere((r) => r.url.path.endsWith('/me'));
      expect(me.headers['authorization'], 'Bearer secret-token');

      // 端末 ID とトークンが残り、次回は登録をやり直さない。
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      // アカウントごとのトークン (D-316)。
      expect(stored['tokens'], {'c3446e59-b937-4a1b-9050-335da9dc346b': 'secret-token'});
      expect(stored['currentAccountId'], 'c3446e59-b937-4a1b-9050-335da9dc346b');
      expect(stored['deviceId'], isNotEmpty);
    });

    test('アクセストークンが 401 なら、まずリフレッシュトークンで取り直す (D-398)。端末の登録はし直さない。回った組を保存する', () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add('${req.method} ${req.url.path} ${req.headers['authorization'] ?? '-'}');
        if (req.url.path.endsWith('/auth/device')) fail('device registration must not be repeated');
        if (req.url.path.endsWith('/auth/refresh')) {
          expect(req.headers['authorization'], isNull, reason: 'リフレッシュは Bearer なしで、本文のリフレッシュトークンだけ');
          expect((jsonDecode(req.body) as Map)['refreshToken'], 'refresh-1');
          return http.Response('{"accountId":"a","handle":"rasq_x","accessToken":"access-2","refreshToken":"refresh-2","expiresIn":900}', 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.headers['authorization'] == 'Bearer access-1') {
          return http.Response(jsonEncode({'error': {'code': '401', 'message': 'expired'}}), 401, headers: {'content-type': 'application/json'});
        }
        return http.Response(meJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final container = containerWith(client, seed: {
        OrgateAccountNotifier.storageKey: jsonEncode({
          'deviceId': 'dev-1',
          'tokens': {'a': 'access-1'},
          'refresh': {'a': 'refresh-1'},
          'currentAccountId': 'a',
        }),
      });
      final account = await container.read(orgateAccountProvider.future);
      expect(account, isNotNull);
      expect(seen.where((s) => s.startsWith('POST /api/v1/auth/refresh')).length, 1);
      expect(container.read(orgateTokenHolderProvider).token, 'access-2');
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      // (保存していた id と /me の id が違えば、分かった id に付け直す — 組ごと移る。)
      expect((stored['tokens'] as Map).values, ['access-2']);
      expect((stored['refresh'] as Map).values, ['refresh-2']);
      expect((stored['tokens'] as Map).keys, (stored['refresh'] as Map).keys);
    });

    test('リフレッシュトークンも断られたら(セッションが消された)、そのアカウントのトークンを捨てる (D-398)', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({'error': {'code': 'session_revoked', 'message': 'revoked'}}), 401, headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/auth/device')) {
          return http.Response(jsonEncode({'error': {'code': '404', 'message': 'no account for this device'}}), 404, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': {'code': '401', 'message': 'expired'}}), 401, headers: {'content-type': 'application/json'});
      });
      final container = containerWith(client, seed: {
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'tokens': {'a': 'access-1'}, 'refresh': {'a': 'refresh-1'}, 'currentAccountId': 'a'}),
      });
      expect(await container.read(orgateAccountProvider.future), isNull);
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      expect(stored['tokens'], isEmpty);
      expect(stored['refresh'], isEmpty);
    });

    test('TokenRefreshingClient: いまのトークンで 401 → 1 回だけ取り直して送り直す。ほかのトークンの 401 はそのまま (D-398)', () async {
      final holder = OrgateTokenHolder()..token = 'old';
      var refreshes = 0;
      holder.refresher = () async {
        refreshes++;
        holder.token = 'new';
        return 'new';
      };
      final sent = <String>[];
      final inner = MockClient((req) async {
        sent.add('${req.headers['authorization']} ${req.body}');
        return req.headers['authorization'] == 'Bearer new' ? http.Response('{"ok":true}', 200) : http.Response('{}', 401);
      });
      final c = OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: TokenRefreshingClient(inner, holder), tokenProvider: () => holder.token);
      expect(await c.postJson('/x', {'a': 1}), {'ok': true});
      expect(sent, ['Bearer old {"a":1}', 'Bearer new {"a":1}']);
      expect(refreshes, 1);
      // 通知専用のトークンなど、いまのアクセストークンでない 401 は取り直さない。
      await expectLater(c.withToken(() => 'notify-token').getJson('/y'), throwsA(isA<OrgateException>()));
      expect(refreshes, 1);
    });

    test('アクセストークンの期限は JWT の exp から読む(署名は見ない)', () {
      final exp = DateTime.utc(2030, 1, 1);
      String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final jwt = '${b64({'alg': 'EdDSA'})}.${b64({'sub': 'a', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
      expect(accessTokenExpiry(jwt)!.toUtc(), exp);
      expect(accessTokenExpiry('opaque-token'), isNull);
      expect(accessTokenExpiry(null), isNull);
    });

    test('保存済みトークンが 401 なら 1 回だけ端末を登録し直す', () async {
      var meCalls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/device')) {
          // 取り直しは「既存のアカウントへ戻るだけ」(D-241: 同意なしに新規アカウントを作らない)。
          expect((jsonDecode(req.body) as Map)['restoreOnly'], isTrue);
          return http.Response('{"accountId":"a","handle":"rasq_x","displayName":"X","accessToken":"fresh","refreshToken":"fresh-refresh"}', 200,
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
      // 401 → (リフレッシュトークンの無い前の形なので)端末の取り直し → Central の /me → ORGATE の /me (D-398、同じモック)。
      expect(meCalls, 3);
    });

    test('取り直しでサーバーにアカウントが無ければ(削除 / 作り直し)、新規に作らず未作成へ戻る (D-241)', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/device')) {
          return http.Response(jsonEncode({'error': {'code': '404', 'message': 'no account for this device'}}), 404, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': {'code': '401', 'message': 'expired'}}), 401, headers: {'content-type': 'application/json'});
      });
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'token': 'stale', 'accountId': 'a'}),
      });
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        orgateClientProvider.overrideWithValue(OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(orgateAccountProvider.future), isNull);
      final stored = (jsonDecode((await storage.read(OrgateAccountNotifier.storageKey))!) as Map);
      expect(stored['deviceId'], 'dev-1');
      expect(stored['tokens'], isEmpty);
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
        'POST /api/v1/auth/device': '{"accountId":"a","handle":"rasq_x","displayName":"X","accessToken":"tok","refreshToken":"tok-refresh"}',
        'GET /api/v1/me': meJson,
        'GET /api/v1/me/sns-accounts': '[]',
        'PUT /api/v1/me/sns-accounts':
            '{"accountKey":"misskey:example.test:tester","kind":"misskey","instance":"example.test","handle":"tester","pluginId":"rasq.official.misskey","displayName":null,"avatarUrl":null,"linkedAt":"2026-09-03T00:00:00Z"}',
      });
      final container = containerWith(server.client);
      await container.read(orgateAccountProvider.future);
      await container.read(orgateAccountProvider.notifier).createAccount();

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

/// `brokeredAuthFactory` は `Ref` を取る(認証開始時に接続先を読み直すため)。
/// テストからは、何もしないプロバイダーの `Ref` を借りて渡す。
final _refProvider = Provider<Ref>((ref) => ref);
