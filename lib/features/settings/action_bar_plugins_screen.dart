import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/plugin_actions.dart';
import '../plugins/slot_plugins.dart';
import 'settings_dsl.dart';

/// 設定 → SNSプラグイン →「プラグインボタン」(D-210 → D-305、契約 v0.14 §2.11)。
///
/// 面ごとの節(投稿タイル / 全画面 / 加工画面 / コンポーザー本文 / 投稿加工(自動))に、宣言されたボタンを並べる。
/// 行 = ボタン名 + 提供元 + 配置の説明 + **switch**(端末全体の主電源。オフなら全アカウント・全面で出ず、自動でも動かない)、
/// その下に **temp**「面を開いたとき自動でオン」(面が作られた瞬間の初期状態の上書き。状態を持たない post.action は
/// `auto_hook` 権限のある審査済みプラグインだけ)。
/// 末尾の「このアカウント」に、従来のアカウントごとの有効 / 無効と束ねる閾値(設定エリア `slots.<accountKey>`、D-176)。
class ActionBarPluginsScreen extends ConsumerWidget {
  const ActionBarPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(currentAccountProvider);
    final accountKey = account?.key ?? '';
    final session = ref.watch(currentSnsSessionProvider);
    final snsActions = session?.actions ?? const <ActionDescriptor>[];
    final settings = ref.watch(slotActionSettingsProvider(accountKey));
    final settingsStore = ref.read(settingsAreaProvider(slotSettingsArea(accountKey)).notifier);
    final editorSettings = ref.watch(slotActionSettingsProvider('editor'));
    final prefs = ref.watch(actionButtonPrefsProvider);
    final prefsStore = ref.read(settingsAreaProvider(actionButtonPrefsArea).notifier);
    final postActions = ref.watch(pluginActionsProvider);
    final l = context.l10n;
    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});

    /// バンドル先の説明(投稿タイル / 加工画面)。
    String bundleOf(PluginAction p, List<ActionDescriptor> existing, double threshold) {
      if (p.isManual) return l.settingsActionBarBundleManual;
      final m = bestMatch(p.decl.tags, existing);
      return m == null || m.score < threshold ? l.settingsActionBarBundleAlone : l.settingsActionBarBundleInto(m.action.label, '${(m.score * 100).round()}');
    }

    Widget hint(String text, [String? detail]) =>
        RasqCaption(text, detail: detail, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm));

    /// ボタン 1 つ: switch の行と、temp を持つものは「面を開いたとき自動でオン」の行。
    List<Widget> rows(PluginAction p, String placement) {
      final on = prefs.switchOn(p.id);
      final override = prefs.autoOverride(p.id);
      final stateLabel = p.declaredAuto ? l.settingsActionBarOn : l.settingsActionBarOff;
      return [
        RasqSwitchListTile(
          key: ValueKey('actionbar.switch.${p.id}'),
          title: p.decl.label,
          subtitle: '${p.plugin.manifest.name} · $placement',
          value: on,
          onChanged: (v) => setActionSwitch(prefsStore, prefs, p.id, v),
        ),
        if (p.hasTemp)
          RasqSwitchListTile(
            key: ValueKey('actionbar.auto.${p.id}'),
            leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: scheme.onSurfaceVariant),
            title: l.settingsActionBarAutoOnTitle,
            subtitle: override == null
                ? (p.plugin.isReviewed && p.decl.auto != null ? l.settingsActionBarAutoDefaultDeclared(stateLabel) : l.settingsActionBarAutoDefault(stateLabel))
                : l.settingsActionBarAutoOverridden(stateLabel),
            value: override ?? p.declaredAuto,
            enabled: on,
            onChanged: (v) => setActionAuto(prefsStore, prefs, p.id, v),
          ),
      ];
    }

    List<Widget> section(String title, String emptyDetail, List<PluginAction> actions, String Function(PluginAction) placement) => [
          RasqSectionHeader(title: title),
          if (actions.isEmpty) hint(l.settingsActionBarEmptyCaption, emptyDetail),
          for (final p in actions) ...rows(p, placement(p)),
        ];

    // 投稿加工(自動、ボタン無し): switch だけ(ActionKey `slot:<pluginId>:post.transform`)。
    final transforms = [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.postTransform)))
        PluginAction(plugin: p, decl: SlotActionDecl(id: SlotIds.postTransform, label: p.manifest.name, slot: SlotIds.postTransform)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsActionBarTitle), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: l.settingsActionBarBackTooltip, onPressed: () => context.pop())),
      body: ListView(children: [
        hint(l.settingsActionBarIntroCaption, l.settingsActionBarIntroDetail),
        ...section(l.settingsActionBarPostTileHeader, l.settingsActionBarPostTileEmptyDetail, postActions, (p) => bundleOf(p, snsActions, settings.threshold)),
        ...section(l.settingsActionBarViewerHeader, l.settingsActionBarViewerEmptyDetail, ref.watch(viewerPluginActionsProvider), (_) => l.settingsActionBarViewerPlacement),
        ...section(l.settingsActionBarMediaHeader, l.settingsActionBarMediaEmptyDetail, ref.watch(mediaPluginActionsProvider), (p) {
          final bundle = bundleOf(p, editorBuiltinActions, editorSettings.threshold);
          return p.decl.isFilterOutput ? l.settingsActionBarFilterPlacement(bundle) : bundle;
        }),
        ...section(l.settingsActionBarComposerTextHeader, l.settingsActionBarComposerTextEmptyDetail, ref.watch(composerTextPluginActionsProvider), (_) => l.settingsActionBarComposerTextPlacement),
        ...section(l.settingsActionBarTransformHeader, l.settingsActionBarTransformEmptyDetail, transforms, (_) => l.settingsActionBarTransformPlacement),
        RasqSectionHeader(title: l.settingsActionBarThisAccountHeader(account == null ? l.settingsActionBarNoAccount : '$account')),
        if (postActions.isEmpty) hint(l.settingsActionBarThisAccountEmptyCaption, l.settingsActionBarThisAccountEmptyDetail),
        for (final p in postActions)
          RasqSwitchListTile(
            key: ValueKey('actionbar.slot.${p.id}'),
            title: p.decl.label,
            subtitle: l.settingsActionBarSlotSubtitle(p.plugin.manifest.name, p.decl.tags.join(' / ')),
            value: settings.isEnabled(p.id),
            enabled: prefs.switchOn(p.id),
            onChanged: (v) => setEnabled(p.id, v),
          ),
        RasqSliderListTile(
          key: const ValueKey('actionbar.slot.threshold'),
          title: l.settingsActionBarThresholdTitle,
          subtitle: l.settingsActionBarThresholdSubtitle,
          detail: l.settingsActionBarThresholdDetail,
          value: settings.threshold * 100,
          min: 50,
          max: 100,
          divisions: 10,
          valueLabel: '${(settings.threshold * 100).round()}%',
          onChanged: (v) => settingsStore.set('threshold', v / 100),
        ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(key: const ValueKey('actionbar.plugins.edit'), onPressed: () => showActionBarEditSheet(ref), icon: const Icon(Icons.tune, size: 18), label: Text(l.settingsActionBarEditButton)),
          ),
        ),
      ]),
    );
  }
}
