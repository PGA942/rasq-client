import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Renders one MFM decoration function around inline content
/// (`rsl-span.schema.json` の `transform` スパン)。
///
/// Core set every host must render (PROTOCOL §2.3):
/// `x2 x3 x4 small blur rotate flip fg bg center shake spin jump bounce
/// rainbow twitch jelly tada plain` — anything else renders [child]
/// unchanged. Text-styling fns (`fg` / `small` / `x2..x4`) are applied via
/// [childStyle] so the inner text lays out at its real size; geometric and
/// animated fns wrap the child widget.
///
/// Animations respect `MediaQuery.disableAnimations` (アクセシビリティ /
/// ホストのモーション設定) and degrade to the static frame.
class RasqMfmTransform extends StatefulWidget {
  const RasqMfmTransform({super.key, required this.fn, this.args = const {}, required this.child});

  final String fn;
  final Map<String, Object?> args;
  final Widget child;

  static const Set<String> coreSet = {
    'x2', 'x3', 'x4', 'small', 'blur', 'rotate', 'flip', 'fg', 'bg', 'center', //
    'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada', 'plain',
  };

  /// Style adjustments a transform applies to its inline children.
  static TextStyle childStyle(String fn, Map<String, Object?> args, TextStyle base) {
    final size = base.fontSize ?? 15;
    return switch (fn) {
      'x2' => base.copyWith(fontSize: size * 2),
      'x3' => base.copyWith(fontSize: size * 3),
      'x4' => base.copyWith(fontSize: size * 4),
      'small' => base.copyWith(fontSize: size * 0.8),
      'fg' => base.copyWith(color: _color(args['color']) ?? base.color),
      _ => base,
    };
  }

  static Color? _color(Object? hex) {
    if (hex == null) return null;
    final s = hex.toString().replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return switch (s.length) {
      3 => Color(0xFF000000 | ((v >> 8) & 0xF) * 0x110000 | ((v >> 4) & 0xF) * 0x1100 | (v & 0xF) * 0x11),
      6 => Color(0xFF000000 | v),
      8 => Color(v),
      _ => null,
    };
  }

  /// `speed` arg (`"1.5s"` / `1.5` / `"0.5"`) → duration; [fallback] otherwise.
  static Duration speedOf(Map<String, Object?> args, Duration fallback) {
    final raw = args['speed'];
    if (raw == null) return fallback;
    final seconds = double.tryParse(raw.toString().replaceFirst(RegExp(r's$'), ''));
    if (seconds == null || seconds <= 0) return fallback;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  State<RasqMfmTransform> createState() => _RasqMfmTransformState();
}

class _RasqMfmTransformState extends State<RasqMfmTransform> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  static const _animated = {'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantsAnimation = _animated.contains(widget.fn) && !MediaQuery.disableAnimationsOf(context);
    if (wantsAnimation && _controller == null) {
      _controller = AnimationController(vsync: this, duration: RasqMfmTransform.speedOf(widget.args, _defaultSpeed(widget.fn)))..repeat();
    } else if (!wantsAnimation) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static Duration _defaultSpeed(String fn) => switch (fn) {
        'spin' => const Duration(milliseconds: 1500),
        'rainbow' => const Duration(seconds: 2),
        'shake' || 'twitch' => const Duration(milliseconds: 500),
        _ => const Duration(milliseconds: 750),
      };

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final args = widget.args;
    switch (widget.fn) {
      // Styling fns are handled in childStyle; nothing to wrap.
      case 'x2' || 'x3' || 'x4' || 'small' || 'fg' || 'plain':
        return child;
      case 'bg':
        return ColoredBox(color: RasqMfmTransform._color(args['color']) ?? Colors.transparent, child: child);
      case 'blur':
        return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: child);
      case 'rotate':
        final deg = (args['deg'] as num?)?.toDouble() ?? 90;
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      case 'flip':
        final v = args['v'] == true;
        final h = args['h'] == true || !v;
        return Transform.flip(flipX: h, flipY: v, child: child);
      case 'center':
        return Align(alignment: Alignment.center, child: child);
    }

    final controller = _controller;
    if (controller == null) return child; // animations off → static frame

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, animatedChild) {
        final t = controller.value;
        final wave = math.sin(t * 2 * math.pi);
        return switch (widget.fn) {
          'spin' => Transform.rotate(angle: t * 2 * math.pi * (widget.args['left'] == true ? -1 : 1), child: animatedChild),
          'jump' => Transform.translate(offset: Offset(0, -4 * wave.abs()), child: animatedChild),
          'bounce' => Transform.translate(offset: Offset(0, 3 * wave), child: animatedChild),
          'shake' => Transform.translate(offset: Offset(1.5 * wave, 1.2 * math.cos(t * 6 * math.pi)), child: animatedChild),
          'twitch' => Transform.translate(offset: Offset(2 * math.sin(t * 10 * math.pi), 0), child: animatedChild),
          'jelly' => Transform.scale(scaleX: 1 + 0.12 * wave, scaleY: 1 - 0.12 * wave, child: animatedChild),
          'tada' => Transform.scale(scale: 1 + 0.15 * wave.abs(), child: Transform.rotate(angle: 0.05 * wave, child: animatedChild)),
          'rainbow' => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                transform: GradientRotation(t * 2 * math.pi),
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: animatedChild,
            ),
          _ => animatedChild!,
        };
      },
    );
  }
}
