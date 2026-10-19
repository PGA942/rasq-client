import 'package:meta/meta.dart';
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

/// マニフェストの文の言語 (D-484 / 契約 v0.24、rasq-sdk-sample PROTOCOL.md §4.6)。
///
/// 素の `name` / `description` / `termsOfService` / `page.title` / `actions[].label` / `assets[].label` は
/// [defaultLocale](省略 = `ja`)の文。ほかの言語は `locales` に、BCP-47 のタグごとに `name` / `description` /
/// `termsOfService` / `pageTitle` / `actions.ID.label` / `assets.ID.label` を書く。
/// 引き方: タグそのもの → 親のタグ(`zh-Hant-TW` → `zh-Hant` → `zh`)→ 素の欄。タグは大文字小文字と `_` / `-` を区別しない。書かれていなければ今までどおり(素の欄)。
@immutable
class ManifestLocales {
  const ManifestLocales({this.defaultLocale = 'ja', this.byTag = const {}});

  /// 素の欄の言語。
  final String defaultLocale;

  /// 正規化したタグ(小文字、`-` 区切り)→ その言語の欄。
  final Map<String, Map<String, Object?>> byTag;

  static const none = ManifestLocales();

  bool get isEmpty => byTag.isEmpty;

  static String _norm(String tag) => tag.trim().replaceAll('_', '-').toLowerCase();

  /// マニフェストの JSON(`defaultLocale` / `locales`)から。形の違うものは読み飛ばす。
  factory ManifestLocales.fromManifest(Map<String, Object?> json) {
    final raw = json['locales'];
    final byTag = <String, Map<String, Object?>>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.key is String && e.value is Map && (e.key as String).trim().isNotEmpty) byTag[_norm(e.key as String)] = (e.value as Map).cast<String, Object?>();
      }
    }
    final def = json['defaultLocale'];
    return byTag.isEmpty && def is! String ? none : ManifestLocales(defaultLocale: def is String && def.trim().isNotEmpty ? def.trim() : 'ja', byTag: byTag);
  }

  /// `toJson` に足す欄(無ければ空)。
  Map<String, Object?> toJson() => {
        if (defaultLocale != 'ja' || byTag.isNotEmpty) 'defaultLocale': defaultLocale,
        if (byTag.isNotEmpty) 'locales': byTag,
      };

  /// [tag] から引く順(`zh-hant-tw` → `zh-hant` → `zh`)。
  static List<String> candidates(String tag) {
    final parts = _norm(tag).split('-').where((p) => p.isNotEmpty).toList();
    return [for (var n = parts.length; n > 0; n--) parts.take(n).join('-')];
  }

  String? _lookup(String? tag, String? Function(Map<String, Object?> entry) read) {
    if (byTag.isEmpty) return null;
    for (final c in candidates(tag ?? RasqUiLocale.tag)) {
      final entry = byTag[c];
      if (entry == null) continue;
      final v = read(entry);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// `name` / `description` / `termsOfService` / `pageTitle` の [tag](省略 = いまの表示の言語)の文。無ければ null(素の欄を使う)。
  String? field(String key, [String? tag]) => _lookup(tag, (e) => e[key] is String ? e[key] as String : null);

  /// `actions.<id>.label`。
  String? actionLabel(String id, [String? tag]) => _lookup(tag, (e) => _label(e['actions'], id));

  /// `assets.<id>.label`。
  String? assetLabel(String id, [String? tag]) => _lookup(tag, (e) => _label(e['assets'], id));

  static String? _label(Object? map, String id) {
    if (map is! Map) return null;
    final item = map[id];
    return item is Map && item['label'] is String ? item['label'] as String : null;
  }
}
