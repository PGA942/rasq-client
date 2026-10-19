import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// D-476: FOW の出入りの動き(ホストが全 FOW に付ける)。開く = 付け先の側からすべり込み + フェード、閉じる = 逆向き(押せない)、
/// モーションの抑制(MediaQuery.disableAnimations)/ FowSpec.motion = false では動かさない。
Widget host(OverlayManager m, {bool reduce = false, Widget? body}) => MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: child!),
      home: OverlayScope(
        manager: m,
        child: OverlayHost(manager: m, child: Scaffold(body: body ?? const SizedBox.expand())),
      ),
    );

/// パネルの出入りの不透明度(中身からいちばん近い Opacity = ホストの動き)。
Finder motionOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first;
double opacityOf(WidgetTester tester, String text) => tester.widget<Opacity>(motionOf(text)).opacity;

/// 閉じかけのパネル(閉じる直前の写し)。
Finder leavingOf(String id) => find.byKey(ValueKey('rasqOverlay.fow.leaving.$id'));
double leavingOpacity(WidgetTester tester, String id) => tester.widget<Opacity>(find.ancestor(of: leavingOf(id), matching: find.byType(Opacity)).first).opacity;

/// 動きの拡大率(ホストの Opacity の直下の Transform)。
double scaleOf(WidgetTester tester, String text) => (tester.widget<Opacity>(motionOf(text)).child! as Transform).transform.entry(0, 0);

