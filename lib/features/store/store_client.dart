import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/services.dart' show rootBundle;

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
/// - [MockStoreClient] — 接続先未設定のときの縮退。掲載は同梱 wasm サンプル
///   (実物)+ 架空 3 件。
/// - `HttpStoreClient` — `orgate-server` の `/api/v1`。接続先は
///   `orgateBaseUrlProvider`(`--dart-define=ORGATE_BASE_URL` か KV
///   `backend.v1` の `baseUrl`)で決まる。
///
/// **どちらでもインストール時の検証(SHA-512 + ed25519)は同じ経路を通る。**
abstract class StoreClient {
  Future<StoreHomeSections> home();
  Future<List<StorePluginCard>> search(String q);
  Future<StorePluginDetail?> plugin(String id);

  /// 構成取得。[version] 省略時は stable 最新(store.yaml `?version=`)。
  /// リリースノート FOW の「Ver.〇〇をインストール」はここで版を指定する (D-137)。
  Future<InstallManifest?> manifest(String id, {String? version});
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version});

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
}

/// 同梱 wasm サンプル(実プラグイン)のストア上の id。
const storeSamplePluginId = 'jp.rasq.misskey-wasm-sample';

/// モックストア (M4 v1)。掲載物 = 実在する同梱 wasm サンプル + 架空の
/// 掲載例。**検証パイプラインは本物**: manifest の SHA-512 は配布物バイトから
/// 計算し、インストール側が downloadArtifact の結果と照合する。
class MockStoreClient implements StoreClient {
  final _bytesCache = <String, Uint8List>{};

