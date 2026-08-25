import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'action_bar_config.dart';
import 'post_row.dart';

/// 「アクションリストの編集」シート (2026-08-25 ワイヤー)。
/// 行 = アイコン + アクション名 + 提供プラグイン名。ドラッグで並び替え、
/// 目のトグルで表示/非表示、`…` でアクションの詳細。即時反映(保存ボタン無し)。
Future<void> showActionBarEditSheet(WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showBottomSheet(
    id: 'actionbar.edit',
    title: 'アクションリストの編集',
    builder: (_) => const _ActionBarEditBody(),
  );
}

class _ActionBarEditBody extends ConsumerWidget {
  const _ActionBarEditBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(currentSnsSessionProvider);
    final registry = ref.watch(pluginRegistryProvider);
    final config = ref.watch(actionBarConfigProvider);
    final store = ref.read(actionBarConfigProvider.notifier);
    final manager = ref.read(overlayManagerProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    // 表示中(構成順)+ 非表示(下)の順で全アクションを並べる。
    final visible = config.apply(actions);
    final hidden = [for (final a in actions) if (config.hidden.contains(a.id)) a];
    final pluginName = registry.plugins.where((p) => p.manifest.id == session?.pluginId).firstOrNull?.manifest.name ?? session?.pluginId ?? '';

    Widget row(ActionDescriptor a, {required bool isHidden, required int index}) => RasqListTile(
          key: ValueKey(a.id),
          title: a.label,
          subtitle: pluginName,
          leading: Icon(PostRow.iconFor(a.icon, Icons.circle_outlined), size: 22, color: isHidden ? scheme.onSurfaceVariant : scheme.onSurface),
          chevron: false,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            RasqIconButton(
              icon: isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              tooltip: isHidden ? '表示する' : '非表示にする',
              onPressed: () {
                final nextHidden = {...config.hidden};
                isHidden ? nextHidden.remove(a.id) : nextHidden.add(a.id);
                store.set(config.copyWith(hidden: nextHidden));
              },
            ),
            RasqIconButton(
              icon: Icons.more_horiz,
              size: 20,
              tooltip: 'アクションの詳細',
              onPressed: () => manager.showAlert(
                id: 'actionbar.detail',
                title: a.label,
                message: '提供: $pluginName\nid: ${a.id} / スロット: ${a.genreTag}\nconfirmMode: ${a.confirmMode.name} / 自動化: ${a.automation.name}',
                confirmText: 'OK',
              ),
            ),
            if (!isHidden) Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
          ]),
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorderItem: (from, to) {
          final ids = [for (final a in visible) a.id];
          final moved = ids.removeAt(from);
          ids.insert(to.clamp(0, ids.length), moved);
          store.set(config.copyWith(order: ids));
        },
        children: [for (final (i, a) in visible.indexed) row(a, isHidden: false, index: i)],
      ),
      if (hidden.isNotEmpty) ...[
        const RasqSectionHeader(title: '非表示'),
        for (final (i, a) in hidden.indexed) row(a, isHidden: true, index: i),
      ],
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.md),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: config.dirty ? store.reset : null, child: const Text('既定に戻す')),
        ]),
      ),
    ]);
  }
}
