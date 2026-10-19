import '../../app/router.dart';
import '../../l10n/l10n.dart';

/// 設定第一階層 (テキストベース仕様 — UI_status「設定第2階層以降はテキストベースで仕様を決める方針」).
/// Wireframe P7: 各セクションの項目名。この画面群は M4 で FOW/DSL 描画に置き換わる。
class SettingsRow {
  const SettingsRow(this.title, {this.subtitle, this.detail, this.warning = false, this.external = false, this.route});
  final String title;
  final String? subtitle;

  /// 開発者モードのときだけ subtitle の代わりに出す詳しい説明 (D-362)。
  final String? detail;
  final bool warning;
  final bool external;

  /// Internal route to push when tapped (null = placeholder).
  final String? route;
}

class SettingsSection {
  const SettingsSection(this.title, this.rows, {this.note, this.noteDetail});
  final String title;
  final List<SettingsRow> rows;
  final String? note;

  /// 開発者モードのときだけ [note] の代わりに出す詳しい説明 (D-362)。
  final String? noteDetail;
}

/// 設定第一階層の節 (D-484: 文言は [AppLocalizations] から)。画面は `settingsSectionsOf(context.l10n)`。
Map<String, SettingsSection> settingsSectionsOf(AppLocalizations l) => <String, SettingsSection>{
  'plugins': SettingsSection(l.settingsSectionsPluginsTitle, [
    SettingsRow(l.settingsSectionsPluginsProxyTitle, subtitle: l.settingsSectionsPluginsProxySubtitle, detail: l.settingsSectionsPluginsProxyDetail, route: '/settings/dsl/plugins.proxy'),
    SettingsRow(l.settingsSectionsPluginsActionBarTitle, subtitle: l.settingsSectionsPluginsActionBarSubtitle, detail: l.settingsSectionsPluginsActionBarDetail, route: Routes.actionBarPlugins),
    SettingsRow(l.settingsSectionsPluginsTrendTitle, route: '/settings/dsl/plugins.trend'),
    SettingsRow(l.settingsSectionsPluginsComposerTitle, route: '/settings/dsl/plugins.composer'),
    SettingsRow(l.settingsSectionsPluginsTimelineTitle, route: '/settings/dsl/plugins.timeline'),
    SettingsRow(l.settingsSectionsPluginsStoreTitle, subtitle: l.settingsSectionsPluginsStoreSubtitle, route: Routes.store),
    SettingsRow(l.settingsSectionsPluginsTelemetryTitle, subtitle: l.settingsSectionsPluginsTelemetrySubtitle, detail: l.settingsSectionsPluginsTelemetryDetail, route: '/settings/dsl/plugins.telemetry'),
  ]),
  'sns': SettingsSection(l.settingsSectionsSnsTitle, [
    // 第二階層 = プラグイン提供の設定 DSL ページ (D-044, `sns.<短area>`)。
    SettingsRow(l.settingsSectionsSnsAccountTitle, route: '/settings/dsl/sns.account'),
    SettingsRow(l.settingsSectionsSnsTimelineTitle, route: '/settings/dsl/sns.timeline'),
    SettingsRow(l.settingsSectionsSnsSecurityTitle, route: '/settings/dsl/sns.security'),
    SettingsRow(l.settingsSectionsSnsSafetyTitle, route: '/settings/dsl/sns.safety'),
    SettingsRow(l.settingsSectionsSnsChildSafeTitle, subtitle: l.settingsSectionsSnsChildSafeSubtitle, detail: l.settingsSectionsSnsChildSafeDetail, route: Routes.childSafe),
    SettingsRow(l.settingsSectionsSnsListsTitle, route: '/lists'),
    SettingsRow(l.settingsSectionsSnsMuteBlockTitle, route: '/settings/mute-block'),
    SettingsRow(l.settingsSectionsSnsPluginButtonsTitle, subtitle: l.settingsSectionsSnsPluginButtonsSubtitle, detail: l.settingsSectionsSnsPluginButtonsDetail, route: Routes.actionBarPlugins),
    SettingsRow(l.settingsSectionsSnsEmojiSearchTitle, subtitle: l.settingsSectionsSnsEmojiSearchSubtitle, detail: l.settingsSectionsSnsEmojiSearchDetail, route: '/settings/dsl/plugins.emoji'),
    SettingsRow(l.settingsSectionsSnsReactionPredictTitle, subtitle: l.settingsSectionsSnsReactionPredictSubtitle, route: '/settings/dsl/plugins.reaction'),
    SettingsRow(l.settingsSectionsSnsAccountPickTitle, subtitle: l.settingsSectionsSnsAccountPickSubtitle, detail: l.settingsSectionsSnsAccountPickDetail, route: '/settings/dsl/plugins.accountPick'),
    SettingsRow(l.settingsSectionsSnsMfmTitle, route: '/settings/dsl/appearance.mfm'),
    SettingsRow(l.settingsSectionsSnsResourcesTitle, route: '/settings/dsl/resources'),
    SettingsRow(l.settingsSectionsSnsLegalTitle, route: Routes.settingsLegal),
  ],
      note: l.settingsSectionsSnsNote,
      noteDetail: l.settingsSectionsSnsNoteDetail),
  'appearance': SettingsSection(l.settingsSectionsAppearanceTitle, [
    SettingsRow(l.settingsSectionsAppearanceDisplayTitle, route: '/settings/dsl/appearance.display'),
    SettingsRow(l.settingsSectionsAppearanceThemeTitle, subtitle: l.settingsSectionsAppearanceThemeSubtitle, route: Routes.settingsTheme),
    SettingsRow(l.settingsSectionsAppearanceColumnsTitle, subtitle: l.settingsSectionsAppearanceColumnsSubtitle, detail: l.settingsSectionsAppearanceColumnsDetail, route: Routes.settingsColumns),
    SettingsRow(l.settingsSectionsAppearanceMotionTitle, route: '/settings/dsl/appearance.motion'),
    SettingsRow(l.settingsSectionsAppearanceTimelineTitle, subtitle: l.settingsSectionsAppearanceTimelineSubtitle, detail: l.settingsSectionsAppearanceTimelineDetail, route: '/settings/dsl/appearance.timeline'),
    SettingsRow(l.settingsSectionsAppearancePipTitle, route: '/settings/dsl/appearance.video'),
    SettingsRow(l.settingsSectionsAppearanceFabTitle, subtitle: l.settingsSectionsAppearanceFabSubtitle, route: '/settings/dsl/appearance.fab'),
    SettingsRow(l.settingsSectionsAppearanceMediaSaveTitle, subtitle: l.settingsSectionsAppearanceMediaSaveSubtitle, route: '/settings/dsl/media.save'),
    SettingsRow(l.settingsSectionsAppearanceNotificationsTitle, route: '/settings/dsl/appearance.notifications'),
    // 表示の言語 (D-484)。
    SettingsRow(l.languageSettingsTitle, subtitle: l.languageSettingsRowSubtitle, route: Routes.settingsLanguage),
  ]),
  'astell': SettingsSection(l.settingsSectionsAstellTitle, [
    SettingsRow(l.settingsSectionsAstellSubscriptionTitle, subtitle: l.settingsSectionsAstellSubscriptionSubtitle, detail: l.settingsSectionsAstellSubscriptionDetail, route: '/settings/dsl/astell.subscription'),
    SettingsRow(l.settingsSectionsAstellTilesTitle, route: '/settings/dsl/astell.tiles'),
    SettingsRow(l.settingsSectionsAstellTrendTitle, route: '/settings/dsl/astell.trend'),
    SettingsRow(l.settingsSectionsAstellRoomButtonsTitle, subtitle: l.settingsSectionsAstellRoomButtonsSubtitle, detail: l.settingsSectionsAstellRoomButtonsDetail, route: settingsActionAstellBar),
    SettingsRow(l.settingsSectionsAstellStoreTitle, subtitle: l.settingsSectionsAstellStoreSubtitle, detail: l.settingsSectionsAstellStoreDetail, route: Routes.store),
    SettingsRow(l.settingsSectionsAstellBackgroundTitle, route: '/settings/dsl/astell.background'),
  ]),
  'relational': SettingsSection(l.settingsSectionsRelationalTitle, [
    SettingsRow(l.settingsSectionsRelationalClusterTitle, subtitle: l.settingsSectionsRelationalClusterSubtitle, detail: l.settingsSectionsRelationalClusterDetail, route: settingsActionRelationalTuning),
    SettingsRow(l.settingsSectionsRelationalRelayTitle, route: '/settings/dsl/relational.relay'),
    SettingsRow(l.settingsSectionsRelationalTrendTitle, route: '/settings/dsl/relational.trend'),
    SettingsRow(l.settingsSectionsRelationalPluginsTitle, route: '/settings/dsl/relational.plugins'),
    SettingsRow(l.settingsSectionsRelationalSamplingTitle, subtitle: l.settingsSectionsRelationalSamplingSubtitle, detail: l.settingsSectionsRelationalSamplingDetail, route: settingsActionRelationalTuning),
  ], note: l.settingsSectionsRelationalNote, noteDetail: l.settingsSectionsRelationalNoteDetail),
  'trend': SettingsSection(l.settingsSectionsTrendTitle, [
    SettingsRow(l.settingsSectionsTrendGenresTitle, route: settingsActionTrendGenres),
    SettingsRow(l.settingsSectionsTrendTendencyTitle, warning: true, route: settingsActionTrendTendency),
    SettingsRow(l.settingsSectionsTrendEmomTitle, subtitle: l.settingsSectionsTrendEmomSubtitle, detail: l.settingsSectionsTrendEmomDetail, route: Routes.settingsEmom),
    SettingsRow(l.settingsSectionsTrendPluginsTitle, route: '/settings/dsl/plugins.trend'),
    SettingsRow(l.settingsSectionsTrendCdnTitle, subtitle: l.settingsSectionsTrendCdnSubtitle, detail: l.settingsSectionsTrendCdnDetail, route: '/settings/dsl/trend.cdn'),
  ]),
  'rai': SettingsSection(l.settingsSectionsRaiTitle, [
    SettingsRow(l.settingsSectionsRaiGraphTitle, route: '/settings/dsl/rai'),
  ]),
  'notifications': SettingsSection(l.settingsSectionsNotificationsTitle, [
    SettingsRow(l.settingsSectionsNotificationsProfileTitle, route: 'notificationPrefs'),
    SettingsRow(l.settingsSectionsNotificationsAccessTokenTitle, subtitle: l.settingsSectionsNotificationsAccessTokenSubtitle, detail: l.settingsSectionsNotificationsAccessTokenDetail, route: Routes.settingsNotifyToken),
    SettingsRow(l.settingsSectionsNotificationsSecurityTitle, subtitle: l.settingsSectionsNotificationsSecuritySubtitle, route: '/settings/dsl/sns.security'),
  ]),
  'about': SettingsSection(l.settingsSectionsAboutTitle, [
    SettingsRow(l.settingsSectionsAboutServerTitle, subtitle: l.settingsSectionsAboutServerSubtitle, detail: l.settingsSectionsAboutServerDetail, route: '/settings/server'),
    SettingsRow(l.settingsSectionsAboutHelpTitle, route: '/settings/dsl/about.help'),
    // RASQ の機能の紹介 (D-471) をもう一度。RAi の `help.tour` もここ(とヘルプのページ)を指す。
    SettingsRow(l.settingsSectionsAboutTourTitle, subtitle: l.settingsSectionsAboutTourSubtitle, route: '${Routes.featureTour}?again=1'),
    SettingsRow(l.settingsSectionsAboutSubscriptionTitle, route: '/settings/dsl/about.subscription'),
    SettingsRow(l.settingsSectionsAboutCookiesTitle, route: '/settings/dsl/about.cookies'),
    SettingsRow(l.settingsSectionsAboutPrivacyTitle, route: '/settings/dsl/about.privacy'),
    SettingsRow(l.settingsSectionsAboutTermsTitle, route: '/settings/dsl/about.terms'),
    SettingsRow(l.settingsSectionsAboutLearningTitle, subtitle: l.settingsSectionsAboutLearningSubtitle, route: Routes.settingsLearning),
    SettingsRow(l.settingsSectionsAboutAstellTermsTitle, route: '/settings/dsl/about.astell'),
    SettingsRow(l.settingsSectionsAboutRaiTermsTitle, route: '/settings/dsl/about.rai'),
    SettingsRow(l.settingsSectionsAboutStoreTermsTitle, route: '/settings/dsl/about.store'),
    SettingsRow(l.settingsSectionsAboutDevTermsTitle, subtitle: l.settingsSectionsAboutDevTermsSubtitle, route: '/settings/dsl/about.devterms'),
    SettingsRow(l.settingsSectionsAboutBillingTitle, route: '/settings/dsl/about.billing'),
    SettingsRow(l.settingsSectionsAboutCommerceTitle, route: '/settings/dsl/about.commerce'),
    SettingsRow(l.settingsSectionsAboutResourcesTitle, route: '/settings/dsl/resources'),
    SettingsRow(l.settingsSectionsAboutLegalTitle, route: Routes.settingsLegal),
    SettingsRow(l.settingsSectionsAboutDeveloperTitle, subtitle: l.settingsSectionsAboutDeveloperSubtitle, route: '/settings/dsl/about.developer'),
  ]),
};

/// いまの表示の言語の [settingsSectionsOf](`BuildContext` の無いところ・テスト用)。
Map<String, SettingsSection> get settingsSections => settingsSectionsOf(appL10n);

/// 画面ではなく FOW / シートを開く行の印 (D-238)。[SettingsSectionScreen] が解釈する。
const settingsActionTrendGenres = 'action:trend.genres';
const settingsActionTrendTendency = 'action:trend.tendency';
const settingsActionRelationalTuning = 'action:relational.tuning';

/// AsTell のルームの下段のボタンの編集 (D-324、アクションバーの編集 FOW の AsTell の面)。
const settingsActionAstellBar = 'action:astell.bar';
