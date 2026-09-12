import 'dart:ui';

/// RAi の移動モーションの計画 (D-191)。glb のクリップ名に対応する:
/// idle / run_start / run_stop / run_start_short / run_short / run_stop_short(それぞれ無印 / _armR / _armL)/ run / accident。
///
/// - 移動距離が **画面幅(カラム幅)の半分未満** → 起動 / 停止モーション(short 系)。基本は同じ側の腕を
///   上げ続ける(_armX)。ただし **画面の縦中央線を跨ぐ** なら、腕を下ろして走り(無印)、逆側の腕を上げて止まる。
/// - それ以上 → 腕を下ろして起動 → 走行(run、ループ)→ 停止 → 目標側の腕を上げて静止(idle_armX)。
/// - 静止は idle(中央 / 指差し無し)か idle_armX(部品を指差す)。
enum RaiArm {
  none,
  left,
  right;

  String get suffix => switch (this) { RaiArm.none => '', RaiArm.left => '_armL', RaiArm.right => '_armR' };
}

/// 指差す側: 部品が RAi の左にあれば左腕、右なら右腕。部品が無ければ下ろす。
RaiArm raiArmFor(Offset pos, Rect? target) {
  if (target == null) return RaiArm.none;
  return target.center.dx < pos.dx ? RaiArm.left : RaiArm.right;
}

class RaiClipStep {
  const RaiClipStep(this.clip, {required this.fraction, this.loop = false});

  /// glb のクリップ名。
  final String clip;

  /// 移動全体のうち、この段が占める割合(合計 1)。
  final double fraction;

  /// 走行のように繰り返すか。
  final bool loop;
}

class RaiMotionPlan {
  const RaiMotionPlan({required this.steps, required this.long, required this.crossesCenter, required this.armTo});
  final List<RaiClipStep> steps;
  final bool long;
  final bool crossesCenter;
  final RaiArm armTo;

  /// 進み具合(0..1)に対応する段。
  RaiClipStep at(double progress) {
    var acc = 0.0;
    for (final s in steps) {
      acc += s.fraction;
      if (progress < acc) return s;
    }
    return steps.last;
  }

  /// 到着後の静止クリップ。
  String get idleClip => raiIdleClip(armTo);
}

String raiIdleClip(RaiArm arm) => 'idle${arm.suffix}';

/// 移動の計画。[columnWidth] は画面幅(大画面ではカラム幅)、[centerX] は画面の縦中央線の x。
RaiMotionPlan planRaiMotion({required Offset from, required Offset to, required double columnWidth, required double centerX, required RaiArm armFrom, required RaiArm armTo}) {
  final distance = (to - from).distance;
  final long = distance >= columnWidth / 2;
  final crosses = (from.dx - centerX) * (to.dx - centerX) < 0;
  if (long) {
    return RaiMotionPlan(
      steps: const [RaiClipStep('run_start', fraction: 0.2), RaiClipStep('run', fraction: 0.6, loop: true), RaiClipStep('run_stop', fraction: 0.2)],
      long: true,
      crossesCenter: crosses,
      armTo: armTo,
    );
  }
  // 短距離: 同じ側の腕を上げたまま。中央線を跨ぐ(または腕が変わる)なら、下ろして走り、逆側を上げて止まる。
  final keep = armFrom != RaiArm.none && armFrom == armTo && !crosses;
  final runArm = keep ? armFrom : RaiArm.none;
  return RaiMotionPlan(
    steps: [
      RaiClipStep('run_start_short${armFrom.suffix}', fraction: 0.3),
      RaiClipStep('run_short${runArm.suffix}', fraction: 0.4, loop: true),
      RaiClipStep('run_stop_short${armTo.suffix}', fraction: 0.3),
    ],
    long: false,
    crossesCenter: crosses,
    armTo: armTo,
  );
}
