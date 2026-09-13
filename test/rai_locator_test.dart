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
}
