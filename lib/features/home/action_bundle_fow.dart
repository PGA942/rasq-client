import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'action_bar_config.dart';
import 'post_row.dart';

/// バンドルのボタンを押したときの FOW (D-210 → D-513): **ボタンにつながったパネル**([TetheredPanel])で出す。
/// 見出しはバンドル名(長押しで指を滑らせている間は、指の下の操作の名前)、下にアクションのアイコン + 名称の行(押下判定は行全体)。
const actionBundleMenuWidth = 280.0;

/// 行の高さ(小さめ、D-211)。
const actionBundleTileHeight = 40.0;

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

/// バンドル FOW の本体 (D-210 → D-277 → D-512 / D-513): アクションのバンドルも、リノート / リブロードの組み込みバンドル(する / 取り消す / 引用)も、
/// 同じ見た目で出す。戻り = 選んだ行の値(閉じたら null)。同じ [id] が開いていれば閉じるだけ。
///
/// - ボタンにつながったパネル (D-513)。[anchorChild] = 首の中に描く元のボタンのアイコン(パネルがボタンを覆うので)。
/// - [holding] = ボタンの**長押し**で開いた (D-512): 指を離さずに滑らせて行を選び、離すとそれを実行する([HoldSlidePicker])。
///   滑らせずに離せば開いたまま(タップで選べる)。タップで開いたとき(false)はふつうのメニュー。
Future<T?> showBundleMenuFow<T>(
  OverlayManager manager, {
  required String id,
  required String title,
  required Rect anchor,
  required List<BundleMenuItem<T>> items,
  String Function(T value)? keyOf,
  int column = 0,
  bool holding = false,
  Widget? anchorChild,
  TetherSide preferredSide = TetherSide.below,
  double iconExtent = kTetherIconExtent,
}) {
  return manager.showHoldSlidePicker<T>(
    id: id,
    anchor: anchor,
    title: title,
    holding: holding,
    column: column,
    width: actionBundleMenuWidth,
    preferredSide: preferredSide,
    iconExtent: iconExtent,
    anchorChild: anchorChild,
    rowExtent: actionBundleTileHeight,
    items: [
      for (final item in items)
        HoldSlideItem<T>(
          key: ValueKey('actionbar.bundle.pick.${keyOf?.call(item.value) ?? item.value}'),
          value: item.value,
          label: item.label,
          builder: (ctx, on) {
            final scheme = Theme.of(ctx).colorScheme;
            final color = item.destructive ? scheme.error : (on ? scheme.primary : scheme.onSurface);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
              child: Row(children: [
                RasqSkinIcon(on && item.doneIcon != null ? item.doneIcon! : item.icon, size: 20, color: color),
                const SizedBox(width: RasqSpacing.md),
                Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.body.copyWith(color: item.destructive ? scheme.error : scheme.onSurface, fontWeight: on ? FontWeight.w700 : null))),
              ]),
            );
          },
        ),
    ],
  );
}

/// アクションのバンドルのボタン(タップ / 長押し、D-210 / D-512)。
Future<void> showActionBundleMenuFow(
  WidgetRef ref, {
  required Rect anchor,
  required ActionListEntry entry,
  required Future<void> Function(ActionDescriptor action) onPick,
  int column = 0,
  bool holding = false,
}) async {
  final picked = await showBundleMenuFow<ActionDescriptor>(
    ref.read(overlayManagerProvider),
    id: actionBundleMenuFowId(entry.list.id),
    title: entry.list.name,
    anchor: anchor,
    column: column,
    holding: holding,
    anchorChild: bundleIconWidget(entry.list, entry.members, size: 20),
    keyOf: (a) => a.id,
    items: [for (final a in entry.members) BundleMenuItem(value: a, label: a.label, icon: PostRow.iconFor(a.icon, Icons.circle_outlined), doneIcon: a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, Icons.circle))],
  );
  if (picked != null) await onPick(picked);
}
