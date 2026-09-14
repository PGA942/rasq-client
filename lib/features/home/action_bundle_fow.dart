import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'action_bar_config.dart';
import 'post_row.dart';

/// バンドルのボタンを押したときの FOW (D-210): **アイコンから出現**する横幅の小さい(600px)FOW。
/// ヘッダーはバンドル名、下にアクションボタン + 名称のタイル(押下判定はタイル全体)。
const actionBundleMenuMaxWidth = 400.0;

/// タイルの高さ(小さめ、D-211)。
const actionBundleTileHeight = 40.0;

/// ヘッダー(ハンドル無し + タイトル行)ぶん。
const actionBundleChromeHeight = 40.0 + 12;

String actionBundleMenuFowId(String listId) => 'actionbar.bundle.menu.$listId';

Future<void> showActionBundleMenuFow(
  WidgetRef ref, {
  required Rect anchor,
  required ActionListEntry entry,
  required Future<void> Function(ActionDescriptor action) onPick,
  int column = 0,
}) async {
  final manager = ref.read(overlayManagerProvider);
  final id = actionBundleMenuFowId(entry.list.id);
  if (manager.contains(id)) {
    manager.close(id);
    return;
  }
  // 高さ = ヘッダー + タイル数ぶんを全部出す(画面端まで。足りなければ中がスクロール、D-211)。
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final hostH = view == null ? 800.0 : view.physicalSize.height / view.devicePixelRatio;
  final need = actionBundleChromeHeight + entry.members.length * actionBundleTileHeight + 8;
  final factor = (need / hostH).clamp(0.08, 0.92);
  final spec = FowSpec(
    title: entry.list.name,
    cancelText: '閉じる',
    maxWidth: actionBundleMenuMaxWidth,
    anchor: anchor,
    columnIndex: column,
    resizable: false,
    showHandle: false,
    initialHeightFactor: factor,
    minHeightFactor: 0.05,
    maxHeightFactor: 0.92,
  );
  await manager.showFow<void>(
    id: id,
    spec: spec,
    barrierBehavior: OverlayBarrierBehavior.dismiss,
    semanticsLabel: entry.list.name,
    builder: (ctx, _) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(padding: EdgeInsets.zero, children: [
        for (final a in entry.members)
          InkWell(
            key: ValueKey('actionbar.bundle.pick.${a.id}'),
            onTap: () async {
              manager.close(id);
              await onPick(a);
            },
            child: SizedBox(
              height: actionBundleTileHeight,
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Row(children: [
                RasqActionButton.icon(icon: PostRow.iconFor(a.icon, Icons.circle_outlined), doneIcon: a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, Icons.circle), tooltip: a.label, onTap: () async {
                  manager.close(id);
                  await onPick(a);
                }),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(child: Text(a.label, style: RasqTypography.body.copyWith(color: scheme.onSurface))),
              ]),
            ),
            ),
          ),
      ]);
    },
  );
}
