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

double raiRestYawFor(RaiArm arm) => switch (arm) { RaiArm.left => -raiRestYaw, RaiArm.right => raiRestYaw, RaiArm.none => 0 };

/// 移動曲線の接線 → ヨー: 画面で下(手前)へ進む = 正面 0、上(奥)= 背中 180°、右 = −90°、左 = +90°。
double raiTangentYaw(Offset tangent) => tangent.distance < 0.01 ? 0 : math.atan2(-tangent.dx, tangent.dy);

/// −π..π に畳む。
double raiWrap(double a) {
  var d = a % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d;
}

/// a → b の最短の差(−π..π)。
double raiYawDelta(double a, double b) => raiWrap(b - a);

/// 走行中の顔の向き (D-196): **接線と直交**(横向きに走る)。2 つの候補のうち正面(0°)に近い方、
/// 同じなら到着時に上げる腕の側(左腕 = 左向き)。
double raiFaceYaw(Offset tangent, {RaiArm arm = RaiArm.none}) {
  if (tangent.distance < 0.01) return 0;
  final t = raiTangentYaw(tangent);
  final a = raiWrap(t + math.pi / 2);
  final b = raiWrap(t - math.pi / 2);
  if ((a.abs() - b.abs()).abs() < 1e-6) {
    return switch (arm) { RaiArm.left => a > 0 ? a : b, RaiArm.right => a < 0 ? a : b, RaiArm.none => a };
  }
  return a.abs() < b.abs() ? a : b;
}

/// 走行開始 / 終了の小さな円運動 (D-196): 起動の段と停止の段で半径 [radius] の円を 1 周する(端点では 0)。
/// [clockwise] は山なりと同じ向き(右へ進むなら時計回り)。
Offset raiLoopOffset(double progress, {required RaiMotionPlan? plan, required double radius, bool clockwise = true}) {
  if (plan == null) return Offset.zero;
  final t = progress.clamp(0.0, 1.0);
  final startEnd = plan.steps.first.fraction;
  final stopStart = 1 - plan.steps.last.fraction;
  double phase;
  if (t < startEnd) {
    phase = t / startEnd;
  } else if (t >= stopStart && t < 1) {
    phase = (t - stopStart) / (1 - stopStart);
  } else {
    return Offset.zero;
  }
  final a = 2 * math.pi * phase * (clockwise ? 1 : -1);
  // 円の上端から出発して 1 周(出発点に戻る)。
  return Offset(radius * math.sin(a), radius * (1 - math.cos(a)) * -1);
}

/// 3D の接線(地面に平行な成分)→ ヨー (D-199): モデルは yaw 0 でカメラ(+z)を向くので、進む向き (tx, tz) を
/// 向くヨーは atan2(tx, tz)。手前へ来る = 正面 0、右へ = +90°、奥へ = 180°。
double raiYaw3(double tx, double tz) => (tx.abs() + tz.abs()) < 1e-6 ? 0 : math.atan2(tx, tz);

/// [prev] から連続な角度で [target] へ(±π で折り返さない)。
double raiUnwrap(double prev, double target) => prev + raiYawDelta(prev, target);

/// 走行中の顔の向きを、直前の向き [prev] に近い方の候補(接線 ±90°)で選び、prev から連続な角度で返す (D-198)。
double raiFaceYawNear(Offset tangent, double prev, {RaiArm arm = RaiArm.none}) {
  if (tangent.distance < 0.01) return prev;
  final t = raiTangentYaw(tangent);
  final a = raiWrap(t + math.pi / 2);
  final b = raiWrap(t - math.pi / 2);
  final da = raiYawDelta(prev, a);
  final db = raiYawDelta(prev, b);
  if ((da.abs() - db.abs()).abs() < 1e-6) return prev + raiYawDelta(prev, raiFaceYaw(tangent, arm: arm));
  return prev + (da.abs() < db.abs() ? da : db);
}

/// 移動中のヨー (D-195 → D-198): 起動の段で出発側の向きから走行の顔(接線と直交)へ、走行中はその顔、
/// 停止の段でその場で到着側の向き(到着時に上げる腕が基準)に合わせる。短距離も同じ。
/// [face] に直前のフレームの「走行の顔」(`raiFaceYawNear` で追った連続な角度)を渡すと、地面に垂直な軸まわりで
/// **スプラインの延長として途切れなく** 回る(候補の切り替えで跳ねない、±π の折り返しもしない)。
/// a → b を [dir] の向き(+1 = 正の向き、−1 = 負の向き)で回るときの差。ほぼ 0 なら 0(1 周しない)。
double raiYawDeltaDir(double a, double b, double dir) {
  var d = (b - a) % (2 * math.pi);
  if (d < 0) d += 2 * math.pi; // 0..2π
  if (dir < 0) d = d - 2 * math.pi; // −2π..0
  if (d.abs() > 2 * math.pi - 0.05) return 0;
  return d;
}

double raiYawAt(double progress, {required RaiMotionPlan? plan, required Offset tangent, required RaiArm armFrom, required RaiArm armTo, double? face, double stopTurn = 0}) {
  final t = progress.clamp(0.0, 1.0);
  final restTo0 = raiRestYawFor(armTo);
  final f = face ?? raiFaceYaw(tangent, arm: armTo);
  // 停止の旋回の向き (D-198): 山なりと同じ向きで回り続ける(0 なら最短)。向きを固定すると、顔が到着側の
  // 真裏を通るときに最短側が入れ替わって跳ねる問題が無い。
  double toRest(double from) => stopTurn == 0 ? raiYawDelta(from, restTo0) : raiYawDeltaDir(from, restTo0, stopTurn);
  if (plan == null || t >= 1) return face == null ? restTo0 : f + toRest(f);
  final restFrom = raiRestYawFor(armFrom);
  double smooth(double x) => x * x * (3 - 2 * x);
  final startEnd = plan.steps.first.fraction;
  final stopStart = 1 - plan.steps.last.fraction;
  if (t < startEnd) return restFrom + raiYawDelta(restFrom, f) * smooth(t / startEnd);
  if (t < stopStart) return f;
  return f + toRest(f) * smooth((t - stopStart) / (1 - stopStart));
}
