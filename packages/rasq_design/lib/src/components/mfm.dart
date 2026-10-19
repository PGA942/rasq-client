import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, Icons, Icon, Colors;

import 'timestamp.dart';

/// MFM の描画の文脈 (D-509)。[RasqRichText] が入れ子の段へ渡す(Misskey の CSS で「継承」されるもの)。
@immutable
class RasqMfmContext {
  const RasqMfmContext({this.zoomDepth = 0, this.emojiEm = 1.25, this.textAlign = TextAlign.start, this.opacity = 1.0, this.hideEmoji = false, this.transparentText = false});

  /// `x2` / `x3` / `x4` の入れ子の深さ(Misskey の `.mfm-x2 .mfm-x2` = 半分だけ、3 段目からは効かない)。
  final int zoomDepth;

  /// カスタム絵文字の高さ(em)。MFM の関数を含む本文は Misskey のノートと同じ 2em。
  final double emojiEm;

  /// `text-align`(`<center>` の中は中央。インラインブロックの中にも継承される)。
  final TextAlign textAlign;

  /// `<small>` の `opacity: 0.7` の積み重ね。
  final double opacity;

  /// 虹色(静止)の 2 枚重ね用: 絵文字を透明に / 文字を透明に。
  final bool hideEmoji;
  final bool transparentText;

  RasqMfmContext copyWith({int? zoomDepth, double? emojiEm, TextAlign? textAlign, double? opacity, bool? hideEmoji, bool? transparentText}) => RasqMfmContext(
        zoomDepth: zoomDepth ?? this.zoomDepth,
        emojiEm: emojiEm ?? this.emojiEm,
        textAlign: textAlign ?? this.textAlign,
        opacity: opacity ?? this.opacity,
        hideEmoji: hideEmoji ?? this.hideEmoji,
        transparentText: transparentText ?? this.transparentText,
      );
}

/// Renders one MFM decoration function around inline content
/// (`rsl-span.schema.json` の `transform` スパン)。
///
/// Misskey(frontend-shared の mfm-renderer と style.scss)に合わせる (D-509):
/// - 関数ごとに `display: inline-block` の箱を作り、その箱に transform / animation を掛ける(入れ子の変形は
///   箱ごとに中心を原点に合成される。`bounce` だけ原点が下の中央)。
/// - `position` は em(その箱の文字の大きさ)、`scale` は 5 まで、`rotate` は度(既定 90)。
/// - アニメーションは Misskey の @keyframes を写したもの(`spin` / `jump` / `bounce` / `twitch` / `shake` / `jelly` /
///   `tada` / `rainbow`、`speed` / `delay`、`spin` の `left` / `alternate` / `x` / `y`)。`twitch` / `shake` は区間ごとに
///   ease、ほかは linear。
/// - 動きを止める設定([motion] / `MediaQuery.disableAnimations`)は Misskey の「MFM のアニメーション」オフと同じ:
///   動きなしの静止(`rainbow` は文字にグラデーション、`sparkle` は中身だけ、`tada` の 150% は残る)。
///
/// `x2..x4` / `small` / `plain` / `clickable` は箱を作らない(Misskey でも普通の span)。[RasqRichText] が
/// 文字の大きさ・色だけ変えて行の中に流す。知らない関数は中身をそのまま(RSL の前方互換)。
class RasqMfmTransform extends StatefulWidget {
  const RasqMfmTransform({super.key, required this.fn, this.args = const {}, required this.child, this.style, this.layer});

  final String fn;
  final Map<String, Object?> args;
  final Widget child;

  /// 箱の中の文字の様式([childStyle] 済み)。`position` の em・`ruby` の読み・`unixtime` に使う。
  final TextStyle? style;

  /// 中身を別の文脈で作り直す(`rainbow` の静止 = 文字だけグラデーションにする 2 枚重ね)。
  final Widget Function(RasqMfmContext Function(RasqMfmContext) adjust)? layer;

