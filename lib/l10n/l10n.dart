import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:rasq_design/rasq_design.dart' show rasqLocaleFromTag;
import 'package:rasq_models/rasq_models.dart' show RasqLangOverride, RasqUiLocale;

import 'app_localizations_overlay.g.dart';
import 'gen/app_localizations.dart';

export 'app_localizations_overlay.g.dart';
export 'gen/app_localizations.dart';

/// アプリの文言 (D-484)。文言は `lib/l10n/parts/<領域>.ja.arb` に書き、`dart run tool/l10n_merge.dart && flutter gen-l10n`
/// で `lib/l10n/gen` を作り直す(手順・名前の付け方は docs/I18N.md)。
///
/// 画面では `context.l10n.<キー>`、画面の外(enum の名前・例外の文など)では [appL10n](いまの表示の言語)を使う。

/// [locale] に対応するアプリの文言。対応していなければ言語だけ → 日本語(テンプレート)の順に倒す。
/// 言語パック (D-592) が効いていれば、パックの文を先に引く層([AppLocalizationsOverlay])を挟む(パックが足した言語は、
/// パックの決めた同梱の言語の文言に倒す)。
AppLocalizations appL10nFor(Locale locale) {
  final base = _bundledAppL10n(rasqLocaleFromTag(RasqLangOverride.baseTag(locale.toLanguageTag())));
  return RasqLangOverride.active ? AppLocalizationsOverlay(base, locale.toString()) : base;
}

AppLocalizations _bundledAppL10n(Locale locale) {
  for (final l in [locale, Locale(locale.languageCode), const Locale(RasqUiLocale.defaultTag)]) {
    if (AppLocalizations.delegate.isSupported(l)) return lookupAppLocalizations(l);
  }
  return lookupAppLocalizations(const Locale(RasqUiLocale.defaultTag));
}

/// アプリの文言の delegate (D-592)。同梱の [AppLocalizations.delegate] の代わりに MaterialApp に入れる: 言語パックが足した
/// 言語も受け付け、パックの上書きの層を返す。[revision](`RasqLangOverride.revision`)が変われば読み直す。
class AppL10nDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppL10nDelegate(this.revision, {this.extraLocales = const []});

  final int revision;

  /// 言語パックが足した言語。
  final List<Locale> extraLocales;

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale) || extraLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(appL10nFor(locale));

  @override
  bool shouldReload(AppL10nDelegate old) => old.revision != revision;
}

/// いまの表示の言語([RasqUiLocale])のアプリの文言 — `BuildContext` が無いところ用。
AppLocalizations get appL10n => appL10nFor(rasqLocaleFromTag(RasqUiLocale.tag));

/// 大きな数の短い表記。日本語・中国語・韓国語は万 / 億の単位の文言([AppLocalizations] の `…TenThousands` など)で組み立てる
/// ので null、それ以外の言語は intl の短い表記(`15K` / `1.2M`)を返す。
String? compactCountOrNull(int n) {
  final lang = appL10n.localeName.split('_').first;
  if (const {'ja', 'zh', 'ko'}.contains(lang)) return null;
  return NumberFormat.compact(locale: lang).format(n);
}

extension AppL10nContext on BuildContext {
  /// アプリの文言。[AppLocalizations.delegate] の無い画面(部品だけを置くテスト)でも、いまの表示の言語の文言を返す。
  AppLocalizations get l10n => AppLocalizations.of(this) ?? appL10n;
}
