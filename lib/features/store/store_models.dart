import 'package:flutter/foundation.dart';

/// プラグインストアのクライアント側モデル (M4 / D-120)。
/// 正本は rasq-sdk-sample/openapi/store.yaml (D-033)。ワイヤ(JSON)からの
/// 復元は各型の `fromJson` にあり、orgate-server の `/api/v1` 応答と
/// BundledStoreClient の両方がこの形に落ちる。

/// 状態表記の統一 (D-033: rasq_design のステータス表示と 1:1)。
enum PluginStatus {
  inReview('in_review', '審査中'),
  published('published', '公開中'),
  updateAvailable('update_available', '更新あり'),
  warning('warning', '警告'),
  suspended('suspended', '停止'),
  withdrawn('withdrawn', '取り下げ'),
  unlisted('unlisted', '非公開'),
  beta('beta', 'ベータ'),
  revoked('revoked', '失効');

  const PluginStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PluginStatus fromWire(String? w) => PluginStatus.values.where((s) => s.wire == w).firstOrNull ?? PluginStatus.published;

  /// 注意喚起系の状態(詳細画面でバナー表示)。
  bool get isCaution => this == warning || this == suspended || this == revoked;
}

/// 提供元の種別(公式/検証済み/コミュニティ)。
enum PluginOrigin {
  official('official', '公式'),
  verified('verified', '検証済み'),
  community('community', 'コミュニティ');

  const PluginOrigin(this.wire, this.label);
  final String wire;
  final String label;
  static PluginOrigin fromWire(String? w) => PluginOrigin.values.where((o) => o.wire == w).firstOrNull ?? PluginOrigin.community;
}

/// 一覧カード(ホーム/検索/ブックマーク)。
@immutable
class StorePluginCard {
  const StorePluginCard({
    required this.id,
    required this.name,
    this.summary = '',
    this.version = '',
    this.status = PluginStatus.published,
    this.origin = PluginOrigin.community,
    this.rating = 0,
    this.downloads = 0,
    this.sizeMb = 0,
    this.hasAds = false,
    this.price = 0,
    this.iconUrl,
    this.developerName = '',
    this.previews = const [],
    this.pluginType = StorePluginType.other,
  });

  /// store.yaml の PluginCard を復元する。省略されたキーは既定値のまま
  /// (`rating` は「評価なし」を 0 として扱う — 表示側が★0 と読める)。
  factory StorePluginCard.fromJson(Map<String, Object?> j) => StorePluginCard(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        version: j['version'] as String? ?? '',
        status: PluginStatus.fromWire(j['status'] as String?),
        origin: PluginOrigin.fromWire(j['origin'] as String?),
        rating: _num(j['rating']),
        downloads: _num(j['downloads']).toInt(),
        sizeMb: _num(j['sizeMb']),
        hasAds: j['hasAds'] == true,
        price: _num(j['price']),
        iconUrl: _uri(j['iconUrl']),
        developerName: j['developerName'] as String? ?? (((j['developer'] as Map?)?['name'] as String?) ?? ''),
        previews: [for (final u in _strings(j['previews'])) ?_uri(u)],
        pluginType: StorePluginType.fromWire(j['pluginType']),
      );

  final String id;
  final String name;
  final String summary;
  final String version;
  final PluginStatus status;
  final PluginOrigin origin;
  final double rating;
  final int downloads;
  final double sizeMb;
  final bool hasAds;
  final double price;
  final Uri? iconUrl;

  /// 開発者の表示名(ストアホームのタイル、D-353。古いサーバーは空)。
  final String developerName;

  /// タイルの自動スライドのプレビュー画像(詳細の screenshots の先頭 4 枚、D-353)。
  final List<Uri> previews;

  /// 種別(タイルの色と見出し、D-354)。古いサーバーは other。
  final StorePluginType pluginType;

  /// タイルに出すプレビュー(詳細なら、カードに無くてもスクリーンショットから)。
  List<Uri> get tilePreviews => previews;
}

