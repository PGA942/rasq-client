import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';

/// 設定(ホーム) — 全ての設定 (ワイヤーフレーム P7). SNS plugin sections appear per
/// installed SNS plugin; 第一階層は `settings/:section`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final manager = ref.watch(overlayManagerProvider);
    final registry = ref.watch(pluginRegistryProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: '全ての設定', onMore: () {}),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: RasqSearchBar(hintText: '操作の検索')),
        RasqListTile(title: 'プラグインの構成', onTap: () => context.push('/settings/section/plugins')),
        for (final p in registry.plugins)
          RasqListTile(
            title: p.manifest.name,
            trailing: p.manifest.verified ? Icon(Icons.verified, color: p.manifest.official ? const Color(0xFF34C759) : const Color(0xFF1E88E5), size: 18) : null,
            onTap: () => context.push('/settings/section/sns'),
          ),
        RasqListTile(title: 'アプリの外観', onTap: () => context.push('/settings/section/appearance')),
        RasqListTile(title: 'ASTell', onTap: () => context.push('/settings/section/astell')),
        RasqListTile(title: 'リレーショナルタイムライン', onTap: () => context.push('/settings/section/relational')),
        RasqListTile(title: 'トレンド', onTap: () => context.push('/settings/section/trend')),
        RasqListTile(title: '通知', onTap: () => context.push('/settings/section/notifications')),
        RasqListTile(title: 'RASQについて', onTap: () => context.push('/settings/section/about')),
        RasqListTile(title: 'ミュート/ブロック', onTap: () => context.pushMuteBlock()),
        RasqListTile(
          title: 'アカウントの重要設定',
          subtitle: 'パスワードの再設定やアカウント削除など、パスワードがいる処理は web 版で行います',
          trailing: const Icon(Icons.north_east, size: 18),
          chevron: false,
          onTap: () => launchUrl(Uri.https(me.account.instance, '/settings'), mode: LaunchMode.externalApplication),
        ),
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
