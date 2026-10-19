import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/services.dart' show rootBundle;
import 'package:rasq_models/rasq_models.dart' show ErrorCode;

import '../../backend/orgate_client.dart' show OrgateException;
import '../../l10n/l10n.dart';

import 'store_models.dart';

/// ストアホームの 3 セクション (D-033: 今週のトレンド/ブックマーク/おすすめ)。
typedef StoreHomeSections = ({
  List<StorePluginCard> trending,
  List<StorePluginCard> bookmarks,
  List<StorePluginCard> recent,
});

/// ストア API のクライアント境界 (D-033: openapi/store.yaml と同じ形)。
///
/// 実装は 2 つ:
/// - [BundledStoreClient] — 接続先未設定のときの縮退。掲載はアプリ同梱の実物だけ(D-393: 架空の掲載・数字・レビューは消した)。
/// - `HttpStoreClient` — `orgate-server` の `/api/v1`。接続先は
///   `orgateBaseUrlProvider`(`--dart-define=ORGATE_BASE_URL` か KV
///   `backend.v1` の `baseUrl`)で決まる。
///
/// **どちらでもインストール時の検証(SHA-512 + ed25519)は同じ経路を通る。**
abstract class StoreClient {
  Future<StoreHomeSections> home();
  /// 検索。[filters] = store.yaml `/plugins` の `filter`(free / no_ads / official / verified / recent / lightweight / offline)。
  Future<List<StorePluginCard>> search(String q, {Set<StoreFilter> filters = const {}});
  Future<StorePluginDetail?> plugin(String id);

  /// 構成取得。[version] 省略時は stable 最新(store.yaml `?version=`)。
  /// リリースノート FOW の「Ver.〇〇をインストール」はここで版を指定する (D-137)。
  Future<InstallManifest?> manifest(String id, {String? version});
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version});

  /// カスタムプラグインの共有セッションの参加者が、インストールせずに一時的に動かす本体 (D-357、S-048)。
  /// `?session=<id>` を付けて構成と配布物を取る(有料でも、そのセッションに入れる人なら通る)。SHA-512 を確かめてから返す。
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version});

  /// レビュー一覧。並びは [sort](サーバー側ソート。モックは端末側で並べる)。
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful});
  Future<List<ReleaseNote>> releases(String id);

  /// レビュー投稿(要認証)。`verifiedUse` はサーバーがインストール履歴から付ける。
  Future<StoreReview> createReview(String pluginId, {required int rating, String title, String body, String? usedVersion});

  /// レビューへの「参考になった / ならなかった」投票(要認証、1 アカウント 1 票)。
  Future<void> voteReview(String pluginId, String reviewId, ReviewVote vote);

  /// ブックマークの追加/削除(要認証)。
  Future<void> setBookmark(String pluginId, bool bookmarked);

  /// ブックマーク一覧(要認証)。
  Future<List<StorePluginCard>> bookmarks();

  /// 有料プラグインをポイントで買う (D-355、store.yaml `purchasePlugin`)。足りなければ `409`。
  /// 口は ORGATE-Server (D-401)。公開テストでは `403 paid_features_disabled`。
  Future<StorePurchaseResult> purchase(String pluginId);

  /// ポイントの残高と付与(ORGATE `GET /me/points`、D-401。前は Central)。公開テストでは `403 paid_features_disabled`。
  Future<StorePoints> points();
}

/// 同梱 wasm サンプル(実プラグイン)のストア上の id。
const storeSamplePluginId = 'jp.rasq.misskey-wasm-sample';

/// スロットプラグインのサンプル (D-168): ストア id = マニフェストの id、
/// 配布物 = 同梱の wasm(`assets/plugins/<asset>`)。インストールでスロット登録される。
List<({String id, String asset, String name, String summary, String description, List<String> features, List<(String, String)> permissions, double sizeMb})> get storeSlotSamples => storeSlotSamplesOf(appL10n);

