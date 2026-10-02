import 'dart:typed_data';

import 'package:rasq_models/rasq_models.dart' show ErrorCode;

import '../../backend/orgate_client.dart';
import '../../backend/payments_api.dart';
import 'store_client.dart';
import 'store_models.dart';
import 'store_providers.dart' show verifyArtifact;

/// `orgate-server` の `/api/v1` に対する [StoreClient]。
/// 経路とペイロードは rasq-sdk-sample/openapi/store.yaml (D-033) の通り。
///
/// 同梱のストア([BundledStoreClient])との違いは**接続先だけ**で、インストールの
/// 検証パイプライン(SHA-512 照合と ed25519 署名検証)は両方とも同じ
/// `store_providers.dart` 側で動く。
///
/// 第 4 段階 (D-401 / ORGATE O-004): お金は ORGATE が持つので、**ポイント (`GET /me/points`) と購入
/// (`POST /plugins/{id}/purchase`) だけは [payments](ORGATE の口)**へ送る。掲載 / 構成 / 配布物などはこれまでどおり
/// [_client](RASQ Central)。ORGATE につながない構成では、ポイント / 購入は使えない(はっきりしたエラー)。
/// `403 paid_features_disabled`(公開テストで有料の機能が止まっている)は [paidFeaturesDisabledMessage] にそろえる。
class HttpStoreClient implements StoreClient {
  HttpStoreClient(this._client, {this.payments});
  final OrgateClient _client;

  /// ORGATE-Server の口(ポイント / 購入)。null = ORGATE につながない構成。
  final OrgateClient? payments;

