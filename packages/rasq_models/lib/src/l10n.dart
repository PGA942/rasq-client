import '../l10n/gen/rasq_models_localizations.dart';
import 'ui_locale.dart';

export '../l10n/gen/rasq_models_localizations.dart';

/// いまの表示の言語([RasqUiLocale])の部品の文言 (D-533)。rasq_models は Flutter に依らないので、文言は
/// `lib/l10n/parts/*.arb` から tool/l10n_merge.dart が作る素の Dart のクラス(docs/I18N.md「Flutter に依らない部品」)。
RasqModelsLocalizations get rasqModelsL10n => lookupRasqModelsLocalizations(RasqUiLocale.tag);