void main() {
  testWidgets('開く: 下端ドックの FOW は下からすべり込みながらフェードインし、180ms で止まる', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'a', spec: FowSpec(initialHeightFactor: 0.4), builder: (_, _) => const Center(child: Text('中身')));
    await tester.pump();
    await tester.pumpAndSettle();
    final restY = tester.getTopLeft(find.text('中身')).dy;
    m.close('a');
    await tester.pumpAndSettle();
    expect(find.text('中身'), findsNothing);

    m.showFow<void>(id: 'a', spec: FowSpec(initialHeightFactor: 0.4), builder: (_, _) => const Center(child: Text('中身')));
    await tester.pump(); // 最初のフレーム = 透明・下にずれている
    expect(opacityOf(tester, '中身'), lessThan(0.05));
    await tester.pump(const Duration(milliseconds: 60));
    final midOpacity = opacityOf(tester, '中身');
    final midY = tester.getTopLeft(find.text('中身')).dy;
    expect(midOpacity, inExclusiveRange(0.05, 1.0));
    expect(midY, greaterThan(restY + 0.5)); // まだ下にいる
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester, '中身'), 1.0);
    expect(tester.getTopLeft(find.text('中身')).dy, moreOrLessEquals(restY));
  });

  testWidgets('閉じる: 閉じたあとも少しの間だけ描かれて下へ抜け(押せない)、終わると消える。戻る / Escape でも同じ', (tester) async {
    final m = OverlayManager();
    var behind = 0;
    var inPanel = 0;
    await tester.pumpWidget(host(m, body: Align(alignment: Alignment.bottomCenter, child: SizedBox(height: 300, width: double.infinity, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => behind++)))));
    m.showFow<void>(
      id: 'a',
      spec: FowSpec(type: FowPanelType.interstitial, initialHeightFactor: 0.4, title: 'パネル', cancelText: 'キャンセル'),
      builder: (_, _) => Center(child: TextButton(onPressed: () => inPanel++, child: const Text('ボタン'))),
    );
    await tester.pumpAndSettle();
    final restY = tester.getTopLeft(find.text('ボタン')).dy;
    final restPanelY = tester.getTopLeft(find.byType(FowSnapshotBoundary)).dy;
    final buttonAt = tester.getCenter(find.text('ボタン'));
    await tester.tap(find.text('ボタン'));
    expect(inPanel, 1);

    // 戻る(Escape)で閉じる: エントリはすぐ外れる(戻るの相手ではなくなる)が、パネルは閉じる動きの間だけ残る。
    expect(m.handleBack(), isTrue);
    expect(m.contains('a'), isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    // 中身のウィジェットはもう無く、閉じる直前の写しが下へ抜けながら薄くなる。
    expect(find.text('ボタン'), findsNothing);
    expect(leavingOf('a'), findsOneWidget);
    expect(leavingOpacity(tester, 'a'), inExclusiveRange(0.0, 1.0));
    expect(tester.getTopLeft(leavingOf('a')).dy, greaterThan(restPanelY + 0.5));
    expect(restY, greaterThan(restPanelY));
    expect(m.leavingFows.map((l) => l.entry.id), ['a']);
    // 閉じかけは押せない: タップは後ろの画面へ抜ける。
    await tester.tapAt(buttonAt);
    expect(inPanel, 1);
    expect(behind, 1);
    // 次の戻るは FOW に取られない。
    expect(m.handleBack(), isFalse);

    await tester.pumpAndSettle();
    expect(leavingOf('a'), findsNothing);
    expect(m.leavingFows, isEmpty);
  });

  testWidgets('Escape キーで閉じても閉じる動きのあとに消える', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m, body: Focus(autofocus: true, onKeyEvent: (_, e) => e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && m.handleBack() ? KeyEventResult.handled : KeyEventResult.ignored, child: const SizedBox.expand())));
    m.showFow<void>(id: 'a', spec: FowSpec(type: FowPanelType.interstitial), builder: (_, _) => const Text('中身'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(m.contains('a'), isFalse);
    await tester.pump(const Duration(milliseconds: 50));
    expect(leavingOf('a'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(leavingOf('a'), findsNothing);
  });

  testWidgets('ヘッダー下付きの FOW は上から、アンカー付きは小さく(0.94 倍から)出てくる', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'top', spec: FowSpec(attachTop: true, initialHeightFactor: 0.3), builder: (_, _) => const Center(child: Text('上')));
    await tester.pumpAndSettle();
    final restTop = tester.getTopLeft(find.text('上')).dy;
    m.close('top');
    await tester.pumpAndSettle();
    m.showFow<void>(id: 'top', spec: FowSpec(attachTop: true, initialHeightFactor: 0.3), builder: (_, _) => const Center(child: Text('上')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(find.text('上')).dy, lessThan(restTop - 0.5));
    await tester.pumpAndSettle();

    m.showFow<void>(id: 'anc', spec: FowSpec(anchor: const Rect.fromLTWH(100, 100, 40, 40), initialHeightFactor: 0.3), builder: (_, _) => const SizedBox.expand(child: Text('アンカー')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester, 'アンカー'), inExclusiveRange(0.94, 1.0));
    await tester.pumpAndSettle();
    expect(scaleOf(tester, 'アンカー'), 1.0);
  });

  testWidgets('モーションの抑制(disableAnimations)では開く / 閉じるとも動かさない', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m, reduce: true));
    m.showFow<void>(id: 'a', spec: FowSpec(type: FowPanelType.interstitial), builder: (_, _) => const Center(child: Text('中身')));
    await tester.pump();
    expect(opacityOf(tester, '中身'), 1.0);
    final y = tester.getTopLeft(find.text('中身')).dy;
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(find.text('中身')).dy, y);
    // スクリムも最初から濃さが付いている。
    final scrim = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).where((b) => b.color.a > 0.3 && b.color.r == 0).toList();
    expect(scrim, isNotEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse); // 動いているものが無い

    m.close('a');
    expect(m.leavingFows, isEmpty); // 写しも撮らない
    await tester.pump();
    expect(find.text('中身'), findsNothing);
  });

  testWidgets('FowSpec.motion = false の FOW は動かさない(自分で動かす FOW と二重にしない)', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'a', spec: FowSpec(motion: false), builder: (_, _) => const Center(child: Text('中身')));
    await tester.pump();
    expect(opacityOf(tester, '中身'), 1.0);
    m.close('a');
    expect(m.leavingFows, isEmpty);
    await tester.pump();
    expect(find.text('中身'), findsNothing);
  });

  testWidgets('開き直し(同じ id)と FOW 群の作り直しでは開く動きを繰り返さない。後ろの FOW が閉じても前の FOW の中身は作り直さない', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'back', spec: FowSpec(initialHeightFactor: 0.3), builder: (_, _) => const Text('後ろ'));
    m.showFow<void>(id: 'front', spec: FowSpec(initialHeightFactor: 0.5), builder: (_, _) => const _Stateful());
    await tester.pumpAndSettle();
    final state = tester.state<_StatefulState>(find.byType(_Stateful));

    // 後ろを暗くする FOW を足す(ホストの外側の並びが変わる)→ 前からいる FOW は動かない。
    m.showFow<void>(id: 'inter', spec: FowSpec(type: FowPanelType.interstitial, initialHeightFactor: 0.2), builder: (_, _) => const Text('割り込み'));
    await tester.pump();
    expect(opacityOf(tester, '後ろ'), 1.0);
    expect(opacityOf(tester, 'state'), 1.0);
    expect(opacityOf(tester, '割り込み'), lessThan(0.05));
    await tester.pumpAndSettle();
    m.close('inter');
    await tester.pumpAndSettle();

    // 後ろの FOW を閉じる: 前の FOW の State はそのまま。
    m.close('back');
    await tester.pumpAndSettle();
    expect(tester.state<_StatefulState>(find.byType(_Stateful)), same(state));

    // 同じ id で開き直す: 古い方は待たずに消え、開く動きは繰り返さない(同じ Element を使い続ける)。
    m.showFow<void>(id: 'front', spec: FowSpec(initialHeightFactor: 0.5), builder: (_, _) => const _Stateful());
    await tester.pump();
    expect(m.leavingFows, isEmpty);
    expect(find.text('state'), findsOneWidget);
    expect(opacityOf(tester, 'state'), 1.0);
  });

  testWidgets('後ろの FOW が閉じても、閉じかけは元の重ね順の位置に描く(前へ飛び出さない)', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    for (final id in ['a', 'b', 'c']) {
      m.showFow<void>(id: id, spec: FowSpec(initialHeightFactor: 0.3), builder: (_, _) => Text(id));
    }
    await tester.pumpAndSettle();
    m.close('c');
    m.close('a');
    await tester.pump();
    final keys = tester.widget<Stack>(find.ancestor(of: find.byKey(const ValueKey('rasqOverlay.fow.b')), matching: find.byType(Stack)).first).children.map((w) => w.key).toList();
    expect(keys, [for (final id in ['a', 'b', 'c']) ValueKey('rasqOverlay.fow.$id')]);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(find.text('c'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('閉じかけの間に同じ GlobalKey を使う FOW を開いても重複しない(閉じた中身はすぐ捨てて写しだけ描く)', (tester) async {
    final m = OverlayManager();
    final shared = GlobalKey();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'one', spec: FowSpec(initialHeightFactor: 0.3), builder: (_, _) => TextField(key: shared));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byKey(shared));
    m.close('one');
    m.showFow<void>(id: 'two', spec: FowSpec(initialHeightFactor: 0.3), builder: (_, _) => TextField(key: shared));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(leavingOf('one'), findsOneWidget);
    expect(find.byKey(shared), findsOneWidget);
    await tester.pumpAndSettle();
    expect(leavingOf('one'), findsNothing);
  });

  testWidgets('親を閉じると子も一緒に閉じる動きをして、両方消える', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(host(m));
    m.showFow<void>(id: 'p', spec: FowSpec(initialHeightFactor: 0.5), builder: (_, _) => const Text('親'));
    m.showFow<void>(id: 'c', ownerId: 'p', spec: FowSpec(initialHeightFactor: 0.3), builder: (_, _) => const Text('子'));
    await tester.pumpAndSettle();
    m.close('p');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(leavingOf('p'), findsOneWidget);
    expect(leavingOf('c'), findsOneWidget);
    expect(m.leavingFows.map((l) => l.entry.id).toSet(), {'p', 'c'});
    // 閉じかけも重ね順はそのまま(子が親の前)。
    List<Key?> order() => tester.widget<Stack>(find.ancestor(of: find.byKey(const ValueKey('rasqOverlay.fow.p')), matching: find.byType(Stack)).first).children.map((w) => w.key).toList();
    expect(order(), [const ValueKey('rasqOverlay.fow.p'), const ValueKey('rasqOverlay.fow.c')]);
    await tester.pumpAndSettle();
    expect(leavingOf('p'), findsNothing);
    expect(leavingOf('c'), findsNothing);
  });
}

class _Stateful extends StatefulWidget {
  const _Stateful();
  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const Text('state');
}