  static final _cards = <StorePluginDetail>[
    StorePluginDetail(
      id: storeSamplePluginId,
      name: 'Misskey コネクタ',
      summary: 'Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。TL 取得/投稿/リアクション/絵文字/投稿加工まで一式。',
      version: '0.5.0',
      status: PluginStatus.published,
      origin: PluginOrigin.official,
      rating: 4.6,
      downloads: 12840,
      sizeMb: 1.8,
      description: 'rasq-sdk-sample の Rust 製 wasm プラグインです。sns.login / sns.timeline / post.transform / tl.sort などの契約(PROTOCOL.md)を実装し、RRL タイルで TL を描画します。ノード定義を持たない投稿加工は、取得ノードに渡す直前に適用されます。',
      updatedAt: null,
      safety: SafetyBlock(
        rasqFeatures: ['タイムライン描画 (RRL)', 'ノードグラフ (tl.sort)', '投稿加工 (post.transform)'],
        permissions: [
          PermissionEntry('net.fetch', 'Misskey インスタンスの API を呼ぶため(接続先はログイン時に指定したホストのみ)'),
          PermissionEntry('storage.safe', 'セッショントークンと TL 設定の保存'),
        ],
        externalHosts: ['<ログインした Misskey インスタンス>'],
        dataHandling: '投稿・トークンは端末内(storage.safe)にのみ保存。開発元への送信はありません。',
        crashFreeRate: 0.998,
      ),
      compatibility: Compatibility(rasqVersion: '>=0.1.0', os: ['ios', 'android', 'macos', 'windows', 'linux']),
      developerName: 'RASQ Project',
      downloadsLastMonth: 1900,
      downloadHistory: [1500, 1620, 1780, 2340, 2410, 2760, 3600],
      ratingHistogram: [1, 2, 4, 9, 22],
    ),
    StorePluginDetail(
      id: 'net.example.siglip-reco',
      name: 'SigLIP レコメンダー',
      summary: '閲覧履歴のプロファイルから TL を並べ替えるおすすめノードを追加します。',
      version: '1.2.1',
      status: PluginStatus.beta,
      origin: PluginOrigin.verified,
      rating: 4.1,
      downloads: 3120,
      sizeMb: 96.4,
      description: 'SigLIP 埋め込みモデル(遅延ダウンロード)でおすすめ度を計算するノードプラグインです。ml.infer(カルクレーター)契約を使います。',
      safety: SafetyBlock(
        rasqFeatures: ['ノードグラフ', 'カルクレーター (ml.infer)'],
        permissions: [
          PermissionEntry('gpu_ml', '埋め込み計算を GPU で実行するため'),
          PermissionEntry('storage.safe', 'プロファイルベクトルの保存'),
        ],
        dataHandling: '埋め込みは端末内で計算し、外部送信はありません。',
        crashFreeRate: 0.991,
        usesGpu: true,
      ),
      compatibility: Compatibility(rasqVersion: '>=0.1.0', os: ['macos', 'windows', 'linux'], requiredRuntimes: ['onnx'], requiresPlugins: [storeSamplePluginId]),
      developerName: 'Example ML Labs',
      downloadsLastMonth: 420,
      downloadHistory: [2400, 2500, 2610, 2700, 2820, 2990, 3120],
      ratingHistogram: [0, 1, 3, 6, 5],
    ),
    StorePluginDetail(
      id: 'net.example.dict-sort',
      name: '辞書ソート',
      summary: '自作辞書(.dic)でタイムラインを並べ替えるノードを追加します。',
      version: '2.0.0',
      status: PluginStatus.updateAvailable,
      origin: PluginOrigin.community,
      rating: 3.8,
      downloads: 880,
      sizeMb: 0.4,
      description: 'ファイルリーダーで読み込んだ辞書を基準に、キーワード一致でソートするノードです。v2.0 でネット辞書の取得に対応(net.fetch 権限が増えています)。',
      safety: SafetyBlock(
        rasqFeatures: ['ノードグラフ'],
        permissions: [
          PermissionEntry('fs.read', 'ユーザーが指定した辞書ファイルの読み込み'),
          PermissionEntry('net.fetch', 'ネット辞書(v2.0 で追加)の取得'),
        ],
        dataHandling: '辞書の内容は端末内でのみ使用します。',
        crashFreeRate: 0.978,
      ),
      compatibility: Compatibility(rasqVersion: '>=0.1.0', os: ['ios', 'android', 'macos', 'windows', 'linux']),
      developerName: 'dict-tools',
      downloadsLastMonth: 130,
      downloadHistory: [600, 640, 690, 720, 760, 810, 880],
      ratingHistogram: [1, 1, 3, 2, 2],
    ),
    StorePluginDetail(
      id: 'net.example.ad-filter',
      name: '広告フィルター',
      summary: 'プロモーション投稿を条件ノードなしで一括で隠します。',
      version: '0.9.2',
      status: PluginStatus.warning,
      origin: PluginOrigin.community,
      rating: 2.9,
      downloads: 15400,
      sizeMb: 0.2,
      description: '投稿加工(post.transform)で広告らしい投稿に注釈を付けます。誤判定の報告が増えているため警告状態です。',
      safety: SafetyBlock(
        rasqFeatures: ['投稿加工 (post.transform)'],
        permissions: [PermissionEntry('storage.safe', 'フィルター設定の保存')],
        dataHandling: '投稿本文は端末内でのみ判定します。',
        crashFreeRate: 0.941,
        backgroundExecution: true,
      ),
      developerName: 'adless',
      downloadsLastMonth: 2300,
      downloadHistory: [9000, 10200, 11500, 12100, 13300, 14800, 15400],
      ratingHistogram: [12, 8, 6, 5, 4],
    ),
  ];

  /// ブックマークはサーバー側の状態なので、モックでは端末内に持つ。
  final _bookmarked = <String>{};
  final _reviews = <String, List<StoreReview>>{};

  @override
  Future<StoreHomeSections> home() async => (
        trending: <StorePluginCard>[_cards[0], _cards[1], _cards[3]],
        bookmarks: <StorePluginCard>[for (final c in _cards) if (_bookmarked.contains(c.id)) c],
        recent: <StorePluginCard>[_cards[2], _cards[1]],
      );

  @override
  Future<StoreReview> createReview(String pluginId, {required int rating, String title = '', String body = '', String? usedVersion}) async {
    final review = StoreReview(
      id: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      rating: rating,
      title: title,
      body: body,
      authorName: 'あなた',
      usedVersion: usedVersion ?? '',
      verifiedUse: true,
      createdAt: DateTime.now(),
    );
    (_reviews[pluginId] ??= []).insert(0, review);
    return review;
  }

