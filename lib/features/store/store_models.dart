import 'package:flutter/foundation.dart';

/// プラグインストアのクライアント側モデル (M4 / D-120)。
/// 正本は rasq-sdk-sample/openapi/store.yaml (D-033)。ワイヤ(JSON)からの
/// 復元は各型の `fromJson` にあり、orgate-server の `/api/v1` 応答と
/// MockStoreClient の両方がこの形に落ちる。

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
}

/// JSON の数値は int でも double でも来る(サーバーの avg は double、
/// downloads は int)。どちらでも受ける。
double _num(Object? v) => v is num ? v.toDouble() : 0;
Uri? _uri(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
List<String> _strings(Object? v) => v is List ? [for (final e in v) if (e is String) e] : const [];
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
    this.description = '',
    this.channel = 'stable',
    this.updatedAt,
    this.safety = const SafetyBlock(),
    this.compatibility = const Compatibility(),
    this.developerName = '',
    this.supportUrl,
    this.screenshots = const [],
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
      description: j['description'] as String? ?? '',
      channel: j['channel'] as String? ?? 'stable',
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      safety: SafetyBlock.fromJson((j['safety'] as Map?)?.cast<String, Object?>() ?? const {}),
      compatibility: Compatibility.fromJson((j['compatibility'] as Map?)?.cast<String, Object?>() ?? const {}),
      developerName: dev['name'] as String? ?? '',
      supportUrl: _uri(dev['supportUrl']),
      screenshots: [for (final u in _strings(j['screenshots'])) ?Uri.tryParse(u)],
    );
  }

  final String description;
  final String channel;
  final DateTime? updatedAt;
  final SafetyBlock safety;
  final Compatibility compatibility;
  final String developerName;
  final Uri? supportUrl;
  final List<Uri> screenshots;
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

@immutable
class StoreReview {
  const StoreReview({required this.id, required this.rating, this.body = '', this.usedVersion = '', this.verifiedUse = false, this.helpfulCount = 0, this.developerReply, required this.createdAt});
  final String id;
  final int rating;
  final String body;
  final String usedVersion;
  final bool verifiedUse;
  final int helpfulCount;
  final String? developerReply;
  final DateTime createdAt;

  factory StoreReview.fromJson(Map<String, Object?> j) => StoreReview(
        id: j['id'] as String? ?? '',
        rating: _num(j['rating']).toInt(),
        body: j['body'] as String? ?? '',
        usedVersion: j['usedVersion'] as String? ?? '',
        verifiedUse: j['verifiedUse'] == true,
        helpfulCount: _num(j['helpfulCount']).toInt(),
        developerReply: j['developerReply'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
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

/// インストール済みプラグイン(KV `store.installed.v1` に永続化)。
@immutable
class InstalledPlugin {
  const InstalledPlugin({required this.id, required this.name, required this.version, required this.sha512, required this.installedAt});
  final String id;
  final String name;
  final String version;

  /// 検証済み配布物の SHA-512(インストール時に照合した値)。
  final String sha512;
  final DateTime installedAt;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'version': version, 'sha512': sha512, 'installedAt': installedAt.toIso8601String()};
  factory InstalledPlugin.fromJson(Map<String, Object?> j) => InstalledPlugin(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        version: j['version'] as String? ?? '',
        sha512: j['sha512'] as String? ?? '',
        installedAt: DateTime.tryParse(j['installedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