/// [storeSlotSamples] の掲載の文を [l] の言語で。
List<({String id, String asset, String name, String summary, String description, List<String> features, List<(String, String)> permissions, double sizeMb})> storeSlotSamplesOf(AppLocalizations l) => [
  (id: 'sample.astell', asset: 'astell_plugin.wasm', name: l.storeCatalogAstellName, summary: l.storeCatalogAstellSummary, description: l.storeCatalogAstellDescription, features: [l.storeCatalogFeatureAstellAction, 'FOW'], permissions: [('fow.widget', l.storeCatalogAstellPerm1), ('storage.safe', l.storeCatalogAstellPerm2)], sizeMb: 0.25),
  (id: 'sample.composer-media', asset: 'composer_media_plugin.wasm', name: l.storeCatalogComposerMediaName, summary: l.storeCatalogComposerMediaSummary, description: l.storeCatalogComposerMediaDescription, features: [l.storeCatalogFeatureMediaComposer, 'FOW'], permissions: [('fow.widget', l.storeCatalogComposerMediaPerm1), ('storage.safe', l.storeCatalogComposerMediaPerm2)], sizeMb: 0.53),
  (id: 'sample.composer-text', asset: 'composer_text_plugin.wasm', name: l.storeCatalogComposerTextName, summary: l.storeCatalogComposerTextSummary, description: l.storeCatalogComposerTextDescription, features: [l.storeCatalogFeatureTextComposer, 'FOW'], permissions: [('fow.widget', l.storeCatalogComposerTextPerm1), ('storage.safe', l.storeCatalogComposerTextPerm2)], sizeMb: 0.14),
  (id: 'sample.media-fullscreen', asset: 'media_fullscreen_plugin.wasm', name: l.storeCatalogMediaFullscreenName, summary: l.storeCatalogMediaFullscreenSummary, description: l.storeCatalogMediaFullscreenDescription, features: [l.storeCatalogFeatureViewerPlugin, 'FOW'], permissions: [('fow.widget', l.storeCatalogMediaFullscreenPerm1), ('mute.words', l.storeCatalogMediaFullscreenPerm2)], sizeMb: 0.71),
  (id: 'sample.post-process', asset: 'post_process_plugin.wasm', name: l.storeCatalogPostProcessName, summary: l.storeCatalogPostProcessSummary, description: l.storeCatalogPostProcessDescription, features: [l.storeCatalogFeaturePostTransform], permissions: [], sizeMb: 0.1),
  (id: 'sample.timeline', asset: 'timeline_plugin.wasm', name: l.storeCatalogTimelineName, summary: l.storeCatalogTimelineSummary, description: l.storeCatalogTimelineDescription, features: [l.storeCatalogFeatureTimelineSort], permissions: [], sizeMb: 0.1),
  (id: 'sample.post-share', asset: 'post_share_plugin.wasm', name: l.storeCatalogPostShareName, summary: l.storeCatalogPostShareSummary, description: l.storeCatalogPostShareDescription, features: [l.storeCatalogFeaturePostShare, 'FOW'], permissions: [('fow.widget', l.storeCatalogPostSharePerm1), ('storage.safe', l.storeCatalogPostSharePerm2)], sizeMb: 0.13),
  (id: 'sample.media-transform', asset: 'media_transform_plugin.wasm', name: l.storeCatalogMediaTransformName, summary: l.storeCatalogMediaTransformSummary, description: l.storeCatalogMediaTransformDescription, features: [l.storeCatalogFeatureMediaComposer, l.storeCatalogFeatureOverlay], permissions: [('fow.widget', l.storeCatalogMediaTransformPerm1)], sizeMb: 0.5),
  (id: 'sample.media-process', asset: 'media_process_plugin.wasm', name: l.storeCatalogMediaProcessName, summary: l.storeCatalogMediaProcessSummary, description: l.storeCatalogMediaProcessDescription, features: [l.storeCatalogFeatureMediaComposer, l.storeCatalogFeatureOverlay, 'FOW'], permissions: [('fow.widget', l.storeCatalogMediaProcessPerm1)], sizeMb: 2.0),
  (id: 'sample.media-draw', asset: 'media_draw_plugin.wasm', name: l.storeCatalogMediaDrawName, summary: l.storeCatalogMediaDrawSummary, description: l.storeCatalogMediaDrawDescription, features: [l.storeCatalogFeatureMediaComposer, l.storeCatalogFeatureOverlay, 'FOW'], permissions: [('fow.widget', l.storeCatalogMediaDrawPerm1), ('storage.safe', l.storeCatalogMediaDrawPerm2)], sizeMb: 0.5),
  (id: 'sample.post-action', asset: 'post_action_plugin.wasm', name: l.storeCatalogPostActionName, summary: l.storeCatalogPostActionSummary, description: l.storeCatalogPostActionDescription, features: [l.storeCatalogFeaturePostAction, 'FOW'], permissions: [('fow.widget', l.storeCatalogPostActionPerm1), ('storage.safe', l.storeCatalogPostActionPerm2)], sizeMb: 0.13),
  (id: 'sample.theme-starry', asset: 'theme_starry.rasqpkg', name: l.storeCatalogThemeStarryName, summary: l.storeCatalogThemeStarrySummary, description: l.storeCatalogThemeStarryDescription, features: [l.storeCatalogFeatureTheme], permissions: [], sizeMb: 0.09),
  (id: 'sample.theme-rasq', asset: 'theme_rasq.rasqpkg', name: l.storeCatalogThemeRasqName, summary: l.storeCatalogThemeRasqSummary, description: l.storeCatalogThemeRasqDescription, features: [l.storeCatalogFeatureTheme], permissions: [], sizeMb: 0.02),
  (id: 'sample.paint', asset: 'custom_plugin_paint.wasm', name: l.storeCatalogPaintName, summary: l.storeCatalogPaintSummary, description: l.storeCatalogPaintDescription, features: [l.storeCatalogFeatureCustomPage, l.storeCatalogFeatureSvgPaint, l.storeCatalogFeatureDisplayPeriod, 'ASTell', l.storeCatalogFeatureProfile], permissions: [('render', l.storeCatalogPaintPerm1), ('shared.session', l.storeCatalogPaintPerm2)], sizeMb: 0.18),
  (id: 'sample.board', asset: 'custom_page_plugin.wasm', name: l.storeCatalogBoardName, summary: l.storeCatalogBoardSummary, description: l.storeCatalogBoardDescription, features: [l.storeCatalogFeatureCustomPage, 'ASTell', l.storeCatalogFeatureProfile], permissions: [('render', l.storeCatalogBoardPerm1), ('shared.session', l.storeCatalogBoardPerm2), ('storage.safe', l.storeCatalogBoardPerm3)], sizeMb: 0.16),
  (id: 'sample.trend', asset: 'trend_plugin.wasm', name: l.storeCatalogTrendName, summary: l.storeCatalogTrendSummary, description: l.storeCatalogTrendDescription, features: [l.storeCatalogFeatureTrendSuggest], permissions: [], sizeMb: 0.1),
];

