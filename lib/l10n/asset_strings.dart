import 'asset_strings.g.dart';
import 'gen/app_localizations.dart';

/// 設定の静的なページ(`assets/settings/*.rrl.json`)の文言 (D-535、docs/I18N.md「設定の静的なページ」)。
///
/// - **画面のページ**(設定の第二階層): 文字列の代わりに `"@l10n:<キー>"` を書き、文言は ARB の部品
///   `lib/l10n/parts/settings_pages.<言語>.arb`(キーは `settingsPages…`)に置く。プレースホルダの要る文は
///   `{"$l10n": "<キー>", "args": {"<名前>": <値>}}`。読み込んだあと [resolveAssetStrings] で表示の言語の文言に置き換える。
///   キー → 文言の表(`asset_strings.g.dart`)は tool/l10n_merge.dart が部品から作る。
/// - **文書のページ**(規約・ポリシーなど `doc` を持つもの): 文書ごと訳す(版と `bodySha256` が言語ごとに違う)ので、
///   言語ごとのファイル `assets/settings/<言語>/<area>.rrl.json` を置く。無ければ日本語(`assets/settings/<area>.rrl.json`)。
///   [settingsPageAssetPaths] の順に探す。

/// 文言の参照の頭。
const assetStringPrefix = '@l10n:';

/// [json] の中の文言の参照を [l] の文言に置き換えた写し。知らないキーはそのまま残す(test/settings_pages_l10n_test.dart が
/// 全部の参照が引けることを確かめる)。
Object? resolveAssetStrings(Object? json, AppLocalizations l) => switch (json) {
      String s when s.startsWith(assetStringPrefix) => appAssetString(l, s.substring(assetStringPrefix.length)) ?? s,
      {r'$l10n': final String key} => appAssetString(l, key, (json['args'] as Map?)?.cast<String, Object?>() ?? const {}) ?? key,
      Map m => <String, Object?>{for (final e in m.entries) '${e.key}': resolveAssetStrings(e.value, l)},
      List xs => [for (final x in xs) resolveAssetStrings(x, l)],
      _ => json,
    };

/// [area] のページのアセットを探す順(表示の言語のタグ → 言語だけ → 日本語の元)。日本語は元のファイルだけ。
List<String> settingsPageAssetPaths(String area, String localeTag) {
  final tag = localeTag.replaceAll('_', '-');
  final lang = tag.split('-').first.toLowerCase();
  return [
    if (lang != 'ja') ...{'assets/settings/$tag/$area.rrl.json', 'assets/settings/$lang/$area.rrl.json'},
    'assets/settings/$area.rrl.json',
  ];
}
