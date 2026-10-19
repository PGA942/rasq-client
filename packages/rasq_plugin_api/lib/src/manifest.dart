import 'package:meta/meta.dart';

import 'manifest_locales.dart';
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

  /// ページ型の共有セッション(サーバー変数 / サーバー関数、契約 v0.18 §2.13、D-357)。
  static const sharedSession = 'shared.session';

  /// `storage.*` の `ns` に対応する権限名。未知の ns は未知の権限名になり、
  /// どの宣言にも一致しないので拒否される。
  static String storageFor(String ns) => 'storage.$ns';

  /// 語彙の全部。マニフェストを持たないサイドロード/開発用サーフェス
  /// (dev の wasm インポート画面)専用 — ストア経由の導入では、必ず
  /// マニフェストの宣言をそのまま渡すこと。
  static const all = {
    render, replaceTile, transformContent, tagMedia, replaceMedia,
    registerAction, decorateAvatar, fowWidget, fowInterstitial, fowSystem,
    network, gpuMl, storageSafe, storageUnsafe, autoHook, sharedSession,
  };
}

/// `function.json` の `network` (schema v0.12): `net.fetch` が繋いでよい先。
///
/// `network` 権限は「どこへでも」ではない。繋ぐ先を宣言し、ランタイムは
/// それ以外のホストを E01 で弾く。宣言が無い = どこにも繋げない (fail-closed)。
///
/// - [hosts]: 完全一致(`misskey.io`)/ `*.example.com`(サブドメインだけ、
///   apex は別に書く)/ `*`(どこでも。開発用の面だけが使い、審査では旗)。
/// - [instance]: そのセッションのアカウントが属するインスタンスへ繋いでよい。
///   ユーザーが選ぶ先なので静的には書けず、ホストが毎回の call に渡す
///   `args.host` と同じものをランタイムに与える。
@immutable
class PluginNetwork {
  const PluginNetwork({this.hosts = const [], this.instance = false});

  final List<String> hosts;
  final bool instance;

  /// 何も繋げない宣言(権限だけ書いて `network` を省いた場合に等しい)。
  static const none = PluginNetwork();

  Map<String, Object?> toJson() => {
        if (hosts.isNotEmpty) 'hosts': hosts,
        if (instance) 'instance': true,
      };

  factory PluginNetwork.fromJson(Map<String, Object?> json) => PluginNetwork(
        hosts: [for (final h in (json['hosts'] as List? ?? const [])) if (h is String) h.trim().toLowerCase()],
        instance: json['instance'] as bool? ?? false,
      );
}

/// Subset of `function.json` the host needs at install/boot time.
/// Full schema (WASM imports, constants, slot declarations) is M3.
@immutable
class PluginManifest {
  const PluginManifest({
    required this.id,
    required String name,
    required this.version,
    required this.kind,
    this.author,
    String? description,
    this.supportedSns = const [],
    this.permissions = const [],
    this.network,
    List<ActionDescriptor> actions = const [],
    String? termsOfService,
    this.verified = false,
    this.official = false,
    this.locales = ManifestLocales.none,
  })  : baseName = name,
        baseDescription = description,
        baseActions = actions,
        baseTermsOfService = termsOfService;

  /// Reverse-DNS-ish stable id, e.g. `rasq.official.misskey`.
  final String id;

  /// 素の `name`([locales] の `defaultLocale` の文)。画面に出すのは [name](表示の言語で引いたもの)。
  final String baseName;
  final String? baseDescription;
  final List<ActionDescriptor> baseActions;
  final String? baseTermsOfService;

  /// ほかの言語の文 (D-484 / 契約 v0.24)。
  final ManifestLocales locales;

  /// 表示の言語の名前(`locales` → 素の `name`)。
  String get name => locales.field('name') ?? baseName;

  /// SemVer string. Per-account versions are resolved by the host.
  final String version;
  final PluginKind kind;
  final String? author;

  /// 表示の言語の説明。
  String? get description => locales.field('description') ?? baseDescription;
  final List<SnsKind> supportedSns;

  /// Operation vocabulary (D-004): `network`, `gpu_ml`, `storage.safe`,
  /// `register_action`, `transform_content`, `tag_media`, …
  final List<String> permissions;

  /// `net.fetch` の接続先の宣言。null = 宣言なし = どこにも繋げない。
  final PluginNetwork? network;

  /// 宣言したアクション(ラベルは表示の言語、`locales.<tag>.actions.<id>.label`)。
  List<ActionDescriptor> get actions => locales.isEmpty
      ? baseActions
      : [
          for (final a in baseActions)
            if (locales.actionLabel(a.id) case final label?) ActionDescriptor.fromJson({...a.toJson(), 'label': label}) else a,
        ];

  /// Markdown shown on the 利用規約画面 before first login(表示の言語)。
  String? get termsOfService => locales.field('termsOfService') ?? baseTermsOfService;

  /// Store-reviewed (審査済み). Sideloaded plugins are `false`.
  final bool verified;
  final bool official;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': baseName,
        'version': version,
        'kind': kind.name,
        if (author != null) 'author': author,
        if (baseDescription != null) 'description': baseDescription,
        'supportedSns': supportedSns.map((e) => e.name).toList(),
        'permissions': permissions,
        if (network != null) 'network': network!.toJson(),
        'actions': baseActions.map((a) => a.toJson()).toList(),
        if (baseTermsOfService != null) 'termsOfService': baseTermsOfService,
        'verified': verified,
        'official': official,
        ...locales.toJson(),
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
        network: json['network'] is Map ? PluginNetwork.fromJson((json['network'] as Map).cast<String, Object?>()) : null,
        actions: [for (final a in (json['actions'] as List? ?? const [])) ActionDescriptor.fromJson(a as Map<String, Object?>)],
        termsOfService: json['termsOfService'] as String?,
        verified: json['verified'] as bool? ?? false,
        official: json['official'] as bool? ?? false,
        locales: ManifestLocales.fromManifest(json),
      );
}
