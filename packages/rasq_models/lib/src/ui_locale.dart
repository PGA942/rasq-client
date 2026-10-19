/// アプリの表示の言語 (D-484) を、画面の外のコード(HTTP の `Accept-Language`・プラグインの呼び出しの `locale`・
/// 日付の書式)から読む置き場。値は BCP-47 の言語タグ(`ja` / `en-US` など)。
///
/// 決めるのはアプリ(`lib/l10n/ui_locale.dart` の `uiLocaleProvider`: 設定の「言語」→ 端末の言語 → 対応していなければ `ja`)で、
/// 決まるたびにここへ書く。画面の中では `Localizations.localeOf(context)` を使う(こちらは画面の外のための写し)。
/// 既定は `ja`(テストや、アプリが決める前の起動直後)。
abstract final class RasqUiLocale {
  /// いまの言語が決まる前の値(そして、対応する言語が無いときに倒す先)。
  static const defaultTag = 'ja';

  static String _tag = defaultTag;

  /// いまの表示の言語(BCP-47)。
  static String get tag => _tag;

  static set tag(String value) => _tag = value.trim().isEmpty ? defaultTag : value.trim();
}
