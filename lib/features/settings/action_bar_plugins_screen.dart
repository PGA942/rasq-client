import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/plugin_actions.dart';
import 'settings_dsl.dart';

/// 設定 → SNSプラグイン →「プラグインボタン」(D-210): 宣言されたプラグインボタンの有効 / 無効と束ねる閾値
/// (アクションバーの編集 FOW から移動。設定エリア `slots.<accountKey>`、D-176)。
class ActionBarPluginsScreen extends ConsumerWidget {
  const ActionBarPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(currentAccountProvider);
    final accountKey = account?.key ?? '';
    final session = ref.watch(currentSnsSessionProvider);
    final snsActions = session?.actions ?? const <ActionDescriptor>[];
    final plugins = ref.watch(pluginActionsProvider);
    final settings = ref.watch(slotActionSettingsProvider(accountKey));
    final settingsStore = ref.read(settingsAreaProvider(slotSettingsArea(accountKey)).notifier);
    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});
    return Scaffold(
      appBar: AppBar(title: const Text('プラグインボタン'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => context.pop())),
      body: ListView(children: [
        RasqSectionHeader(title: '宣言されたボタン(${account == null ? 'このアカウント' : '$account'})'),
        if (plugins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
            child: Text('post.action を宣言したプラグインがここに並びます(ストアから追加)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        for (final p in plugins)
          Builder(
            builder: (_) {
              final m = bestMatch(p.decl.tags, snsActions);
              final where = m == null || m.score < settings.threshold ? '単体で末尾' : '「${m.action.label}」のバンドル(${(m.score * 100).round()}%)';
              return RasqSwitchListTile(
                key: ValueKey('actionbar.slot.${p.id}'),
                title: p.decl.label,
                subtitle: '${p.plugin.manifest.name} · タグ: ${p.decl.tags.join(' / ')} → $where',
                value: settings.isEnabled(p.id),
                onChanged: (v) => setEnabled(p.id, v),
              );
            },
          ),
        RasqSliderListTile(
          key: const ValueKey('actionbar.slot.threshold'),
          title: '束ねる閾値',
          subtitle: 'タグの類似度がこれ以上なら既存ボタンのバンドルに入る',
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
            child: TextButton.icon(key: const ValueKey('actionbar.plugins.edit'), onPressed: () => showActionBarEditSheet(ref), icon: const Icon(Icons.tune, size: 18), label: const Text('アクションバーを編集')),
          ),
        ),
      ]),
    );
  }
}