/// モックストア (M4 v1)。掲載物 = 実在する同梱 wasm サンプル + 架空の
/// 掲載例。**検証パイプラインは本物**: manifest の SHA-512 は配布物バイトから
/// 計算し、インストール側が downloadArtifact の結果と照合する。
/// Central + 同梱カタログ (D-256): ふだんは [primary](Central)。**アプリに同梱しているサンプル**([bundledIds])で、Central に
/// 掲載が無い(404 = null)/ つながらないものだけ、[bundled](同梱のカタログ)で答える。サンプルのページが開けない・
/// 起動時の読み込み直しができない、を防ぐ。一覧 / 検索 / レビューの投稿などは Central のまま。
class BundledFallbackStoreClient implements StoreClient {
  BundledFallbackStoreClient(this.primary, this.bundled);
  final StoreClient primary;
  final StoreClient bundled;

  static final Set<String> bundledIds = {storeSamplePluginId, for (final s in storeSlotSamples) s.id};

  Future<T> _or<T>(String id, Future<T> Function(StoreClient c) call, bool Function(T value) missing) async {
    if (!bundledIds.contains(id)) return call(primary);
    try {
      final v = await call(primary);
      if (!missing(v)) return v;
    } catch (_) {}
    return call(bundled);
  }

  /// Central に掲載の無い(404)同梱のサンプルの id。一度調べたら、このクライアントの間は覚えておく。
  Set<String>? _unlisted;