  static const Set<String> coreSet = {
    'x2', 'x3', 'x4', 'small', 'blur', 'rotate', 'flip', 'fg', 'bg', 'center', //
    'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada', 'plain',
  };

  /// Misskey の描画が知っている関数(MFM の `$[…]`)。
  static const Set<String> misskeyFns = {
    'tada', 'jelly', 'twitch', 'shake', 'spin', 'jump', 'bounce', 'flip', 'x2', 'x3', 'x4', 'font', 'blur', 'rainbow', //
    'sparkle', 'rotate', 'position', 'scale', 'fg', 'bg', 'border', 'ruby', 'unixtime', 'clickable',
  };

  /// 箱(inline-block)を作らず、文字の様式だけ変えて行に流す関数。
  static const Set<String> inlineFns = {'x2', 'x3', 'x4', 'small', 'plain', 'clickable'};

  /// 行を占める箱(ブロック)。
  static const Set<String> blockFns = {'center', 'quote', 'code_block', 'search'};

  /// 箱(inline-block)を作る関数。
  static const Set<String> boxFns = {
    'tada', 'jelly', 'twitch', 'shake', 'spin', 'jump', 'bounce', 'flip', 'font', 'blur', 'rainbow', 'sparkle', //
    'rotate', 'position', 'scale', 'fg', 'bg', 'border', 'ruby', 'unixtime',
  };

  static const _animated = {'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada', 'sparkle'};

  /// `x2` / `x3` / `x4` の倍率(Misskey: 200% / 400% / 600%、入れ子の 2 段目は `/ 2 + 50%`、3 段目からは 100%)。
  static double zoomOf(String fn, int depth) {
    final z = switch (fn) { 'x2' => 2.0, 'x3' => 4.0, 'x4' => 6.0, _ => 1.0 };
    if (depth == 0) return z;
    if (depth == 1) return z / 2 + 0.5;
    return 1.0;
  }

  /// Style adjustments a transform applies to its inline children.
  static TextStyle childStyle(String fn, Map<String, Object?> args, TextStyle base, {int zoomDepth = 0}) {
    final size = base.fontSize ?? 15;
    return switch (fn) {
      'x2' || 'x3' || 'x4' => base.copyWith(fontSize: size * zoomOf(fn, zoomDepth)),
      // `<small>` = font-size: smaller(1/1.2)。opacity は [RasqMfmContext.opacity]。
      'small' => base.copyWith(fontSize: size / 1.2),
      'tada' => base.copyWith(fontSize: size * 1.5),
      'unixtime' => base.copyWith(fontSize: size * 0.9),
      // fg: 色が読めなければ f00(Misskey)。`#abcde` のような CSS で無効な色は継承。
      'fg' => base.copyWith(color: validColor(args['color']) == null ? const Color(0xFFFF0000) : (cssHexColor(validColor(args['color'])!) ?? base.color)),
      'font' => base.copyWith(fontFamily: fontFamilyOf(args)),
      _ => base,
    };
  }

  /// `font` の書体(Misskey の順: serif → monospace → cursive → fantasy → emoji → math)。
  static String? fontFamilyOf(Map<String, Object?> args) {
    for (final f in const ['serif', 'monospace', 'cursive', 'fantasy', 'emoji', 'math']) {
      if (args[f] != null && args[f] != false) return f;
    }
    return null;
  }

  /// Misskey の `validColor`(`/^[0-9a-f]{3,6}$/i`)。
  static String? validColor(Object? c) {
    if (c == null || c is bool) return null;
    final s = c.toString();
    return RegExp(r'^[0-9a-f]{3,6}$', caseSensitive: false).hasMatch(s) ? s : null;
  }

