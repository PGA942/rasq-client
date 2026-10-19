import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-397: 畳まれた stick FOW がカラムの下端にある間は、そのカラムの中身を FOW の高さだけ縮める(重ねない)。
void main() {
  // 1000x800 論理。カラム 2 つ(0〜400 / 400〜1000)。
  const slots = [FowColumnSlot(x: 0, width: 400), FowColumnSlot(x: 400, width: 600)];
  Widget host(OverlayManager m) => MaterialApp(
        home: OverlayScope(
          manager: m,
          child: OverlayHost(
            manager: m,
            fowColumns: (_) => slots,
            child: Scaffold(
              body: Row(children: [
                SizedBox(width: 400, child: FowStickPadding(manager: m, child: const SizedBox.expand(key: ValueKey('col0')))),
                Expanded(child: FowStickPadding(manager: m, column: 1, child: const SizedBox.expand(key: ValueKey('col1')))),
              ]),
            ),
          ),
        ),
      );
  double heightOf(WidgetTester t, String key) => t.getSize(find.byKey(ValueKey(key))).height;

  testWidgets('stick のあいだはそのカラムだけ縮み、展開 / 閉じると元に戻る', (tester) async {
    tester.view.physicalSize = const Size(2000, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final spec = FowSpec(stickCollapse: true, initialHeightFactor: 0.15, minHeightFactor: 0.1, heightStops: const [0.15, 0.6], columnIndex: 1);
    await tester.pumpWidget(host(m));
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'col0'), 800);
    expect(heightOf(tester, 'col1'), 800);

    m.showFow<void>(id: 's', spec: spec, builder: (context, handle) => const SizedBox());
    await tester.pumpAndSettle();
    expect(spec.isStick, isTrue);
    // FOW の高さ = 0.15 × 800 = 120。右のカラムの中身は残りの 680 に並ぶ。左は FOW が無いのでそのまま。
    expect(m.fowStickReserve.value, {1: 120});
    expect(heightOf(tester, 'col1'), closeTo(680, 0.5));
    expect(heightOf(tester, 'col0'), 800);
    // 中身の下端が FOW の上端にそろう。
    final panel = find.byWidgetPredicate(isFrontmostFowPanel);
    expect(tester.getBottomLeft(find.byKey(const ValueKey('col1'))).dy, closeTo(tester.getTopLeft(panel).dy, 0.5));

    // 展開モード(stick でない)では縮めない(これまでどおり上に重なる)。
    spec.expandStick();
    await tester.pumpAndSettle();
    expect(spec.isStick, isFalse);
    expect(heightOf(tester, 'col1'), 800);

    // また畳むと縮み、閉じると戻る。
    spec.heightFactor.value = 0.15;
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'col1'), closeTo(680, 0.5));
    m.close('s');
    await tester.pumpAndSettle();
    expect(m.fowStickReserve.value, isEmpty);
    expect(heightOf(tester, 'col1'), 800);
  });

  testWidgets('stick にならない FOW / 壁付けの FOW では縮めない', (tester) async {
    tester.view.physicalSize = const Size(2000, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'plain', spec: FowSpec(initialHeightFactor: 0.3), builder: (context, handle) => const SizedBox());
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'col0'), 800);
    final pinned = FowSpec(stickCollapse: true, initialHeightFactor: 0.15, minHeightFactor: 0.1, heightStops: const [0.15, 0.6])..pinnedWall = -1;
    m.showFow<void>(id: 'pinned', spec: pinned, builder: (context, handle) => const SizedBox());
    await tester.pumpAndSettle();
    expect(m.fowStickReserve.value, isEmpty);
    expect(heightOf(tester, 'col0'), 800);
  });
}
