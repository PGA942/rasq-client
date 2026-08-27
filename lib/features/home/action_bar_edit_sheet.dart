import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'action_bar_config.dart';
import 'post_row.dart';

/// 「アクションリストの編集」シート (2026-08-25 ワイヤー)。
/// 行 = アイコン + 名前 + 提供プラグイン名。ドラッグで並び替え、目のトグルで
/// 表示/非表示、`…` で詳細/リスト解除。「リストを作成」で複数アクションを
/// 1 ボタンに束ねる。即時反映+永続化(保存ボタン無し)。
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
    final entries = config.apply(actions);
    final hidden = [for (final a in actions) if (config.hidden.contains(a.id)) a];
    final pluginName = registry.plugins.where((p) => p.manifest.id == session?.pluginId).firstOrNull?.manifest.name ?? session?.pluginId ?? '';

    String keyOf(ActionBarEntry e) => switch (e) {
          SingleActionEntry() => e.action.id,
          ActionListEntry() => ActionBarConfig.listKey(e.list.id),
        };

    Widget actionRow(ActionDescriptor a, {required bool isHidden}) => RasqListTile(
          key: ValueKey(isHidden ? 'hidden:${a.id}' : a.id),
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

    Widget listRow(ActionListEntry e) => RasqListTile(
          key: ValueKey(ActionBarConfig.listKey(e.list.id)),
          title: e.list.name,
          subtitle: 'アクションリスト: ${e.members.map((a) => a.label).join(' / ')}',
          leading: Icon(Icons.apps, size: 22, color: scheme.onSurface),
          chevron: false,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            RasqIconButton(
              icon: Icons.more_horiz,
              size: 20,
              tooltip: 'リストの操作',
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;
                final rect = box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
                final pick = await manager.showDropdown<String>(id: 'actionbar.list.menu', anchor: rect, dense: true, items: const [
                  RasqDropdownItem('リストを解除', 'dissolve'),
                  RasqDropdownItem('リストを削除(中身も非表示)', 'delete', destructive: true),
                ]);
                if (pick == 'dissolve') {
                  store.set(config.copyWith(lists: [for (final l in config.lists) if (l.id != e.list.id) l]));
                } else if (pick == 'delete') {
                  store.set(config.copyWith(
                    lists: [for (final l in config.lists) if (l.id != e.list.id) l],
                    hidden: {...config.hidden, ...e.list.memberIds},
                  ));
                }
              },
            ),
            Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
          ]),
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorderItem: (from, to) {
          final ids = [for (final e in entries) keyOf(e)];
          final moved = ids.removeAt(from);
          ids.insert(to.clamp(0, ids.length), moved);
          store.set(config.copyWith(order: ids));
        },
        children: [
          for (final e in entries)
            switch (e) {
              SingleActionEntry() => actionRow(e.action, isHidden: false),
              ActionListEntry() => listRow(e),
            },
        ],
      ),
      if (hidden.isNotEmpty) ...[
        const RasqSectionHeader(title: '非表示'),
        for (final a in hidden) actionRow(a, isHidden: true),
      ],
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.md),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton.icon(
            onPressed: () => _createList(ref, manager, config, store, entries),
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('リストを作成'),
          ),
          TextButton(onPressed: config.dirty ? store.reset : null, child: const Text('既定に戻す')),
        ]),
      ),
    ]);
  }

  Future<void> _createList(WidgetRef ref, OverlayManager manager, ActionBarConfig config, ActionBarConfigStore store, List<ActionBarEntry> entries) async {
    final candidates = [for (final e in entries) if (e is SingleActionEntry) e.action];
    if (candidates.length < 2) {
      await manager.showAlert(id: 'actionbar.list.short', title: 'リストを作成', message: '束ねられるアクションが 2 つ以上必要です。', confirmText: 'OK');
      return;
    }
    final name = TextEditingController(text: 'マイリスト');
    final selected = <String>{};
    await manager.showBottomSheet(
      id: 'actionbar.list.create',
      title: 'リストを作成',
      confirmText: '作成',
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInput(controller: name, hintText: 'リスト名')),
          for (final a in candidates)
            RasqSwitchListTile(
              title: a.label,
              value: selected.contains(a.id),
              onChanged: (v) => setState(() => v ? selected.add(a.id) : selected.remove(a.id)),
            ),
        ]),
      ),
    );
    if (selected.length < 2 || name.text.trim().isEmpty) return;
    final def = ActionListDef(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: name.text.trim(), memberIds: selected.toList());
    // 先頭メンバーの位置にリストを差し込む。
    final order = [for (final e in entries) switch (e) { SingleActionEntry() => e.action.id, ActionListEntry() => ActionBarConfig.listKey(e.list.id) }];
    final firstIndex = order.indexWhere(selected.contains);
    final key = ActionBarConfig.listKey(def.id);
    if (firstIndex >= 0) {
      order.insert(firstIndex, key);
    } else {
      order.add(key);
    }
    store.set(config.copyWith(lists: [...config.lists, def], order: order));
  }
}
