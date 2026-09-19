import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

RasqOverlayEntry entry(String id, OverlayLayer layer, {String? owner}) =>
    RasqOverlayEntry(id: id, layer: layer, ownerId: owner, builder: (_, _) => const SizedBox());

void main() {
  _fowTests();
  group('OverlayManager rules', () {
    test('modal and bottom sheet stack; dropdown is exclusive', () {
      final m = OverlayManager();
      m.show(entry('m1', OverlayLayer.modal));
      m.show(entry('m2', OverlayLayer.modal));
      m.show(entry('s1', OverlayLayer.bottomSheet));
      m.show(entry('s2', OverlayLayer.bottomSheet));
      expect(m.inLayer(OverlayLayer.modal).length, 2);
      expect(m.inLayer(OverlayLayer.bottomSheet).length, 2);

      var replacedReason = <OverlayCloseReason>[];
      m.show(RasqOverlayEntry(id: 'd1', layer: OverlayLayer.dropdown, builder: (_, _) => const SizedBox(), onClosed: (r, _) => replacedReason.add(r)));
      m.show(entry('d2', OverlayLayer.dropdown));
      expect(m.inLayer(OverlayLayer.dropdown).map((e) => e.id), ['d2']);
      expect(replacedReason, [OverlayCloseReason.replaced]);
    });

    test('entries are ordered by layer z regardless of insertion order', () {
      final m = OverlayManager();
      m.show(entry('modal', OverlayLayer.modal));
      m.show(entry('sheet', OverlayLayer.bottomSheet));
      m.show(entry('rai', OverlayLayer.rai));
      m.show(entry('fow', OverlayLayer.fow));
      expect(m.entries.map((e) => e.id), ['fow', 'sheet', 'modal', 'rai']);
    });

    test('barrier tap: modal ignored, sheet discards, sidebar dismisses', () async {
      final m = OverlayManager();
      final modalResult = m.show(entry('modal', OverlayLayer.modal));
      m.barrierTapped('modal');
      expect(m.contains('modal'), isTrue);

      OverlayCloseReason? sheetReason;
      m.show(RasqOverlayEntry(id: 'sheet', layer: OverlayLayer.bottomSheet, builder: (_, _) => const SizedBox(), onClosed: (r, _) => sheetReason = r));
      m.barrierTapped('sheet');
      expect(m.contains('sheet'), isFalse);
      expect(sheetReason, OverlayCloseReason.discard);

      m.show(entry('side', OverlayLayer.sidebar));
      m.barrierTapped('side');
      expect(m.contains('side'), isFalse);

      m.close('modal', result: 42);
      expect(await modalResult, 42);
    });

    test('VC中に別VC参加 → auto leave & join (exclusive replace)', () {
      final m = OverlayManager();
      m.show(entry('vc:a', OverlayLayer.vcVideo));
      m.show(entry('vc:b', OverlayLayer.vcVideo));
      expect(m.inLayer(OverlayLayer.vcVideo).map((e) => e.id), ['vc:b']);
    });

    test('handleBack consumes for blocking layers only', () {
      final m = OverlayManager();
      expect(m.handleBack(), isFalse);
      m.show(entry('rai', OverlayLayer.rai));
      expect(m.handleBack(), isFalse);
      m.show(entry('sheet', OverlayLayer.bottomSheet));
      expect(m.handleBack(), isTrue);
      expect(m.contains('sheet'), isFalse);
      m.show(entry('modal', OverlayLayer.modal));
      expect(m.handleBack(), isTrue); // swallowed, still open
      expect(m.contains('modal'), isTrue);
    });

    test('handleBack は退避中の FOW を閉じない(全画面の加工画面の下のコンポーザー)', () {
      final m = OverlayManager();
      RasqOverlayEntry fow(String id) => RasqOverlayEntry(id: id, layer: OverlayLayer.fow, barrierBehavior: OverlayBarrierBehavior.dismiss, builder: (_, _) => const SizedBox());
      m.show(fow('fow.composer'));
      m.show(fow('media.pro.child'));
      m.setFowSuspend((e) => e.id == 'fow.composer');
      m.handleBack();
      expect(m.contains('media.pro.child'), isFalse);
      m.handleBack(); // 残りは退避中のコンポーザーだけ → 何もしない
      expect(m.contains('fow.composer'), isTrue);
      m.setFowSuspend(null);
      m.handleBack();
      expect(m.contains('fow.composer'), isFalse);
    });

    test('closeOwnedBy isolates a crashed plugin', () {
      final m = OverlayManager();
      m.show(entry('p1.sheet', OverlayLayer.bottomSheet, owner: 'plugin-1'));
      m.show(entry('p2.sheet', OverlayLayer.bottomSheet, owner: 'plugin-2'));
      m.closeOwnedBy('plugin-1');
      expect(m.entries.map((e) => e.id), ['p2.sheet']);
    });
  });

  testWidgets('OverlayHost renders scrim for sheet and tapping it closes', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: OverlayHost(manager: m, child: const Scaffold(body: Text('content')))));
    m.show(RasqOverlayEntry(id: 's', layer: OverlayLayer.bottomSheet, alignment: Alignment.bottomCenter, builder: (_, _) => const SizedBox(height: 100, child: Text('sheet'))));
    await tester.pump();
    expect(find.text('sheet'), findsOneWidget);
    await tester.tapAt(const Offset(200, 50)); // scrim
    await tester.pump();
    expect(find.text('sheet'), findsNothing);
  });
}

void _fowTests() {
  testWidgets('FOW panels stack bottom-up (newest at bottom), resize via handle, interstitial scrim discards', (tester) async {
    final m = OverlayManager();
    await tester.pumpWidget(MaterialApp(home: OverlayHost(manager: m, child: const Scaffold(body: Text('content')))));
    final parentSpec = FowSpec(type: FowPanelType.interstitial, initialHeightFactor: 0.5, title: 'parent', cancelText: 'cancel');
    final childSpec = FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.3, title: 'child');
    m.showFow(id: 'parent', spec: parentSpec, builder: (_, _) => const Text('P'));
    m.showFow(id: 'child', spec: childSpec, ownerId: 'parent', builder: (_, _) => const Text('C'));
    await tester.pump();
    expect(m.inLayer(OverlayLayer.fow).length, 2);
    final pTop = tester.getTopLeft(find.text('P')).dy;
    final cTop = tester.getTopLeft(find.text('C')).dy;
    expect(cTop, greaterThan(pTop)); // child below parent

    // drag child's handle up → taller
    final before = childSpec.heightFactor.value;
    final handle = find.bySemanticsLabel('サイズ変更ハンドル').last;
    await tester.drag(handle, const Offset(0, -60));
    await tester.pump();
    expect(childSpec.heightFactor.value, greaterThan(before));

    // tapping the scrim closes the interstitial parent (discard)
    await tester.tapAt(const Offset(200, 20));
    await tester.pump();
    expect(m.contains('parent'), isFalse);
    m.closeOwnedBy('parent');
    expect(m.contains('child'), isFalse);
  });
}
