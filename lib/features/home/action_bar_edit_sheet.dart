import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'action_bar_config.dart';
import 'plugin_actions.dart';
import 'post_row.dart';

/// 「アクションリストの編集」シート (2026-08-25 ワイヤー、D-176 で拡張)。
/// 行 = アイコン + 名前 + 提供プラグイン名。ドラッグで並び替え、目のトグルで
/// 表示/非表示、`…` はドロップダウン(詳細 / 置き換え / 削除)。「リストを作成」で複数アクションを
/// 1 ボタンに束ねる。「プラグインボタン(このアカウント)」節 = スロット設定(有効 / 無効、閾値)、
/// 「プラグインボタンを検索」FOW で登録済みプラグインの宣言から足す。即時反映+永続化(保存ボタン無し)。
const actionBarPluginSearchFowId = 'actionbar.plugins';
const actionBarPluginSearchKey = Key('actionbar.plugins.search');

Future<void> showActionBarEditSheet(WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showBottomSheet(id: 'actionbar.edit', title: 'アクションリストの編集', builder: (_) => const _ActionBarEditBody());
}

/// プラグインボタンを検索する FOW (D-176): 登録済みプラグインの `post.action` 宣言から選ぶ。
/// 戻りは選んだ [PluginAction](キャンセルは null)。
Future<PluginAction?> showPluginActionSearchFow(WidgetRef ref, {String title = 'プラグインボタンを検索', String? ownerId}) async {
  final manager = ref.read(overlayManagerProvider);
  final all = ref.read(pluginActionsProvider);
  final query = TextEditingController();
  try {
    // 編集シート(ボトムシート層)の上に出す必要があるので、同じ層に積む(FOW 層はシートの下)。
    return await manager.showBottomSheet<PluginAction>(
      id: actionBarPluginSearchFowId,
      ownerId: ownerId,
      title: title,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final q = query.text.trim().toLowerCase();
          final hits = [
            for (final a in all)
              if (q.isEmpty || a.decl.label.toLowerCase().contains(q) || a.plugin.manifest.name.toLowerCase().contains(q) || a.decl.tags.any((t) => t.toLowerCase().contains(q))) a,
          ];
          final scheme = Theme.of(ctx).colorScheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
                child: RasqInput(key: actionBarPluginSearchKey, controller: query, hintText: 'ボタン名 / プラグイン名 / タグ', onChanged: (_) => setLocal(() {})),
              ),
              if (hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(RasqSpacing.page),
                  child: Text(all.isEmpty ? 'post.action を宣言したプラグインがありません(ストアから追加)' : '見つかりません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                )
              else
                for (final a in hits)
                  RasqListTile(
                    key: ValueKey('actionbar.plugin.${a.id}'),
                    leading: Icon(PostRow.iconFor(a.decl.icon, Icons.extension_outlined), size: 22, color: scheme.onSurface),
                    title: a.decl.label,
                    subtitle: '${a.plugin.manifest.name} · タグ: ${a.decl.tags.join(' / ')}',
                    onTap: () => manager.close(actionBarPluginSearchFowId, result: a),
                  ),
            ],
          );
        },
      ),
    );
  } finally {
    query.dispose();
  }
}

class _ActionBarEditBody extends ConsumerWidget {
  const _ActionBarEditBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(currentSnsSessionProvider);
    final account = ref.watch(currentAccountProvider);
    final registry = ref.watch(pluginRegistryProvider);
    final accountKey = account?.key ?? '';
    // アカウントごとの構成 (D-200)。
    final config = ref.watch(actionBarConfigProvider(accountKey));
    final store = ref.read(actionBarConfigProvider(accountKey).notifier);
    final manager = ref.read(overlayManagerProvider);
    final snsActions = session?.actions ?? const <ActionDescriptor>[];
    final plugins = ref.watch(pluginActionsProvider);
    final settings = ref.watch(slotActionSettingsProvider(accountKey));
    final settingsStore = ref.read(settingsAreaProvider(slotSettingsArea(accountKey)).notifier);
    // 表示中のバーと同じ合成(プラグインボタン込み)。
    final merged = mergePluginActions(config: config, snsActions: snsActions, plugins: plugins, settings: settings);
    final actions = merged.actions;
    final entries = merged.config.apply(actions);
    final hidden = [
      for (final a in actions)
        if (config.hidden.contains(a.id)) a,
    ];
    final pluginName = registry.plugins.where((p) => p.manifest.id == session?.pluginId).firstOrNull?.manifest.name ?? session?.pluginId ?? '';
    String providerOf(ActionDescriptor a) => isPluginActionId(a.id) ? (plugins.where((p) => p.id == a.id).firstOrNull?.plugin.manifest.name ?? 'プラグイン') : pluginName;

