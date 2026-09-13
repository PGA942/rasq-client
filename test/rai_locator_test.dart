import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_locator.dart';

/// 位置検索 (D-197): 同じ部品が複数ある(IndexedStack に隠れたタブなど)ときは見えているものを選ぶ。
void main() {
  testWidgets('IndexedStack の隠れた方ではなく、表示中の方の矩形を返す', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IndexedStack(index: 1, children: [
          Align(alignment: Alignment.topLeft, child: Tooltip(message: '投稿', child: SizedBox(width: 40, height: 40, child: Container(color: Colors.red)))),
          Align(alignment: Alignment.bottomRight, child: Tooltip(message: '投稿', child: SizedBox(width: 40, height: 40, child: Container(color: Colors.blue)))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    final r = locateWidgetRect(tooltip: '投稿')!;
    final visible = tester.getRect(find.byType(Container).last);
    expect(r, visible);
    expect(r.left, greaterThan(100)); // 右下の方
    expect(locateWidgetRect(tooltip: '無い'), isNull);
  });

  testWidgets('同じ部品が複数見えているとき (D-204): 全部の候補 / 近いもの / ランダム', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          for (var i = 0; i < 3; i++) Tooltip(message: 'リアクション', child: SizedBox(width: 40, height: 40, child: Container(color: Colors.red))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    final all = locateWidgetRects(tooltip: 'リアクション');
    expect(all.length, 3);
    // 近いもの: 3 つ目の少し下の矩形を渡すと 3 つ目。
    final near = locateWidgetRect(tooltip: 'リアクション', near: all[2].shift(const Offset(0, 8)));
    expect(near, all[2]);
    // ランダム: 全部の候補のどれか(固定シードで再現可能)。
    final r = locateWidgetRect(tooltip: 'リアクション', random: math.Random(7));
    expect(all, contains(r));
    // 指定なしは最初のもの。
    expect(locateWidgetRect(tooltip: 'リアクション'), all[0]);
  });
}
