import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-065: FOW の付け先(ヘッダー下付き / アンカー / 壁付き)と
/// FOW スイッチャー(ハンドルをその場で長押し、D-340)。
Widget host(OverlayManager m, {List<FowColumnSlot> Function(BuildContext)? columns, double Function(BuildContext)? topInset, double Function(BuildContext)? topClearance}) => MaterialApp(
      home: OverlayScope(
        manager: m,
        child: OverlayHost(manager: m, fowColumns: columns, fowTopInset: topInset, fowTopClearance: topClearance, child: const Scaffold(body: SizedBox.expand())),
      ),
    );

Finder fowPanel() => find.byWidgetPredicate((w) => w is Material && w.elevation == 8);

void main() {
  testWidgets('FOW スイッチャー: ハンドル長押し → リスト → 親選択で子が自動クローズ + 前面化', (tester) async {
    final m = OverlayManager();
    m.showFow<void>(id: 'parent', spec: FowSpec(title: '親パネル', cancelText: '閉じる'), builder: (context, handle) => const SizedBox());
    m.showFow<void>(id: 'child', ownerId: 'parent', spec: FowSpec(title: '子ピッカー', cancelText: '閉じる'), builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m));
    await tester.pumpAndSettle();

    // 重ね表示: 両方のパネルが載っている(縦積みで高さを分け合わない)。
    expect(find.text('親パネル'), findsOneWidget);
    expect(find.text('子ピッカー'), findsOneWidget);

    // タップではもう開かない (D-340)。その場で長押し → ブラックアウト + リスト表示(パネルは Offstage)。
    await tester.tap(find.bySemanticsLabel('サイズ変更ハンドル').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(m.fowSwitcherOpen, isFalse);
    await tester.longPress(find.bySemanticsLabel('サイズ変更ハンドル').last, warnIfMissed: false);
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

  testWidgets('D-340: stick FOW はハンドル / 空いたところのタップで展開モードへ(ボタンのタップは奪わない)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final spec = FowSpec(stickCollapse: true, initialHeightFactor: 0.15, minHeightFactor: 0.1, heightStops: const [0.15, 0.6]);
    var pressed = 0;
    m.showFow<void>(
      id: 's',
      spec: spec,
      builder: (context, handle) => Align(alignment: Alignment.topLeft, child: TextButton(onPressed: () => pressed++, child: const Text('ボタン'))),
    );
    await tester.pumpWidget(host(m));
    await tester.pumpAndSettle();
    expect(spec.isStick, isTrue);

    // ボタンのタップはボタンが取る(展開しない)。
    await tester.tap(find.text('ボタン'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(spec.isStick, isTrue);

    // 空いたところのタップ → 展開(最上段)。
    await tester.tapAt(tester.getBottomRight(fowPanel()) - const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(spec.heightFactor.value, closeTo(0.6, 0.001));
    expect(spec.isStick, isFalse);

    // 畳んで、ハンドルのタップでも展開。
    spec.heightFactor.value = 0.15;
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('サイズ変更ハンドル').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(spec.heightFactor.value, closeTo(0.6, 0.001));

    // 展開中のタップでは何もしない。stick にならない FOW は段が 2 つあっても対象外。
    final plain = FowSpec(heightStops: const [0.2, 0.5], initialHeightFactor: 0.2);
    expect(plain.isStick, isFalse);
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

  testWidgets('親子 FOW (D-067/D-068): 親は子の高さぶん枠を伸ばし FowChildGap が場所を空ける、方向は親側指定、親クローズで連動', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    final parentSpec = FowSpec(title: '親コンポーザー', cancelText: '閉じる', initialHeightFactor: 0.4);
    final childSpec = FowSpec(title: '子ピッカー', cancelText: '閉じる', initialHeightFactor: 0.3);
    // 親の中身: [入力部][バー][FowChildGap(下)] — gap が子の高さに伸びて
    // バー/入力部を押し上げる (D-068)。
    m.showFow<void>(
        id: 'parent',
        spec: parentSpec,
        builder: (context, handle) => Column(children: [
              const Expanded(child: ColoredBox(color: Color(0xFF808080), child: SizedBox.expand(child: Center(child: Text('入力部'))))),
              const SizedBox(height: 40, child: Center(child: Text('バー'))),
              FowChildGap(spec: parentSpec),
            ]));
    m.showFow<void>(id: 'child', ownerId: 'parent', spec: childSpec, builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m, topInset: (_) => 60));
    await tester.pumpAndSettle();

    Rect panelOf(String title) => tester.getRect(find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate((w) => w is Material && w.shape is RoundedRectangleBorder)).first);
    // 子は画面下端。親の**枠**は下端まで伸びたまま(持ち上げない)、
    // gap 通知が子の高さになり、バーは子の上辺に載る。
    expect(panelOf('子ピッカー').bottom, closeTo(800, 1));
    expect(panelOf('親コンポーザー').bottom, closeTo(800, 1));
    expect(panelOf('親コンポーザー').top, closeTo(800 - (320 + 240), 1)); // 0.4*800 + 子 240
    expect(parentSpec.childGapBottom.value, closeTo(240, 1));
    expect(tester.getBottomLeft(find.text('バー')).dy, lessThanOrEqualTo(800 - 240 + 21)); // バーは子の上辺(gap 分上)

    // 子をリサイズ → gap がリアルタイム追従。
    childSpec.heightFactor.value = 0.5;
    await tester.pumpAndSettle();
    expect(parentSpec.childGapBottom.value, closeTo(400, 1));
    expect(panelOf('親コンポーザー').top, closeTo(800 - (320 + 400), 1));

    // 親をヘッダー下付きへ → 方向は親側指定なので子も追従し、gap は上側へ。
    await tester.drag(find.text('親コンポーザー'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(parentSpec.attachTop, isTrue);
    expect(panelOf('子ピッカー').top, closeTo(60, 1));
    expect(panelOf('親コンポーザー').top, closeTo(60, 1)); // 枠は同じ根本(ヘッダー下)
    expect(parentSpec.childGapTop.value, closeTo(400, 1));
    expect(parentSpec.childGapBottom.value, 0);

    // 親を閉じると子は連動クローズ (CONTRACT)。
    m.close('parent');
    await tester.pumpAndSettle();
    expect(m.contains('child'), isFalse);
    expect(m.entries, isEmpty);
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

  testWidgets('上辺の余白 (D-178): 下端ドック / 壁付けの FOW は fowTopClearance より上へ伸びず、ハンドルは 26px', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    m.showFow<void>(id: 'full', spec: FowSpec(title: '全高', cancelText: '閉じる', initialHeightFactor: 1.0, maxHeightFactor: 1.0), builder: (context, handle) => const SizedBox());
    await tester.pumpWidget(host(m, topClearance: (_) => 100));
    await tester.pumpAndSettle();
    final handle = find.bySemanticsLabel('サイズ変更ハンドル');
    expect(tester.getSize(handle).height, kFowHandleHeight);
    expect(tester.getTopLeft(handle).dy, greaterThanOrEqualTo(100));
    // 壁付け(高さ 1.0 固定)も同じ。
    final spec = m.entries.single.fow!..pinnedWall = -1;
    spec.geometryRev.value++;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, greaterThanOrEqualTo(100));
  });

  testWidgets('サイドバーの前に出る FOW (D-274): 後ろを暗くしてサイドバーに被さる。戻る / Escape は FOW が先。狭いカラムなら全カラムにまたがる', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = OverlayManager();
    var sidebarTaps = 0;
    m.show(RasqOverlayEntry(id: 'sidebar', layer: OverlayLayer.sidebar, alignment: Alignment.centerLeft, builder: (_, _) => GestureDetector(onTap: () => sidebarTaps++, child: Container(width: 340, height: double.infinity, color: Colors.white))));
    var fowTaps = 0;
    m.showFow<void>(
      id: 'accounts',
      barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
      spec: FowSpec(title: 'アカウント', cancelText: '閉じる', aboveSidebar: true, dimBehind: true, spanColumnsBelow: 360, initialHeightFactor: 0.5),
      builder: (_, _) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => fowTaps++, child: const SizedBox.expand(key: ValueKey('fow.body'))),
    );
    // 2 カラム: 左 300px は狭い(< 360)→ 2 カラムにまたがる。
    await tester.pumpWidget(host(m, columns: (_) => const [FowColumnSlot(x: 0, width: 300), FowColumnSlot(x: 300, width: 600)]));
    await tester.pumpAndSettle();
    expect(tester.getSize(fowPanel()).width, 900);
    // サイドバー(x < 340)と重なる位置を押す → 前にいる FOW が受ける。
    await tester.tapAt(Offset(100, tester.getCenter(find.byKey(const ValueKey('fow.body'))).dy));
    expect((fowTaps, sidebarTaps), (1, 0));
    // 暗い幕(FOW の上の余白)を押す → FOW だけ閉じ、サイドバーは残る。
    expect(m.handleBack(), isTrue);
    expect((m.contains('accounts'), m.contains('sidebar')), (false, true));

    // 左カラムが広ければ、左カラムに収まる。
    m.showFow<void>(id: 'accounts', spec: FowSpec(title: 'アカウント', cancelText: '閉じる', aboveSidebar: true, spanColumnsBelow: 360), builder: (_, _) => const SizedBox.expand());
    await tester.pumpWidget(host(m, columns: (_) => const [FowColumnSlot(x: 0, width: 400), FowColumnSlot(x: 400, width: 500)]));
    await tester.pumpAndSettle();
    expect(tester.getSize(fowPanel()).width, 400);
  });
}