    String keyOf(ActionBarEntry e) => switch (e) {
      SingleActionEntry() => e.action.id,
      ActionListEntry() => ActionBarConfig.listKey(e.list.id),
    };

    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});

    /// 置き換え (D-176): 既存ボタンの位置にプラグインボタンを入れ、既存は非表示に。
    Future<void> replaceWith(ActionDescriptor a) async {
      final pick = await showPluginActionSearchFow(ref, title: '${a.label} を置き換える', ownerId: 'actionbar.edit');
      if (pick == null) return;
      await setEnabled(pick.id, true);
      final order = [for (final e in entries) keyOf(e)];
      final at = order.indexOf(a.id);
      order.remove(pick.id);
      if (at >= 0) {
        order[at] = pick.id;
      } else {
        order.add(pick.id);
      }
      store.set(config.copyWith(order: order, hidden: {...config.hidden, a.id}..remove(pick.id)));
    }

    Widget actionRow(ActionDescriptor a, {required bool isHidden}) => RasqListTile(
      key: ValueKey(isHidden ? 'hidden:${a.id}' : a.id),
      title: a.label,
      subtitle: providerOf(a),
      leading: Icon(PostRow.iconFor(a.icon, Icons.circle_outlined), size: 22, color: isHidden ? scheme.onSurfaceVariant : scheme.onSurface),
      chevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Builder(
            builder: (ctx) => RasqIconButton(
              icon: Icons.more_horiz,
              size: 20,
              tooltip: 'アクションの操作',
              onPressed: () async {
                final box = ctx.findRenderObject() as RenderBox;
                final pick = await manager.showDropdown<String>(
                  id: 'actionbar.action.menu',
                  anchor: box.localToGlobal(Offset.zero) & box.size,
                  dense: true,
                  items: [
                    const RasqDropdownItem('詳細', 'detail'),
                    if (!isHidden) const RasqDropdownItem('置き換え', 'replace'),
                    RasqDropdownItem(isHidden ? '表示する' : '削除(非表示)', isHidden ? 'show' : 'delete', destructive: !isHidden),
                  ],
                );
                switch (pick) {
                  case 'detail':
                    await manager.showAlert(
                      id: 'actionbar.detail',
                      title: a.label,
                      message: '提供: ${providerOf(a)}\nid: ${a.id} / スロット: ${a.genreTag}\nconfirmMode: ${a.confirmMode.name} / 自動化: ${a.automation.name}',
                      confirmText: 'OK',
                    );
                  case 'replace':
                    await replaceWith(a);
                  case 'delete':
                    store.set(config.copyWith(hidden: {...config.hidden, a.id}));
                  case 'show':
                    store.set(config.copyWith(hidden: {...config.hidden}..remove(a.id)));
                }
              },
            ),
          ),
          if (!isHidden) Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    Widget listRow(ActionListEntry e) => RasqListTile(
      key: ValueKey(ActionBarConfig.listKey(e.list.id)),
      title: e.list.name,
      subtitle: '${e.list.id.startsWith('auto:') ? '自動バンドル' : 'アクションリスト'}: ${e.members.map((a) => a.label).join(' / ')}',
      leading: Icon(Icons.apps, size: 22, color: scheme.onSurface),
      chevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (ctx) => RasqIconButton(
              icon: Icons.more_horiz,
              size: 20,
              tooltip: 'リストの操作',
              onPressed: () async {
                final box = ctx.findRenderObject() as RenderBox;
                final rect = box.localToGlobal(Offset.zero) & box.size;
                final auto = e.list.id.startsWith('auto:');
                final pick = await manager.showDropdown<String>(
                  id: 'actionbar.list.menu',
                  anchor: rect,
                  dense: true,
                  items: [
                    if (!auto) const RasqDropdownItem('リストを解除', 'dissolve'),
                    if (auto) const RasqDropdownItem('固定リストにする', 'pin'),
                    const RasqDropdownItem('リストを削除(中身も非表示)', 'delete', destructive: true),
                  ],
                );
                if (pick == 'dissolve') {
                  store.set(
                    config.copyWith(
                      lists: [
                        for (final l in config.lists)
                          if (l.id != e.list.id) l,
                      ],
                    ),
                  );
                } else if (pick == 'pin') {
                  // 自動バンドルをユーザーのリストとして保存(以後は並べ替え / 解除できる)。
                  final def = ActionListDef(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: e.list.name, memberIds: e.list.memberIds);
                  final order = [for (final x in entries) keyOf(x) == ActionBarConfig.listKey(e.list.id) ? ActionBarConfig.listKey(def.id) : keyOf(x)];
                  store.set(config.copyWith(lists: [...config.lists, def], order: order));
                } else if (pick == 'delete') {
                  store.set(
                    config.copyWith(
                      lists: [
                        for (final l in config.lists)
                          if (l.id != e.list.id) l,
                      ],
                      hidden: {...config.hidden, ...e.list.memberIds},
                    ),
                  );
                }
              },
            ),
          ),
          Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    // 節が増えた (D-176) ので縦にスクロール(シートの高さに収まらない端末向け)。
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            onReorderItem: (from, to) {
              final ids = [for (final e in entries) keyOf(e)];
              final moved = ids.removeAt(from);
              ids.insert(to.clamp(0, ids.length), moved);
              // 自動バンドルを並べ替えたら固定リストに昇格させる(order に残せるように)。
              final lists = [...config.lists];
              for (final e in entries) {
                if (e is ActionListEntry && e.list.id.startsWith('auto:') && !lists.any((l) => l.id == e.list.id)) lists.add(e.list);
              }
              store.set(config.copyWith(order: ids, lists: lists));
            },
            children: [
              for (final e in entries)
                switch (e) {
                  SingleActionEntry() => actionRow(e.action, isHidden: false),
                  ActionListEntry() => listRow(e),
                },
            ],
          ),
          if (hidden.isNotEmpty) ...[const RasqSectionHeader(title: '非表示'), for (final a in hidden) actionRow(a, isHidden: true)],
          // スロット設定 (D-176): このアカウントでのプラグインボタンの有効 / 無効と、束ねる閾値。
          RasqSectionHeader(title: 'プラグインボタン(${account == null ? 'このアカウント' : '$account'})'),
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
            child: Wrap(
              spacing: RasqSpacing.sm,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(onPressed: () => _createList(ref, manager, config, store, entries), icon: const Icon(Icons.create_new_folder_outlined, size: 18), label: const Text('リストを作成')),
                TextButton.icon(
                  key: const ValueKey('actionbar.plugins.open'),
                  onPressed: () async {
                    final pick = await showPluginActionSearchFow(ref, ownerId: 'actionbar.edit');
                    if (pick == null) return;
                    await setEnabled(pick.id, true);
                    store.set(config.copyWith(hidden: {...config.hidden}..remove(pick.id)));
                  },
                  icon: const Icon(Icons.extension_outlined, size: 18),
                  label: const Text('プラグインボタンを検索'),
                ),
                TextButton(onPressed: config.dirty ? store.reset : null, child: const Text('既定に戻す')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createList(WidgetRef ref, OverlayManager manager, ActionBarConfig config, ActionBarConfigStore store, List<ActionBarEntry> entries) async {
    final candidates = [
      for (final e in entries)
        if (e is SingleActionEntry) e.action,
    ];
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
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: RasqInput(controller: name, hintText: 'リスト名'),
            ),
            for (final a in candidates) RasqSwitchListTile(title: a.label, value: selected.contains(a.id), onChanged: (v) => setState(() => v ? selected.add(a.id) : selected.remove(a.id))),
          ],
        ),
      ),
    );
    if (selected.length < 2 || name.text.trim().isEmpty) return;
    final def = ActionListDef(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: name.text.trim(), memberIds: selected.toList());
    // 先頭メンバーの位置にリストを差し込む。
    final order = [
      for (final e in entries)
        switch (e) {
          SingleActionEntry() => e.action.id,
          ActionListEntry() => ActionBarConfig.listKey(e.list.id),
        },
    ];
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
