import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import '../l10n/gen/rasq_plugin_api_localizations.dart';

export '../l10n/gen/rasq_plugin_api_localizations.dart';

/// いまの表示の言語([RasqUiLocale])の部品の文言 (D-533)。rasq_plugin_api は Flutter に依らないので、文言は
/// `lib/l10n/parts/*.arb` から tool/l10n_merge.dart が作る素の Dart のクラス(docs/I18N.md「Flutter に依らない部品」)。
RasqPluginApiLocalizations get rasqPluginApiL10n => lookupRasqPluginApiLocalizations(RasqUiLocale.tag);
