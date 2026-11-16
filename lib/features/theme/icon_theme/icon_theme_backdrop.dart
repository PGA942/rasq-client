import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'icon_theme_codec.dart';
import 'rasq_theme_spec.dart';
import 'theme_frames.dart';

/// テーマの背景 (D-564): 背景の色 / グラデーション(拡張のアニメ)・テーマフレーム(SVG)・パーティクル(常時のスロットは
/// 流れ続け、クリック / スライドのスロットは押した / なぞった所から出る)。仮組みの「閲覧する」の描き方を写した。
/// 「動きを減らす」(端末の設定)では、止めた 1 枚だけを描く。
class IconThemeBackdrop extends StatefulWidget {
  const IconThemeBackdrop({super.key, required this.spec, this.child});
  final RasqThemeSpec spec;

  /// 上に重ねる中身(押す / なぞるのは、この中のボタンなどに当たらなかったときだけパーティクルを出す)。
  final Widget? child;

  @override
  State<IconThemeBackdrop> createState() => _IconThemeBackdropState();
}

Color themeColor(List<int> c) => Color.fromARGB(255, c[0], c[1], c[2]);

/// HSL で色相 / 明るさをずらす(仮組みの shift)。
Color _shift(List<int> c, double dh, double dl) {
  final h = iconThemeRgbToHsl(c);
  final rgb = iconThemeHslToRgb([h[0] + dh, h[1], math.min(0.95, math.max(0.03, h[2] + dl))]);
  return themeColor(rgb);
}

List<int> _shiftRgb(List<int> c, double dh, double dl) {
  final h = iconThemeRgbToHsl(c);
  return iconThemeHslToRgb([h[0] + dh, h[1], math.min(0.95, math.max(0.03, h[2] + dl))]);
}

/// 背景の塗り(仮組みの bgCss)。[angle] = 度(null なら種類ごとの既定)、[hue] / [light] = アニメのゆらぎ。
Decoration iconThemeBackground(IconThemeBasic t, {double? angle, double hue = 0, double light = 0}) {
  final b = _shiftRgb(t.bg, hue, light);
  if (t.bgMode != IconThemeBg.gradient) return BoxDecoration(color: themeColor(b));
  // CSS の角度(0deg = 上へ、時計回り)→ Flutter の始点 / 終点。
  (Alignment, Alignment) dir(double deg) {
    final r = deg * math.pi / 180;
    final v = Offset(math.sin(r), -math.cos(r));
    return (Alignment(-v.dx, -v.dy), Alignment(v.dx, v.dy));
  }

  switch (t.gradient % 4) {
    case 0:
      final (s, e) = dir(angle ?? 180);
      return BoxDecoration(gradient: LinearGradient(begin: s, end: e, colors: [themeColor(b), _shift(b, 0, -0.14)]));
    case 1:
      final (s, e) = dir(angle ?? 135);
      return BoxDecoration(gradient: LinearGradient(begin: s, end: e, colors: [themeColor(b), _shift(b, 55, 0.04)]));
    case 2:
      final r = angle == null ? 0.0 : angle * math.pi / 180;
      final cx = angle == null ? 0.0 : 0.64 * math.sin(r), cy = angle == null ? -0.4 : -0.64 * math.cos(r);
      return BoxDecoration(gradient: RadialGradient(center: Alignment(cx, cy), radius: 1.1, colors: [_shift(b, 0, 0.16), themeColor(b), _shift(b, 0, -0.08)], stops: const [0, 0.55, 1]));
    default:
      final (s, e) = dir(angle ?? 160);
      return BoxDecoration(gradient: LinearGradient(begin: s, end: e, colors: [_shift(b, -45, 0.06), themeColor(b), _shift(b, 70, 0.02)], stops: const [0, 0.45, 1]));
  }
}

/// イージング(0 = 直線 / 1 = イーズ / 2 = バネ / 3 = ガム)。
double _ease(int k, double t) => switch (k) {
      0 => t,
      1 => t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2,
      2 => 1 - math.exp(-5 * t) * math.cos(11 * t),
      _ => () {
          const c = 1.70158 * 1.525 * 1.6;
          return t < 0.5 ? (math.pow(2 * t, 2) * ((c + 1) * 2 * t - c)) / 2 : (math.pow(2 * t - 2, 2) * ((c + 1) * (t * 2 - 2) + c) + 2) / 2;
        }(),
    };

