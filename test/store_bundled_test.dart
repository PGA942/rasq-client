import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256, sha512;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/orgate_client.dart' show OrgateException;
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';

import 'support/fake_store_client.dart';

/// 同梱のストア (D-393): アプリの中身は実物だけ。架空の掲載 / 数字 / レビュー / リリースノートを出さない。
class _EmptyCentral extends FakeStoreClient {
  @override
  Future<StorePluginDetail?> plugin(String id) async => null;
  @override
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) async => const [];
  @override
  Future<List<ReleaseNote>> releases(String id) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('掲載は同梱の実物だけ(架空の net.example.* は無い)。評価 / ダウンロード数 / 推移は 0 / 空、版は SOURCES.json から', () async {
    final store = BundledStoreClient();
    final all = await store.search('');
    final ids = {for (final c in all) c.id};
    expect(ids, {storeSamplePluginId, for (final s in storeSlotSamples) s.id});
    expect(ids.any((id) => id.startsWith('net.example.')), isFalse);
    final sources = (jsonDecode(await rootBundle.loadString(bundledPluginSourcesAsset)) as Map)['assets'] as Map;
    for (final c in all) {
      final d = (await store.plugin(c.id))!;
      expect((d.rating, d.downloads, d.downloadHistory, d.ratingHistogram, d.downloadsLastMonth, d.safety.crashFreeRate), (0, 0, const <int>[], const <int>[], null, null), reason: '${c.id}: 作り物の数字は無い');
      final asset = c.id == storeSamplePluginId ? 'misskey_wasm_sample.wasm' : storeSlotSamples.firstWhere((s) => s.id == c.id).asset;
      expect(d.version, (sources[asset] as Map)['version'], reason: '${c.id}: 版は同梱の記録から');
    }
    expect((await store.home()).trending, isEmpty, reason: 'トレンドはサーバーの集計');
    expect(await store.reviews(storeSamplePluginId), isEmpty);
    expect(await store.releases(storeSamplePluginId), isEmpty);
    expect((await store.points()).balance, 0, reason: 'ポイントを配らない');
    await expectLater(store.purchase(storeSlotSamples.first.id), throwsA(isA<OrgateException>()));
    await expectLater(store.createReview(storeSamplePluginId, rating: 5), throwsA(isA<OrgateException>()));
    await expectLater(store.downloadArtifact('net.example.siglip-reco', 'bundle'), throwsA(isA<OrgateException>()), reason: '同梱していない id は 404');
  });

  test('配布物 = 同梱のアセットそのもの(SHA-512 が合う)。SOURCES.json の sha256 とも合う', () async {
    final store = BundledStoreClient();
    final sources = (jsonDecode(await rootBundle.loadString(bundledPluginSourcesAsset)) as Map)['assets'] as Map;
    for (final s in storeSlotSamples) {
      final m = (await store.manifest(s.id))!;
      final bytes = await store.downloadArtifact(s.id, 'bundle');
      expect(m.artifacts.single.sha512, sha512.convert(bytes).toString());
      expect(m.storePublicKey, isEmpty);
      expect(sha256.convert(bytes).toString(), (sources[s.asset] as Map)['sha256'], reason: '${s.asset}: 記録と同じ中身');
      expect(await store.manifest(s.id, version: '9.9.9'), isNull, reason: '同梱しているのは 1 つの版だけ');
    }
    expect(Uint8List.fromList(await store.downloadArtifact(storeSamplePluginId, 'bundle')).length, greaterThan(1000));
  });

  test('Central + 同梱: レビュー / リリースノートは Central の答えのまま(空でも同梱の作り物で埋めない)。ページ / 配布物は同梱で補う', () async {
    final client = BundledFallbackStoreClient(_EmptyCentral(), BundledStoreClient());
    expect(await client.reviews(storeSamplePluginId), isEmpty);
    expect(await client.releases(storeSamplePluginId), isEmpty);
    final d = await client.plugin(storeSamplePluginId);
    expect(d?.id, storeSamplePluginId);
    expect((d!.rating, d.downloads), (0, 0), reason: '補うときも数字は無い');
  });
}
