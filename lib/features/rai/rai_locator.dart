import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 画面上の部品の位置検索 (D-179、`位置検索関数`)。
///
/// ツールチップ(アイコンボタン)/ 表示テキスト(ラベル付きボタン)/ Key で要素木を辿り、
/// 最初に見つかった描画済みの矩形(グローバル座標)を返す。RRL の `role` 付きノードは
/// ジオメトリ登録簿(D-072)側で引けるので、ここはネイティブ部品向け。
Rect? locateWidgetRect({String? tooltip, String? text, Key? key, Rect? within, Rect? near, math.Random? random}) {
  final all = locateWidgetRects(tooltip: tooltip, text: text, key: key, within: within);
  if (all.isEmpty) return null;
  // 前回の矩形に最も近いもの (D-204: 追い直し / リサイズ後の再取得で別のコピーへ飛ばない)。
  if (near != null) {
    Rect best = all.first;
    var bestD = double.infinity;
    for (final r in all) {
      final d = (r.center - near.center).distance;
      if (d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return best;
  }
  // 同じ部品が複数見えている(TL の各投稿のボタンなど)ときは、表示されている中からランダムに (D-204)。
  if (random != null && all.length > 1) return all[random.nextInt(all.length)];
  return all.first;
}

/// 見えている候補を全部(グローバル矩形)。同じ部品が複数ある(タブの IndexedStack に隠れたページ、
/// 2 カラムの複製、TL の各投稿のボタン …)ときは、実際に見えている(ヒットテストで当たる)ものだけ (D-197)。
/// どれも当たらなければ最初のもの。
List<Rect> locateWidgetRects({String? tooltip, String? text, Key? key, Rect? within}) => [for (final c in _locate(tooltip: tooltip, text: text, key: key, within: within)) c.rect];

List<({Rect rect, Element element})> _locate({String? tooltip, String? text, Key? key, Rect? within}) {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return const [];
  final candidates = <({Rect rect, RenderBox box, Element element})>[];
  void visit(Element e) {
    final w = e.widget;
    // 見えない枝は探さない (D-201): Offstage / Visibility(false) / Opacity(0)。
    if ((w is Offstage && w.offstage) || (w is Visibility && !w.visible) || (w is Opacity && w.opacity <= 0.01)) return;
    final hit = (tooltip != null && w is Tooltip && w.message == tooltip) ||
        (text != null && w is Text && w.data == text) ||
        (key != null && w.key == key);
    if (hit) {
      final ro = e.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize && ro.size.width > 0) {
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        if (within == null || within.overlaps(r)) candidates.add((rect: r, box: ro, element: e));
      }
    }
    e.visitChildren(visit);
  }

  visit(root);
  if (candidates.isEmpty) return const [];
  final visible = [for (final c in candidates) if (_isHitTestable(c.box, c.rect.center)) (rect: c.rect, element: c.element)];
  return visible.isEmpty ? [(rect: candidates.first.rect, element: candidates.first.element)] : visible;
}

/// その矩形の中心へのヒットテストで、この RenderBox(かその子孫)まで届くか。
bool _isHitTestable(RenderBox box, Offset globalPoint) {
  try {
    final view = RendererBinding.instance.renderViews.firstOrNull;
    if (view == null) return true;
    final result = BoxHitTestResult();
    view.hitTest(result, position: globalPoint);
    for (final entry in result.path) {
      final t = entry.target;
      if (t == box) return true;
      if (t is RenderObject) {
        // 子孫が当たっていれば、この部品は見えている。
        RenderObject? p = t;
        while (p != null) {
          if (p == box) return true;
          p = p.parent;
        }
      }
    }
    return false;
  } catch (_) {
    return true;
  }
}
