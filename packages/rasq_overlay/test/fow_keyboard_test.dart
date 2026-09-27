import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-351: アンカー FOW(アクションボタンから出る FOW)の入力欄は、大きいキーボードで下付き → 上付きに入れ替わっても消えない
/// (以前はハンドルの位置が変わると本体ごと作り直され、フォーカスが外れてキーボードが一瞬で閉じていた)。
void main() {
  testWidgets('キーボードで付け方が入れ替わっても、入力欄の State とフォーカスが残る', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400); // 800x1200 論理(iPad の縦くらい)
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    // 画面の中ほどより下のボタン(投稿のリアクションボタンくらい)から、下付きで出る。
    m.showFow<void>(
      id: 'emoji',
      spec: FowSpec(title: '絵文字', cancelText: '閉じる', anchor: const Rect.fromLTWH(300, 620, 40, 40), initialHeightFactor: 0.35, minHeightFactor: 0.2),
      builder: (context, handle) => Padding(padding: const EdgeInsets.all(8), child: TextField(key: const ValueKey('emoji.search'), focusNode: focus, controller: controller)),
    );
    await tester.pumpWidget(MaterialApp(
      home: OverlayScope(manager: m, child: OverlayHost(manager: m, child: const Scaffold(body: SizedBox.expand()))),
    ));
    await tester.pumpAndSettle();
    final panelTop = tester.getTopLeft(find.text('絵文字')).dy;
    expect(panelTop, greaterThan(620)); // 下付き

    await tester.tap(find.byKey(const ValueKey('emoji.search')));
    await tester.enterText(find.byKey(const ValueKey('emoji.search')), 'ねこ');
    await tester.pump();
    final state = tester.state(find.byKey(const ValueKey('emoji.search')));
    expect(focus.hasFocus, isTrue);

    // 大きいキーボード(画面の半分)→ ボタンの下の空きが足りなくなり、上付きに入れ替わる。
    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('絵文字')).dy, lessThan(620)); // 上付き
    expect(identical(tester.state(find.byKey(const ValueKey('emoji.search'))), state), isTrue);
    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'ねこ');
  });
}
