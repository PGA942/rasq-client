import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/store/http_store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';

/// D-407 (セキュリティ指摘 #11): 共有セッションの一時プラグイン(登録元 `store:` = フル機能)も、通常のインストールと
/// 同じ署名 + 焼き込んだ鍵の検証を通す。ハッシュだけでは、構成と配布物をまとめてすり替えられると防げない。
void main() {
  final bytes = Uint8List.fromList(utf8.encode('fake wasm package bytes'));
  final digest = sha512.convert(bytes);

  late SimpleKeyPair storeKey, otherKey;
  late String storePub, otherPub, goodSig, otherSig;

  setUpAll(() async {
    storeKey = await Ed25519().newKeyPair();
    otherKey = await Ed25519().newKeyPair();
    storePub = base64Encode((await storeKey.extractPublicKey()).bytes);
    otherPub = base64Encode((await otherKey.extractPublicKey()).bytes);
    goodSig = base64Encode((await Ed25519().sign(digest.bytes, keyPair: storeKey)).bytes);
    otherSig = base64Encode((await Ed25519().sign(digest.bytes, keyPair: otherKey)).bytes);
  });

  InstallManifest manifest({String pluginId = 'net.example.page', String version = '1.2.0', String signature = '', String? key, String? hash}) => InstallManifest(
        pluginId: pluginId,
        version: version,
        manifest: const {},
        storePublicKey: key ?? storePub,
        artifacts: [StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: hash ?? digest.toString(), signature: signature)],
      );

  Future<Uint8List> verify(InstallManifest m, {String pinned = '', String? version = '1.2.0'}) =>
      verifySessionPackage(pluginId: 'net.example.page', version: version, manifest: m, bytes: bytes, pinnedKey: pinned);

  group('verifySessionPackage', () {
    test('ピン留めしたビルド: 署名が無い一時パッケージは断る', () async {
      await expectLater(verify(manifest(), pinned: storePub), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('署名がありません'))));
    });

    test('ピン留めしたビルド: 正しくない署名 / 別の鍵(すり替えたストア)は断る', () async {
      await expectLater(verify(manifest(signature: otherSig), pinned: storePub), throwsStateError);
      await expectLater(verify(manifest(signature: otherSig, key: otherPub), pinned: storePub), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('焼き込んだ鍵'))));
    });

    test('ピン留めした鍵で署名された、頼んだ版は通る', () async {
      expect(await verify(manifest(signature: goodSig), pinned: storePub), bytes);
    });

    test('頼んだものと違うプラグイン / 版の構成は、署名が正しくても断る', () async {
      await expectLater(verify(manifest(signature: goodSig, pluginId: 'net.example.other'), pinned: storePub), throwsStateError);
      await expectLater(verify(manifest(signature: goodSig, version: '9.9.9'), pinned: storePub), throwsStateError);
    });

    test('ハッシュが違えば(ピン留め無しでも)断る。ピン留め無し + 署名無しは通常のインストールと同じくハッシュだけで通す', () async {
      await expectLater(verify(manifest(hash: '-')), throwsStateError);
      expect(await verify(manifest()), bytes);
      // 署名があれば、ピン留め無しでも検証する。
      await expectLater(verify(manifest(signature: otherSig)), throwsStateError);
    });
  });

  test('HttpStoreClient.sessionPackage は検証を通す(署名の壊れた配布物を返さない)', () async {
    var sig = otherSig;
    final client = HttpStoreClient(OrgateClient(
      baseUrl: Uri.parse('https://central.test'),
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/manifest')) {
          expect(req.url.queryParameters['session'], 's1');
          return http.Response(
            jsonEncode({
              'pluginId': 'net.example.page',
              'version': '1.2.0',
              'manifest': <String, Object?>{},
              'storePublicKey': storePub,
              'artifacts': [
                {'id': 'bundle', 'kind': 'bundle', 'sizeBytes': bytes.length, 'sha512': digest.toString(), 'signature': sig},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(bytes, 200);
      }),
    ));
    await expectLater(client.sessionPackage('net.example.page', 's1', version: '1.2.0'), throwsStateError);
    sig = goodSig;
    expect(await client.sessionPackage('net.example.page', 's1', version: '1.2.0'), bytes);
  });
}
