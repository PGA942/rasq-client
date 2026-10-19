import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:rasq_design/rasq_design.dart' show rasqLocaleFromTag;
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import '../features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'l10n.dart';

/// 表示の言語 (D-484)。
///
/// - 設定 → アプリの外観 → 言語(`LanguageSettingsScreen`)で「システムに合わせる」か、対応する言語のどれかを選ぶ。
///   端末に保存する(KV `appearance.language.v1` の `locale`。無い / `system` = システムに合わせる)。
/// - 対応する言語 = gen-l10n の [AppLocalizations.supportedLocales](= `lib/l10n/parts/*.<言語>.arb` がある言語)。
///   言語を足すのは訳のファイルを足すだけ(docs/I18N.md)。
/// - 決まった言語は MaterialApp の `locale` に渡し、画面の外のための写し [RasqUiLocale] にも書く
///   (Central / ORGATE への `Accept-Language`・プラグインの呼び出しの `locale`・日付の書式)。
///   RASQ アカウントにログインしていれば ORGATE にも伝える(`locale_sync.dart`)。

/// 言語の設定の KV の領域(`appearance.language.v1`)。
const languageSettingsArea = 'appearance.language';

/// 設定の値「システムに合わせる」。
const systemLocaleSetting = 'system';

/// 選べる言語(gen-l10n が作った一覧の順)。
List<Locale> get supportedUiLocales => AppLocalizations.supportedLocales;

/// 設定 [setting](BCP-47 / `system` / null)と端末の言語 [system] から、表示の言語を決める。
/// 設定が対応する言語ならそれ。そうでなければ端末の言語を順に見て、言語・文字・地域まで同じもの → 言語が同じもの。
/// どれも無ければ日本語。
Locale resolveUiLocale(String? setting, List<Locale> system, {List<Locale>? supported}) {
  final list = supported ?? supportedUiLocales;
  Locale? pick(Locale want) {
    for (final s in list) {
      if (s == want) return s;
    }
    for (final s in list) {
      if (s.languageCode == want.languageCode && (s.scriptCode == null || s.scriptCode == want.scriptCode) && s.countryCode == null) return s;
    }
    for (final s in list) {
      if (s.languageCode == want.languageCode) return s;
    }
    return null;
  }

  if (setting != null && setting.isNotEmpty && setting != systemLocaleSetting) {
    final chosen = pick(rasqLocaleFromTag(setting));
    if (chosen != null) return chosen;
  }
  for (final l in system) {
    final p = pick(l);
    if (p != null) return p;
  }
  return list.firstWhere((l) => l.languageCode == RasqUiLocale.defaultTag, orElse: () => list.isEmpty ? const Locale(RasqUiLocale.defaultTag) : list.first);
}

/// 保存している言語の設定(BCP-47)。null = システムに合わせる。
final uiLocaleSettingProvider = Provider<String?>((ref) {
  final v = ref.watch(settingsAreaProvider(languageSettingsArea)).value?['locale'];
  return v is String && v.isNotEmpty && v != systemLocaleSetting ? v : null;
});

/// 言語の設定を保存する(null = システムに合わせる)。
Future<void> setUiLocaleSetting(WidgetRef ref, String? tag) =>
    ref.read(settingsAreaProvider(languageSettingsArea).notifier).set('locale', tag ?? systemLocaleSetting);

/// 端末の言語の並び。アプリの実行中に端末の言語が変わったら追う。
class SystemLocalesNotifier extends Notifier<List<Locale>> with WidgetsBindingObserver {
  @override
  List<Locale> build() {
    try {
      WidgetsBinding.instance.addObserver(this);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    } catch (_) {
      // WidgetsBinding の無いテスト(ProviderContainer だけ)では追わない。
    }
    return PlatformDispatcher.instance.locales;
  }

  @override
  void didChangeLocales(List<Locale>? locales) => state = locales ?? PlatformDispatcher.instance.locales;
}

final systemLocalesProvider = NotifierProvider<SystemLocalesNotifier, List<Locale>>(SystemLocalesNotifier.new);

/// いまの表示の言語。決まるたびに [RasqUiLocale] と intl の既定にも写す。
final uiLocaleProvider = Provider<Locale>((ref) {
  final locale = resolveUiLocale(ref.watch(uiLocaleSettingProvider), ref.watch(systemLocalesProvider));
  final tag = locale.toLanguageTag();
  RasqUiLocale.tag = tag;
  Intl.defaultLocale = Intl.canonicalizedLocale(tag.replaceAll('-', '_'));
  return locale;
});

/// いまの表示の言語の BCP-47(`Accept-Language` / ORGATE の `locale` / プラグインの `locale` に送る値)。
final uiLocaleTagProvider = Provider<String>((ref) => ref.watch(uiLocaleProvider).toLanguageTag());
