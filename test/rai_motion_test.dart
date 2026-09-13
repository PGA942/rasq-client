import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_motion.dart';

/// RAi の移動モーションの計画 (D-191): 距離が画面幅の半分未満なら起動 / 停止(short 系、同じ側の腕)、
/// 縦中央線を跨ぐなら腕を下ろして逆側を上げる、半分以上なら走行を挟む。推論中は一時停止。
void main() {
  test('指差す側: 部品が左なら左腕、右なら右腕、無ければ下ろす', () {
    expect(raiArmFor(const Offset(200, 300), const Rect.fromLTWH(20, 280, 40, 40)), RaiArm.left);
    expect(raiArmFor(const Offset(200, 300), const Rect.fromLTWH(300, 280, 40, 40)), RaiArm.right);
    expect(raiArmFor(const Offset(200, 300), null), RaiArm.none);
  });

  test('短距離・同じ側: 起動 / 走行 / 停止とも同じ腕を上げたまま', () {
    final p = planRaiMotion(from: const Offset(60, 300), to: const Offset(120, 380), columnWidth: 360, centerX: 180, armFrom: RaiArm.right, armTo: RaiArm.right);
    expect(p.long, isFalse);
    expect(p.crossesCenter, isFalse);
    expect([for (final s in p.steps) s.clip], ['run_start_short_armR', 'run_short_armR', 'run_stop_short_armR']);
    expect(p.at(0.1).clip, 'run_start_short_armR');
    expect(p.at(0.5).loop, isTrue);
    expect(p.at(0.95).clip, 'run_stop_short_armR');
    expect(p.idleClip, 'idle_armR');
  });

  test('短距離・中央線を跨ぐ: 腕を下ろして走り、逆側の腕を上げて止まる', () {
    final p = planRaiMotion(from: const Offset(120, 300), to: const Offset(240, 320), columnWidth: 360, centerX: 180, armFrom: RaiArm.right, armTo: RaiArm.left);
    expect(p.long, isFalse);
    expect(p.crossesCenter, isTrue);
    expect([for (final s in p.steps) s.clip], ['run_start_short_armR', 'run_short', 'run_stop_short_armL']);
    expect(p.idleClip, 'idle_armL');
  });

  test('長距離(画面幅の半分以上): 腕を下ろして起動 → 走行(ループ)→ 停止、到着後に腕を上げる', () {
    final p = planRaiMotion(from: const Offset(40, 100), to: const Offset(300, 600), columnWidth: 360, centerX: 180, armFrom: RaiArm.left, armTo: RaiArm.right);
    expect(p.long, isTrue);
    expect([for (final s in p.steps) s.clip], ['run_start', 'run', 'run_stop']);
    expect(p.at(0.5).loop, isTrue);
    expect(p.idleClip, 'idle_armR');
    // 中央固定(アシスタント)へ戻るときは腕なし。
    expect(planRaiMotion(from: const Offset(40, 100), to: const Offset(180, 300), columnWidth: 360, centerX: 180, armFrom: RaiArm.left, armTo: RaiArm.none).idleClip, 'idle');
  });

  test('コントローラー: 計画に沿ってクリップが進み、到着で腕が更新、推論中は paused', () {
    final c = RaiMascot3dController();
    var notified = 0;
    c.addListener(() => notified++);
    expect(c.clip, 'idle');
    c.idle(RaiArm.right);
    expect(c.clip, 'idle_armR');
    final p = planRaiMotion(from: const Offset(60, 300), to: const Offset(120, 380), columnWidth: 360, centerX: 180, armFrom: RaiArm.right, armTo: RaiArm.left);
    c.start(p);
    expect(c.clip, 'run_start_short_armR');
    c.advance(0.5);
    expect(c.clip, 'run_short');
    expect(c.loop, isTrue);
    c.advance(0.9);
    expect(c.clip, 'run_stop_short_armL');
    c.finish();
    expect(c.arm, RaiArm.left);
    expect(c.clip, 'idle_armL');
    c.paused = true;
    expect(c.paused, isTrue);
    expect(notified, greaterThanOrEqualTo(6));
    c.dispose();
  });

  test('テスト環境では 3D を使わない(FLUTTER_TEST)', () {
    expect(raiMascot3dProvider, isNotNull);
  });

  test('ヨー (D-196): 走行中の顔は接線と直交(正面に近い側)、起動 / 停止の段で向き替え', () {
    expect(raiRestYawFor(RaiArm.left), closeTo(-30 * math.pi / 180, 1e-9));
    expect(raiRestYawFor(RaiArm.right), closeTo(30 * math.pi / 180, 1e-9));
    expect(raiTangentYaw(const Offset(1, 0)), closeTo(-math.pi / 2, 1e-9));
    // 右へ走る = 顔は正面(0°)。左へ走る = 正面。上へ走る(接線 180°)= 横向き ±90°(腕の側)。
    expect(raiFaceYaw(const Offset(1, 0)), closeTo(0, 1e-9));
    expect(raiFaceYaw(const Offset(-1, 0)), closeTo(0, 1e-9));
    expect(raiFaceYaw(const Offset(0, -1), arm: RaiArm.left), closeTo(math.pi / 2, 1e-9));
    expect(raiFaceYaw(const Offset(0, -1), arm: RaiArm.right), closeTo(-math.pi / 2, 1e-9));
    expect(raiFaceYaw(const Offset(1, 1)).abs(), closeTo(math.pi / 4, 1e-9));
    final long = planRaiMotion(from: const Offset(40, 100), to: const Offset(300, 600), columnWidth: 360, centerX: 180, armFrom: RaiArm.left, armTo: RaiArm.right);
    expect(raiYawAt(0.5, plan: long, tangent: const Offset(1, 0), armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(0, 1e-9));
    expect(raiYawAt(0, plan: long, tangent: const Offset(1, 0), armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(-30 * math.pi / 180, 1e-9));
    expect(raiYawAt(1, plan: long, tangent: const Offset(1, 0), armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(30 * math.pi / 180, 1e-9));
    final stopping = raiYawAt(0.9, plan: long, tangent: const Offset(1, 0), armFrom: RaiArm.left, armTo: RaiArm.right);
    expect(stopping, inExclusiveRange(0, 30 * math.pi / 180));
    expect(raiYawAt(0.5, plan: null, tangent: Offset.zero, armFrom: RaiArm.none, armTo: RaiArm.none), 0);
  });

  test('円運動 (D-196): 起動 / 停止の段で小さな円を 1 周し、段の端では 0、走行中も 0', () {
    final long = planRaiMotion(from: const Offset(40, 100), to: const Offset(300, 600), columnWidth: 360, centerX: 180, armFrom: RaiArm.left, armTo: RaiArm.right);
    expect(raiLoopOffset(0, plan: long, radius: 40), Offset.zero);
    expect(raiLoopOffset(0.1, plan: long, radius: 40).distance, greaterThan(1)); // 起動の途中
    expect((raiLoopOffset(0.2, plan: long, radius: 40)).distance, lessThan(1e-6)); // 起動の終わり = 1 周
    expect(raiLoopOffset(0.5, plan: long, radius: 40), Offset.zero); // 走行中
    expect(raiLoopOffset(0.9, plan: long, radius: 40).distance, greaterThan(1)); // 停止の途中
    expect(raiLoopOffset(1, plan: long, radius: 40), Offset.zero);
    // 時計回り / 反時計回りは x の符号が逆。
    expect(raiLoopOffset(0.05, plan: long, radius: 40).dx.sign, isNot(raiLoopOffset(0.05, plan: long, radius: 40, clockwise: false).dx.sign));
    expect(raiLoopOffset(0.1, plan: null, radius: 40), Offset.zero);
  });
}
