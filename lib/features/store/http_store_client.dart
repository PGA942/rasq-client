import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;

import '../../backend/orgate_client.dart';
import 'store_client.dart';
import 'store_models.dart';

/// `orgate-server` の `/api/v1` に対する [StoreClient]。
/// 経路とペイロードは rasq-sdk-sample/openapi/store.yaml (D-033) の通り。
///
/// モック([MockStoreClient])との違いは**接続先だけ**で、インストールの
/// 検証パイプライン(SHA-512 照合と ed25519 署名検証)は両方とも同じ
/// `store_providers.dart` 側で動く。
class HttpStoreClient implements StoreClient {
  HttpStoreClient(this._client);
  final OrgateClient _client;

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
      return InstallManifest.fromJson(await _client.getJson('/plugins/${Uri.encodeComponent(id)}/manifest', {'version': ?version}));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) =>
      // 版指定は API.md「?version= で版を選べる(既定は現在版)」。
      _client.getBytes('/plugins/${Uri.encodeComponent(pluginId)}/artifacts/${Uri.encodeComponent(artifactId)}', {'version': ?version});

  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) async {
    final id = Uri.encodeComponent(pluginId);
    final m = InstallManifest.fromJson(await _client.getJson('/plugins/$id/manifest', {'version': ?version, 'session': sessionId}));
    final bundle = m.bundle;
    if (bundle == null) throw StateError('配布物がありません');
    final bytes = await _client.getBytes('/plugins/$id/artifacts/${Uri.encodeComponent(bundle.id)}', {'version': m.version, 'session': sessionId});
    if (bundle.sha512.isNotEmpty && bundle.sha512 != '-' && sha512.convert(bytes).toString() != bundle.sha512) {
      throw StateError('配布物が構成と違います(SHA-512 が一致しません)');
    }
    return bytes;
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

  @override
  Future<StorePurchaseResult> purchase(String pluginId) async {
    final j = await _client.postJson('/plugins/${Uri.encodeComponent(pluginId)}/purchase', const {});
    return (purchased: j['purchased'] == true, pointsSpent: (j['pointsSpent'] as num?)?.toInt() ?? 0, balance: (j['balance'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<StorePoints> points() async => StorePoints.fromJson(await _client.getJson('/me/points'));
}
