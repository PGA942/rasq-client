import 'package:meta/meta.dart';
import 'package:rasq_models/rasq_models.dart';

import 'action.dart';

/// Plugin kinds (原典: ワイヤーフレーム「アップデート/デプロイの設定」SNS/アクション/ビュー
/// + D-004③ メディアビューワープラグイン + トレンドプロバイダー).
enum PluginKind { sns, action, view, trend, mediaViewer, postProcessor }

/// Subset of `function.json` the host needs at install/boot time.
/// Full schema (WASM imports, constants, slot declarations) is M3.
@immutable
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.kind,
    this.author,
    this.description,
    this.supportedSns = const [],
    this.permissions = const [],
    this.actions = const [],
    this.termsOfService,
    this.verified = false,
    this.official = false,
  });

  /// Reverse-DNS-ish stable id, e.g. `rasq.official.misskey`.
  final String id;
  final String name;

  /// SemVer string. Per-account versions are resolved by the host.
  final String version;
  final PluginKind kind;
  final String? author;
  final String? description;
  final List<SnsKind> supportedSns;

  /// Operation vocabulary (D-004): `network`, `gpu_ml`, `storage.safe`,
  /// `register_action`, `transform_content`, `tag_media`, …
  final List<String> permissions;
  final List<ActionDescriptor> actions;

  /// Markdown shown on the 利用規約画面 before first login.
  final String? termsOfService;

  /// Store-reviewed (審査済み). Sideloaded plugins are `false`.
  final bool verified;
  final bool official;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'kind': kind.name,
        if (author != null) 'author': author,
        if (description != null) 'description': description,
        'supportedSns': supportedSns.map((e) => e.name).toList(),
        'permissions': permissions,
        'actions': actions.map((a) => a.toJson()).toList(),
        if (termsOfService != null) 'termsOfService': termsOfService,
        'verified': verified,
        'official': official,
      };

  factory PluginManifest.fromJson(Map<String, Object?> json) => PluginManifest(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as String,
        kind: PluginKind.values.byName(json['kind'] as String? ?? 'sns'),
        author: json['author'] as String?,
        description: json['description'] as String?,
        supportedSns: [for (final s in (json['supportedSns'] as List? ?? const [])) SnsKind.values.byName(s as String)],
        permissions: [for (final p in (json['permissions'] as List? ?? const [])) p as String],
        actions: [for (final a in (json['actions'] as List? ?? const [])) ActionDescriptor.fromJson(a as Map<String, Object?>)],
        termsOfService: json['termsOfService'] as String?,
        verified: json['verified'] as bool? ?? false,
        official: json['official'] as bool? ?? false,
      );
}
