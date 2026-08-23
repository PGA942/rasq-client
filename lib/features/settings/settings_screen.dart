import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/navigation.dart';
import '../../shell/headers.dart';

/// 設定(ホーム) — 全ての設定 (ワイヤーフレーム P7).
/// SNS plugin sections appear per installed SNS plugin; from M4 the first
/// level and below are rendered from FOW DSL.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final mode = ref.watch(themeModeProvider);
    final manager = ref.watch(overlayManagerProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: '全ての設定', onMore: () {}),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: RasqSearchBar(hintText: '操作の検索')),
        RasqListTile(title: 'プラグインの構成', onTap: () {}),
        RasqListTile(title: 'BlueSky Plugin', trailing: const Icon(Icons.verified, color: Color(0xFF34C759), size: 18), onTap: () {}),
        RasqListTile(title: 'Misskey Plugin', trailing: const Icon(Icons.verified, color: Color(0xFF1E88E5), size: 18), onTap: () {}),
        RasqListTile(title: 'ミュート/ブロック', onTap: () => context.pushMuteBlock()),
        RasqValueListTile(
          title: 'アプリの外観',
          value: switch (mode) { ThemeModeSetting.system => 'システム', ThemeModeSetting.light => 'ライト', ThemeModeSetting.dark => 'ダーク' },
          onTap: () async {
            final picked = await manager.showBottomSheet<ThemeModeSetting>(
              id: 'settings.appearance',
              title: 'アプリの外観',
              builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
                for (final m in ThemeModeSetting.values)
                  RasqRadioListTile<ThemeModeSetting>(
                    title: switch (m) { ThemeModeSetting.system => 'システムに合わせる', ThemeModeSetting.light => 'ライト', ThemeModeSetting.dark => 'ダーク' },
                    value: m,
                    groupValue: mode,
                    onChanged: (v) => OverlayScope.read(ctx).close('settings.appearance', result: v),
                  ),
              ]),
            );
            if (picked != null) ref.read(themeModeProvider.notifier).set(picked);
          },
        ),
        RasqListTile(title: 'ASTell', onTap: () {}),
        RasqListTile(title: 'リレーショナルタイムライン', onTap: () {}),
        RasqListTile(title: 'トレンド', onTap: () {}),
        RasqListTile(title: '通知', onTap: () {}),
        RasqListTile(title: 'RASQについて', onTap: () {}),
        RasqDestructiveListTile(
          title: '@${me.handle}からログアウト',
          onTap: () async {
            final ok = await manager.showAlert(id: 'settings.logout', title: 'ログアウトしますか？', message: 'このアカウントのプラグイン構成はデバイスに残ります。', confirmText: 'ログアウト', cancelText: 'キャンセル', destructive: true);
            final account = ref.read(currentAccountProvider);
            if (ok && account != null) await ref.read(sessionsProvider.notifier).remove(account);
          },
        ),
      ]),
    );
  }
}