/// プラグインの種別 (D-354、store.yaml `PluginCard.pluginType`)。ストアのタイルの色(色相)と見出し。
enum StorePluginType {
  sns('sns', 'SNS', 212),
  composer('composer', '投稿作成', 150),
  post('post', '投稿', 32),
  viewer('viewer', '全画面表示', 275),
  timeline('timeline', 'タイムライン', 188),
  astell('astell', 'AsTell', 330),
  trend('trend', 'トレンド', 0),
  theme('theme', '着せ替え', 52),
  assets('assets', 'ステッカー / 素材', 95),
  custom('custom', 'カスタム', 300),
  other('other', 'その他', -1);

  const StorePluginType(this.wire, this.label, this.hue);
  final String wire;
  final String label;

  /// 色相(-1 = 無彩色)。
  final double hue;

  static StorePluginType fromWire(Object? w) => values.where((t) => t.wire == w).firstOrNull ?? other;
}

/// 検索の絞り込み(store.yaml `/plugins` の `filter`、D-353 の検索画面のチップ)。
enum StoreFilter {
  free('free', '無料'),
  noAds('no_ads', '広告なし'),
  official('official', '公式'),
  verified('verified', '認証済み'),
  recent('recent', '30 日以内'),
  lightweight('lightweight', '軽量(5MB 未満)'),
  offline('offline', 'オフライン');

  const StoreFilter(this.wire, this.label);
  final String wire;
  final String label;
}

/// JSON の数値は int でも double でも来る(サーバーの avg は double、
/// downloads は int)。どちらでも受ける。
double _num(Object? v) => v is num ? v.toDouble() : 0;
Uri? _uri(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
List<String> _strings(Object? v) => v is List ? [for (final e in v) if (e is String) e] : const [];
List<int> _ints(Object? v) => v is List ? [for (final e in v) if (e is num) e.toInt()] : const [];
List<PermissionEntry> _permissions(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) PermissionEntry(e['permission'] as String? ?? '', e['reason'] as String? ?? ''),
      ]
    : const [];

/// 権限 1 件(manifest の権限 id + 開発者が記入した用途理由)。
@immutable
class PermissionEntry {
  const PermissionEntry(this.permission, this.reason);
  final String permission;
  final String reason;

  /// 権限 id の種別(表示のグループ分け, D-137)。
  PermissionKind get kind => PermissionKind.of(permission);
}

/// 権限の種別 (D-137: 「プライバシーと必要な権限」を権限タイプごとに
/// グループ表示する)。manifest の権限 id は `<領域>.<操作>` か
/// `<領域>_<修飾>` なので、先頭の領域語で分類する。未知の領域は
/// [other] に落ちる(隠さない)。
enum PermissionKind {
  network('ネットワーク', '外部への通信'),
  storage('ストレージ', '端末内の保存領域'),
  files('ファイル', 'ユーザーが選んだファイルの読み書き'),
  sns('投稿とアカウント', 'SNS アカウントを使った操作'),
  dm('ダイレクトメッセージ', 'DM の読み書き'),
  gpuMl('GPU / 機械学習', 'GPU 実行・モデル推論'),
  clipboard('クリップボード', 'コピー内容の読み書き'),
  background('バックグラウンド実行', '画面を閉じても動作'),
  ui('画面と配置', '画面の表示とボタンの配置'),
  other('その他', '');

  const PermissionKind(this.label, this.description);
  final String label;
  final String description;

  static PermissionKind of(String permission) {
    final head = permission.split(RegExp(r'[._:/]')).first.toLowerCase();
    return switch (head) {
      'net' || 'network' || 'http' || 'fetch' => network,
      'storage' || 'kv' || 'cache' => storage,
      'fs' || 'file' || 'files' => files,
      'sns' || 'post' || 'account' || 'timeline' || 'tl' => sns,
      'dm' => dm,
      'gpu' || 'gpu_ml' || 'ml' || 'model' => gpuMl,
      'clipboard' => clipboard,
      'background' || 'bg' => background,
      'fow' || 'ui' || 'widget' || 'action' => ui,
      _ => head.startsWith('gpu') ? gpuMl : other,
    };
  }

