import 'dart:math' as math;
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

/// 指差し時の RAi の大きさ(px)と、移動の手前再接近 / アシスタントのスタンバイでの最大の大きさ。
const raiPointSize = 180.0;
const raiApproachSize = 700.0;

/// 画面に収まる「手前再接近」の大きさ。
double raiApproachSizeFor(Size screen) => raiApproachSize.clamp(raiPointSize, (screen.shortestSide * 0.9).clamp(raiPointSize, raiApproachSize));

/// 移動中の大きさ: 両端は指差しサイズ、中ほどで手前に寄って大きくなる(山なり)。
double raiSizeAt(double progress, {required double approach, double point = raiPointSize}) {
  final t = progress.clamp(0.0, 1.0);
  final bump = 4 * t * (1 - t); // 0 → 1 → 0
  return point + (approach - point) * bump;
}

/// 移動時間: 短距離 2〜4 秒、長距離 4〜6 秒(距離に比例)。
Duration raiMoveDuration({required double distance, required double columnWidth, required bool long}) {
  final half = columnWidth / 2;
  if (!long) {
    final r = half == 0 ? 1.0 : (distance / half).clamp(0.0, 1.0);
    return Duration(milliseconds: (2000 + 2000 * r).round());
  }
  final r = ((distance - half) / (columnWidth * 1.5)).clamp(0.0, 1.0);
  return Duration(milliseconds: (4000 + 2000 * r).round());
}

/// 静止時のヨー (D-193 → D-194): 指差す側へ 30°(左腕 = −30°、右腕 = +30°、腕なし = 正面)。
const raiRestYaw = 30 * math.pi / 180;

/// 走行中に進行方向へ向く角度。
const raiTravelYaw = 60 * math.pi / 180;

/// 後半で背中を見せる角度。
const raiBackYaw = math.pi;

double raiRestYawFor(RaiArm arm) => switch (arm) { RaiArm.left => -raiRestYaw, RaiArm.right => raiRestYaw, RaiArm.none => 0 };

/// 移動中のヨー (D-194):
/// - 短距離: 出発側の向きから到着側の向きへ滑らかに。
/// - 長距離: 起動で進行方向(±60°)を向き → 前半で回り続けて **後半は背中(180°)を見せ** → 停止の段で
///   **その場で同じ回転方向に旋回し続けて** 到着側の向き(±30°、到着時に上げる腕が基準)に合わせる。
///   回転方向は山なりの向き = 進行方向(右へ走るなら時計回り = 負)。
double raiYawAt(double progress, {required RaiMotionPlan? plan, required double velocityDx, required RaiArm armFrom, required RaiArm armTo}) {
  final t = progress.clamp(0.0, 1.0);
  final restTo = raiRestYawFor(armTo);
  if (plan == null || t >= 1) return restTo;
  final restFrom = raiRestYawFor(armFrom);
  double smooth(double x) => x * x * (3 - 2 * x);
  if (!plan.long) return restFrom + (restTo - restFrom) * smooth(t);
  final dir = velocityDx >= 0 ? -1.0 : 1.0;
  final travel = dir * raiTravelYaw;
  final back = dir * raiBackYaw;
  // 到着側の向きを、背中(±180°)からさらに同じ方向へ回った先の等価角に置く(旋回して合わせる)。
  final finalYaw = restTo + dir * 2 * math.pi;
  final startEnd = plan.steps.first.fraction;
  final stopStart = 1 - plan.steps.last.fraction;
  if (t < startEnd) return restFrom + (travel - restFrom) * smooth(t / startEnd);
  if (t < 0.5) return travel + (back - travel) * smooth((t - startEnd) / (0.5 - startEnd));
  if (t < stopStart) return back;
  return back + (finalYaw - back) * smooth((t - stopStart) / (1 - stopStart));
}