  /// CSS の `#rgb` / `#rgba` / `#rrggbb`(5 桁は無効 = null)。
  static Color? cssHexColor(String s) {
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    int nib(int i) => ((v >> (4 * i)) & 0xF) * 0x11;
    return switch (s.length) {
      3 => Color.fromARGB(0xFF, nib(2), nib(1), nib(0)),
      4 => Color.fromARGB(nib(0), nib(3), nib(2), nib(1)),
      6 => Color(0xFF000000 | v),
      _ => null,
    };
  }

  static Color? _color(Object? c) {
    final s = validColor(c);
    return s == null ? null : cssHexColor(s);
  }

  /// JS の `parseFloat`(先頭の数だけ読む。文字列以外の数はそのまま)。Misskey の `safeParseFloat`。
  static double? parseNum(Object? v) {
    if (v is num) return v.toDouble();
    if (v is! String || v.isEmpty) return null;
    final s = v.trimLeft();
    if (s.startsWith('Infinity') || s.startsWith('+Infinity')) return double.infinity;
    if (s.startsWith('-Infinity')) return double.negativeInfinity;
    final m = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m[0]!);
  }

  /// Misskey の `validTime`(`/^-?[0-9.]+s$/`)→ 秒。数(RSL の wire)はそのまま秒。
  static double? timeOf(Object? v) {
    if (v is num) return v.toDouble();
    if (v is! String || !RegExp(r'^-?[0-9.]+s$').hasMatch(v)) return null;
    return double.tryParse(v.substring(0, v.length - 1));
  }

  /// `speed` arg (`"1.5s"` / `1.5`) → duration; [fallback] otherwise.
  static Duration speedOf(Map<String, Object?> args, Duration fallback) {
    final seconds = timeOf(args['speed']);
    if (seconds == null || seconds <= 0) return fallback;
    return Duration(microseconds: (seconds * 1e6).round());
  }

  /// 各アニメーションの既定の長さ(Misskey)。
  static Duration defaultSpeed(String fn) => switch (fn) {
        'spin' => const Duration(milliseconds: 1500),
        'twitch' || 'shake' => const Duration(milliseconds: 500),
        'jump' || 'bounce' => const Duration(milliseconds: 750),
        _ => const Duration(seconds: 1), // tada / jelly / rainbow
      };

  /// アプリの設定 (D-238「カスタムモーションとアニメーション」): 動く装飾を再生するか / 速さの倍率(1.0 = 標準)。
  /// ホストが起動時と設定変更時に書き換える。変更は表示中の装飾にもすぐ効く。
  static final ValueNotifier<({bool enabled, double speed})> motion = ValueNotifier((enabled: true, speed: 1.0));

  /// [fn] の、経過 [seconds] 秒の時点の変形(静止の変形を含む。動かないなら単位行列)。テストとプレビューでも使う。
  static Matrix4 transformAt(String fn, Map<String, Object?> args, double seconds, {double em = 15, bool animate = true}) {
    switch (fn) {
      case 'rotate':
        return Matrix4.rotationZ((parseNum(args['deg']) ?? 90) * math.pi / 180);
      case 'position':
        return Matrix4.translationValues((parseNum(args['x']) ?? 0) * em, (parseNum(args['y']) ?? 0) * em, 0);
      case 'scale':
        return Matrix4.diagonal3Values(math.min(parseNum(args['x']) ?? 1, 5), math.min(parseNum(args['y']) ?? 1, 5), 1);
      case 'flip':
        final h = args['h'] != null && args['h'] != false;
        final v = args['v'] != null && args['v'] != false;
        return h && v ? Matrix4.diagonal3Values(-1, -1, 1) : (v ? Matrix4.diagonal3Values(1, -1, 1) : Matrix4.diagonal3Values(-1, 1, 1));
    }
    if (!animate) return Matrix4.identity();
    final p = _progress(fn, args, seconds);
    if (p == null) return Matrix4.identity();
    if (fn == 'spin') {
      final rad = p * 2 * math.pi;
      if (args['x'] != null && args['x'] != false) return _perspective()..multiply(Matrix4.rotationX(rad));
      if (args['y'] != null && args['y'] != false) return _perspective()..multiply(Matrix4.rotationY(rad));
      return Matrix4.rotationZ(rad);
    }
    final frames = _keyframes[fn];
    if (frames == null) return Matrix4.identity();
    return _sample(frames, p, ease: fn == 'twitch' || fn == 'shake').matrix;
  }

  /// CSS の `perspective(128px)`。
  static Matrix4 _perspective() => Matrix4.identity()..setEntry(3, 2, -1 / 128);

  /// CSS のアニメーションの進み(0..1、`animation-direction` 込み)。遅延の前・長さ 0 以下は null(動かない)。
  static double? _progress(String fn, Map<String, Object?> args, double seconds) {
    final speed = motion.value.speed <= 0 ? 1.0 : motion.value.speed;
    final durRaw = timeOf(args['speed']) ?? defaultSpeed(fn).inMicroseconds / 1e6;
    if (durRaw <= 0) return null;
    final dur = durRaw / speed;
    final delay = (timeOf(args['delay']) ?? 0) / speed;
    final local = seconds - delay;
    if (local < 0) return null;
    final iteration = (local / dur).floor();
    final frac = local / dur - iteration;
    if (fn == 'spin') {
      if (args['left'] != null && args['left'] != false) return 1 - frac;
      if (args['alternate'] != null && args['alternate'] != false) return iteration.isOdd ? 1 - frac : frac;
    }
    return frac;
  }

  /// `rainbow`(`hue-rotate(θ) contrast(150%) saturate(150%)`)の色の行列。
  static List<double> rainbowMatrix(double deg) {
    final a = deg * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    final hue = <double>[
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283,
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072,
    ];
    const k = 1.5; // saturate
    const sat = <double>[
      0.213 + 0.787 * k, 0.715 - 0.715 * k, 0.072 - 0.072 * k, //
      0.213 - 0.213 * k, 0.715 + 0.285 * k, 0.072 - 0.072 * k,
      0.213 - 0.213 * k, 0.715 - 0.715 * k, 0.072 + 0.928 * k,
    ];
    const contrast = 1.5;
    // saturate · contrast · hue。contrast の足し算は saturate の行の和が 1 なのでそのまま。
    final out = <double>[];
    for (var r = 0; r < 3; r++) {
      for (var col = 0; col < 3; col++) {
        var v = 0.0;
        for (var i = 0; i < 3; i++) {
          v += sat[r * 3 + i] * hue[i * 3 + col];
        }
        out.add(v * contrast);
      }
      out.addAll([0, (0.5 - 0.5 * contrast) * 255]);
    }
    out.addAll([0, 0, 0, 1, 0]);
    return out;
  }

  @override
  State<RasqMfmTransform> createState() => _RasqMfmTransformState();
}

