import 'package:meta/meta.dart';
import 'package:rasq_models/rasq_models.dart';

import 'action.dart';

/// Plugin kinds (原典: ワイヤーフレーム「アップデート/デプロイの設定」SNS/アクション/ビュー
/// + D-004③ メディアビューワープラグイン + トレンドプロバイダー).
enum PluginKind { sns, action, view, trend, mediaViewer, postProcessor }

/// `function.json` の `permissions[]` の語彙 (schema/manifest.schema.json)。
///
/// プラグインが宣言する文字列であると同時に、ランタイムが host-fn を通すか
/// どうかの判定キーでもある。スキーマの enum と必ず揃えること — ホストが
/// 知らない権限名は「無視」ではなく「拒否」に倒れる (fail-closed)。
abstract final class RasqPermissions {
  static const render = 'render';
  static const replaceTile = 'replace_tile';
  static const transformContent = 'transform_content';
  static const tagMedia = 'tag_media';
  static const replaceMedia = 'replace_media';
  static const registerAction = 'register_action';
  static const decorateAvatar = 'decorate_avatar';
  static const fowWidget = 'fow.widget';
  static const fowInterstitial = 'fow.interstitial';
  static const fowSystem = 'fow.system';
  static const network = 'network';
  static const gpuMl = 'gpu_ml';
  static const storageSafe = 'storage.safe';
  static const storageUnsafe = 'storage.unsafe';
  static const autoHook = 'auto_hook';

  /// `storage.*` の `ns` に対応する権限名。未知の ns は未知の権限名になり、
  /// どの宣言にも一致しないので拒否される。
  static String storageFor(String ns) => 'storage.$ns';

  /// 語彙の全部。マニフェストを持たないサイドロード/開発用サーフェス
  /// (dev の wasm インポート画面)専用 — ストア経由の導入では、必ず
  /// マニフェストの宣言をそのまま渡すこと。
  static const all = {
    render, replaceTile, transformContent, tagMedia, replaceMedia,
    registerAction, decorateAvatar, fowWidget, fowInterstitial, fowSystem,
    network, gpuMl, storageSafe, storageUnsafe, autoHook,
  };
}

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