  /// 一覧 / 検索に足す同梱のもの (D-443): Central の答えに無く、Central に**掲載そのものが無い**(詳細が 404)サンプルだけ。
  /// 着せ替え(星空 / RASQ)は Central に出したことが無く、ストアの一覧から消えていた(ページは開けた)。Central に掲載があって
  /// 一覧に出ないもの(審査中 / 非掲載 / 止めたもの)は足さない(Central の判断のまま)。
  Future<List<StorePluginCard>> _missing(Iterable<StorePluginCard> shown, Future<List<StorePluginCard>> Function() fromBundled) async {
    final ids = {for (final c in shown) c.id};
    var unlisted = _unlisted;
    if (unlisted == null) {
      unlisted = <String>{};
      for (final id in bundledIds) {
        if (ids.contains(id)) continue;
        try {
          if (await primary.plugin(id) == null) unlisted.add(id);
        } catch (_) {
          // つながらないなど: 足さない(次に一覧を開いたときにもう一度調べる)。
          return const [];
        }
      }
      _unlisted = unlisted;
    }
    if (unlisted.isEmpty) return const [];
    return [for (final c in await fromBundled()) if (unlisted.contains(c.id) && !ids.contains(c.id)) c];
  }

  @override
  Future<StoreHomeSections> home() async {
    final h = await primary.home();
    final extra = await _missing([...h.trending, ...h.bookmarks, ...h.recent], () async => (await bundled.home()).recent);
    if (extra.isEmpty) return h;
    return (trending: h.trending, bookmarks: h.bookmarks, recent: [...h.recent, ...extra]);
  }

  @override
  Future<List<StorePluginCard>> search(String q, {Set<StoreFilter> filters = const {}}) async {
    final found = await primary.search(q, filters: filters);
    return [...found, ...await _missing(found, () => bundled.search(q, filters: filters))];
  }
  @override
  // 版の空の詳細 = Central に掲載はあるが、承認済みの版がまだ無い(審査中)。同梱があればそちらで答える(rasq-central S-080 の前の
  // サーバーは、この詳細を 404 にせず返していた。みんなのボードが空のページになっていた)。
  Future<StorePluginDetail?> plugin(String id) => _or(id, (c) => c.plugin(id), (v) => v == null || v.version.isEmpty);
  @override
  Future<InstallManifest?> manifest(String id, {String? version}) => _or(id, (c) => c.manifest(id, version: version), (v) => v == null);
  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) => _or(pluginId, (c) => c.downloadArtifact(pluginId, artifactId, version: version), (v) => false);
  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) => _or(pluginId, (c) => c.sessionPackage(pluginId, sessionId, version: version), (v) => false);
  @override
  // レビュー / リリースノートは、空も正しい答え(同梱の作り物で埋めない、D-393)。
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) => primary.reviews(id, sort: sort);
  @override
  Future<List<ReleaseNote>> releases(String id) => primary.releases(id);
  @override
  Future<StoreReview> createReview(String pluginId, {required int rating, String title = '', String body = '', String? usedVersion}) => primary.createReview(pluginId, rating: rating, title: title, body: body, usedVersion: usedVersion);
  @override
  Future<void> voteReview(String pluginId, String reviewId, ReviewVote vote) => primary.voteReview(pluginId, reviewId, vote);
  @override
  Future<void> setBookmark(String pluginId, bool bookmarked) => primary.setBookmark(pluginId, bookmarked);
  @override
  Future<List<StorePluginCard>> bookmarks() => primary.bookmarks();
  @override
  Future<StorePurchaseResult> purchase(String pluginId) => primary.purchase(pluginId);
  @override
  Future<StorePoints> points() => primary.points();
}

/// 同梱の実物だけのストア (D-393)。RASQ Central につないでいないときの縮退で、Central につないでいるときも
/// 同梱のもの(Central に掲載の無いもの)のページ / 配布物をここで答える([BundledFallbackStoreClient])。
///
/// - 掲載 = アプリに同梱している**実物のプラグインだけ**(Misskey コネクタ + スロットプラグインのサンプル)。
///   以前の架空の掲載(`net.example.*`)と、評価 / ダウンロード数 / クラッシュしない率 / 推移 / レビュー / リリースノートの
///   作り物は消した(テストの `FakeStoreClient` に移した)。数字は 0 / 空 = 「まだ無い」。
/// - 版と出どころは、同梱のときに書き出した `assets/plugins/SOURCES.json`(`tool/build_bundled_plugins.sh`)から。
/// - レビュー / 購入 / ポイントはサーバーの機能なので、ここでは空 / 使えない(「RASQ サーバーにつないでください」)。
class BundledStoreClient implements StoreClient {
  final _bytesCache = <String, Uint8List>{};
  Map<String, Object?>? _sources;