// ── キーフレーム(Misskey の style.scss) ─────────────────────────────────────

class _Frame {
  const _Frame(this.at, {this.tx = 0, this.ty = 0, this.sx = 1, this.sy = 1, this.rot = 0});
  final double at;
  final double tx, ty, sx, sy, rot; // px / 倍率 / 度

  /// CSS の `translate(tx, ty) scale(sx, sy) rotate(rot)`(この順の合成)。
  Matrix4 get matrix => Matrix4.translationValues(tx, ty, 0)
    ..multiply(Matrix4.diagonal3Values(sx, sy, 1))
    ..multiply(Matrix4.rotationZ(rot * math.pi / 180));
}

_Frame _sample(List<_Frame> frames, double p, {required bool ease}) {
  for (var i = 0; i < frames.length - 1; i++) {
    final a = frames[i], b = frames[i + 1];
    if (p >= a.at && p <= b.at) {
      var t = b.at == a.at ? 1.0 : (p - a.at) / (b.at - a.at);
      if (ease) t = Curves.ease.transform(t.clamp(0.0, 1.0));
      double l(double x, double y) => x + (y - x) * t;
      return _Frame(p, tx: l(a.tx, b.tx), ty: l(a.ty, b.ty), sx: l(a.sx, b.sx), sy: l(a.sy, b.sy), rot: l(a.rot, b.rot));
    }
  }
  return frames.last;
}