  /// [permissions] を種別ごとにまとめる(出現順 = enum 順、空の種別は除く)。
  static List<PermissionGroup> group(Iterable<PermissionEntry> permissions) {
    final map = <PermissionKind, List<PermissionEntry>>{};
    for (final p in permissions) {
      (map[p.kind] ??= []).add(p);
    }
    return [for (final k in PermissionKind.values) if (map[k] case final list?) PermissionGroup(k, list)];
  }
}

/// 同じ種別の権限のまとまり(「プライバシーと必要な権限」の 1 フレーム)。
@immutable
class PermissionGroup {
  const PermissionGroup(this.kind, this.entries);
  final PermissionKind kind;
  final List<PermissionEntry> entries;
}

/// 詳細画面上部の常設ブロック(権限・安全性, D-033)。
@immutable
class SafetyBlock {
  const SafetyBlock({
    this.rasqFeatures = const [],
    this.permissions = const [],
    this.externalHosts = const [],
    this.dataHandling = '',
    this.crashFreeRate,
    this.backgroundExecution = false,
    this.usesGpu = false,
    this.externalSdks = const [],
    this.adPlacements = const [],
  });

  final List<String> rasqFeatures;
  final List<PermissionEntry> permissions;
  final List<String> externalHosts;
  final String dataHandling;
  final double? crashFreeRate;
  final bool backgroundExecution;
  final bool usesGpu;
  final List<String> externalSdks;
  final List<String> adPlacements;

  /// 端末に控える形([InstalledInfo]。`fromJson` で読み戻せる)。
  Map<String, Object?> toJson() => {
        'rasqFeatures': rasqFeatures,
        'permissions': [for (final p in permissions) {'permission': p.permission, 'reason': p.reason}],
        'externalHosts': externalHosts,
        'dataHandling': dataHandling,
        if (crashFreeRate != null) 'crashFreeRate': crashFreeRate,
        'backgroundExecution': backgroundExecution,
        'usesGpu': usesGpu,
        'externalSdks': externalSdks,
        'adPlacements': adPlacements,
      };

  factory SafetyBlock.fromJson(Map<String, Object?> j) => SafetyBlock(
        rasqFeatures: _strings(j['rasqFeatures']),
        permissions: _permissions(j['permissions']),
        externalHosts: _strings(j['externalHosts']),
        dataHandling: j['dataHandling'] as String? ?? '',
        crashFreeRate: j['crashFreeRate'] is num ? (j['crashFreeRate'] as num).toDouble() : null,
        backgroundExecution: j['backgroundExecution'] == true,
        usesGpu: j['usesGpu'] == true,
        externalSdks: _strings(j['externalSdks']),
        adPlacements: _strings(j['adPlacements']),
      );
}

@immutable
class Compatibility {
  const Compatibility({this.rasqVersion = '', this.os = const [], this.requiresPlugins = const [], this.conflictsWith = const [], this.requiredRuntimes = const []});
  final String rasqVersion;
  final List<String> os;
  final List<String> requiresPlugins;
  final List<String> conflictsWith;
  final List<String> requiredRuntimes;

  factory Compatibility.fromJson(Map<String, Object?> j) => Compatibility(
        rasqVersion: j['rasqVersion'] as String? ?? '',
        os: _strings(j['os']),
        requiresPlugins: _strings(j['requiresPlugins']),
        conflictsWith: _strings(j['conflictsWith']),
        requiredRuntimes: _strings(j['requiredRuntimes']),
      );
}

/// プラグインページ(詳細)。
@immutable
class StorePluginDetail extends StorePluginCard {
  const StorePluginDetail({
    required super.id,
    required super.name,
    super.summary,
    super.version,
    super.status,
    super.origin,
    super.rating,
    super.downloads,
    super.sizeMb,
    super.hasAds,
    super.price,
    super.iconUrl,
    super.developerName,
    super.previews,
    super.pluginType,
    this.purchased,
    this.description = '',
    this.channel = 'stable',
    this.updatedAt,
    this.safety = const SafetyBlock(),
    this.compatibility = const Compatibility(),
    this.supportUrl,
    this.screenshots = const [],
    this.bannerUrl,
    this.downloadsLastMonth,
    this.downloadHistory = const [],
    this.ratingHistogram = const [],
  });

