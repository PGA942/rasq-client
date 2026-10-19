import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import '../../l10n/ui_locale.dart';
import '../../shell/headers.dart';

/// アプリの外観 → 言語 (D-484): 「システムに合わせる」か、対応する言語(gen-l10n の一覧から作る)を選ぶ。
/// 端末に保存し(KV `appearance.language.v1`)、すぐ画面に反映する。言語の名前は、その言語の訳の `languageSelfName`。
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final setting = ref.watch(uiLocaleSettingProvider);
    final current = ref.watch(uiLocaleProvider);
    // 選んでいる値: 対応する言語のどれか / null(システムに合わせる)。保存値が対応していない言語なら「システム」扱い。
    final chosen = supportedUiLocales.where((s) => s.toLanguageTag() == setting).firstOrNull;
    return Scaffold(
      appBar: RasqPageHeader(title: l.languageSettingsTitle),
      body: ListView(children: [
        RasqCaption(
          l.languageSettingsCaption,
          detail: l.languageSettingsCaptionDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        RasqSectionHeader(title: l.languageSettingsListHeader),
        RasqRadioListTile<String>(
          key: const ValueKey('language.system'),
          title: l.languageSettingsSystem,
          subtitle: l.languageSettingsSystemCurrent(appL10nFor(current).languageSelfName),
          value: systemLocaleSetting,
          groupValue: chosen == null ? systemLocaleSetting : chosen.toLanguageTag(),
          onChanged: (_) => setUiLocaleSetting(ref, null),
        ),
        for (final locale in supportedUiLocales)
          RasqRadioListTile<String>(
            key: ValueKey('language.${locale.toLanguageTag()}'),
            title: appL10nFor(locale).languageSelfName,
            value: locale.toLanguageTag(),
            groupValue: chosen == null ? systemLocaleSetting : chosen.toLanguageTag(),
            onChanged: (v) => setUiLocaleSetting(ref, v),
          ),
      ]),
    );
  }
}
