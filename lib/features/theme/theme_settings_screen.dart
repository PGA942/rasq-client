import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/feature_flags.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import '../store/rasqpkg.dart';
import '../store/store_providers.dart';
import 'icon_theme/icon_theme_reader.dart' show iconThemesEnabledProvider, iconThemesSettingKey;
import 'theme_display.dart';
import 'theme_packs.dart';
import '../../l10n/l10n.dart';

/// 着せ替えの .rasqpkg を選ぶ口(テストで差し替える)。null = やめた。
final themePackPickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      final f = await fs.openFile(acceptedTypeGroups: [fs.XTypeGroup(label: appL10n.themePickerLabel, extensions: const ['rspkg', 'rasqpkg'])]);
      return f == null ? null : await f.readAsBytes();
    });

/// 設定 → アプリの外観 →「フォントやカラースキーム」(D-335): 着せ替えを選ぶ。
///
/// 着せ替えなし(既定)+ インストールした着せ替えパック(ストア / ファイルから)。同時に効くのは 1 つ。各行に色の見本、
/// 効く明るさ(暗いモードだけ、など)、未審査の印、削除。ストアへの入口と、ファイル(.rasqpkg)からの読み込み。
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});
  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _select(String? id) => ref.read(settingsAreaProvider(themeSettingsArea).notifier).set('id', id);

  Future<void> _importFile() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final bytes = await ref.read(themePackPickerProvider)();
      if (bytes == null) return;
      final pkg = RasqPackage.open(bytes, decompress: ref.read(rasqpkgZstdProvider));
      if (!pkg.root.isTheme) throw RasqPackageException(appL10n.themeNotATheme(pkg.root.id, pkg.root.kind));
      final pack = await ref.read(themePacksProvider.notifier).install(pkg, sideloaded: true);
      await _select(pack.id);
    } on RasqPackageException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.themeLoadFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(InstalledThemePack p) async {
    // ストアから入れたものはストアのインストール記録ごと外す(画像も消える)。ファイルから入れたものは着せ替えだけ。
    if (ref.read(installedPluginsProvider).any((x) => x.id == p.id)) {
      await ref.read(installedPluginsProvider.notifier).uninstall(p.id);
    } else {
      await ref.read(themePacksProvider.notifier).uninstall(p.id);
    }
  }

  String _originLabel(BuildContext context, ThemeOrigin o) => switch (o) {
        ThemeOrigin.icon => context.l10n.themeOriginIcon,
        ThemeOrigin.atmos => context.l10n.themeOriginAtmos,
        ThemeOrigin.community => context.l10n.themeOriginCommunity,
      };

  String _scopeLabel(BuildContext context, ThemeDisplayScope s) => switch (s) {
        ThemeDisplayScope.followees => context.l10n.themeScopeFollowees,
        ThemeDisplayScope.all => context.l10n.themeScopeAll,
        ThemeDisplayScope.off => context.l10n.themeScopeOff,
      };

  Future<void> _pickScope(BuildContext tileContext, ThemeOrigin o) async {
    final box = tileContext.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
    final current = ref.read(themeDisplayScopeProvider(o));
    final pick = await ref.read(overlayManagerProvider).showDropdown<ThemeDisplayScope>(id: 'theme.display.${o.name}', anchor: anchor, items: [
      for (final s in ThemeDisplayScope.values) RasqDropdownItem(_scopeLabel(tileContext, s), s, checked: s == current),
    ]);
    if (pick != null) await setThemeDisplayScope(ref, o, pick);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final packs = ref.watch(themePacksProvider);
    final active = ref.watch(activeThemeIdProvider);
    final selected = packs.any((p) => p.id == active) ? active : null;
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.themeTitle),
      body: ListView(children: [
        RasqCaption(
          context.l10n.themeCaption,
          detail: context.l10n.themeCaptionDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        // ライト / ダーク (D-375): 設定の「フォントやカラースキーム」から、ここへ来る。
        RasqSectionHeader(title: context.l10n.themeColorScheme),
        for (final m in ThemeModeSetting.values)
          RasqRadioListTile<ThemeModeSetting>(
            key: ValueKey('theme.mode.${m.name}'),
            title: switch (m) { ThemeModeSetting.system => context.l10n.themeModeSystem, ThemeModeSetting.light => context.l10n.themeModeLight, ThemeModeSetting.dark => context.l10n.themeModeDark },
            value: m,
            groupValue: ref.watch(themeModeProvider),
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
          ),
        RasqSectionHeader(title: context.l10n.themePacks),
        RasqRadioListTile<String?>(key: const ValueKey('theme.none'), title: context.l10n.themeNone, value: null, groupValue: selected, onChanged: (_) => _select(null)),
        for (final p in packs)
          Row(children: [
            Expanded(
              child: RasqRadioListTile<String?>(
                key: ValueKey('theme.pack.${p.id}'),
                title: p.name,
                subtitle: [
                  'v${p.version}',
                  if (p.description.isNotEmpty) p.description,
                  switch (p.theme['brightness']) { 'dark' => context.l10n.themeDarkOnly, 'light' => context.l10n.themeLightOnly, _ => null },
                  if (p.sideloaded) context.l10n.themeSideloaded,
                ].whereType<String>().join(context.l10n.themeSeparator),
                value: p.id,
                groupValue: selected,
                onChanged: (v) => _select(v),
              ),
            ),
            // 色の見本。
            for (final c in p.swatches.take(4))
              Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: scheme.outline))),
            RasqIconButton(key: ValueKey('theme.remove.${p.id}'), icon: Icons.delete_outline, size: 20, tooltip: context.l10n.themeRemove, onPressed: () => _remove(p)),
          ]),
        // 選んだ着せ替えが、いまの明るさでは効かないとき (D-374): 「入れたのに FOW の背景が変わらない」にならないように。
        if (packs.where((p) => p.id == selected).firstOrNull case final p?)
          if (switch (p.theme['brightness']) { 'dark' => Theme.of(context).brightness != Brightness.dark, 'light' => Theme.of(context).brightness != Brightness.light, _ => false })
            RasqNotice(
              key: const ValueKey('theme.brightnessHint'),
              text: p.theme['brightness'] == 'dark' ? context.l10n.themeDarkOnlyNotice(p.name) : context.l10n.themeLightOnlyNotice(p.name),
              action: TextButton(
                key: const ValueKey('theme.brightnessHint.switch'),
                onPressed: () => ref.read(themeModeProvider.notifier).set(p.theme['brightness'] == 'dark' ? ThemeModeSetting.dark : ThemeModeSetting.light),
                child: Text(p.theme['brightness'] == 'dark' ? context.l10n.themeSwitchToDark : context.l10n.themeSwitchToLight),
              ),
            ),
        if (packs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
            child: Text(context.l10n.themeEmpty, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (_error != null)
          Padding(
            key: const ValueKey('theme.error'),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text(_error!, style: RasqTypography.caption.copyWith(color: RasqColors.danger)),
          ),
        const Divider(height: RasqSpacing.lg),
        // アイコンに埋め込まれたテーマを読む (D-580)。止めると、アイコンを取り直さない(枠・添付の並び・拡大したときの背景は既定)。
        // 埋め込むほうは、プロフィールの編集のアイコン / ヘッダーの 🎨 から(D-581)。
        RasqSwitchListTile(
          key: const ValueKey('theme.iconThemes'),
          title: context.l10n.iconThemeSettingsRead,
          subtitle: context.l10n.iconThemeSettingsReadSubtitle,
          leading: const Icon(Icons.palette_outlined),
          value: ref.watch(iconThemesEnabledProvider),
          onChanged: (v) => ref.read(settingsAreaProvider(themeSettingsArea).notifier).set(iconThemesSettingKey, v),
        ),
        // ほかの人のテーマ (D-587): 種類ごとに、出す範囲と、着せ替え(上で選んだもの)とどちらを優先するか。値でのミュートの一覧。
        RasqSectionHeader(title: context.l10n.themeDisplayTitle),
        for (final o in [ThemeOrigin.icon, if (ref.watch(featureFlagsProvider).atmos) ThemeOrigin.atmos, if (ref.watch(featureFlagsProvider).communityTagThemes) ThemeOrigin.community]) ...[
          Builder(
            builder: (tileContext) => RasqListTile(
              key: ValueKey('theme.display.${o.name}.scope'),
              title: _originLabel(context, o),
              subtitle: _scopeLabel(context, ref.watch(themeDisplayScopeProvider(o))),
              leading: Icon(switch (o) { ThemeOrigin.icon => Icons.account_circle_outlined, ThemeOrigin.atmos => Icons.auto_awesome_outlined, ThemeOrigin.community => Icons.tag }),
              onTap: () => _pickScope(tileContext, o),
            ),
          ),
          RasqSwitchListTile(
            key: ValueKey('theme.display.${o.name}.overPlugin'),
            title: context.l10n.themeDisplayOverPlugin,
            subtitle: context.l10n.themeDisplayOverPluginSubtitle,
            value: ref.watch(themeOverPluginProvider(o)),
            onChanged: (v) => setThemeOverPlugin(ref, o, v),
          ),
        ],
        RasqListTile(
          key: const ValueKey('theme.muted'),
          title: context.l10n.themeMutedTitle,
          subtitle: context.l10n.themeMutedCount(ref.watch(mutedThemesProvider).length),
          leading: const Icon(Icons.visibility_off_outlined),
          onTap: () => context.push(Routes.settingsMutedThemes),
        ),
        const Divider(height: RasqSpacing.lg),
        RasqListTile(key: const ValueKey('theme.store'), title: context.l10n.themeFindInStore, leading: const Icon(Icons.storefront_outlined), onTap: () => context.push(Routes.store)),
        RasqListTile(
          key: const ValueKey('theme.import'),
          title: context.l10n.themeImport,
          subtitle: context.l10n.themeImportSubtitle,
          detail: context.l10n.themeImportDetail,
          leading: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open_outlined),
          onTap: _busy ? null : _importFile,
        ),
      ]),
    );
  }
}
