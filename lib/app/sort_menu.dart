import 'dart:ui';

import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// `∨` sort/filter dropdown (リアクション数 昇順/降順 / デフォルト).
Future<RasqSortOrder?> showSortMenu(OverlayManager manager, Rect anchor, RasqSortOrder current, {String id = 'sort'}) => manager.showDropdown<RasqSortOrder>(
      id: 'sort.$id',
      anchor: anchor,
      dense: true,
      items: [
        for (final o in [RasqSortOrder.reactionsAsc, RasqSortOrder.reactionsDesc, RasqSortOrder.defaultOrder]) RasqDropdownItem(o.label, o, checked: o == current),
      ],
    );

/// Applies [order] to posts (client-side; default keeps plugin order).
List<T> sortByReactions<T>(List<T> items, RasqSortOrder order, int Function(T) reactions) {
  if (order == RasqSortOrder.defaultOrder) return items;
  final copy = [...items];
  copy.sort((a, b) => order == RasqSortOrder.reactionsDesc ? reactions(b).compareTo(reactions(a)) : reactions(a).compareTo(reactions(b)));
  return copy;
}
