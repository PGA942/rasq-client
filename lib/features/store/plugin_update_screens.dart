import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../settings/settings_dsl.dart';
import 'plugin_updates.dart';

/// アップデート/デプロイの設定 (D-356、ワイヤーフレーム p.8)。上のタブ = 区分(SNS / アクション / ビュー)、
/// その中に 3 つのモード(おまかせ / インストールだけおまかせ / 全て手動で構成)。下に共通の「アップデート後の起動時にポップアップを表示」
/// と「更新ログ ›」、「いま確かめる」。
class PluginUpdateSettingsScreen extends ConsumerStatefulWidget {
  const PluginUpdateSettingsScreen({super.key});
  @override
  ConsumerState<PluginUpdateSettingsScreen> createState() => _PluginUpdateSettingsScreenState();
}

class _PluginUpdateSettingsScreenState extends ConsumerState<PluginUpdateSettingsScreen> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    final container = ProviderScope.containerOf(context);
    try {
      final entries = await runPluginUpdates(container);
      messenger?.showSnackBar(SnackBar(content: Text(entries.isEmpty ? '自動で入れる更新はありませんでした' : [for (final e in entries) '${e.name}: ${e.summary}'].join('\n'))));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final popup = ref.watch(pluginUpdatePopupProvider);
    final store = ref.read(settingsAreaProvider(pluginUpdateArea).notifier);
    return DefaultTabController(
      length: PluginUpdateGroup.values.length,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: 'アップデート/デプロイの設定',
          showMore: false,
          bottom: RasqTabs(items: [for (final g in PluginUpdateGroup.values) RasqTabItem(g.label, id: g.wire, chevron: false)], showChevron: false),
        ),
        body: Column(children: [
          SizedBox(
            height: 260,
            child: TabBarView(children: [
              for (final g in PluginUpdateGroup.values)
                ListView(key: ValueKey('store.updates.tab.${g.wire}'), children: [
                  const RasqSectionHeader(title: 'アップデート/デプロイ', topMargin: 0),
                  for (final m in PluginUpdateMode.values)
                    RadioListTile<PluginUpdateMode>(
                      key: ValueKey('store.updates.${g.wire}.${m.wire}'),
                      value: m,
                      // ignore: deprecated_member_use
                      groupValue: ref.watch(pluginUpdateModeProvider(g)),
                      // ignore: deprecated_member_use
                      onChanged: (v) => store.set('mode.${g.wire}', v!.wire),
                      title: Text(m.label, style: RasqTypography.body),
                      subtitle: Text(m.description, style: RasqTypography.caption),
                      controlAffinity: ListTileControlAffinity.trailing,
                      dense: true,
                    ),
                ]),
            ]),
          ),
          const Divider(height: 1),
          RasqSwitchListTile(
            key: const ValueKey('store.updates.popup'),
            title: 'アップデート後の起動時にポップアップを表示',
            value: popup,
            onChanged: (v) => store.set('popup', v),
          ),
          RasqListTile(key: const ValueKey('store.updates.log'), title: '更新ログ', leading: const Icon(Icons.history), onTap: () => context.push(Routes.storeUpdateLog)),
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(
                key: const ValueKey('store.updates.checkNow'),
                onPressed: _checking ? null : _checkNow,
                icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.system_update_alt),
                label: const Text('いま確かめる'),
              ),
              const SizedBox(height: RasqSpacing.xs),
              const RasqCaption(
                '権限が増える版と有料の版は、自動では入りません',
                detail: '権限が増える版(増えないことを確かめられない版も)と、買っていない有料の版は、どのモードでも自動では入れません(更新ログに理由が残ります)。起動するたびに 1 回確かめます。',
                padding: EdgeInsets.zero,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 更新ログ (D-356): 新しい順。自動 / いま確かめる で入れた・切り替えた・入れなかった(理由つき)。
class PluginUpdateLogScreen extends ConsumerWidget {
  const PluginUpdateLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(pluginUpdateLogProvider);
    final scheme = Theme.of(context).colorScheme;
    String date(DateTime d) => '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: const RasqPageHeader(title: '更新ログ', showMore: false),
      body: log.isEmpty
          ? const RasqEmptyView(title: 'まだありません', hint: 'アップデートすると、ここに残ります')
          : ListView.separated(
              itemCount: log.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = log[i];
                final icon = switch (e.result) {
                  'activated' || 'switched' => Icons.check_circle_outline,
                  'installed' => Icons.download_done,
                  'skipped' => Icons.pause_circle_outline,
                  _ => Icons.error_outline,
                };
                return ListTile(
                  key: ValueKey('store.updateLog.$i'),
                  leading: Icon(icon, color: e.result == 'failed' ? scheme.error : null),
                  title: Text(e.name, style: RasqTypography.body),
                  subtitle: Text('${e.summary}\n${date(e.at)}', style: RasqTypography.caption),
                  isThreeLine: true,
                  onTap: () => context.push(Routes.storePlugin(e.pluginId)),
                );
              },
            ),
    );
  }
}
