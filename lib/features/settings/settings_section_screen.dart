import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show Routes;
import '../../shell/headers.dart';
import '../../shell/rasq_account_fow.dart';
import '../home/action_bar_edit_sheet.dart';
import '../notifications/notifications_screen.dart';
import '../relational/relational_timeline_view.dart' show openRelationalTuning;
import '../theme/theme_packs.dart';
import '../trend/tendency_fows.dart';
import 'settings_dsl.dart' show settingsRowVisible;
import 'settings_sections.dart';
import '../../l10n/l10n.dart';

/// Generic first-level settings page driven by [settingsSections].
/// アプリの外観 has live controls (テーマ); everything else is a labelled placeholder.
class SettingsSectionScreen extends ConsumerWidget {
  const SettingsSectionScreen({super.key, required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final section = settingsSectionsOf(l)[sectionId];
    if (section == null) return Scaffold(appBar: RasqPageHeader(title: l.settingsHomeGenericTitle), body: RasqEmptyView(title: l.settingsHomeUnknownSection));
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: section.title, onMore: () {}),
      body: ListView(children: [
        // 「RASQについて」の最上部 (D-291): RASQ アカウントのタイル(サイドバーのバンドルタイルと同じ見た目)。
        // 押すとアカウントの FOW。これまでの「アカウント >」の行は、これに置き換えた。
        if (sectionId == 'about') const RasqAccountTile(key: ValueKey('settings.about.account')),
        // SNS プラグインの設定ページの行は、プラグインが宣言したものだけ (D-482)。
        for (final r in section.rows.where((r) => settingsRowVisible(ref, r.route)))
          if (sectionId == 'appearance' && r.route == Routes.settingsTheme)
            // 着せ替えの画面へ (D-375): 以前はここでライト / ダークのシートだけを開き、入れた着せ替えを選ぶ画面に行けなかった。
            // ライト / ダークは着せ替えの画面の上に置いた。
            RasqValueListTile(
              key: const ValueKey('settings.appearance.theme'),
              title: r.title,
              value: [
                switch (mode) { ThemeModeSetting.system => l.settingsHomeThemeModeSystem, ThemeModeSetting.light => l.settingsHomeThemeModeLight, ThemeModeSetting.dark => l.settingsHomeThemeModeDark },
                ?ref.watch(themePacksProvider).where((p) => p.id == ref.watch(activeThemeIdProvider)).firstOrNull?.name,
              ].join(context.l10n.settingsCommonSeparator),
              onTap: () => context.push(Routes.settingsTheme),
            )
          else if (r.warning)
            RasqWarningListTile(title: r.title, subtitle: r.subtitle, detail: r.detail, onTap: () => openSettingsRow(context, ref, r))
          else
            RasqListTile(
              title: r.title,
              subtitle: r.subtitle,
              detail: r.detail,
              trailing: r.external ? const Icon(Icons.north_east, size: 18) : null,
              onTap: () => openSettingsRow(context, ref, r),
            ),
        if (section.note != null) RasqCaption(section.note!, detail: section.noteDetail, padding: const EdgeInsets.all(RasqSpacing.page)),
      ]),
    );
  }

}

/// 行の行き先 (D-238): 画面(route)/ FOW やシートを開く印(`action:` …)/ まだ無ければ従来の案内。設定の検索 (D-385) からも使う。
void openSettingsRow(BuildContext context, WidgetRef ref, SettingsRow r) {
  switch (r.route) {
    case 'notificationPrefs':
      showNotificationPrefs(ref);
    case settingsActionTrendGenres:
      openGenreFow(context, ref);
    case settingsActionTrendTendency:
      openTendencyFow(context, ref);
    case settingsActionRelationalTuning:
      openRelationalTuning(ref);
    case settingsActionAstellBar:
      showActionBarEditSheet(ref, surfaces: const [ActionBarSurface.astell]);
    case null:
      ref.read(overlayManagerProvider).showAlert(
          id: 'settings.placeholder', title: r.title, message: rasqDetail(context, context.l10n.settingsHomePlaceholder, context.l10n.settingsHomePlaceholderDetail), confirmText: context.l10n.settingsHomeOk);
    default:
      context.push(r.route!);
  }
}