List<_Frame> _translateFrames(List<List<double>> xy) => [for (var i = 0; i < xy.length; i++) _Frame(i * 0.05, tx: xy[i][0], ty: xy[i][1])];

final Map<String, List<_Frame>> _keyframes = {
  'jump': const [_Frame(0), _Frame(0.25, ty: -16), _Frame(0.5), _Frame(0.75, ty: -8), _Frame(1)],
  'bounce': const [_Frame(0), _Frame(0.25, ty: -16), _Frame(0.5), _Frame(0.75, sx: 1.5, sy: 0.75), _Frame(1)],
  // mfm-twitch(0% から 5% 刻み)
  'twitch': _translateFrames(const [
    [7, -2], [-3, 1], [-7, -1], [0, -1], [-8, 6], [-4, -3], [-4, -6], [-8, -8], [4, 6], [-3, 1], [2, -10], //
    [-7, 0], [-2, 4], [3, -8], [6, 7], [-7, -2], [-7, -8], [9, 3], [-3, -2], [-10, 2], [-2, -6],
  ]),
  // mfm-shake(translate + rotate、5% 刻み)
  'shake': [
    for (final (i, f) in const <List<double>>[
      [-3, -1, -8], [0, -1, -10], [1, -3, 0], [1, 1, 11], [-2, 1, 1], [-1, -2, -2], [-1, 2, -3], [2, 1, 6], [-2, -3, -9], //
      [0, -1, -12], [1, 2, 10], [0, -3, 8], [1, -1, 8], [0, -1, -7], [-1, -3, 6], [0, -2, 4], [-2, -1, 3], [1, -3, -10],
      [1, 0, 3], [-2, 0, -3], [2, 1, 2],
    ].indexed)
      _Frame(i * 0.05, tx: f[0], ty: f[1], rot: f[2]),
  ],
  // mfm-rubberBand
  'jelly': const [
    _Frame(0), _Frame(0.3, sx: 1.25, sy: 0.75), _Frame(0.4, sx: 0.75, sy: 1.25), _Frame(0.5, sx: 1.15, sy: 0.85), //
    _Frame(0.65, sx: 0.95, sy: 1.05), _Frame(0.75, sx: 1.05, sy: 0.95), _Frame(1),
  ],
  // global-tada
  'tada': const [
    _Frame(0), _Frame(0.1, sx: 0.91, sy: 0.91, rot: -2), _Frame(0.2, sx: 0.91, sy: 0.91, rot: -2), //
    _Frame(0.3, sx: 1.09, sy: 1.09, rot: 2), _Frame(0.5, sx: 1.09, sy: 1.09, rot: -2), _Frame(0.7, sx: 1.09, sy: 1.09, rot: 2),
    _Frame(0.9, sx: 1.09, sy: 1.09, rot: -2), _Frame(1),
  ],
};

// ── 箱 ────────────────────────────────────────────────────────────────────

