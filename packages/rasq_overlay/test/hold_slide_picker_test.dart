import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-512: 長押しして滑らせて離す選び方([HoldSlidePicker] / [OverlayManager.showHoldSlidePicker])と、
/// D-513: ボタンにつながった FOW([FowSpec.tether])・ボタンにつながったメニュー([OverlayManager.showDropdown] の tetherAnchorChild)。
const buttonKey = ValueKey('button');

Widget host(OverlayManager m, {required void Function(Rect anchor, bool hold) open, bool reduce = false}) => MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: child!),
      home: OverlayScope(
        manager: m,
        child: OverlayHost(
          manager: m,
          child: Scaffold(
            body: Align(
              alignment: const Alignment(0, -0.6),
              child: Builder(
                builder: (ctx) {
                  Rect rect() {
                    final box = ctx.findRenderObject() as RenderBox;
                    return box.localToGlobal(Offset.zero) & box.size;
                  }

                  return InkResponse(
                    key: buttonKey,
                    onTap: () => open(rect(), false),
                    onLongPress: () => open(rect(), true),
                    child: const SizedBox.square(dimension: 44, child: Icon(Icons.repeat, size: 20)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

List<HoldSlideItem<String>> items(List<String> names) => [
      for (final n in names) HoldSlideItem<String>(key: ValueKey('pick.$n'), value: n, label: '名前 $n', builder: (context, on) => Center(child: Text(n))),
    ];

void main() {
  late OverlayManager m;
  late List<String?> results;
  late List<int> haptics;

  setUp(() {
    m = OverlayManager();
    results = [];
    haptics = [];
  });

  Future<void> pumpHost(WidgetTester tester, {HoldSlideLayout layout = HoldSlideLayout.list, bool reduce = false}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick') haptics.add(1);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(host(m, reduce: reduce, open: (anchor, hold) async {
      results.add(await m.showHoldSlidePicker<String>(id: 'pick', anchor: anchor, title: 'リノート', holding: hold, layout: layout, items: items(['a', 'b', 'c']), anchorChild: const Icon(Icons.repeat, size: 20)));
    }));
  }

  HoldSlidePickerState<String> state(WidgetTester tester) => tester.state<HoldSlidePickerState<String>>(find.byType(HoldSlidePicker<String>));
  String header(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('pick.header.text'))).data!;

  testWidgets('長押しでボタンにつながったパネルが開き、滑らせると光る候補と見出しが変わり(振動)、離すとそれを選ぶ', (tester) async {
    await pumpHost(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(TetheredPanel), findsOneWidget, reason: 'ボタンにつながった形');
    expect(find.byKey(const ValueKey('pick.a')), findsOneWidget);
    expect(header(tester), 'リノート');
    // パネルはボタンの下。
    expect(tester.getTopLeft(find.byKey(const ValueKey('pick.a'))).dy, greaterThan(tester.getCenter(find.byKey(buttonKey)).dy));

    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('pick.a'))));
    await tester.pump();
    expect(state(tester).highlighted, 0);
    expect(header(tester), '名前 a');
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('pick.c'))));
    await tester.pump();
    expect(state(tester).highlighted, 2);
    expect(header(tester), '名前 c');
    expect(haptics, hasLength(2), reason: '光る候補が変わるたびに軽い振動');
    await g.up();
    await tester.pumpAndSettle();
    expect(results, ['c']);
    expect(find.byType(HoldSlidePicker<String>), findsNothing);
  });

  testWidgets('滑らせて候補の外で離すと、何もせずに閉じる', (tester) async {
    await pumpHost(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('pick.b'))));
    await tester.pump();
    expect(state(tester).highlighted, 1);
    // 候補から外れると光りも消える。
    await g.moveTo(const Offset(5, 590));
    await tester.pump();
    expect(state(tester).highlighted, isNull);
    await g.up();
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.byType(HoldSlidePicker<String>), findsNothing);
  });

  testWidgets('滑らせずに離すと開いたまま、タップで選べる(ジェスチャーなしでも使える)', (tester) async {
    await pumpHost(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(HoldSlidePicker<String>), findsOneWidget);
    expect(state(tester).holding, isFalse);
    expect(results, isEmpty);
    await tester.tap(find.byKey(const ValueKey('pick.b')));
    await tester.pumpAndSettle();
    expect(results, ['b']);
  });

  testWidgets('タップで開いたときはふつうのメニュー: 外のタップ / 首(元のボタン)のタップで閉じる', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    expect(find.byType(TetheredPanel), findsOneWidget);
    expect(state(tester).holding, isFalse);
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();
    expect(results, [null]);
    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rasqOverlay.tether.hit')));
    await tester.pumpAndSettle();
    expect(results, [null, null]);
    expect(find.byType(HoldSlidePicker<String>), findsNothing);
  });

  testWidgets('格子でも、指の下のマスを選ぶ / モーションの抑制中は拡大しない', (tester) async {
    await pumpHost(tester, layout: HoldSlideLayout.grid, reduce: true);
    final g = await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();
    // 抑制中は出てくる動きも無い(最初のフレームから置かれている)。
    expect(find.byKey(const ValueKey('pick.b')), findsOneWidget);
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('pick.b'))));
    await tester.pump();
    expect(state(tester).highlighted, 1);
    final scale = tester.widget<AnimatedScale>(find.descendant(of: find.byKey(const ValueKey('pick.b')), matching: find.byType(AnimatedScale)));
    expect(scale.scale, 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(results, ['b']);
  });

  testWidgets('FowSpec.tether: アンカー付きの FOW はボタンにつながった形で、カラムの中に収まる(中身・見出しはそのまま)', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: OverlayScope(
        manager: m,
        child: OverlayHost(
          manager: m,
          fowColumns: (_) => const [FowColumnSlot(x: 0, width: 600), FowColumnSlot(x: 600, width: 600)],
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    ));
    const anchor = Rect.fromLTWH(610, 100, 44, 44); // 2 つ目のカラムの左端のボタン
    m.showFow<void>(
      id: 'share',
      spec: FowSpec(title: '共有', cancelText: '閉じる', initialHeightFactor: 0.4, anchor: anchor, columnIndex: 1, tether: const FowTether(anchorChild: Icon(Icons.ios_share, size: 20))),
      builder: (_, _) => ListView(children: const [ListTile(key: ValueKey('row'), title: Text('リンクをコピー'))]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TetheredPanel), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    final panel = tester.getRect(find.byKey(kTetherPanelKey));
    expect(panel.left, greaterThanOrEqualTo(600), reason: 'ボタンのカラム(右)の中');
    expect(panel.top, greaterThan(anchor.center.dy));
    expect(panel.height, closeTo(0.4 * 800, 2));
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byType(TetheredPanel), findsNothing);
  });
}
