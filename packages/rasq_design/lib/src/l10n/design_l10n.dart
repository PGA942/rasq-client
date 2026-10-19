import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_local;
import 'package:intl/intl.dart';
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import '../../l10n/gen/rasq_design_localizations.dart';

export '../../l10n/gen/rasq_design_localizations.dart';

/// BCP-47 の言語タグ(`ja` / `en-US` / `zh-Hant-TW`)→ [Locale]。読めなければ `ja`。
Locale rasqLocaleFromTag(String tag) {
  final p = tag.replaceAll('_', '-').split('-').where((s) => s.isNotEmpty).toList();
  if (p.isEmpty) return const Locale(RasqUiLocale.defaultTag);
  String? script;
  String? country;
  for (final s in p.skip(1)) {
    if (s.length == 4 && script == null && country == null) {
      script = s[0].toUpperCase() + s.substring(1).toLowerCase();
    } else if ((s.length == 2 || (s.length == 3 && int.tryParse(s) != null)) && country == null) {
      country = s.toUpperCase();
    }
  }
  return Locale.fromSubtags(languageCode: p.first.toLowerCase(), scriptCode: script, countryCode: country);
}

/// [locale] に対応する部品の文言。対応していなければ日本語(テンプレート)。
RasqDesignLocalizations rasqDesignL10nFor(Locale locale) {
  for (final l in [locale, Locale(locale.languageCode), const Locale(RasqUiLocale.defaultTag)]) {
    if (RasqDesignLocalizations.delegate.isSupported(l)) return lookupRasqDesignLocalizations(l);
  }
  return lookupRasqDesignLocalizations(const Locale(RasqUiLocale.defaultTag));
}

/// いまの表示の言語([RasqUiLocale])の部品の文言 — `BuildContext` が無いところ(静的な書式・enum の名前)用。
RasqDesignLocalizations get rasqDesignL10n => rasqDesignL10nFor(rasqLocaleFromTag(RasqUiLocale.tag));

extension RasqDesignL10nContext on BuildContext {
  /// 部品の文言 (D-484)。アプリが [RasqDesignLocalizations.delegate] を入れていない画面(部品だけのテスト)でも、
  /// いまの表示の言語(既定は日本語)の文言を返す。
  RasqDesignLocalizations get designL10n => RasqDesignLocalizations.of(this) ?? rasqDesignL10n;
}

/// 日付の書式 (D-484): 表示の言語に合わせた intl の書式。日本語なら `8月31日` / `2017年2月` / `2017年2月3日`。
/// [locale] を渡さなければ [RasqUiLocale.tag]。intl に無い言語は、言語だけ → 日本語の順に倒す。
abstract final class RasqDateFormat {
  static bool _ready = false;

  /// intl の書式の名前(`ja` / `en_US`)。
  static String intlLocale([String? tag]) {
    if (!_ready) {
      // 端末内の表をそのまま読む(同期で終わる。Future は形だけ)。flutter_localizations が先に入れていても両立する。
      intl_local.initializeDateFormatting();
      _ready = true;
    }
    final canonical = Intl.canonicalizedLocale((tag ?? RasqUiLocale.tag).replaceAll('-', '_'));
    if (DateFormat.localeExists(canonical)) return canonical;
    final short = Intl.shortLocale(canonical);
    return DateFormat.localeExists(short) ? short : RasqUiLocale.defaultTag;
  }

  /// 月と日(`8月31日`)。
  static String monthDay(DateTime t, {String? locale}) => DateFormat.MMMd(intlLocale(locale)).format(t);

  /// 年と月(`2017年2月`)。
  static String yearMonth(DateTime t, {String? locale}) => DateFormat.yMMM(intlLocale(locale)).format(t);

  /// 年月日(`2017年2月3日`)。
  static String yearMonthDay(DateTime t, {String? locale}) => DateFormat.yMMMd(intlLocale(locale)).format(t);

  /// 時刻(`14:30`)。
  static String time(DateTime t, {String? locale}) => DateFormat.Hm(intlLocale(locale)).format(t);
}
