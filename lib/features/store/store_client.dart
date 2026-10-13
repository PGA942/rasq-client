import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/services.dart' show rootBundle;
import 'package:rasq_models/rasq_models.dart' show ErrorCode;

import '../../backend/orgate_client.dart' show OrgateException;

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
const storeSlotSamples = <({String id, String asset, String name, String summary, String description, List<String> features, List<(String, String)> permissions, double sizeMb})>[
  (id: 'sample.astell', asset: 'astell_plugin.wasm', name: 'ASTell 効果音・効果映像', summary: 'ASTell のプラグインアクションから効果音 / 生成した効果映像 / 定型テキストを流します。', description: 'スロット `astell.action`。ルーム下段の、このプラグインが宣言したボタンで FOW を開き、システム音(ピンポン / クリック)、紙吹雪・花火・拍手の生成 PNG、定型テキストを共有します。「ASTell で共有」した投稿の受け取りも表示します。', features: ['ASTell プラグインアクション', 'FOW'], permissions: [('fow.widget', '操作パネル(FOW)を出すため'), ('storage.safe', '効果の使用回数の保存')], sizeMb: 0.25),
  (id: 'sample.composer-media', asset: 'composer_media_plugin.wasm', name: 'メディア加工', summary: '添付画像のガンマ補正 / 回転 / 色相 / クロップ。', description: 'スロット `composer.media`。コンポーザーの添付タイルの「プラグインで加工」で FOW を開き、プレビューを見ながら適用します。処理は端末内の wasm だけで完結します。', features: ['メディアコンポーザー', 'FOW'], permissions: [('fow.widget', '加工パネル(FOW)を出すため'), ('storage.safe', '前回の設定の保存')], sizeMb: 0.53),
  (id: 'sample.composer-text', asset: 'composer_text_plugin.wasm', name: 'ハッシュタグ候補', summary: '本文で # を打つと候補が出て、タップで挿入します。', description: 'スロット `composer.text`。本文の変化を受け取り、カーソル直前が #〜 のときに候補 FOW(最近使ったタグ + 辞書)を出します。', features: ['テキストコンポーザー', 'FOW'], permissions: [('fow.widget', '候補パネル(FOW)を出すため'), ('storage.safe', '最近使ったタグの保存')], sizeMb: 0.14),
  (id: 'sample.media-fullscreen', asset: 'media_fullscreen_plugin.wasm', name: 'QR コード検出', summary: '全画面表示の画像から QR コードを見つけて枠を出し、タップでリンクを開けます。', description: 'スロット `viewer.overlay`。全画面ビューワーの画像を受け取って QR を検出し、バウンディングボックスを重ねます。タップでリンク FOW(コピー / ブラウザで開く / ミュート語に追加)。', features: ['全画面表示プラグイン', 'FOW'], permissions: [('fow.widget', 'リンクパネル(FOW)を出すため'), ('mute.words', '「このリンクをミュート」でミュート語に追加するため(毎回確認)')], sizeMb: 0.71),
  (id: 'sample.post-process', asset: 'post_process_plugin.wasm', name: '相対日付を日付に', summary: '「今日」「昨日」「明日」を投稿日基準の日付に置き換えます。', description: 'スロット `post.transform`。全 TL の表示直前に本文の相対日付を「9/10(今日)」のように書き換えます(JST)。URL の中は触りません。', features: ['投稿加工 (post.transform)'], permissions: [], sizeMb: 0.1),
  (id: 'sample.timeline', asset: 'timeline_plugin.wasm', name: 'Unicode 昇順 TL', summary: 'ホームに本文の Unicode 順で並ぶタブを足します。', description: 'スロット `tl`。基礎 TL(ホーム)を受け取り、本文の Unicode コードポイント昇順で並べ替えたカスタムタブを出します。', features: ['タイムライン (tl.sort)'], permissions: [], sizeMb: 0.1),
  (id: 'sample.post-share', asset: 'post_share_plugin.wasm', name: '共有テンプレート', summary: '共有 FOW から投稿をテンプレート(リンク / 引用 / 作者に言及)で整えてコンポーザーへ。', description: 'スロット `post.share`。投稿の共有 FOW の「プラグイン」節に自動で並び、タップするとインライン FOW で文面を選んでコンポーザー / コピー / ブラウザ / ASTell へ渡します。', features: ['投稿共有 (post.share)', 'FOW'], permissions: [('fow.widget', 'テンプレート選択パネル(FOW)を出すため'), ('storage.safe', '前回のテンプレートの保存')], sizeMb: 0.13),
  (id: 'sample.media-transform', asset: 'media_transform_plugin.wasm', name: '変形ハンドル', summary: '画像の上に回転 / クロップのハンドルを重ねて編集します。', description: 'スロット `composer.media`(変形)。メディアエディターのプレビューに RRL の重ね(契約 v0.5 `composer.media.overlay`)でハンドルを描き、指でなぞって回転角やクロップ範囲を決めます。', features: ['メディアコンポーザー', '重ね (overlay)'], permissions: [('fow.widget', 'パネル(FOW)を出すため')], sizeMb: 0.5),
  (id: 'sample.media-process', asset: 'media_process_plugin.wasm', name: '加工(顔ぼかし / スタンプ)', summary: '顔を検知してぼかす、スタンプをオブジェクトとして貼る(移動 / 拡縮 / 回転 / 削除 / 複製)。', description: 'スロット `composer.media`(加工)。顔検知は端末内の wasm(rustface)で行い、外部送信はありません。スタンプは重ねの枠とハンドルで動かせます。', features: ['メディアコンポーザー', '重ね (overlay)', 'FOW'], permissions: [('fow.widget', 'スタンプ選択パネル(FOW)を出すため')], sizeMb: 2.0),
  (id: 'sample.media-draw', asset: 'media_draw_plugin.wasm', name: '描画(ペン / 図形)', summary: 'ペンの軌跡をスプライン曲線で描く、四角 / 丸を追加して編集します。', description: 'スロット `composer.media`(描画)。ペンは指の軌跡を Catmull-Rom スプラインで滑らかにして描きます。図形はオブジェクトとして移動 / 拡縮 / 削除 / 複製できます。', features: ['メディアコンポーザー', '重ね (overlay)', 'FOW'], permissions: [('fow.widget', 'ペンの太さ / 色のパネル(FOW)を出すため'), ('storage.safe', 'ペンの設定の保存')], sizeMb: 0.5),
  (id: 'sample.post-action', asset: 'post_action_plugin.wasm', name: '投稿ボタン', summary: '後で読む / 本文をコピー / 引用の下書き — タグで既存ボタンのバンドルに入ります。', description: 'スロット `post.action`。マニフェストのタグ(希望スロット)が既存のアクションボタンに近ければ、そのバンドルの最下層に自動で入ります。「アクションリストの編集」でアカウントごとに有効 / 無効と閾値を変えられます。', features: ['投稿のアクションボタン (post.action)', 'FOW'], permissions: [('fow.widget', '後で読む一覧(FOW)を出すため'), ('storage.safe', '後で読むの保存')], sizeMb: 0.13),
  (id: 'sample.theme-starry', asset: 'theme_starry.rasqpkg', name: '着せ替え「星空」', summary: '夜空の背景、星の粒を重ねた投稿タイル、星のいいね。', description: '着せ替え(`kind: "theme"`、契約 v0.16)。コードを持たない配布物で、色 / アイコンの差し替え / 画面・投稿タイル・FOW・ボタンの背景の画像のレイヤーを宣言します。インストール後に 設定 → アプリの外観 → フォントやカラースキーム で選びます(暗いモードのときに効きます)。', features: ['着せ替え'], permissions: [], sizeMb: 0.09),
  (id: 'sample.theme-rasq', asset: 'theme_rasq.rasqpkg', name: '着せ替え「RASQ」', summary: '投稿の上に紺のグラデーションの帯と薄い RASQ のマーク、FOW は緑のグラデーション。', description: '着せ替え(`kind: "theme"`、契約 v0.17)。投稿タイルの上辺に #1F1E33 から投稿の背景色へ溶けるグラデーションの帯、背景に薄い RASQ のマーク、FOW の背景は上から下へ #02775C → #178178 のグラデーション(文字は白)。明るい / 暗いモードのどちらでも効きます。', features: ['着せ替え'], permissions: [], sizeMb: 0.02),
  (id: 'sample.paint', asset: 'custom_plugin_paint.wasm', name: 'みんなで落書き', summary: '1 人 1 マスの落書きを、期限つきでみんなに見せ合います。ASTell のルームやプロフィールで。', description: 'カスタムプラグイン(スロット `page`、契約 v0.22)。3:4 のマスを 2 列に並べ(並びは人ごとにシャッフル)、自分のマスを押すとメディア編集画面の SVG モードで落書きします。表示期間は各自が選び、管理者(セッションの持ち主)が既定と上限を決めます。期限が来ると Central が消します。管理者は他人の落書きを削除できます。', features: ['カスタムプラグイン (page)', 'SVG の落書き', '表示期間', 'ASTell', 'プロフィール'], permissions: [('render', '落書きのマスを表示し、編集画面を開くため'), ('shared.session', 'みんなの落書きと管理者の設定を、期限つきで共有するため')], sizeMb: 0.18),
  (id: 'sample.board', asset: 'custom_page_plugin.wasm', name: 'みんなのボード', summary: 'カウンター・投票・寄せ書き・🎉。ASTell のルームやプロフィールで、みんなで同じボードを使えます。', description: 'カスタムプラグイン(スロット `page`、契約 v0.18)。ページを 1 枚足し、共有セッションではサーバー変数(カウンター / 投票 / 寄せ書き)とサーバー関数(🎉 を全員に)で同じ画面を共有します。セッションが無いときは端末の中だけで動きます。', features: ['カスタムプラグイン (page)', 'ASTell', 'プロフィール'], permissions: [('render', 'ページを描くため'), ('shared.session', 'みんなの値(カウンター / 投票 / 寄せ書き)を共有するため'), ('storage.safe', '1 人で使うときのボードの保存')], sizeMb: 0.16),
  (id: 'sample.trend', asset: 'trend_plugin.wasm', name: 'トレンドサジェスト', summary: '今のトレンド語から関連タグをローカル規則で提案します。', description: 'スロット `trend.suggest`。TL のノード(トレンドを取得 / Today / 候補のチップ)と、検索ホームの「検索の候補」で出します。サーバー無しの共起辞書 + 前方一致です。', features: ['トレンド (trend.suggest)'], permissions: [], sizeMb: 0.1),
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
        name: 'Misskey コネクタ',
        summary: 'Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。TL 取得/投稿/リアクション/絵文字/投稿加工まで一式。',
        version: version,
        status: PluginStatus.published,
        origin: PluginOrigin.official,
        sizeMb: 1.8,
        description: 'rasq-sdk-sample の Rust 製 wasm プラグインです。sns.login / sns.timeline / post.transform / tl.sort などの契約(PROTOCOL.md)を実装し、RRL タイルで TL を描画します。ノード定義を持たない投稿加工は、取得ノードに渡す直前に適用されます。',
        safety: const SafetyBlock(
          rasqFeatures: ['タイムライン描画 (RRL)', 'ノードグラフ (tl.sort)', '投稿加工 (post.transform)'],
          permissions: [
            PermissionEntry('net.fetch', 'Misskey インスタンスの API を呼ぶため(接続先はログイン時に指定したホストのみ)'),
            PermissionEntry('storage.safe', 'セッショントークンと TL 設定の保存'),
          ],
          externalHosts: ['<ログインした Misskey インスタンス>'],
          dataHandling: '投稿・トークンは端末内(storage.safe)にのみ保存。開発元への送信はありません。',
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
          dataHandling: '処理は端末内の wasm で完結し、外部送信はありません。',
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

  static OrgateException _needsServer(String what) => OrgateException(ErrorCode.http(503), '$whatは RASQ サーバーにつなぐと使えます');

  @override
  Future<StorePurchaseResult> purchase(String pluginId) async => throw _needsServer('購入');

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
  Future<StoreReview> createReview(String pluginId, {required int rating, String title = '', String body = '', String? usedVersion}) async => throw _needsServer('レビュー');

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
    if (asset == null) throw OrgateException(ErrorCode.http(404), '掲載がありません');
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