  /// store.yaml の PluginDetail は `allOf: [PluginCard, {...}]` なので、
  /// サーバーは 1 つの平坦なオブジェクトを返す。カード部分も同じ JSON から読む。
  factory StorePluginDetail.fromJson(Map<String, Object?> j) {
    final card = StorePluginCard.fromJson(j);
    final dev = (j['developer'] as Map?)?.cast<String, Object?>() ?? const {};
    return StorePluginDetail(
      id: card.id,
      name: card.name,
      summary: card.summary,
      version: card.version,
      status: card.status,
      origin: card.origin,
      rating: card.rating,
      downloads: card.downloads,
      sizeMb: card.sizeMb,
      hasAds: card.hasAds,
      price: card.price,
      iconUrl: card.iconUrl,
      previews: card.previews,
      pluginType: card.pluginType,
      purchased: j['purchased'] as bool?,
      description: j['description'] as String? ?? '',
      channel: j['channel'] as String? ?? 'stable',
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      safety: SafetyBlock.fromJson((j['safety'] as Map?)?.cast<String, Object?>() ?? const {}),
      compatibility: Compatibility.fromJson((j['compatibility'] as Map?)?.cast<String, Object?>() ?? const {}),
      developerName: dev['name'] as String? ?? '',
      supportUrl: _uri(dev['supportUrl']),
      screenshots: [for (final u in _strings(j['screenshots'])) ?Uri.tryParse(u)],
      bannerUrl: _uri(j['bannerUrl']),
      downloadsLastMonth: j['downloadsLastMonth'] is num ? (j['downloadsLastMonth'] as num).toInt() : null,
      downloadHistory: _ints(j['downloadHistory']),
      ratingHistogram: _ints(j['ratingHistogram']),
    );
  }

  final String description;
  final String channel;
  final DateTime? updatedAt;

  /// 見ている RASQ アカウントが買っているか(有料でログイン中のときだけ、D-355)。null = 分からない / 無料。
  final bool? purchased;

  /// 買わないと入れられないか。
  bool get needsPurchase => price > 0 && purchased != true;

  /// 購入の状態だけ差し替えた写し(モックストア / 買った直後)。
  StorePluginDetail withPurchased(bool? value) => StorePluginDetail(
        id: id,
        name: name,
        summary: summary,
        version: version,
        status: status,
        origin: origin,
        rating: rating,
        downloads: downloads,
        sizeMb: sizeMb,
        hasAds: hasAds,
        price: price,
        iconUrl: iconUrl,
        developerName: developerName,
        previews: previews,
        pluginType: pluginType,
        purchased: value,
        description: description,
        channel: channel,
        updatedAt: updatedAt,
        safety: safety,
        compatibility: compatibility,
        supportUrl: supportUrl,
        screenshots: screenshots,
        bannerUrl: bannerUrl,
        downloadsLastMonth: downloadsLastMonth,
        downloadHistory: downloadHistory,
        ratingHistogram: ratingHistogram,
      );
  final SafetyBlock safety;
  final Compatibility compatibility;
  final Uri? supportUrl;
  final List<Uri> screenshots;

  @override
  List<Uri> get tilePreviews => previews.isNotEmpty ? previews : screenshots.take(4).toList();

  /// ストアページ上部のバナー画像(ワイヤーフレーム「全体像」)。無ければ
  /// アイコン色のプレースホルダー。
  final Uri? bannerUrl;

  /// 「先月のダウンロード数」。null = サーバーが集計を返していない(非表示)。
  final int? downloadsLastMonth;

  /// 直近の累積ダウンロード推移(古い → 新しい、等間隔)。折れ線の点。
  final List<int> downloadHistory;

  /// 評価の分布 `[★1, ★2, ★3, ★4, ★5]` の件数。空ならレビューから導く。
  final List<int> ratingHistogram;
}