  /// 同梱の記録(アセット名 → {repo, commit, version, sha256})。読めなければ空。
  Future<Map<String, Object?>> _sourceMap() async {
    if (_sources != null) return _sources!;
    try {
      // アセットのキャッシュは使わない(このクライアントの中で一度だけ読んで持つ。テストで、前のテストの読みかけの
      // キャッシュを待ち続けないように)。
      final j = jsonDecode(await rootBundle.loadString(bundledPluginSourcesAsset, cache: false));
      _sources = j is Map ? ((j['assets'] as Map?) ?? const {}).cast<String, Object?>() : <String, Object?>{};
    } catch (_) {
      _sources = <String, Object?>{};
    }
    return _sources!;
  }

  Future<String> _versionOf(String asset) async {
    final e = (await _sourceMap())[asset];
    return e is Map && e['version'] is String ? e['version'] as String : '';
  }

  static const _misskeyAsset = 'misskey_wasm_sample.wasm';

  static StorePluginDetail _misskey(String version) => StorePluginDetail(
        id: storeSamplePluginId,
        name: appL10n.storeCatalogMisskeyName,
        summary: appL10n.storeCatalogMisskeySummary,
        version: version,
        status: PluginStatus.published,
        origin: PluginOrigin.official,
        sizeMb: 1.8,
        description: appL10n.storeCatalogMisskeyDescription,
        safety: SafetyBlock(
          rasqFeatures: [appL10n.storeCatalogFeatureTimelineRrl, appL10n.storeCatalogFeatureNodeGraph, appL10n.storeCatalogFeaturePostTransform],
          permissions: [
            PermissionEntry('net.fetch', appL10n.storeCatalogMisskeyPerm1),
            PermissionEntry('storage.safe', appL10n.storeCatalogMisskeyPerm2),
          ],
          externalHosts: [appL10n.storeCatalogMisskeyHost],
          dataHandling: appL10n.storeCatalogMisskeyDataHandling,
        ),
        compatibility: const Compatibility(rasqVersion: '>=0.1.0', os: ['ios', 'android', 'macos', 'windows', 'linux']),
        developerName: 'RASQ Project',
        pluginType: StorePluginType.sns,
      );

  static StorePluginDetail _sample(({String id, String asset, String name, String summary, String description, List<String> features, List<(String, String)> permissions, double sizeMb}) x, String version) => StorePluginDetail(
        id: x.id,
        name: x.name,
        summary: x.summary,
        version: version,
        status: PluginStatus.published,
        origin: PluginOrigin.official,
        sizeMb: x.sizeMb,
        description: x.description,
        safety: SafetyBlock(
          rasqFeatures: x.features,
          permissions: [for (final (p, why) in x.permissions) PermissionEntry(p, why)],
          dataHandling: appL10n.storeCatalogSampleDataHandling,
        ),
        compatibility: const Compatibility(rasqVersion: '>=0.1.0', os: ['ios', 'android', 'macos', 'windows', 'linux']),
        developerName: 'RASQ Project',
        pluginType: _sampleType(x.asset),
      );

  Future<List<StorePluginDetail>> _all() async => [
        _misskey(await _versionOf(_misskeyAsset)),
        for (final x in storeSlotSamples) _sample(x, await _versionOf(x.asset)),
      ];

  /// 同梱サンプルの種別 (D-354): 配布物の名前から(マニフェストのスロットに合わせたもの)。
  static StorePluginType _sampleType(String asset) => switch (asset) {
        final a when a.startsWith('theme_') => StorePluginType.theme,
        final a when a.startsWith('astell') => StorePluginType.astell,
        final a when a.startsWith('composer') || a.startsWith('media_transform') || a.startsWith('media_process') || a.startsWith('media_draw') => StorePluginType.composer,
        final a when a.startsWith('media_fullscreen') => StorePluginType.viewer,
        final a when a.startsWith('post_') => StorePluginType.post,
        final a when a.startsWith('timeline') => StorePluginType.timeline,
        final a when a.startsWith('trend') => StorePluginType.trend,
        final a when a.startsWith('custom_page') => StorePluginType.custom,
        _ => StorePluginType.other,
      };

  /// ブックマークはサーバー側の状態なので、つないでいない間は端末内に持つ(再起動で消える)。
  final _bookmarked = <String>{};

