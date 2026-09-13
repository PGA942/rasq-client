import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_space.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';

/// RAi のマスコット層 (D-202): 実機のログ(ParentDataWidget の誤用、three_js の作り直しと破棄時の EGL 例外、
/// 2 つ目のインスタンスによる描画の崩れ)の再発防止。
void main() {
  testWidgets('層は出す / 隠す / スタンバイのどの状態でも同じ Stack を返す(Stack の外に Positioned を返さない)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Stack(children: [RaiMascotLayer()]))));
    await tester.pump();
    final c = ProviderScope.containerOf(tester.element(find.byType(RaiMascotLayer)));
    Finder layerStack() => find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(Stack));
    // 隠れている(吹き出し無し)。
    expect(layerStack(), findsOneWidget);
    expect(find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot)), findsNothing);
    // スタンバイ(アシスタント + ホームの枠)。
    c.read(raiProvider.notifier).open(mode: RaiMode.assistant);
    c.read(raiStandbySlotProvider.notifier).set(const Rect.fromLTWH(100, 100, 200, 250));
    await tester.pump();
    expect(layerStack(), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 枠が消える → 隠れる。
    c.read(raiStandbySlotProvider.notifier).set(null);
    await tester.pump();
    expect(layerStack(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小さい RAi アイコンは 3D が有効でも 2D で描く(three_js のインスタンスを増やさない)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [raiMascot3dProvider.overrideWithValue(true)],
      child: const MaterialApp(home: Center(child: RaiIcon())),
    ));
    await tester.pump();
    expect(find.byType(RaiMascot3d), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('setFrame は通知する(較正枠が毎フレーム追従する)', () {
    final ctrl = RaiMascot3dController();
    var n = 0;
    ctrl.addListener(() => n++);
    ctrl.setFrame(world: const RaiVec3(0, 0, -5), yaw: 0.2, screenPos: const Offset(10, 20), sizePx: 180);
    expect(n, 1);
    expect(ctrl.screenPos, const Offset(10, 20));
    expect(ctrl.sizePx, 180);
    ctrl.dispose();
  });
}
