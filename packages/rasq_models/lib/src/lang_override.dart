/// 言語パックの上書きを引く口 (D-592、docs/I18N.md「言語パック」)。
///
/// アプリは文言を同梱している(公式の言語パック = orgate-question/langpack の `packs/official` の写しから生成したクラス)。
/// 利用者が非公式の言語パック(`.rasqlang`)を読み込むと、アプリ(`lib/l10n/langpack/`)が [lookup] などを差し込み、
/// 部品ごとの文言のクラスの「上書きの層」(`…Overlay`、tool/l10n_merge.dart が生成)が**先にこちらを引く**。
/// null が返ったキー(パックに無い・壊れていて捨てた)は同梱の文言のまま。
///
/// 部品(rasq_design / rasq_plugin_api / sns_misskey など)は言語パックの仕組みを知らず、この口だけを見る。
abstract final class RasqLangOverride {
  /// [locale] の言語(BCP-47 / `zh_Hant` のどちらでも)・領域 [domain](`app` / `rasq_design` / `rasq_models` /
  /// `rasq_plugin_api` / `sns_misskey` / `rai` / `plugin:<プラグインの id>`)・キー [key] の文。プレースホルダは [args] で埋めた
  /// 結果を返す。上書きが無ければ null。null を入れると上書き無し(同梱の文言だけ)。
  static String? Function(String locale, String domain, String key, Map<String, Object?> args)? lookup;

  /// パックが足した言語(同梱に無い言語。例 `fr`)の、足りないキーを引く同梱の言語(`fr` → `en`)。同梱の言語ならそのまま。
  static String Function(String tag)? baseTagOf;

  /// プラグイン [pluginId] に渡す、[locale] の文の表(マニフェスト以外のキー。`args.localeStrings`、契約 v0.26)。
  static Map<String, String>? Function(String pluginId, String locale)? pluginStrings;

  /// 上書きが変わるたびに増える番号(文言を持っておく所が読み直す目安)。
  static int revision = 0;

  /// 上書きがあるか。
  static bool get active => lookup != null;

  /// [lookup] を引く(無ければ null)。
  static String? text(String locale, String domain, String key, [Map<String, Object?> args = const {}]) => lookup?.call(locale, domain, key, args);

  /// [tag] の足りないキーを引く同梱の言語のタグ。
  static String baseTag(String tag) => baseTagOf?.call(tag) ?? tag;

  /// 全部外す(テストの後始末にも)。
  static void clear() {
    lookup = null;
    baseTagOf = null;
    pluginStrings = null;
    revision++;
  }
}