  static OrgateException _needsServer(String what) => OrgateException(ErrorCode.http(503), appL10n.storeNeedsServer(what));

  @override
  Future<StorePurchaseResult> purchase(String pluginId) async => throw _needsServer(appL10n.storeFeaturePurchase);

  @override
  Future<StorePoints> points() async => const StorePoints(balance: 0, grants: []);

  @override
  Future<StoreHomeSections> home() async {
    final all = await _all();
    return (
      trending: const <StorePluginCard>[],
      bookmarks: <StorePluginCard>[for (final c in all) if (_bookmarked.contains(c.id)) c],
      recent: <StorePluginCard>[...all],
    );
  }

  @override
  Future<StoreReview> createReview(String pluginId, {required int rating, String title = '', String body = '', String? usedVersion}) async => throw _needsServer(appL10n.storeFeatureReview);

  @override
  Future<void> voteReview(String pluginId, String reviewId, ReviewVote vote) async {}

  @override
  Future<void> setBookmark(String pluginId, bool bookmarked) async => bookmarked ? _bookmarked.add(pluginId) : _bookmarked.remove(pluginId);

  @override
  Future<List<StorePluginCard>> bookmarks() async => [for (final c in await _all()) if (_bookmarked.contains(c.id)) c];

  @override
  Future<List<StorePluginCard>> search(String q, {Set<StoreFilter> filters = const {}}) async {
    final query = q.trim().toLowerCase();
    bool pass(StorePluginDetail c) => filters.every((f) => switch (f) {
          StoreFilter.free => c.price == 0,
          StoreFilter.noAds => !c.hasAds,
          StoreFilter.official => c.origin == PluginOrigin.official,
          StoreFilter.verified => c.origin == PluginOrigin.verified,
          StoreFilter.recent => true,
          StoreFilter.lightweight => c.sizeMb < 5,
          StoreFilter.offline => !c.safety.permissions.any((p) => p.permission.startsWith('net')),
        });
    return [
      for (final c in await _all())
        if (pass(c) && (query.isEmpty || c.name.toLowerCase().contains(query) || c.summary.toLowerCase().contains(query) || c.description.toLowerCase().contains(query))) c,
    ];
  }

  @override
  Future<StorePluginDetail?> plugin(String id) async => (await _all()).where((c) => c.id == id).firstOrNull;

  /// 配布物 = アプリ同梱のアセット。同梱していない id は 404。
  Future<Uint8List> _bytesOf(String pluginId) async {
    final cached = _bytesCache[pluginId];
    if (cached != null) return cached;
    final sample = storeSlotSamples.where((x) => x.id == pluginId).firstOrNull;
    final asset = pluginId == storeSamplePluginId ? _misskeyAsset : sample?.asset;
    if (asset == null) throw OrgateException(ErrorCode.http(404), appL10n.storeNoListing);
    return _bytesCache[pluginId] = (await rootBundle.load('assets/plugins/$asset')).buffer.asUint8List();
  }

  @override
  Future<InstallManifest?> manifest(String id, {String? version}) async {
    final detail = await plugin(id);
    if (detail == null) return null;
    // 同梱しているのは 1 つの版だけ。
    if (version != null && version != detail.version) return null;
    final bytes = await _bytesOf(id);
    return InstallManifest(
      pluginId: id,
      version: detail.version,
      channel: detail.channel,
      manifest: {'id': id, 'name': detail.name, 'permissions': [for (final p in detail.safety.permissions) p.permission]},
      // 同梱の配布物はアプリと一緒に届くので、署名は無い(storePublicKey が空 = SHA-512 の照合だけ)。
      storePublicKey: '',
      artifacts: [StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: sha512.convert(bytes).toString())],
    );
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) => _bytesOf(pluginId);

  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) => downloadArtifact(pluginId, 'bundle', version: version);

  /// レビュー / リリースノートはサーバーのもの。つないでいない間は無い。
  @override
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) async => const [];

  @override
  Future<List<ReleaseNote>> releases(String id) async => const [];
}

/// 同梱のプラグインの出どころ(ソースのリポジトリ / コミット / 版 / sha256、`tool/build_bundled_plugins.sh` が書く)。
const bundledPluginSourcesAsset = 'assets/plugins/SOURCES.json';
