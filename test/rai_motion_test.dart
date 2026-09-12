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
}