/// 配布物 1 件(.rasqpkg 本体 / ML モデル / アセット, D-034)。
@immutable
class StoreArtifact {
  const StoreArtifact({required this.id, this.kind = 'bundle', required this.sizeBytes, required this.sha512, this.signature = '', this.lazy = false});
  final String id;
  final String kind;
  final int sizeBytes;
  final String sha512;
  final String signature;
  final bool lazy;

  factory StoreArtifact.fromJson(Map<String, Object?> j) => StoreArtifact(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? 'bundle',
        sizeBytes: _num(j['sizeBytes']).toInt(),
        sha512: j['sha512'] as String? ?? '',
        signature: j['signature'] as String? ?? '',
        lazy: j['lazy'] == true,
      );
}

/// インストール確認シートと検証の根拠 (D-033/D-034)。
@immutable
class InstallManifest {
  const InstallManifest({
    required this.pluginId,
    required this.version,
    this.channel = 'stable',
    this.manifest = const {},
    this.permissionsAdded = const [],
    this.artifacts = const [],
    this.storePublicKey = '',
  });

  final String pluginId;
  final String version;
  final String channel;
  final Map<String, Object?> manifest;
  final List<PermissionEntry> permissionsAdded;
  final List<StoreArtifact> artifacts;

  /// 署名検証に使うストアの ed25519 公開鍵 (base64)。store.yaml には無い
  /// RASQ の追加フィールドで、クライアントは焼き込んだ鍵と一致することを
  /// 確かめてから `artifacts[].signature` を検証する (D-034)。
  final String storePublicKey;

  /// 本体(.rasqpkg)の配布物。無ければインストールできない。
  StoreArtifact? get bundle => artifacts.where((a) => a.kind == 'bundle').firstOrNull;

  factory InstallManifest.fromJson(Map<String, Object?> j) => InstallManifest(
        pluginId: j['pluginId'] as String? ?? '',
        version: j['version'] as String? ?? '',
        channel: j['channel'] as String? ?? 'stable',
        manifest: (j['manifest'] as Map?)?.cast<String, Object?>() ?? const {},
        permissionsAdded: _permissions(j['permissionsAdded']),
        artifacts: [
          for (final a in (j['artifacts'] as List? ?? const []))
            if (a is Map) StoreArtifact.fromJson(a.cast<String, Object?>()),
        ],
        storePublicKey: j['storePublicKey'] as String? ?? '',
      );
}

/// レビュー TL の並び順(store.yaml `GET /reviews?sort=`)。
enum ReviewSort {
  helpful('helpful', '関連性'),
  recent('recent', '最新'),
  ratingHigh('rating_high', '評価が高い'),
  ratingLow('rating_low', '評価が低い');

  const ReviewSort(this.wire, this.label);
  final String wire;
  final String label;
}

/// レビューへの「参考になった」投票(端末側の状態。KV `store.reviewVotes.v1`)。
enum ReviewVote {
  none('none'),
  up('up'),
  down('down');

  const ReviewVote(this.wire);
  final String wire;
  static ReviewVote fromWire(String? w) => ReviewVote.values.where((v) => v.wire == w).firstOrNull ?? ReviewVote.none;
}

@immutable
class StoreReview {
  const StoreReview({
    required this.id,
    required this.rating,
    this.title = '',
    this.body = '',
    this.authorName = '',
    this.authorHandle = '',
    this.authorAvatarUrl,
    this.usedVersion = '',
    this.verifiedUse = false,
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.developerReply,
    required this.createdAt,
  });
  final String id;
  final int rating;

  /// 見出し(ワイヤーフレーム「自動判定は万能ではない」)。空なら本文の先頭行。
  final String title;
  final String body;

  /// 投稿者(RASQ アカウントの表示名 / ハンドル / アバター)。匿名なら空。
  final String authorName;
  final String authorHandle;
  final Uri? authorAvatarUrl;
  final String usedVersion;
  final bool verifiedUse;
  final int helpfulCount;
  final int notHelpfulCount;
  final String? developerReply;
  final DateTime createdAt;

  /// タイルの見出し: [title] があればそれ、無ければ本文の 1 行目。
  String get headline => title.isNotEmpty ? title : body.split('\n').first;

