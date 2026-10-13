import 'dart:ui';

import 'geometry.dart';
import 'model.dart';

/// 投げ輪 (D-473): 囲んだ輪(閉じた多角形)の中に、形の上の点([PaintItem.samples])の**半分以上**が入っているものを選ぶ。
/// 輪が小さすぎる(点が 3 つ未満 / 面積 4 未満 = タップ)なら何も選ばない。
Set<PaintItem> lassoSelect(List<PaintItem> items, List<Offset> polygon, {double threshold = 0.5}) {
  if (polygon.length < 3 || signedArea(polygon).abs() < 4) return {};
  final box = boundsOf(polygon);
  final out = <PaintItem>{};
  for (final item in items) {
    if (!box.overlaps(item.bounds)) continue;
    final s = item.samples;
    if (s.isEmpty) continue;
    var inside = 0;
    for (final p in s) {
      if (box.contains(p) && pointInPolygon(p, polygon)) inside++;
    }
    if (inside >= s.length * threshold) out.add(item);
  }
  return out;
}

/// 選んだものの外接矩形(線の太さ込み)。
Rect selectionBounds(Iterable<PaintItem> items) {
  Rect? r;
  for (final i in items) {
    r = r == null ? i.bounds : r.expandToInclude(i.bounds);
  }
  return r ?? Rect.zero;
}

/// 並びの中の選んだものを [m] で動かす(並びの順は保つ)。戻り = (新しい並び, 動かした後の選択)。
(List<PaintItem>, Set<PaintItem>) transformSelection(List<PaintItem> items, Set<PaintItem> sel, Affine m) {
  final next = <PaintItem>[];
  final picked = <PaintItem>{};
  for (final i in items) {
    if (sel.contains(i)) {
      final t = i.transformed(m);
      next.add(t);
      picked.add(t);
    } else {
      next.add(i);
    }
  }
  return (next, picked);
}

/// 選んだものの写しを、ずらして一番上に足す。戻り = (新しい並び, 写し)。
(List<PaintItem>, Set<PaintItem>) duplicateSelection(List<PaintItem> items, Set<PaintItem> sel, {Offset shift = const Offset(12, 12)}) {
  final m = Affine.translate(shift);
  final copies = [
    for (final i in items)
      if (sel.contains(i)) i.transformed(m),
  ];
  return ([...items, ...copies], copies.toSet());
}

/// 選んだものの色を変える。
(List<PaintItem>, Set<PaintItem>) recolorSelection(List<PaintItem> items, Set<PaintItem> sel, Color color) {
  final next = <PaintItem>[];
  final picked = <PaintItem>{};
  for (final i in items) {
    if (sel.contains(i)) {
      final t = i.recolored(color);
      next.add(t);
      picked.add(t);
    } else {
      next.add(i);
    }
  }
  return (next, picked);
}
