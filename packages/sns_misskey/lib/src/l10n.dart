import 'package:rasq_models/rasq_models.dart' show RasqLangOverride, RasqUiLocale;

import '../l10n/gen/sns_misskey_localizations.dart';

export '../l10n/gen/sns_misskey_localizations.dart';

/// いまの表示の言語([RasqUiLocale])の部品の文言 (D-533)。sns_misskey は Flutter に依らないので、文言は
/// `lib/l10n/parts/*.arb` から tool/l10n_merge.dart が作る素の Dart のクラス(docs/I18N.md「Flutter に依らない部品」)。
/// Misskey のアダプターは SNS のプラグインの Dart 版なので、WASM のプラグインと同じく、文言を自分で持つ。
/// 言語パック(D-592)で上書きがあれば、上書きを先に引く層([SnsMisskeyLocalizationsOverlay])を挟む。
SnsMisskeyLocalizations get snsMisskeyL10n {
  final tag = RasqUiLocale.tag;
  final base = lookupSnsMisskeyLocalizations(RasqLangOverride.baseTag(tag));
  return RasqLangOverride.active ? SnsMisskeyLocalizationsOverlay(base, tag) : base;
}