class _RasqMfmTransformState extends State<RasqMfmTransform> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _elapsed = ValueNotifier<Duration>(Duration.zero);

  @override
  void initState() {
    super.initState();
    RasqMfmTransform.motion.addListener(_onMotion);
  }

  void _onMotion() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  bool get _animate => RasqMfmTransform._animated.contains(widget.fn) && RasqMfmTransform.motion.value.enabled && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_animate) {
      _ticker ??= createTicker((elapsed) => _elapsed.value = elapsed)..start();
    } else {
      _ticker?.dispose();
      _ticker = null;
      _elapsed.value = Duration.zero;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RasqMfmTransform old) {
    super.didUpdateWidget(old);
    if (old.fn != widget.fn) _sync();
  }

  @override
  void dispose() {
    RasqMfmTransform.motion.removeListener(_onMotion);
    _ticker?.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  double get _em => widget.style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 15;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final args = widget.args;
    final animate = _ticker != null;
    switch (widget.fn) {
      case 'rotate' || 'position' || 'scale' || 'flip':
        return Transform(transform: RasqMfmTransform.transformAt(widget.fn, args, 0, em: _em), alignment: Alignment.center, child: child);
      case 'bg':
        // 読めない色は f00(Misskey)。
        return ColoredBox(color: RasqMfmTransform.validColor(args['color']) == null ? const Color(0xFFFF0000) : (RasqMfmTransform._color(args['color']) ?? Colors.transparent), child: child);
      case 'border':
        return _border(context, child);
      case 'blur':
        return _MfmBlur(child: child);
      case 'ruby':
        final style = widget.style ?? DefaultTextStyle.of(context).style;
        final rt = '${args['rt'] ?? ''}';
        // ルビ: 読みは本文の半分の大きさで上に(CSS の rt の既定 50%)。
        return _Ruby(rt: Text(rt, style: style.copyWith(fontSize: (style.fontSize ?? 15) * 0.5, height: 1), textAlign: TextAlign.center), base: child);
      case 'unixtime':
        return _unixtime(context);
      case 'rainbow' when !animate:
        // 静止の虹色: 文字だけグラデーション(background-clip: text)。絵文字はそのまま。
        final layer = widget.layer;
        if (layer == null) return child;
        return Stack(children: [
          ExcludeSemantics(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => const LinearGradient(colors: _rainbowColors, stops: [0, .17, .33, .5, .67, .83, 1]).createShader(rect),
              child: layer((c) => c.copyWith(hideEmoji: true)),
            ),
          ),
          layer((c) => c.copyWith(transparentText: true)),
        ]);
      case 'center':
        return _FullWidth(child: Align(alignment: Alignment.topCenter, child: child));
      case 'quote':
        // Misskey: margin 8px / padding 6px 0 6px 12px / 左の線 3px(文字色)/ opacity 0.7。
        final fg = DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;
        return _FullWidth(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Opacity(
              opacity: 0.7,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: fg, width: 3))),
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          ),
        );
      case 'code_block':
        return _FullWidth(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
          ),
        );
      case 'search':
        return _search(context, child);
    }
    if (!animate) return child; // 動きなし → 静止(Misskey の animatedMfm オフ)

    switch (widget.fn) {
      case 'rainbow':
        return AnimatedBuilder(
          animation: _elapsed,
          child: child,
          builder: (context, c) {
            final p = RasqMfmTransform._progress('rainbow', args, _elapsed.value.inMicroseconds / 1e6);
            if (p == null) return c!;
            return ColorFiltered(colorFilter: ColorFilter.matrix(RasqMfmTransform.rainbowMatrix(p * 360)), child: c);
          },
        );
      case 'sparkle':
        return CustomPaint(foregroundPainter: _SparklePainter(_elapsed, seed: identityHashCode(this)), child: child);
    }
    final origin = widget.fn == 'bounce' ? Alignment.bottomCenter : Alignment.center;
    return AnimatedBuilder(
      animation: _elapsed,
      child: child,
      builder: (context, c) => Transform(
        transform: RasqMfmTransform.transformAt(widget.fn, args, _elapsed.value.inMicroseconds / 1e6),
        alignment: origin,
        child: c,
      ),
    );
  }

  static const _rainbowColors = [
    Color(0xFFFF0000), Color(0xFFFFA500), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), //
  ];

  /// Misskey: `border: {width}px {style} {color}; border-radius: {radius}px;` + `overflow: clip`(`noclip` で切らない)。
  Widget _border(BuildContext context, Widget child) {
    final args = widget.args;
    final color = RasqMfmTransform._color(args['color']) ?? Theme.of(context).colorScheme.primary;
    const styles = {'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset'};
    final style = styles.contains(args['style']) ? args['style'] as String : 'solid';
    var width = RasqMfmTransform.parseNum(args['width']) ?? 1;
    if (width < 0 || !width.isFinite || style == 'hidden') width = 0; // 負は無効(枠なし)、hidden は幅 0
    final radius = math.max(0.0, RasqMfmTransform.parseNum(args['radius']) ?? 0);
    final noclip = args['noclip'] != null && args['noclip'] != false;
    return Container(
      decoration: BoxDecoration(border: width > 0 ? Border.all(color: color, width: width) : null, borderRadius: radius > 0 ? BorderRadius.circular(radius) : null),
      padding: EdgeInsets.all(width),
      child: noclip ? child : ClipRRect(borderRadius: BorderRadius.circular(math.max(0, radius - width)), child: child),
    );
  }

  /// Misskey: 丸い枠の中に時計 + 日時(detail)。
  Widget _unixtime(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final secs = widget.args['time'];
    final String label;
    if (secs is num) {
      final t = DateTime.fromMillisecondsSinceEpoch((secs * 1000).round());
      label = '${RasqTimestamp.format(t, mode: RasqTimestampMode.absolute)} (${RasqTimestamp.format(t)})';
    } else {
      label = '?';
    }
    final em = style.fontSize ?? 15;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(999)),
      child: Text.rich(
        TextSpan(children: [
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: EdgeInsets.only(right: em * 0.25), child: Icon(Icons.schedule, size: em, color: style.color))),
          TextSpan(text: label),
        ]),
        style: style,
      ),
    );
  }

  /// Misskey の MkGoogle: 検索語の欄 + 検索ボタン(中身 = ボタンのリンク)。
  Widget _search(BuildContext context, Widget button) {
    final scheme = Theme.of(context).colorScheme;
    final side = BorderSide(color: scheme.outlineVariant);
    return _FullWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.fromBorderSide(side), borderRadius: const BorderRadius.horizontal(left: Radius.circular(4))),
              child: Text('${widget.args['query'] ?? ''}', style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, border: Border(top: side, right: side, bottom: side), borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
            child: button,
          ),
        ]),
      ),
    );
  }
}