  /// `paid_features_disabled` を、アプリの文にそろえて投げ直す。
  static Future<T> _paid<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on OrgateException catch (e) {
      if (e.serverCode == paidFeaturesDisabledCode) throw OrgateException(e.code, paidFeaturesDisabledMessage, serverCode: e.serverCode);
      rethrow;
    }
  }

  OrgateClient _orgate(String what) =>
      payments ?? (throw OrgateException(ErrorCode.http(503), '$whatは ORGATE-Server につなぐと使えます(接続先が設定されていません)'));

  static List<StorePluginCard> _cards(Object? v) => [
        for (final c in (v as List? ?? const []))
          if (c is Map) StorePluginCard.fromJson(c.cast<String, Object?>()),
      ];

  @override
  Future<StoreHomeSections> home() async {
    final j = await _client.getJson('/home');
    return (trending: _cards(j['trending']), bookmarks: _cards(j['bookmarks']), recent: _cards(j['recent']));
  }

  @override
  Future<List<StorePluginCard>> search(String q, {Set<StoreFilter> filters = const {}}) async {
    final j = await _client.getJson('/plugins', {'q': q.trim(), 'filter': filters.isEmpty ? null : [for (final f in filters) f.wire].join(',')});
    return _cards(j['items']);
  }

  @override
  Future<StorePluginDetail?> plugin(String id) async {
    try {
      return StorePluginDetail.fromJson(await _client.getJson('/plugins/${Uri.encodeComponent(id)}'));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<InstallManifest?> manifest(String id, {String? version}) async {
    try {
      return await _paid(() async => InstallManifest.fromJson(await _client.getJson('/plugins/${Uri.encodeComponent(id)}/manifest', {'version': ?version})));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) =>
      // 版指定は API.md「?version= で版を選べる(既定は現在版)」。
      _paid(() => _client.getBytes('/plugins/${Uri.encodeComponent(pluginId)}/artifacts/${Uri.encodeComponent(artifactId)}', {'version': ?version}));

  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) async {
    final id = Uri.encodeComponent(pluginId);
    final m = InstallManifest.fromJson(await _client.getJson('/plugins/$id/manifest', {'version': ?version, 'session': sessionId}));
    final bundle = m.bundle;
    if (bundle == null) throw StateError('配布物がありません');
    final bytes = await _client.getBytes('/plugins/$id/artifacts/${Uri.encodeComponent(bundle.id)}', {'version': m.version, 'session': sessionId});
    return verifySessionPackage(pluginId: pluginId, version: version, manifest: m, bytes: bytes);
  }

  @override
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) async {
    final j = await _client.getJson('/plugins/${Uri.encodeComponent(id)}/reviews', {'sort': sort.wire});
    return [
      for (final r in (j['items'] as List? ?? const []))
        if (r is Map) StoreReview.fromJson(r.cast<String, Object?>()),
    ];
  }

  @override
  Future<List<ReleaseNote>> releases(String id) async {
    final j = await _client.getJson('/plugins/${Uri.encodeComponent(id)}/releases');
    return [
      for (final r in (j['items'] as List? ?? const []))
        if (r is Map) ReleaseNote.fromJson(r.cast<String, Object?>()),
    ];
  }

  @override
  Future<StoreReview> createReview(String pluginId, {required int rating, String title = '', String body = '', String? usedVersion}) async {
    final j = await _client.postJson('/plugins/${Uri.encodeComponent(pluginId)}/reviews', {
      'rating': rating,
      if (title.isNotEmpty) 'title': title,
      'body': body,
      'usedVersion': ?usedVersion,
    });
    return StoreReview.fromJson(j);
  }

  /// store.yaml `PUT /plugins/{id}/reviews/{reviewId}/vote`(D-137 で追加。
  /// orgate-server 側の実装はこれから — 未実装の 404 は呼び出し側が握る)。
  @override
  Future<void> voteReview(String pluginId, String reviewId, ReviewVote vote) =>
      _client.putJson('/plugins/${Uri.encodeComponent(pluginId)}/reviews/${Uri.encodeComponent(reviewId)}/vote', {'vote': vote.wire});

  @override
  Future<void> setBookmark(String pluginId, bool bookmarked) =>
      _client.putJson('/me/bookmarks', {'pluginId': pluginId, 'bookmarked': bookmarked});

  @override
  Future<List<StorePluginCard>> bookmarks() async => _cards(await _client.getList('/me/bookmarks'));

  /// 購入は ORGATE (D-401)。
  @override
  Future<StorePurchaseResult> purchase(String pluginId) => _paid(() async {
        final j = await _orgate('購入').postJson('/plugins/${Uri.encodeComponent(pluginId)}/purchase', const {});
        return (purchased: j['purchased'] == true, pointsSpent: (j['pointsSpent'] as num?)?.toInt() ?? 0, balance: (j['balance'] as num?)?.toInt() ?? 0);
      });

  /// ポイントの残高は ORGATE (D-401)。
  @override
  Future<StorePoints> points() => _paid(() async => StorePoints.fromJson(await _orgate('ポイント').getJson('/me/points')));
}

/// 共有セッションの一時実行で受け取った配布物の検証 (D-407、セキュリティ指摘 #11)。登録元は `store:`(審査済み = フル機能)
/// になるので、**通常のインストールと同じ** [verifyArtifact](SHA-512 照合 + ed25519 署名 + 焼き込んだ鍵のピン留め、
/// 鍵をピン留めしたビルドでは署名の欠落も失敗)を通す。構成が名乗るプラグイン / 版も、頼んだものと一致すること
/// (別のプラグイン / 版の署名済み配布物にすり替えさせない)。通らなければ例外(実行しない)。
/// [pinnedKey] はテストで差し替えるためのもの。
Future<Uint8List> verifySessionPackage({
  required String pluginId,
  String? version,
  required InstallManifest manifest,
  required Uint8List bytes,
  String pinnedKey = pinnedStorePublicKey,
}) async {
  if (manifest.pluginId != pluginId) throw StateError('構成のプラグイン (${manifest.pluginId}) が頼んだもの ($pluginId) と違います');
  if (version != null && manifest.version != version) throw StateError('構成の版 (${manifest.version}) が頼んだ版 ($version) と違います');
  final bundle = manifest.bundle;
  if (bundle == null) throw StateError('配布物がありません');
  final verified = await verifyArtifact(bytes: bytes, artifact: bundle, storePublicKey: manifest.storePublicKey, pinnedKey: pinnedKey);
  if (!verified.ok) throw StateError(verified.message);
  return bytes;
}
