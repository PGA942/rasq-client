import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import '../store/rasqpkg.dart';
import '../store/store_providers.dart';
import 'theme_packs.dart';

/// 着せ替えの .rasqpkg を選ぶ口(テストで差し替える)。null = やめた。
final themePackPickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      final f = await fs.openFile(acceptedTypeGroups: const [fs.XTypeGroup(label: '着せ替え(.rasqpkg)', extensions: ['rasqpkg'])]);
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
      if (!pkg.root.isTheme) throw RasqPackageException('着せ替え(kind: theme)ではありません: ${pkg.root.id}(${pkg.root.kind})');
      final pack = await ref.read(themePacksProvider.notifier).install(pkg, sideloaded: true);
      await _select(pack.id);
    } on RasqPackageException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '読み込めませんでした: $e');
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final packs = ref.watch(themePacksProvider);
    final active = ref.watch(activeThemeIdProvider);
    final selected = packs.any((p) => p.id == active) ? active : null;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'フォントやカラースキーム'),
      body: ListView(children: [
        const RasqCaption(
          '色やアイコン、背景を変えられます。使えるのは 1 つだけです',
          detail: '着せ替え(テーマ)は、色・アイコン・画面 / 投稿タイル / FOW / ボタンの背景を変えるパックです。コードは動きません。同時に使えるのは 1 つです。',
          padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        const RasqSectionHeader(title: '着せ替え'),
        RasqRadioListTile<String?>(key: const ValueKey('theme.none'), title: '着せ替えなし(既定)', value: null, groupValue: selected, onChanged: (_) => _select(null)),
        for (final p in packs)
          Row(children: [
            Expanded(
              child: RasqRadioListTile<String?>(
                key: ValueKey('theme.pack.${p.id}'),
                title: p.name,
                subtitle: [
                  'v${p.version}',
                  if (p.description.isNotEmpty) p.description,
                  switch (p.theme['brightness']) { 'dark' => '暗いモードのときに効きます', 'light' => '明るいモードのときに効きます', _ => null },
                  if (p.sideloaded) 'ファイルから読み込み(未審査)',
                ].whereType<String>().join(' ・ '),
                value: p.id,
                groupValue: selected,
                onChanged: (v) => _select(v),
              ),
            ),
            // 色の見本。
            for (final c in p.swatches.take(4))
              Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: scheme.outline))),
            RasqIconButton(key: ValueKey('theme.remove.${p.id}'), icon: Icons.delete_outline, size: 20, tooltip: '削除', onPressed: () => _remove(p)),
          ]),
        // 選んだ着せ替えが、いまの明るさでは効かないとき (D-374): 「入れたのに FOW の背景が変わらない」にならないように。
        if (packs.where((p) => p.id == selected).firstOrNull case final p?)
          if (switch (p.theme['brightness']) { 'dark' => Theme.of(context).brightness != Brightness.dark, 'light' => Theme.of(context).brightness != Brightness.light, _ => false })
            RasqNotice(
              key: const ValueKey('theme.brightnessHint'),
              text: p.theme['brightness'] == 'dark' ? '「${p.name}」は暗いモードのときに効きます。いまは明るいモードです。' : '「${p.name}」は明るいモードのときに効きます。いまは暗いモードです。',
              action: TextButton(
                key: const ValueKey('theme.brightnessHint.switch'),
                onPressed: () => ref.read(themeModeProvider.notifier).set(p.theme['brightness'] == 'dark' ? ThemeModeSetting.dark : ThemeModeSetting.light),
                child: Text(p.theme['brightness'] == 'dark' ? '暗いモードにする' : '明るいモードにする'),
              ),
            ),
        if (packs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
            child: Text('インストールした着せ替えはまだありません。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (_error != null)
          Padding(
            key: const ValueKey('theme.error'),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text(_error!, style: RasqTypography.caption.copyWith(color: RasqColors.danger)),
          ),
        const Divider(height: RasqSpacing.lg),
        RasqListTile(key: const ValueKey('theme.store'), title: 'ストアで着せ替えを探す', leading: const Icon(Icons.storefront_outlined), onTap: () => context.push(Routes.store)),
        RasqListTile(
          key: const ValueKey('theme.import'),
          title: 'ファイルから読み込む(.rasqpkg)',
          subtitle: '自分で作った着せ替えを読み込みます',
          detail: 'rasq build で作った着せ替えパック。コードを含まないので、未審査でもそのまま使えます',
          leading: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open_outlined),
          onTap: _busy ? null : _importFile,
        ),
      ]),
    );
  }
}