/// ブロック(`<center>` / 引用 / コード / 検索)を行の幅いっぱいに。幅が決まらない所(横に無限)では中身の幅。
class _FullWidth extends SingleChildRenderObjectWidget {
  const _FullWidth({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFullWidth();
}

class _RenderFullWidth extends RenderProxyBox {
  BoxConstraints _inner(BoxConstraints c) => c.hasBoundedWidth ? BoxConstraints.tightFor(width: c.maxWidth) : BoxConstraints(maxHeight: c.maxHeight);

  @override
  void performLayout() {
    child!.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child!.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(child!.getDryLayout(_inner(constraints)));

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => child!.getDryBaseline(_inner(constraints), baseline);
}

/// ルビ: 読み([rt])を本文([base])の上の中央に。基準線は本文の基準線(行の中で本文が揃う)。
class _Ruby extends MultiChildRenderObjectWidget {
  _Ruby({required Widget rt, required Widget base}) : super(children: [rt, base]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRuby();
}

class _RubyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRuby extends RenderBox with ContainerRenderObjectMixin<RenderBox, _RubyParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _RubyParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RubyParentData) child.parentData = _RubyParentData();
  }

  RenderBox get _rt => firstChild!;
  RenderBox get _base => lastChild!;

  (Size, Size, Size) _measure(BoxConstraints c, Size Function(RenderBox, BoxConstraints) layout) {
    final loose = c.loosen();
    final rt = layout(_rt, loose);
    final base = layout(_base, loose);
    return (rt, base, c.constrain(Size(math.max(rt.width, base.width), rt.height + base.height)));
  }

  @override
  void performLayout() {
    final (rt, base, s) = _measure(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    size = s;
    (_rt.parentData! as _RubyParentData).offset = Offset((s.width - rt.width) / 2, 0);
    (_base.parentData! as _RubyParentData).offset = Offset((s.width - base.width) / 2, rt.height);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, (child, c) => child.getDryLayout(c)).$3;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = _base.getDistanceToActualBaseline(baseline);
    return b == null ? null : b + (_base.parentData! as _RubyParentData).offset.dy;
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final loose = constraints.loosen();
    final b = _base.getDryBaseline(loose, baseline);
    return b == null ? null : b + _rt.getDryLayout(loose).height;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(_rt.getMinIntrinsicWidth(height), _base.getMinIntrinsicWidth(height));
  @override
  double computeMaxIntrinsicWidth(double height) => math.max(_rt.getMaxIntrinsicWidth(height), _base.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) => _rt.getMinIntrinsicHeight(width) + _base.getMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _rt.getMaxIntrinsicHeight(width) + _base.getMaxIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// `blur`: ぼかし 6px。ホバー / タップで外す(0.3 秒で)。
class _MfmBlur extends StatefulWidget {
  const _MfmBlur({required this.child});
  final Widget child;

  @override
  State<_MfmBlur> createState() => _MfmBlurState();
}

class _MfmBlurState extends State<_MfmBlur> {
  bool _hover = false;
  bool _tapped = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => setState(() => _tapped = !_tapped),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _hover || _tapped ? 0 : 6),
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
            child: widget.child,
            builder: (context, sigma, child) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: child),
          ),
        ),
      );
}

