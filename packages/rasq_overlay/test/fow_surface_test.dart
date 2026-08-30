import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-065: FOW の付け先(ヘッダー下付き / アンカー / 壁付き)と
/// FOW スイッチャー(ハンドルクリック)。
Widget host(OverlayManager m, {List<FowColumnSlot> Function(BuildContext)? columns, double Function(BuildContext)? topInset}) => MaterialApp(
      home: OverlayScope(
        manager: m,
        child: OverlayHost(manager: m, fowColumns: columns, fowTopInset: topInset, child: const Scaffold(body: SizedBox.expand())),
      ),
    );

Finder fowPanel() => find.byWidgetPredicate((w) => w is Material && w.elevation == 8);

void main() {
  testWidgets('FOW スイッチャー: ハンドルクリック → リスト → 親選択で子が自動クローズ + 前面化', (tester) async {
    final m = OverlayManager();
    m.showFow<void>(id: 'parent', spec: FowSpec(title: '親パネル', cancelText: '閉じる'), builder: (context, handle) => const SizedBox());
    m.showFow<void>(id: 'child', ownerId: 'parent', spec: FowSpec(title: '子ピッカー', cancelText: '閉じる'), builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m));
    await tester.pumpAndSettle();

    // 重ね表示: 両方のパネルが載っている(縦積みで高さを分け合わない)。
    expect(find.text('親パネル'), findsOneWidget);
    expect(find.text('子ピッカー'), findsOneWidget);

    // ハンドルのクリック → ブラックアウト + リスト表示(パネルは Offstage)。
    await tester.tap(find.bySemanticsLabel('サイズ変更ハンドル').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(m.fowSwitcherOpen, isTrue);
    expect(find.bySemanticsLabel('FOW切り替え'), findsOneWidget);
    // プレビュー (D-066): 開く直前のキャプチャがカードに載る。
    expect(find.byType(RawImage), findsNWidgets(2));

    // 「親パネル」を選択 → 子(ownerId=parent)は自動で閉じ、親が前面へ。
    await tester.tap(find.text('親パネル'));
    await tester.pumpAndSettle();
    expect(m.fowSwitcherOpen, isFalse);
    expect(m.contains('child'), isFalse);
    expect(m.entries.last.id, 'parent');
  });

  testWidgets('付け先の切り替え: FOW 内ヘッダーを縦へ 1 割動かすとヘッダー下付き ⇄ 下側ドック', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final spec = FowSpec(title: 'パネル', cancelText: '閉じる', initialHeightFactor: 0.4);
    m.showFow<void>(id: 'p', spec: spec, builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m, topInset: (_) => 60));
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(fowPanel()).dy, closeTo(800, 1)); // 既定 = 下端

    // 上へ 100px(> 800 の 1 割)→ アプリヘッダー(60px)に下付き。
    await tester.drag(find.text('パネル'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(spec.attachTop, isTrue);
    expect(tester.getTopLeft(fowPanel()).dy, closeTo(60, 1));

    // 下へ 100px → 下側ドックへ戻る。
    await tester.drag(find.text('パネル'), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(spec.attachTop, isFalse);
    expect(tester.getBottomLeft(fowPanel()).dy, closeTo(800, 1));
  });

  testWidgets('アンカー FOW: 基本下付き → 縦ドラッグで上付き → 別カラムへ動かすと壁付き表示', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final spec = FowSpec(title: 'リアクション', cancelText: '閉じる', initialHeightFactor: 0.3)
      ..anchor = const Rect.fromLTWH(100, 300, 200, 40);
    m.showFow<void>(id: 'r', spec: spec, builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m, columns: (_) => const [FowColumnSlot(x: 0, width: 700), FowColumnSlot(x: 700, width: 500)]));
    await tester.pumpAndSettle();

    // 下付き: FOW の上辺 = ボタンの下辺(340)。幅は所属カラム(700)。
    expect(tester.getTopLeft(fowPanel()).dy, closeTo(340, 1));
    expect(tester.getTopLeft(fowPanel()).dx, closeTo(0, 1));
    expect(tester.getSize(fowPanel()).width, closeTo(700, 1));

    // 縦へ上に 100px → 上付き(FOW の下辺 = ボタンの上辺 300)。
    await tester.drag(find.text('リアクション'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(spec.anchorBelow, isFalse);
    expect(tester.getBottomLeft(fowPanel()).dy, closeTo(300, 1));

    // 横へ 1 割以上 = 別カラムへ → その時点で壁付き表示(anchor は解除)。
    await tester.drag(find.text('リアクション'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(spec.anchor, isNull);
    expect(spec.pinnedWall, 1);
    expect(tester.getTopLeft(fowPanel()).dx, closeTo(1200 - 320, 1));
    expect(tester.getSize(fowPanel()).width, closeTo(320, 1));
    expect(tester.getSize(fowPanel()).height, closeTo(800, 1));
  });
}