class _Slot {
  _Slot(this.s, this.path, this.shape);
  final IconThemeSlot s;
  final List<int> path;
  final Path? shape;
  double blend(double t) {
    final m = s.mix / 7;
    return (1 - m) * _ease(s.easeA, t) + m * _ease(s.easeB, t);
  }
}

class _Particle {
  _Particle(this.slot, this.p, {required this.t0, required this.off, required this.size, required this.ph, required this.rate, required this.alpha, this.x = 0, this.y = 0, this.born = 0, this.dur = 1});
  final _Slot slot;
  final List<double> p;
  final double t0, off, size, ph, rate, alpha;
  final double x, y, born, dur;
}

const _fallPath = [16, 0, 16, 16, 16, 31];

Path _toPath(List<IconThemeCmd> shape) {
  final p = Path();
  for (final c in shape) {
    final a = [for (final v in c.args) v - 16.0];
    switch (c.op) {
      case 'M':
        p.moveTo(a[0], a[1]);
      case 'L':
        p.lineTo(a[0], a[1]);
      case 'Q':
        p.quadraticBezierTo(a[0], a[1], a[2], a[3]);
      default:
        p.close();
    }
  }
  return p;
}

class _IconThemeBackdropState extends State<IconThemeBackdrop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _rnd = math.Random();
  final _elapsed = ValueNotifier<double>(0);
  List<_Slot> _slots = const [];
  List<_Particle> _loops = const [];
  final List<_Particle> _shots = [];
  Offset? _down;
  bool _moved = false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _ticker.stop();
      _elapsed.value = 4;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(IconThemeBackdrop old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec) _build();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final now = d.inMicroseconds / 1e6;
    _shots.removeWhere((p) => now - p.born > p.dur);
    _elapsed.value = now;
  }

  double _jitter(IconThemeSlot s) => (_rnd.nextDouble() - 0.5) * 2 * s.angleRand * 6 * math.pi / 180;

  static List<double> _turn(List<double> p, double ang, double cx, double cy) {
    final c = math.cos(ang), n = math.sin(ang);
    return [
      for (var i = 0; i < 6; i += 2) ...[cx + (p[i] - cx) * c - (p[i + 1] - cy) * n, cy + (p[i] - cx) * n + (p[i + 1] - cy) * c],
    ];
  }

  void _build() {
    final t = widget.spec.basic, ext = widget.spec.ext;
    final shapes = ext == null || ext.isUrl ? const <Path>[] : [for (final s in ext.shapes) _toPath(s)];
    _slots = ext != null && !ext.isUrl
        ? [for (final s in ext.slots) _Slot(s, ext.paths[s.path], shapes[s.shape])]
        // 拡張が無いとき: 常時の丸い粒のスロットを 1 つ。
        : t.particle != 0
            ? [_Slot(const IconThemeSlot(trigger: IconThemeTrigger.always, shape: 0, path: 0, rand: 15, sway: 4), _fallPath, null)]
            : const [];
    final always = _slots.where((s) => s.s.trigger == IconThemeTrigger.always).toList();
    final n = always.isEmpty ? 0 : (t.amount * 4 / always.length).round();
    _loops = [
      for (final s in always)
        for (var i = 0; i < n; i++)
          _Particle(s, _turn([for (final v in s.path) v.toDouble()], _jitter(s.s), 15.5, 15.5),
              t0: _rnd.nextDouble(), off: 0.5 + (_rnd.nextDouble() - 0.5) * (s.s.rand + 1) / 16, size: 10 + _rnd.nextDouble() * 16, ph: _rnd.nextDouble() * 6.28, rate: 0.7 + _rnd.nextDouble() * 0.6, alpha: 0.35 + _rnd.nextDouble() * 0.5),
    ];
    _shots.clear();
  }

  void _spawn(IconThemeTrigger trig, Offset at, int count) {
    if (_still) return;
    final now = _elapsed.value;
    for (final s in _slots) {
      if (s.s.trigger != trig) continue;
      for (var i = 0; i < count; i++) {
        final r = _rnd.nextDouble() * (4 + s.s.rand * 7), a = _rnd.nextDouble() * 6.28;
        final p = [for (final v in s.path) v.toDouble()];
        _shots.add(_Particle(s, _turn(p, _jitter(s.s), p[0], p[1]),
            t0: 0, off: 0, x: at.dx + math.cos(a) * r, y: at.dy + math.sin(a) * r, born: now, dur: (2.6 - widget.spec.basic.speed * 0.11) * (0.75 + _rnd.nextDouble() * 0.5), size: 12 + _rnd.nextDouble() * 16, ph: _rnd.nextDouble() * 6.28, rate: 1, alpha: 0.55 + _rnd.nextDouble() * 0.4));
      }
    }
    if (_shots.length > 400) _shots.removeRange(0, _shots.length - 400);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec, ext = spec.ext;
    final baseAngle = ext == null || ext.isUrl ? null : ext.angle * 22.5;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _down = e.localPosition;
        _moved = false;
      },
      onPointerMove: (e) {
        final d = _down;
        if (d == null) return;
        if ((e.localPosition - d).distance > 22) {
          _moved = true;
          _down = e.localPosition;
          _spawn(IconThemeTrigger.slide, e.localPosition, 1);
        }
      },
      onPointerUp: (e) {
        if (_down != null && !_moved) _spawn(IconThemeTrigger.tap, e.localPosition, 4 + spec.basic.amount);
        _down = null;
      },
      onPointerCancel: (_) => _down = null,
      child: Stack(fit: StackFit.expand, children: [
        ValueListenableBuilder<double>(
          valueListenable: _elapsed,
          builder: (_, el, _) {
            var angle = baseAngle;
            var hue = 0.0, light = 0.0;
            if (ext != null && !ext.isUrl && ext.anim != 0 && !_still) {
              final ph = el * (0.15 + ext.animSpeed * 0.14);
              if (ext.anim == 1) {
                angle = (angle ?? 0) + ph * 40;
              } else if (ext.anim == 2) {
                hue = math.sin(ph) * 28;
              } else {
                light = math.sin(ph * 1.6) * 0.07;
              }
            }
            return DecoratedBox(key: const ValueKey('iconTheme.background'), decoration: iconThemeBackground(spec.basic, angle: angle, hue: hue, light: light));
          },
        ),
        if (spec.frames.isNotEmpty) ThemeFramesLayer(frames: spec.frames, tint: themeColor(spec.basic.accent)),
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('iconTheme.particles'),
            painter: _ParticlePainter(this),
          ),
        ),
        ?widget.child,
      ]),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.state) : super(repaint: state._elapsed);
  final _IconThemeBackdropState state;

  @override
  void paint(Canvas canvas, Size size) {
    final el = state._elapsed.value;
    final t = state.widget.spec.basic;
    final paint = Paint()..color = themeColor(t.accent);
    final base = 0.03 + t.speed * 0.012;
    final w = size.width, h = size.height;
    void draw(_Slot s, double x, double y, double sz, double rot, double alpha) {
      paint.color = themeColor(t.accent).withValues(alpha: alpha.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      if (s.shape != null) {
        canvas.rotate(rot);
        canvas.scale(sz / 32, sz / 32);
        canvas.drawPath(s.shape!, paint);
      } else {
        canvas.drawCircle(Offset.zero, sz / 5, paint);
      }
      canvas.restore();
    }

    List<double> bez(List<double> p, double e) {
      final u = 1 - e;
      return [u * u * p[0] + 2 * u * e * p[2] + e * e * p[4], u * u * p[1] + 2 * u * e * p[3] + e * e * p[5]];
    }

    for (final p in state._loops) {
      final s = p.slot, path = p.p;
      final vertical = (path[5] - path[1]).abs() >= (path[4] - path[0]).abs();
      final b = bez(path, s.blend((p.t0 + el * base * p.rate) % 1));
      final sw = s.s.sway * 2.2 * math.sin(el * 1.3 + p.ph);
      var x = b[0] / 31, y = b[1] / 31;
      if (vertical) {
        x = (((x - 0.5 + p.off) * w + sw) % w + w) % w;
        y = y * (h + 60) - 30;
      } else {
        y = (((y - 0.5 + p.off) * h + sw) % h + h) % h;
        x = x * (w + 60) - 30;
      }
      draw(s, x, y, p.size, p.ph + el * s.s.spin * 0.25, p.alpha);
    }
    for (final p in state._shots) {
      final s = p.slot, path = p.p, tt = ((el - p.born) / p.dur).clamp(0.0, 1.0);
      final b = bez(path, s.blend(tt));
      final x = p.x + (b[0] - path[0]) / 31 * w * 0.5, y = p.y + (b[1] - path[1]) / 31 * h * 0.42 + s.s.sway * 1.2 * math.sin(tt * 6 + p.ph);
      draw(s, x, y, p.size, p.ph + tt * s.s.spin * 1.2, p.alpha * (1 - tt * tt * tt));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.state != state;
}