  /// 「関連性」の並び (D-137): 参考になった数 → 実利用済み → 新しさ。
  /// サーバーの `helpful` ソートと同じ基準を端末側でも再現する。
  static int compareRelevance(StoreReview a, StoreReview b) {
    final byHelpful = (b.helpfulCount - b.notHelpfulCount).compareTo(a.helpfulCount - a.notHelpfulCount);
    if (byHelpful != 0) return byHelpful;
    if (a.verifiedUse != b.verifiedUse) return a.verifiedUse ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// [sort] で並べ替えたコピー。
  static List<StoreReview> sorted(Iterable<StoreReview> reviews, ReviewSort sort) {
    final list = [...reviews];
    switch (sort) {
      case ReviewSort.helpful:
        list.sort(compareRelevance);
      case ReviewSort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ReviewSort.ratingHigh:
        list.sort((a, b) => b.rating != a.rating ? b.rating.compareTo(a.rating) : compareRelevance(a, b));
      case ReviewSort.ratingLow:
        list.sort((a, b) => a.rating != b.rating ? a.rating.compareTo(b.rating) : compareRelevance(a, b));
    }
    return list;
  }

  /// `[★1 … ★5]` の件数分布。
  static List<int> histogram(Iterable<StoreReview> reviews) {
    final h = List<int>.filled(5, 0);
    for (final r in reviews) {
      if (r.rating >= 1 && r.rating <= 5) h[r.rating - 1]++;
    }
    return h;
  }

  StoreReview copyWith({int? helpfulCount, int? notHelpfulCount}) => StoreReview(
        id: id,
        rating: rating,
        title: title,
        body: body,
        authorName: authorName,
        authorHandle: authorHandle,
        authorAvatarUrl: authorAvatarUrl,
        usedVersion: usedVersion,
        verifiedUse: verifiedUse,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        notHelpfulCount: notHelpfulCount ?? this.notHelpfulCount,
        developerReply: developerReply,
        createdAt: createdAt,
      );

  factory StoreReview.fromJson(Map<String, Object?> j) {
    final author = (j['author'] as Map?)?.cast<String, Object?>() ?? const {};
    return StoreReview(
      id: j['id'] as String? ?? '',
      rating: _num(j['rating']).toInt(),
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      authorName: author['name'] as String? ?? '',
      authorHandle: author['handle'] as String? ?? '',
      authorAvatarUrl: _uri(author['avatarUrl']),
      usedVersion: j['usedVersion'] as String? ?? '',
      verifiedUse: j['verifiedUse'] == true,
      helpfulCount: _num(j['helpfulCount']).toInt(),
      notHelpfulCount: _num(j['notHelpfulCount']).toInt(),
      developerReply: j['developerReply'] as String?,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

@immutable
class ReleaseNote {
  const ReleaseNote({required this.version, this.channel = 'stable', this.notes = '', this.permissionsAdded = const [], required this.publishedAt});
  final String version;
  final String channel;
  final String notes;
  final List<PermissionEntry> permissionsAdded;
  final DateTime publishedAt;

  factory ReleaseNote.fromJson(Map<String, Object?> j) => ReleaseNote(
        version: j['version'] as String? ?? '',
        channel: j['channel'] as String? ?? 'stable',
        notes: j['notes'] as String? ?? '',
        permissionsAdded: _permissions(j['permissionsAdded']),
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// インストール時に控える掲載の写し (D-256): ストアの掲載が消えても / つながらなくても、インストール済みのページで
/// 「何を入れたか」(見出し部と、プライバシーと必要な権限)を見せられるように。
@immutable
class InstalledInfo {
  const InstalledInfo({this.summary = '', this.description = '', this.developerName = '', this.iconUrl, this.safety = const SafetyBlock()});
  final String summary;
  final String description;
  final String developerName;
  final Uri? iconUrl;
  final SafetyBlock safety;

  factory InstalledInfo.of(StorePluginDetail d) => InstalledInfo(summary: d.summary, description: d.description, developerName: d.developerName, iconUrl: d.iconUrl, safety: d.safety);

  Map<String, Object?> toJson() => {'summary': summary, 'description': description, 'developerName': developerName, if (iconUrl != null) 'iconUrl': '$iconUrl', 'safety': safety.toJson()};
  factory InstalledInfo.fromJson(Map<String, Object?> j) => InstalledInfo(
        summary: j['summary'] as String? ?? '',
        description: j['description'] as String? ?? '',
        developerName: j['developerName'] as String? ?? '',
        iconUrl: j['iconUrl'] is String ? Uri.tryParse(j['iconUrl'] as String) : null,
        safety: j['safety'] is Map ? SafetyBlock.fromJson((j['safety'] as Map).cast<String, Object?>()) : const SafetyBlock(),
      );
}

/// 入っている版 1 つ (D-355): 検証済みの SHA-512 とチャンネル。
@immutable
class InstalledVersion {
  const InstalledVersion({required this.version, required this.sha512, required this.installedAt, this.channel = 'stable'});
  final String version;
  final String sha512;
  final DateTime installedAt;
  final String channel;

  bool get isPreview => channel != 'stable';

  Map<String, Object?> toJson() => {'version': version, 'sha512': sha512, 'installedAt': installedAt.toIso8601String(), 'channel': channel};
  factory InstalledVersion.fromJson(Map<String, Object?> j) => InstalledVersion(
        version: j['version'] as String? ?? '',
        sha512: j['sha512'] as String? ?? '',
        installedAt: DateTime.tryParse(j['installedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        channel: j['channel'] as String? ?? 'stable',
      );
}

/// インストール済みプラグイン(KV `store.installed.v1` に永続化)。
///
/// 版 (D-355): **いくつかの版を並べて入れておける**([versions])。[version] / [sha512] = **既定の版**(アカウントごとの指定が無い
/// アカウントが使う)。[accountVersions] = SNS アカウント(キー)→ そのアカウントで使う版(「アカウントごとにバージョンを設定」)。
/// 動かす(スロットに登録する)のは、既定と、どれかのアカウントが指定している版だけ([usedVersions])。
@immutable
class InstalledPlugin {
  const InstalledPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.sha512,
    required this.installedAt,
    this.info,
    this.versions = const [],
    this.accountVersions = const {},
    this.pluginType = StorePluginType.other,
  });
  final String id;
  final String name;

  /// 既定の版。
  final String version;

  /// 既定の版の、検証済み配布物の SHA-512(インストール時に照合した値)。
  final String sha512;
  final DateTime installedAt;

  /// 掲載の写し (D-256)。それより前に入れたものは null。
  final InstalledInfo? info;

  /// 入っている版(新しく入れた順)。空 = 古い記録(既定の版だけ)。
  final List<InstalledVersion> versions;

  /// アカウントのキー → そのアカウントで使う版 (D-355)。
  final Map<String, String> accountVersions;

  /// 種別(アップデートの設定の区分、D-355)。
  final StorePluginType pluginType;

  /// 入っている版(古い記録でも既定の版を 1 つ返す)。
  List<InstalledVersion> get allVersions => versions.isNotEmpty ? versions : [InstalledVersion(version: version, sha512: sha512, installedAt: installedAt)];

  /// そのアカウントで使う版(指定が無ければ既定)。null = 既定。
  String versionFor(String? accountKey) => (accountKey == null ? null : accountVersions[accountKey]) ?? version;

  /// 動かす版 = 既定 + アカウントが指定している版。
  Set<String> get usedVersions => {version, ...accountVersions.values};

  InstalledVersion? versionInfo(String v) => allVersions.where((x) => x.version == v).firstOrNull;

  InstalledPlugin copyWith({String? name, String? version, String? sha512, DateTime? installedAt, InstalledInfo? info, List<InstalledVersion>? versions, Map<String, String>? accountVersions, StorePluginType? pluginType}) => InstalledPlugin(
        id: id,
        name: name ?? this.name,
        version: version ?? this.version,
        sha512: sha512 ?? this.sha512,
        installedAt: installedAt ?? this.installedAt,
        info: info ?? this.info,
        versions: versions ?? this.versions,
        accountVersions: accountVersions ?? this.accountVersions,
        pluginType: pluginType ?? this.pluginType,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'sha512': sha512,
        'installedAt': installedAt.toIso8601String(),
        if (info != null) 'info': info!.toJson(),
        if (versions.isNotEmpty) 'versions': [for (final v in versions) v.toJson()],
        if (accountVersions.isNotEmpty) 'accountVersions': accountVersions,
        if (pluginType != StorePluginType.other) 'pluginType': pluginType.wire,
      };
  factory InstalledPlugin.fromJson(Map<String, Object?> j) => InstalledPlugin(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        version: j['version'] as String? ?? '',
        sha512: j['sha512'] as String? ?? '',
        installedAt: DateTime.tryParse(j['installedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        info: j['info'] is Map ? InstalledInfo.fromJson((j['info'] as Map).cast<String, Object?>()) : null,
        versions: [for (final v in j['versions'] as List? ?? const []) if (v is Map) InstalledVersion.fromJson(v.cast<String, Object?>())],
        accountVersions: {for (final e in ((j['accountVersions'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
        pluginType: StorePluginType.fromWire(j['pluginType']),
      );
}

/// ポイント (D-355、Central S-047): Web コンソールで Stripe から買う。付与ごとに 1 か月で失効(2026-10-01 に 2 か月から短縮)。
@immutable
class StorePointGrant {
  const StorePointGrant({required this.amount, required this.remaining, required this.expiresAt, this.createdAt, this.source = '', this.expired = false});
  final int amount;
  final int remaining;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final String source;
  final bool expired;

  factory StorePointGrant.fromJson(Map<String, Object?> j) => StorePointGrant(
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        remaining: (j['remaining'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse('${j['expiresAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: DateTime.tryParse('${j['createdAt']}'),
        source: '${j['source'] ?? ''}',
        expired: j['expired'] == true,
      );
}

@immutable
class StorePoints {
  const StorePoints({this.balance = 0, this.grants = const []});
  final int balance;
  final List<StorePointGrant> grants;

  /// いちばん早く失効する、残りのある付与(案内用)。
  StorePointGrant? get nextExpiring {
    final live = [for (final g in grants) if (!g.expired && g.remaining > 0) g]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return live.firstOrNull;
  }

  factory StorePoints.fromJson(Map<String, Object?> j) => StorePoints(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        grants: [for (final g in j['grants'] as List? ?? const []) if (g is Map) StorePointGrant.fromJson(g.cast<String, Object?>())],
      );
}

/// 購入の結果(store.yaml `purchasePlugin`)。
typedef StorePurchaseResult = ({bool purchased, int pointsSpent, int balance});

/// 値段 → ポイント(1 ポイント = 1 円、切り上げ)。
int storePricePoints(double price) => price.ceil();

/// 版の比較(REC-10、2026-09-28 録画: 入っている 0.1.1 に「0.1.0 に更新」、自動更新で 0.3.0 → 0.1.0 に下がった)。
/// `1.2.10` > `1.2.9`、数字の部分を順に比べる。`-beta` などの付いた版は同じ数字の正式版より前。読めない部分は文字列で比べる。
/// 戻り: a が新しければ正、同じなら 0、古ければ負。
int compareVersions(String a, String b) {
  (List<String>, String?) split(String v) {
    final t = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final i = t.indexOf('-');
    return ((i < 0 ? t : t.substring(0, i)).split('.'), i < 0 ? null : t.substring(i + 1));
  }

  final (pa, ra) = split(a);
  final (pb, rb) = split(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? pa[i] : '0';
    final y = i < pb.length ? pb[i] : '0';
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  if (ra == rb) return 0;
  if (ra == null) return 1; // 正式版 > プレリリース
  if (rb == null) return -1;
  return ra.compareTo(rb);
}

/// [candidate] が [current] より新しいか(空はどちらも「新しくない」)。
bool isNewerVersion(String candidate, String? current) =>
    candidate.isNotEmpty && (current == null || current.isEmpty || compareVersions(candidate, current) > 0);
