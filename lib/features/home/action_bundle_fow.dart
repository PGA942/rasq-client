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

/// バンドル FOW の 1 行(アイコン + 名称。押下判定はタイル全体)。
class BundleMenuItem<T> {
  const BundleMenuItem({required this.value, required this.label, required this.icon, this.doneIcon, this.destructive = false});
  final T value;
  final String label;
  final IconData icon;
  final IconData? doneIcon;

  /// 取り消し / 削除など(赤で出す)。
  final bool destructive;
}

/// バンドル FOW の本体 (D-210 → D-277): アクションのバンドルも、リノート / リブロードの組み込みバンドル(する / 取り消す / 引用)も、
/// 同じ見た目で出す(ドロップダウンはやめた)。戻り = 選んだ行の値(閉じたら null)。同じ [id] が開いていれば閉じるだけ。
Future<T?> showBundleMenuFow<T>(
  OverlayManager manager, {
  required String id,
  required String title,
  required Rect anchor,
  required List<BundleMenuItem<T>> items,
  String Function(T value)? keyOf,
  int column = 0,
}) async {
  if (manager.contains(id)) {
    manager.close(id);
    return null;
  }
  // 高さ = ヘッダー + タイル数ぶんを全部出す(画面端まで。足りなければ中がスクロール、D-211)。
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final hostH = view == null ? 800.0 : view.physicalSize.height / view.devicePixelRatio;
  final need = actionBundleChromeHeight + items.length * actionBundleTileHeight + 8;
  final factor = (need / hostH).clamp(0.08, 0.92);
  final spec = FowSpec(
    title: title,
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
  return manager.showFow<T>(
    id: id,
    spec: spec,
    barrierBehavior: OverlayBarrierBehavior.dismiss,
    semanticsLabel: title,
    builder: (ctx, handle) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(padding: EdgeInsets.zero, children: [
        for (final item in items)
          InkWell(
            key: ValueKey('actionbar.bundle.pick.${keyOf?.call(item.value) ?? item.value}'),
            onTap: () => handle.close(result: item.value),
            child: SizedBox(
              height: actionBundleTileHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                child: Row(children: [
                  // 赤は「済み」の色の指定で出す(部品に色の口が無いので)。
                  RasqActionButton.icon(icon: item.icon, doneIcon: item.destructive ? item.icon : item.doneIcon, done: item.destructive, doneColor: scheme.error, tooltip: item.label, onTap: () => handle.close(result: item.value)),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text(item.label, style: RasqTypography.body.copyWith(color: item.destructive ? scheme.error : scheme.onSurface))),
                ]),
              ),
            ),
          ),
      ]);
    },
  );
}

Future<void> showActionBundleMenuFow(
  WidgetRef ref, {
  required Rect anchor,
  required ActionListEntry entry,
  required Future<void> Function(ActionDescriptor action) onPick,
  int column = 0,
}) async {
  final picked = await showBundleMenuFow<ActionDescriptor>(
    ref.read(overlayManagerProvider),
    id: actionBundleMenuFowId(entry.list.id),
    title: entry.list.name,
    anchor: anchor,
    column: column,
    keyOf: (a) => a.id,
    items: [for (final a in entry.members) BundleMenuItem(value: a, label: a.label, icon: PostRow.iconFor(a.icon, Icons.circle_outlined), doneIcon: a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, Icons.circle))],
  );
  if (picked != null) await onPick(picked);
}
