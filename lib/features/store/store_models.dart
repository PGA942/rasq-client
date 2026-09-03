import 'package:flutter/foundation.dart';

/// プラグインストアのクライアント側モデル (M4 / D-120)。
/// 正本は rasq-sdk-sample/openapi/store.yaml (D-033) — サーバー実装
/// (ORGATE-server)前はモッククライアントが同じ形を返す。

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
  });

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
}

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
}

@immutable
class Compatibility {
  const Compatibility({this.rasqVersion = '', this.os = const [], this.requiresPlugins = const [], this.conflictsWith = const [], this.requiredRuntimes = const []});
  final String rasqVersion;
  final List<String> os;
  final List<String> requiresPlugins;
  final List<String> conflictsWith;
  final List<String> requiredRuntimes;
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
    this.description = '',
    this.channel = 'stable',
    this.updatedAt,
    this.safety = const SafetyBlock(),
    this.compatibility = const Compatibility(),
    this.developerName = '',
    this.supportUrl,
  });

  final String description;
  final String channel;
  final DateTime? updatedAt;
  final SafetyBlock safety;
  final Compatibility compatibility;
  final String developerName;
  final Uri? supportUrl;
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
}

/// インストール確認シートと検証の根拠 (D-033/D-034)。
@immutable
class InstallManifest {
  const InstallManifest({required this.pluginId, required this.version, this.channel = 'stable', this.manifest = const {}, this.permissionsAdded = const [], this.artifacts = const []});
  final String pluginId;
  final String version;
  final String channel;
  final Map<String, Object?> manifest;
  final List<PermissionEntry> permissionsAdded;
  final List<StoreArtifact> artifacts;
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
}

@immutable
class ReleaseNote {
  const ReleaseNote({required this.version, this.channel = 'stable', this.notes = '', this.permissionsAdded = const [], required this.publishedAt});
  final String version;
  final String channel;
  final String notes;
  final List<PermissionEntry> permissionsAdded;
  final DateTime publishedAt;
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