/// `sparkle`(Misskey の MkSparkle): 箱の中のでたらめな位置に 4 つ角の星が 0.5〜1 秒おきに現れ、1〜2 秒かけて
/// 回りながら大きく → 消える。色は #FF1493 / #00FFFF / #FFE202。
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.elapsed, {required this.seed}) : super(repaint: elapsed);
  final ValueListenable<Duration> elapsed;
  final int seed;

  static const _colors = [Color(0xFFFF1493), Color(0xFF00FFFF), Color(0xFFFFE202), Color(0xFFFFE202), Color(0xFFFFE202)];

  static final Path _star = () {
    // MkSparkle の 64×64 の星(先の丸みは省く)。
    return Path()
      ..moveTo(32, 0)
      ..lineTo(39.5, 22)
      ..quadraticBezierTo(40.5, 23.5, 42, 24.5)
      ..lineTo(64, 32)
      ..lineTo(42, 39.5)
      ..quadraticBezierTo(40.5, 40.5, 39.5, 42)
      ..lineTo(32, 64)
      ..lineTo(24.5, 42)
      ..quadraticBezierTo(23.5, 40.5, 22, 39.5)
      ..lineTo(0, 32)
      ..lineTo(22, 24.5)
      ..quadraticBezierTo(23.5, 23.5, 24.5, 22)
      ..close();
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final now = elapsed.value.inMicroseconds / 1e6;
    // k 番目の星は k × 0.75 秒 ± 0.25 秒に生まれる(Misskey は 0.5〜1 秒おき)。寿命は dur - 0.1 秒(dur ≤ 2 秒)。
    final last = (now / 0.75).floor() + 1;
    for (var k = math.max(0, last - 4); k <= last; k++) {
      final rnd = math.Random(seed * 7919 + k);
      final born = k * 0.75 + (rnd.nextDouble() - 0.5) * 0.5;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final f = rnd.nextDouble();
      final scaleMax = 0.2 + f / 10 * 3;
      final dur = 1.0 + f;
      final color = _colors[rnd.nextInt(_colors.length)];
      final age = now - born;
      if (age < 0 || age >= dur - 0.1) continue;
      final p = age / dur;
      final scale = p < 0.5 ? scaleMax * p * 2 : scaleMax * (1 - p) * 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * 2 * math.pi);
      canvas.scale(scale);
      canvas.translate(-32, -32);
      canvas.drawPath(_star, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.seed != seed;
}