  /// 投票はモックでは端末側([ReviewVotes])だけで完結する。サーバーが
  /// 無いので集計は動かない(受け取って捨てる)。
  @override
  Future<void> voteReview(String pluginId, String reviewId, ReviewVote vote) async {}

  @override
  Future<void> setBookmark(String pluginId, bool bookmarked) async =>
      bookmarked ? _bookmarked.add(pluginId) : _bookmarked.remove(pluginId);

  @override
  Future<List<StorePluginCard>> bookmarks() async => [for (final c in _cards) if (_bookmarked.contains(c.id)) c];

  @override
  Future<List<StorePluginCard>> search(String q) async {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List<StorePluginCard>.from(_cards);
    return [
      for (final c in _cards)
        if (c.name.toLowerCase().contains(query) || c.summary.toLowerCase().contains(query) || c.description.toLowerCase().contains(query)) c,
    ];
  }

  @override
  Future<StorePluginDetail?> plugin(String id) async => _cards.where((c) => c.id == id).firstOrNull;

  /// 配布物の実体: 同梱 wasm サンプルはアプリ同梱のアセット、架空掲載は
  /// 決定的なダミーバイト(id から生成)。
  Future<Uint8List> _bytesOf(String pluginId) async {
    final cached = _bytesCache[pluginId];
    if (cached != null) return cached;
    Uint8List bytes;
    if (pluginId == storeSamplePluginId) {
      bytes = (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List();
    } else {
      bytes = Uint8List.fromList(utf8.encode('rasqpkg-mock:$pluginId'));
    }
    return _bytesCache[pluginId] = bytes;
  }

  @override
  Future<InstallManifest?> manifest(String id, {String? version}) async {
    final detail = await plugin(id);
    if (detail == null) return null;
    final bytes = await _bytesOf(id);
    // 版指定 (D-137): リリースノートに載っている版だけ受ける。権限の増分は
    // その版のリリースノートから(現在版は掲載メタと同じ)。
    final notes = await releases(id);
    final target = version ?? detail.version;
    final note = notes.where((n) => n.version == target).firstOrNull;
    if (version != null && note == null) return null;
    return InstallManifest(
      pluginId: id,
      version: target,
      channel: note?.channel ?? detail.channel,
      manifest: {'id': id, 'name': detail.name, 'permissions': [for (final p in detail.safety.permissions) p.permission]},
      permissionsAdded: note?.permissionsAdded ?? const [],
      // モックは署名鍵を持たない。storePublicKey が空なので、インストール側は
      // SHA-512 照合だけを行い署名検証は飛ばす(サーバー接続時のみ検証が効く)。
      storePublicKey: '',
      artifacts: [
        StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: sha512.convert(bytes).toString()),
        if (id == 'net.example.siglip-reco') const StoreArtifact(id: 'model-siglip', kind: 'model', sizeBytes: 96 * 1024 * 1024, sha512: '-', lazy: true),
      ],
    );
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) => _bytesOf(pluginId);

