import '../l10n/gen/rasq_models_localizations.dart';
import 'lang_override.dart';
import 'ui_locale.dart';

export '../l10n/gen/rasq_models_localizations.dart';

/// いまの表示の言語([RasqUiLocale])の部品の文言 (D-533)。rasq_models は Flutter に依らないので、文言は
/// `lib/l10n/parts/*.arb` から tool/l10n_merge.dart が作る素の Dart のクラス(docs/I18N.md「Flutter に依らない部品」)。
/// 言語パック(D-592)で上書きがあれば、上書きを先に引く層([RasqModelsLocalizationsOverlay])を挟む。
RasqModelsLocalizations get rasqModelsL10n {
  final tag = RasqUiLocale.tag;
  final base = lookupRasqModelsLocalizations(RasqLangOverride.baseTag(tag));
  return RasqLangOverride.active ? RasqModelsLocalizationsOverlay(base, tag) : base;
}
