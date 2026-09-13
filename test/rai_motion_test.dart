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

  test('ヨー (D-194): 静止は指差す側へ 30°(左腕 −30° / 右腕 +30°)、短距離は滑らかに、長距離は進行方向 → 後半は背中 → 停止でその場旋回して合わせる', () {
    expect(raiRestYawFor(RaiArm.left), closeTo(-30 * math.pi / 180, 1e-9));
    expect(raiRestYawFor(RaiArm.right), closeTo(30 * math.pi / 180, 1e-9));
    expect(raiRestYawFor(RaiArm.none), 0);
    final short = planRaiMotion(from: const Offset(60, 300), to: const Offset(120, 380), columnWidth: 360, centerX: 180, armFrom: RaiArm.right, armTo: RaiArm.left);
    expect(raiYawAt(0, plan: short, velocityDx: 1, armFrom: RaiArm.right, armTo: RaiArm.left), closeTo(30 * math.pi / 180, 1e-9));
    expect(raiYawAt(1, plan: short, velocityDx: 1, armFrom: RaiArm.right, armTo: RaiArm.left), closeTo(-30 * math.pi / 180, 1e-9));
    expect(raiYawAt(0.5, plan: short, velocityDx: 1, armFrom: RaiArm.right, armTo: RaiArm.left), closeTo(0, 1e-9));
    final long = planRaiMotion(from: const Offset(40, 100), to: const Offset(300, 600), columnWidth: 360, centerX: 180, armFrom: RaiArm.left, armTo: RaiArm.right);
    // 右へ走る = 時計回り(負)。起動の終わり(20%)で −60°、後半(50〜80%)は背中 −180°。
    expect(raiYawAt(0.2, plan: long, velocityDx: 3, armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(-60 * math.pi / 180, 1e-6));
    expect(raiYawAt(0.6, plan: long, velocityDx: 3, armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(-math.pi, 1e-9));
    // 停止の段: 同じ方向に回り続けて到着側(+30° ≡ −330°)に合わせる。単調に減る。
    final a = raiYawAt(0.85, plan: long, velocityDx: 3, armFrom: RaiArm.left, armTo: RaiArm.right);
    final b = raiYawAt(0.95, plan: long, velocityDx: 3, armFrom: RaiArm.left, armTo: RaiArm.right);
    expect(a, lessThan(-math.pi));
    expect(b, lessThan(a));
    expect(b, greaterThan(30 * math.pi / 180 - 2 * math.pi));
    expect(raiYawAt(1, plan: long, velocityDx: 3, armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(30 * math.pi / 180, 1e-9));
    // 左へ走るなら反時計回り(正)。
    expect(raiYawAt(0.6, plan: long, velocityDx: -3, armFrom: RaiArm.left, armTo: RaiArm.right), closeTo(math.pi, 1e-9));
    expect(raiYawAt(0.5, plan: null, velocityDx: 0, armFrom: RaiArm.none, armTo: RaiArm.none), 0);
  });
}