  @override
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) async =>
      StoreReview.sorted([...?_reviews[id], ..._seededReviews(id)], sort);

  /// ダミーのレビュー TL (D-137)。ストアページの「レビュー」フレームには
  /// ここから関連性上位 10 件が出る。ワイヤーフレーム「レビューを表示」の
  /// タイル(見出し / 投稿者 / ★ / 本文 / 👍👎)を埋められる情報を持たせる。
  List<StoreReview> _seededReviews(String id) => switch (id) {
        storeSamplePluginId => [
            StoreReview(id: 'r1', rating: 5, title: 'wasm でここまで動く', body: 'wasm でここまで動くのすごい。TL も速いし、リアクションの反映も遅れない。', authorName: 'タロ・ヤマダ', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 12, notHelpfulCount: 1, createdAt: DateTime(2026, 8, 20)),
            StoreReview(id: 'r2', rating: 4, title: '絵文字ピッカーが最初だけ重い', body: '絵文字ピッカーの読み込みが最初だけ遅い。2 回目以降は問題なし。', authorName: 'mio', usedVersion: '0.4.2', verifiedUse: true, helpfulCount: 3, developerReply: '0.5.0 でキャッシュを入れました!', createdAt: DateTime(2026, 8, 2)),
            StoreReview(id: 'r3', rating: 3, title: '自動判定は万能ではない', body: '投稿加工の判定がガバくて、打ち上げ以外の投稿にも 🚀 が付くことがある。結局自分で確認しないといけないのは変わらなかった。', authorName: 'k_sato', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 9, notHelpfulCount: 2, createdAt: DateTime(2026, 8, 25)),
            StoreReview(id: 'r4', rating: 5, title: '複数インスタンスが楽', body: '3 つのインスタンスを 1 つの TL に流せるのが最高。関連TL との相性も良い。', authorName: 'なつめ', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 7, createdAt: DateTime(2026, 8, 30)),
            StoreReview(id: 'r5', rating: 2, title: 'カスタム絵文字が出ない時がある', body: '一部のインスタンスでカスタム絵文字がテキストのまま表示される。再ログインで直った。', authorName: 'rin', usedVersion: '0.4.2', verifiedUse: false, helpfulCount: 4, notHelpfulCount: 3, createdAt: DateTime(2026, 7, 28)),
            StoreReview(id: 'r6', rating: 4, title: '権限が最小限で安心', body: 'net.fetch がログインしたホストだけに制限されているのが確認できて安心した。', authorName: 'sec_watch', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 6, createdAt: DateTime(2026, 9, 1)),
            StoreReview(id: 'r7', rating: 5, body: '普通に使える。以上。', authorName: 'anon', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 1, createdAt: DateTime(2026, 9, 2)),
            StoreReview(id: 'r8', rating: 3, title: 'リノートの展開が惜しい', body: '純リノートの展開は直ったけど、引用リノートの中の引用は畳まれたまま。', authorName: 'tofu', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 5, notHelpfulCount: 1, createdAt: DateTime(2026, 9, 3)),
            StoreReview(id: 'r9', rating: 4, title: '投票が使える', body: '投票の作成と回答が両方できる。締切の表示が相対時間なのは好み。', authorName: 'poll_lover', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 2, createdAt: DateTime(2026, 8, 12)),
            StoreReview(id: 'r10', rating: 1, title: 'ログインできなかった', body: '自分のインスタンスだと OAuth の途中で止まる。サポートに連絡中。', authorName: 'yuki', usedVersion: '0.4.2', verifiedUse: false, helpfulCount: 0, notHelpfulCount: 4, developerReply: 'MiAuth 非対応のインスタンスかもしれません。DM で状況を教えてください。', createdAt: DateTime(2026, 7, 15)),
            StoreReview(id: 'r11', rating: 5, title: 'tl.sort が楽しい', body: 'リアクション順 TL をノードで組めるのが楽しい。サンプルとして完成度が高い。', authorName: 'nodeman', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 8, createdAt: DateTime(2026, 8, 29)),
            StoreReview(id: 'r12', rating: 4, title: 'DM も届く', body: 'DM の受信と既読が反映される。通知のタイミングが少しズレることがある。', authorName: 'hana', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 3, createdAt: DateTime(2026, 8, 18)),
          ],
        'net.example.siglip-reco' => [
            StoreReview(id: 's1', rating: 4, title: 'おすすめ精度は良い', body: 'モデルの初回ダウンロードが 96MB あるのは覚悟が要るが、おすすめ精度は良い。', authorName: 'ml_guy', usedVersion: '1.2.1', verifiedUse: true, helpfulCount: 5, createdAt: DateTime(2026, 8, 22)),
            StoreReview(id: 's2', rating: 3, title: 'GPU 必須', body: 'CPU だと数秒固まる。GPU 権限の説明はちゃんと書いてある。', authorName: 'lowspec', usedVersion: '1.2.0', verifiedUse: true, helpfulCount: 4, notHelpfulCount: 1, createdAt: DateTime(2026, 8, 5)),
          ],
        'net.example.dict-sort' => [
            StoreReview(id: 'd1', rating: 3, title: '権限が増えたのが気になる', body: 'v2 で権限が増えたのが気になる。オフラインで使いたいので 1.3 を維持している。', authorName: 'offline_first', usedVersion: '2.0.0', verifiedUse: true, helpfulCount: 8, createdAt: DateTime(2026, 8, 28)),
            StoreReview(id: 'd2', rating: 5, title: '自作辞書が活きる', body: 'Sudachi のユーザー辞書を流用できた。', authorName: 'jisho', usedVersion: '1.3.0', verifiedUse: true, helpfulCount: 3, createdAt: DateTime(2026, 6, 20)),
            StoreReview(id: 'd3', rating: 2, body: '大きい辞書だと起動が遅い。', authorName: 'anon', usedVersion: '1.3.0', verifiedUse: false, helpfulCount: 1, notHelpfulCount: 2, createdAt: DateTime(2026, 7, 2)),
          ],
        'net.example.ad-filter' => [
            StoreReview(id: 'a1', rating: 2, title: '誤判定が多い', body: 'セール告知じゃない投稿まで注釈が付く。設定で緩められるようにしてほしい。', authorName: 'shopper', usedVersion: '0.9.2', verifiedUse: true, helpfulCount: 15, notHelpfulCount: 2, createdAt: DateTime(2026, 8, 15)),
            StoreReview(id: 'a2', rating: 4, title: '広告が減った', body: 'プロモーション投稿がだいぶ減った。誤判定は自分で解除している。', authorName: 'quiet_tl', usedVersion: '0.9.2', verifiedUse: true, helpfulCount: 6, createdAt: DateTime(2026, 8, 27)),
          ],
        _ => const [],
      };

  @override
  Future<List<ReleaseNote>> releases(String id) async => switch (id) {
        storeSamplePluginId => [
            ReleaseNote(version: '0.6.0-pre.1', channel: 'beta', notes: 'sns.dm のリアルタイム受信(WebSocket)を試験導入。\n通知のタイミングずれを修正。', permissionsAdded: const [PermissionEntry('net.stream', 'インスタンスへの常時接続(DM リアルタイム受信)')], publishedAt: DateTime(2026, 9, 4)),
            ReleaseNote(version: '0.5.0', notes: 'sns.emojis / repostTargetId / reactionEmojis を追加(純リノートの展開を修正)。\n絵文字ピッカーの初回読み込みをキャッシュで高速化。', publishedAt: DateTime(2026, 9, 1)),
            ReleaseNote(version: '0.4.2', notes: 'tl.sort の安定化。', publishedAt: DateTime(2026, 8, 10)),
            ReleaseNote(version: '0.4.0', notes: '投票の作成・回答、DM の送受信に対応。', permissionsAdded: const [PermissionEntry('storage.safe', 'セッショントークンと TL 設定の保存')], publishedAt: DateTime(2026, 7, 20)),
          ],
        'net.example.siglip-reco' => [
            ReleaseNote(version: '1.2.1', channel: 'beta', notes: 'モデルの遅延ダウンロードに失敗したときの再試行を追加。', publishedAt: DateTime(2026, 8, 20)),
            ReleaseNote(version: '1.2.0', channel: 'beta', notes: 'SigLIP 埋め込みを GPU で計算するようにしました。', permissionsAdded: const [PermissionEntry('gpu_ml', '埋め込み計算を GPU で実行するため')], publishedAt: DateTime(2026, 8, 1)),
          ],
        'net.example.ad-filter' => [
            ReleaseNote(version: '0.9.2', notes: '判定語句を更新。', publishedAt: DateTime(2026, 8, 12)),
          ],
        'net.example.dict-sort' => [
            ReleaseNote(version: '2.0.0', notes: 'ネット辞書の取得に対応。', permissionsAdded: const [PermissionEntry('net.fetch', 'ネット辞書の取得')], publishedAt: DateTime(2026, 8, 25)),
            ReleaseNote(version: '1.3.0', notes: '大きい辞書の読み込みを高速化。', publishedAt: DateTime(2026, 6, 1)),
          ],
        _ => const [],
      };
}
