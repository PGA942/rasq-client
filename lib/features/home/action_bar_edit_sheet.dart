import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'action_bar_config.dart';
import 'plugin_actions.dart';
import 'post_row.dart';

/// 「アクションバーの編集」シート (D-208、ワイヤーフレーム p.7「アクションバー編集画面(投稿)」)。
/// Android のホーム画面の編集のように、**少し大きいアクションアイコン**を並べ、左上の (…) をクリック
/// (アイコン本体の shift + クリック / 右クリックでも)するとドロップダウン(詳細 / アクションリスト化 / 削除)。
/// **押したまま動かす**と: 隙間に落として並び替え、別のアイコンの上で離すと新規バンドル FOW、バンドルの上で
/// 離すとそのバンドルに入れて編集 FOW。表示 / 非表示は廃止(D-208)。
/// 「プラグインボタン(このアカウント)」節 = スロット設定(有効 / 無効、閾値)、「プラグインボタンを検索」FOW で
/// 登録済みプラグインの宣言から足す。即時反映+永続化(保存ボタン無し)。
const actionBarPluginSearchFowId = 'actionbar.plugins';
const actionBarPluginSearchKey = Key('actionbar.plugins.search');

Future<void> showActionBarEditSheet(WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showBottomSheet(id: 'actionbar.edit', title: 'アクションバーの編集', builder: (_) => const _ActionBarEditBody());
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

class _ActionBarEditBody extends ConsumerStatefulWidget {
  const _ActionBarEditBody();
  @override
  ConsumerState<_ActionBarEditBody> createState() => _ActionBarEditBodyState();
}

/// タイルの大きさ (D-208: 少し大型化)。
const actionBarTileSize = 56.0;

class _ActionBarEditBodyState extends ConsumerState<_ActionBarEditBody> {
  /// ドラッグ中のキー(隙間を広げて落としやすくする)。
  String? _dragging;

  static String keyOf(ActionBarEntry e) => switch (e) {
        SingleActionEntry() => e.action.id,
        ActionListEntry() => ActionBarConfig.listKey(e.list.id),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(currentSnsSessionProvider);
    final account = ref.watch(currentAccountProvider);
    final me = ref.watch(currentUserProvider);
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
    final pluginName = registry.plugins.where((p) => p.manifest.id == session?.pluginId).firstOrNull?.manifest.name ?? session?.pluginId ?? '';
    String providerOf(ActionDescriptor a) => isPluginActionId(a.id) ? (plugins.where((p) => p.id == a.id).firstOrNull?.plugin.manifest.name ?? 'プラグイン') : pluginName;
    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});

    /// 自動バンドルは並べ替え / 編集で固定リストに昇格する(order に残せるように)。
    List<ActionListDef> listsWithAuto() {
      final lists = [...config.lists];
      for (final e in entries) {
        if (e is ActionListEntry && !lists.any((l) => l.id == e.list.id)) lists.add(e.list);
      }
      return lists;
    }

    List<String> orderOf() => [for (final e in entries) keyOf(e)];

    void reorder(String key, int gap) {
      final ids = orderOf();
      final from = ids.indexOf(key);
      if (from < 0) return;
      ids.removeAt(from);
      final to = (gap > from ? gap - 1 : gap).clamp(0, ids.length);
      ids.insert(to, key);
      store.set(config.copyWith(order: ids, lists: listsWithAuto()));
    }

    /// 新規バンドル FOW (D-208): 名前 + 初期メンバー → 先頭メンバーの位置にバンドルを置く。
    Future<void> newBundle(List<String> memberIds) async {
      final name = TextEditingController(text: 'マイリスト');
      final ok = await manager.showBottomSheet<bool>(
        id: 'actionbar.bundle.new',
        title: '新規バンドル',
        confirmText: '作成',
        onConfirm: () => manager.close('actionbar.bundle.new', result: true),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqInput(key: const ValueKey('actionbar.bundle.name'), controller: name, hintText: 'バンドル名'),
            const SizedBox(height: RasqSpacing.sm),
            Wrap(spacing: RasqSpacing.xs, children: [
              for (final id in memberIds)
                Chip(avatar: Icon(PostRow.iconFor(actions.where((a) => a.id == id).firstOrNull?.icon, Icons.circle_outlined), size: 16), label: Text(actions.where((a) => a.id == id).firstOrNull?.label ?? id, style: RasqTypography.caption)),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            Text('作成後もアイコンをバンドルの上に落として足せます', style: RasqTypography.caption.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
      final title = name.text.trim();
      name.dispose();
      if (ok != true || title.isEmpty || memberIds.isEmpty) return;
      final def = ActionListDef(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: title, memberIds: memberIds);
      final order = orderOf();
      final first = order.indexWhere(memberIds.contains);
      final key = ActionBarConfig.listKey(def.id);
      order.removeWhere(memberIds.contains);
      order.insert(first < 0 ? order.length : first.clamp(0, order.length), key);
      store.set(config.copyWith(lists: [...listsWithAuto(), def], order: order));
    }

    /// バンドルに入れる(自動バンドルは固定に昇格)→ 編集 FOW。
    Future<void> addToBundle(ActionListDef list, String memberId) async {
      final lists = listsWithAuto();
      final i = lists.indexWhere((l) => l.id == list.id);
      if (i < 0 || list.memberIds.contains(memberId)) return;
      lists[i] = ActionListDef(id: list.id, name: list.name, memberIds: [...list.memberIds, memberId]);
      final order = orderOf()..remove(memberId);
      store.set(config.copyWith(lists: lists, order: order));
      await showActionBundleFow(ref, accountKey: accountKey, listId: list.id);
    }

    Future<void> menuFor(BuildContext ctx, ActionBarEntry e) async {
      final box = ctx.findRenderObject() as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      switch (e) {
        case SingleActionEntry():
          final a = e.action;
          final isPlugin = isPluginActionId(a.id);
          final pick = await manager.showDropdown<String>(
            id: 'actionbar.action.menu',
            anchor: rect,
            dense: true,
            items: [
              const RasqDropdownItem('アクションの詳細', 'detail'),
              const RasqDropdownItem('アクションリスト化', 'bundle'),
              if (isPlugin) const RasqDropdownItem('削除', 'delete', destructive: true),
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
            case 'bundle':
              await newBundle([a.id]);
            case 'delete':
              // プラグインボタンだけ外せる(スロット設定で無効に)。SNS のボタンは非表示にしない (D-208)。
              await setEnabled(a.id, false);
          }
        case ActionListEntry():
          final auto = e.list.id.startsWith('auto:');
          final pick = await manager.showDropdown<String>(
            id: 'actionbar.list.menu',
            anchor: rect,
            dense: true,
            items: [
              const RasqDropdownItem('アクションリストの詳細', 'detail'),
              const RasqDropdownItem('アクションリストを編集', 'edit'),
              if (auto) const RasqDropdownItem('固定リストにする', 'pin'),
              const RasqDropdownItem('削除', 'delete', destructive: true),
            ],
          );
          switch (pick) {
            case 'detail':
              await manager.showAlert(id: 'actionbar.list.detail', title: e.list.name, message: '${auto ? '自動バンドル' : 'アクションリスト'}: ${e.members.map((a) => a.label).join(' / ')}', confirmText: 'OK');
            case 'edit':
              if (auto) store.set(config.copyWith(lists: listsWithAuto()));
              await showActionBundleFow(ref, accountKey: accountKey, listId: e.list.id);
            case 'pin':
              store.set(config.copyWith(lists: listsWithAuto()));
            case 'delete':
              // 解除: 中身はバンドルの位置に戻る(非表示にはしない)。
              final order = orderOf();
              final at = order.indexOf(keyOf(e));
              order.remove(keyOf(e));
              order.insertAll(at < 0 ? order.length : at, e.list.memberIds);
              store.set(config.copyWith(order: order, lists: [for (final l in listsWithAuto()) if (l.id != e.list.id) l]));
          }
      }
    }

    Widget tile(ActionBarEntry e) {
      final key = keyOf(e);
      final (IconData icon, String label) = switch (e) {
        SingleActionEntry() => (PostRow.iconFor(e.action.icon, Icons.circle_outlined), e.action.label),
        ActionListEntry() => (Icons.apps, e.list.name),
      };
      final face = Container(
        width: actionBarTileSize,
        height: actionBarTileSize,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: scheme.onSurface),
      );
      return DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != key,
        onAcceptWithDetails: (d) async {
          final dragged = d.data;
          if (dragged.startsWith('list:')) return; // バンドル同士は重ねない
          switch (e) {
            case ActionListEntry():
              await addToBundle(e.list, dragged);
            case SingleActionEntry():
              await newBundle([e.action.id, dragged]);
          }
        },
        builder: (ctx, candidates, _) {
          final hot = candidates.isNotEmpty;
          return LongPressDraggable<String>(
            key: ValueKey('actionbar.tile.$key'),
            data: key,
            delay: const Duration(milliseconds: 200),
            onDragStarted: () => setState(() => _dragging = key),
            onDragEnd: (_) => setState(() => _dragging = null),
            feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: face)),
            childWhenDragging: Opacity(opacity: 0.3, child: face),
            child: Semantics(
              label: label,
              child: GestureDetector(
                // shift + クリック / 右クリックでもメニュー (D-208)。
                onTap: () {
                  if (HardwareKeyboard.instance.isShiftPressed) menuFor(ctx, e);
                },
                onSecondaryTapUp: (_) => menuFor(ctx, e),
                child: Tooltip(
                  message: label,
                  child: SizedBox(
                    width: actionBarTileSize + 12,
                    height: actionBarTileSize + 12,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned(left: 8, top: 8, child: AnimatedScale(duration: const Duration(milliseconds: 120), scale: hot ? 1.12 : 1, child: face)),
                      // 左上の (…) (D-208)。
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Builder(
                          builder: (bctx) => Material(
                            color: scheme.surface,
                            shape: const CircleBorder(),
                            elevation: 1,
                            child: InkWell(
                              key: ValueKey('actionbar.tile.menu.$key'),
                              customBorder: const CircleBorder(),
                              onTap: () => menuFor(bctx, e),
                              child: SizedBox(width: 22, height: 22, child: Icon(Icons.more_horiz, size: 16, color: scheme.onSurface)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    /// 隙間 (D-208): ここに落とすと並び替え。ドラッグ中は広がる。
    Widget gap(int i) => DragTarget<String>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) => reorder(d.data, i),
          builder: (_, candidates, _) => AnimatedContainer(
            key: ValueKey('actionbar.gap.$i'),
            duration: const Duration(milliseconds: 120),
            width: _dragging == null ? 6 : (candidates.isNotEmpty ? 28 : 18),
            height: actionBarTileSize + 12,
            alignment: Alignment.center,
            child: candidates.isNotEmpty ? Container(width: 3, height: actionBarTileSize, decoration: BoxDecoration(color: RasqColors.accent, borderRadius: BorderRadius.circular(2))) : null,
          ),
        );

    final bar = Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: RasqSpacing.xs, children: [
      // (+): プラグインボタンを検索して足す。
      Padding(
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: RasqIconButton(
          key: const ValueKey('actionbar.plugins.open'),
          icon: Icons.add_circle_outline,
          size: 28,
          tooltip: 'プラグインボタンを検索',
          onPressed: () async {
            final pick = await showPluginActionSearchFow(ref, ownerId: 'actionbar.edit');
            if (pick == null) return;
            await setEnabled(pick.id, true);
          },
        ),
      ),
      for (var i = 0; i < entries.length; i++) ...[gap(i), tile(entries[i])],
      gap(entries.length),
    ]);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 投稿の見出し(ワイヤーフレーム p.7): 自分のアイコン / 名前 / @ハンドル + ブックマーク / …。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: Row(children: [
              RasqAvatar(imageUrl: me.avatarUrl, fallbackLabel: me.displayName, size: 40),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me.displayName, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Flexible(child: Text('@${me.account.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    RasqSnsPill(account: me.account),
                  ]),
                ]),
              ),
              Icon(Icons.bookmark_border, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: RasqSpacing.sm),
              Icon(Icons.more_horiz, size: 20, color: scheme.onSurfaceVariant),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: bar),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: Text('(…) / shift + クリック / 右クリックでメニュー。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
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
            child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: config.dirty ? store.reset : null, child: const Text('既定に戻す'))),
          ),
        ],
      ),
    );
  }
}

/// バンドルの編集 FOW (D-208): 名前、メンバーの並び替え / 外す、解除。従来の編集画面の形。
Future<void> showActionBundleFow(WidgetRef ref, {required String accountKey, required String listId}) async {
  final manager = ref.read(overlayManagerProvider);
  final store = ref.read(actionBarConfigProvider(accountKey).notifier);
  final initial = ref.read(actionBarConfigProvider(accountKey)).lists.where((l) => l.id == listId).firstOrNull;
  if (initial == null) return;
  final name = TextEditingController(text: initial.name);
  try {
    await manager.showBottomSheet<void>(
      id: 'actionbar.bundle',
      title: 'バンドルを編集',
      cancelText: '閉じる',
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final scheme = Theme.of(ctx).colorScheme;
          final config = ref.watch(actionBarConfigProvider(accountKey));
          final list = config.lists.where((l) => l.id == listId).firstOrNull;
          if (list == null) return const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: Text('解除しました'));
          final session = ref.watch(currentSnsSessionProvider);
          final plugins = ref.watch(pluginActionsProvider);
          final settings = ref.watch(slotActionSettingsProvider(accountKey));
          final merged = mergePluginActions(config: config, snsActions: session?.actions ?? const [], plugins: plugins, settings: settings);
          final byId = {for (final a in merged.actions) a.id: a};
          void update(ActionListDef next) => store.set(config.copyWith(lists: [for (final l in config.lists) l.id == listId ? next : l]));
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: RasqInput(key: const ValueKey('actionbar.bundle.edit.name'), controller: name, hintText: 'バンドル名', onChanged: (v) => update(ActionListDef(id: list.id, name: v.trim().isEmpty ? list.name : v.trim(), memberIds: list.memberIds))),
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorderItem: (from, to) {
                final ids = [...list.memberIds];
                final moved = ids.removeAt(from);
                ids.insert((to > from ? to - 1 : to).clamp(0, ids.length), moved);
                update(ActionListDef(id: list.id, name: list.name, memberIds: ids));
              },
              children: [
                for (final id in list.memberIds)
                  RasqListTile(
                    key: ValueKey('actionbar.bundle.member.$id'),
                    leading: Icon(PostRow.iconFor(byId[id]?.icon, Icons.circle_outlined), size: 22, color: scheme.onSurface),
                    title: byId[id]?.label ?? id,
                    chevron: false,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      RasqIconButton(
                        icon: Icons.remove_circle_outline,
                        size: 20,
                        tooltip: 'バンドルから外す',
                        onPressed: () {
                          final ids = [...list.memberIds]..remove(id);
                          // 外したものはバンドルの後ろに戻す。
                          final order = [...config.order];
                          final at = order.indexOf(ActionBarConfig.listKey(list.id));
                          order.insert(at < 0 ? order.length : at + 1, id);
                          store.set(config.copyWith(order: order, lists: [for (final l in config.lists) l.id == listId ? ActionListDef(id: l.id, name: l.name, memberIds: ids) : l]));
                        },
                      ),
                      Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
                    ]),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('actionbar.bundle.dissolve'),
                  onPressed: () {
                    final order = [...config.order];
                    final at = order.indexOf(ActionBarConfig.listKey(list.id));
                    order.remove(ActionBarConfig.listKey(list.id));
                    order.insertAll(at < 0 ? order.length : at, list.memberIds);
                    store.set(config.copyWith(order: order, lists: [for (final l in config.lists) if (l.id != listId) l]));
                    manager.close('actionbar.bundle');
                  },
                  child: const Text('バンドルを解除'),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  } finally {
    name.dispose();
  }
}
