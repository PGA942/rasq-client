@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/store/http_store_client.dart';
import 'package:rasq_client/features/store/store_providers.dart';

/// 実際に動いている ORGATE-Server(ログイン)と RASQ Central(ストア)に対する疎通テスト (D-398)。
///
/// 既定では**丸ごとスキップ**する。走らせるときは接続先を渡す:
///
/// ```sh
/// flutter test test/orgate_live_test.dart \
///   --dart-define=ORGATE_LIVE_URL=http://127.0.0.1:8081 \
///   --dart-define=CENTRAL_LIVE_URL=http://127.0.0.1:8080
/// ```
///
/// 掲載物は `rasq-central/scripts/smoke.sh` が投入したものを前提にする。
void main() {
  const baseUrl = String.fromEnvironment('ORGATE_LIVE_URL');
  const centralUrl = String.fromEnvironment('CENTRAL_LIVE_URL');
  const pluginId = 'jp.rasq.misskey-wasm-sample';

  test('ストア一巡 + 配布物の SHA-512 / ed25519 検証', () async {
    final client = OrgateClient(baseUrl: Uri.parse(baseUrl));
    addTearDown(client.close);

    // 端末登録(ORGATE)→ 以後はそのアクセストークンを Central へ Bearer で渡す。
    final device = await client.postJson('/auth/device', {'deviceId': 'flutter-live-test'});
    final token = device['accessToken'] as String;
    final authed = OrgateClient(baseUrl: Uri.parse(centralUrl.isEmpty ? baseUrl : centralUrl), tokenProvider: () => token);
    addTearDown(authed.close);

    final store = HttpStoreClient(authed);

    final home = await store.home();
    expect(home.trending.map((c) => c.id), contains(pluginId));

    final detail = (await store.plugin(pluginId))!;
    expect(detail.safety.permissions, isNotEmpty);
    expect(detail.compatibility.os, isNotEmpty);

    final manifest = (await store.manifest(pluginId))!;
    final bundle = manifest.bundle!;
    expect(manifest.storePublicKey, isNotEmpty, reason: 'サーバーは署名鍵の公開鍵を配る');

    final bytes = await store.downloadArtifact(pluginId, bundle.id);
    final verified = await verifyArtifact(bytes: bytes, artifact: bundle, storePublicKey: manifest.storePublicKey);
    expect(verified.ok, isTrue, reason: verified.message);
    expect(verified.signatureChecked, isTrue, reason: 'ed25519 署名まで検証できること');

    // 落とした配布物は実物の wasm と同じバイト列。
    expect(bytes.length, bundle.sizeBytes);
    expect(bytes.sublist(0, 4), [0x00, 0x61, 0x73, 0x6d], reason: 'wasm のマジックナンバー');

    // ブックマークの往復。
    await store.setBookmark(pluginId, true);
    expect((await store.bookmarks()).map((c) => c.id), contains(pluginId));
    await store.setBookmark(pluginId, false);
    expect(await store.bookmarks(), isEmpty);

    // レビュー投稿 — verifiedUse はインストール履歴から**サーバーが**付ける。
    final review = await store.createReview(pluginId, rating: 4, body: 'live test', usedVersion: detail.version);
    expect(review.verifiedUse, isTrue, reason: '直前に配布物を落としているので実利用済み');
  }, skip: baseUrl.isEmpty ? 'ORGATE_LIVE_URL 未設定のためスキップ' : false);

  test('接続できないサーバーは B01 になる', () async {
    // ポート 1 は何も待ち受けていない。
    final client = OrgateClient(baseUrl: Uri.parse('http://127.0.0.1:1'));
    addTearDown(client.close);
    await expectLater(
      HttpStoreClient(client).search('x'),
      throwsA(isA<OrgateException>().having((e) => e.code.code, 'code', 'B01')),
    );
  }, skip: Platform.isAndroid || Platform.isIOS ? 'ホストのループバックが使えない環境' : false);
}
