import 'package:flutter/material.dart';

/// 画面上の部品の位置検索 (D-179、`位置検索関数`)。
///
/// ツールチップ(アイコンボタン)/ 表示テキスト(ラベル付きボタン)/ Key で要素木を辿り、
/// 最初に見つかった描画済みの矩形(グローバル座標)を返す。RRL の `role` 付きノードは
/// ジオメトリ登録簿(D-072)側で引けるので、ここはネイティブ部品向け。
Rect? locateWidgetRect({String? tooltip, String? text, Key? key, Rect? within}) {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return null;
  Rect? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    final hit = (tooltip != null && w is Tooltip && w.message == tooltip) ||
        (text != null && w is Text && w.data == text) ||
        (key != null && w.key == key);
    if (hit) {
      final ro = e.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize && ro.size.width > 0) {
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        if (within == null || within.overlaps(r)) {
          found = r;
          return;
        }
      }
    }
    e.visitChildren(visit);
  }

  visit(root);
  return found;
}
