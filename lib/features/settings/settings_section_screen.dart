import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../notifications/notifications_screen.dart';
import 'settings_sections.dart';

/// Generic first-level settings page driven by [settingsSections].
/// アプリの外観 has live controls (テーマ); everything else is a labelled placeholder.
class SettingsSectionScreen extends ConsumerWidget {
  const SettingsSectionScreen({super.key, required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = settingsSections[sectionId];
    final manager = ref.watch(overlayManagerProvider);
    if (section == null) return Scaffold(appBar: const RasqPageHeader(title: '設定'), body: const RasqEmptyView(title: '不明な設定セクション'));
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: section.title, onMore: () {}),
      body: ListView(children: [
        for (final r in section.rows)
          if (sectionId == 'appearance' && r.title == 'フォントやカラースキーム')
            RasqValueListTile(
              title: r.title,
              value: switch (mode) { ThemeModeSetting.system => 'システム', ThemeModeSetting.light => 'ライト', ThemeModeSetting.dark => 'ダーク' },
              onTap: () async {
                final picked = await manager.showBottomSheet<ThemeModeSetting>(
                  id: 'settings.appearance',
                  title: 'カラースキーム',
                  builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final m in ThemeModeSetting.values)
                      RasqRadioListTile<ThemeModeSetting>(
                        title: switch (m) { ThemeModeSetting.system => 'システムに合わせる', ThemeModeSetting.light => 'ライト', ThemeModeSetting.dark => 'ダーク' },
                        value: m,
                        groupValue: mode,
                        onChanged: (v) => ref.read(overlayManagerProvider).close('settings.appearance', result: v),
                      ),
                  ]),
                );
                if (picked != null) ref.read(themeModeProvider.notifier).set(picked);
              },
            )
          else if (r.warning)
            RasqWarningListTile(title: r.title, onTap: () => _placeholder(manager, r.title))
          else
            RasqListTile(
              title: r.title,
              subtitle: r.subtitle,
              trailing: r.external ? const Icon(Icons.north_east, size: 18) : null,
              onTap: () {
                if (r.route == 'notificationPrefs') {
                  showNotificationPrefs(ref);
                } else if (r.route != null) {
                  context.push(r.route!);
                } else {
                  _placeholder(manager, r.title);
                }
              },
            ),
        if (section.note != null) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(section.note!, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }

  Future<void> _placeholder(OverlayManager manager, String title) => manager.showAlert(id: 'settings.placeholder', title: title, message: 'この設定は第二階層以降の仕様確定後(M4: FOW/DSL 描画)に実装します。', confirmText: 'OK');
}
