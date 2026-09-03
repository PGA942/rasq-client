import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/services.dart' show rootBundle;

import 'store_models.dart';

/// ストア API のクライアント境界 (D-033: openapi/store.yaml と同じ形)。
/// ORGATE-server 実装後は HTTP クライアントに差し替える(モック開発方針)。
abstract class StoreClient {
  Future<({List<StorePluginCard> trending, List<StorePluginCard> recent})> home();
  Future<List<StorePluginCard>> search(String q);
  Future<StorePluginDetail?> plugin(String id);
  Future<InstallManifest?> manifest(String id);
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId);
  Future<List<StoreReview>> reviews(String id);
  Future<List<ReleaseNote>> releases(String id);
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
      compatibility: Compatibility(rasqVersion: '>=0.1.0', os: ['macos', 'windows', 'linux'], requiredRuntimes: ['onnx']),
      developerName: 'Example ML Labs',
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
      ),
      developerName: 'adless',
    ),
  ];

  @override
  Future<({List<StorePluginCard> trending, List<StorePluginCard> recent})> home() async => (
        trending: <StorePluginCard>[_cards[0], _cards[1], _cards[3]],
        recent: <StorePluginCard>[_cards[2], _cards[1]],
      );

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
  Future<InstallManifest?> manifest(String id) async {
    final detail = await plugin(id);
    if (detail == null) return null;
    final bytes = await _bytesOf(id);
    return InstallManifest(
      pluginId: id,
      version: detail.version,
      channel: detail.channel,
      manifest: {'id': id, 'name': detail.name, 'permissions': [for (final p in detail.safety.permissions) p.permission]},
      permissionsAdded: id == 'net.example.dict-sort' ? const [PermissionEntry('net.fetch', 'ネット辞書(v2.0 で追加)の取得')] : const [],
      artifacts: [
        StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: sha512.convert(bytes).toString(), signature: 'mock-ed25519'),
        if (id == 'net.example.siglip-reco') const StoreArtifact(id: 'model-siglip', kind: 'model', sizeBytes: 96 * 1024 * 1024, sha512: '-', lazy: true),
      ],
    );
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId) => _bytesOf(pluginId);

  @override
  Future<List<StoreReview>> reviews(String id) async => switch (id) {
        storeSamplePluginId => [
            StoreReview(id: 'r1', rating: 5, body: 'wasm でここまで動くのすごい。TL も速い。', usedVersion: '0.5.0', verifiedUse: true, helpfulCount: 12, createdAt: DateTime(2026, 8, 20)),
            StoreReview(id: 'r2', rating: 4, body: '絵文字ピッカーの読み込みが最初だけ遅い。', usedVersion: '0.4.2', verifiedUse: true, helpfulCount: 3, developerReply: '0.5.0 でキャッシュを入れました!', createdAt: DateTime(2026, 8, 2)),
          ],
        'net.example.dict-sort' => [
            StoreReview(id: 'r3', rating: 3, body: 'v2 で権限が増えたのが気になる。オフラインで使いたい。', usedVersion: '2.0.0', verifiedUse: true, helpfulCount: 8, createdAt: DateTime(2026, 8, 28)),
          ],
        _ => const [],
      };

  @override
  Future<List<ReleaseNote>> releases(String id) async => switch (id) {
        storeSamplePluginId => [
            ReleaseNote(version: '0.5.0', notes: 'sns.emojis / repostTargetId / reactionEmojis を追加(純リノートの展開を修正)。', publishedAt: DateTime(2026, 9, 1)),
            ReleaseNote(version: '0.4.2', notes: 'tl.sort の安定化。', publishedAt: DateTime(2026, 8, 10)),
          ],
        'net.example.dict-sort' => [
            ReleaseNote(version: '2.0.0', notes: 'ネット辞書の取得に対応。', permissionsAdded: const [PermissionEntry('net.fetch', 'ネット辞書の取得')], publishedAt: DateTime(2026, 8, 25)),
            ReleaseNote(version: '1.3.0', notes: '大きい辞書の読み込みを高速化。', publishedAt: DateTime(2026, 6, 1)),
          ],
        _ => const [],
      };
}
