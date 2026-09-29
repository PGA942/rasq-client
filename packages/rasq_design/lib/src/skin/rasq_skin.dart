import 'package:flutter/material.dart';

/// 着せ替え (D-335、契約 v0.16 §2.12 `kind: "theme"`)。
///
/// 着せ替えパック(wasm を持たない配布物)のマニフェストの `theme` を読んだもの。ホストで同時に効くのは 1 つ。
/// - `colors` = Material の ColorScheme の一部を上書き(明 / 暗ごと)
/// - `icons` = 名前で指すアイコンの差し替え(別の Material アイコン、またはパックの画像)。[RasqSkinIcon] で描く
/// - `surfaces` = 面(`app` / `postTile` / `fow` / `actionButton`)の背景色・角丸・画像のレイヤー。[RasqSkinned] で描く
///   レイヤーは `below`(中身の下 = 背景)か `above`(中身の上に重ねる、触れない)。画像か**グラデーション**(v0.17、D-337)、
///   `height` を書くと `alignment` の辺に寄せた**帯**になる。面の `onColor` は、その面の上の文字とアイコンの色
/// `brightness` が `dark` / `light` のときは、合わない明るさでは色と面を使わない(アイコンの差し替えは常に効く)。
enum RasqSkinSurfaceId { app, postTile, fow, actionButton }

@immutable
class RasqSkinLayer {
  const RasqSkinLayer({this.image, this.gradient, this.above = false, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.repeat = ImageRepeat.noRepeat, this.opacity = 1, this.height}) : assert((image == null) != (gradient == null));

  /// 画像か、グラデーション(v0.17)のどちらか。
  final ImageProvider? image;
  final Gradient? gradient;

  /// true = 中身の上(上付き)、false = 中身の下(下付き)。
  final bool above;
  final BoxFit fit;
  final Alignment alignment;
  final ImageRepeat repeat;
  final double opacity;

  /// 帯の高さ(v0.17)。null = 面いっぱい。書くと [alignment] の辺(上 / 真ん中 / 下)に寄せた帯。
  final double? height;

  Widget build() {
    final Widget paint = gradient != null
        ? DecoratedBox(decoration: BoxDecoration(gradient: gradient))
        : Image(image: image!, fit: fit, alignment: alignment, repeat: repeat, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink());
    final body = IgnorePointer(child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: paint));
    final h = height;
    if (h == null) return Positioned.fill(child: body);
    // 帯: 上辺 / 下辺 / 上下の真ん中に、幅いっぱい・高さ h。
    return Positioned.fill(child: Align(alignment: Alignment(0, alignment.y.sign), child: SizedBox(height: h, width: double.infinity, child: body)));
  }
}

@immutable
class RasqSkinSurface {
  const RasqSkinSurface({this.color, this.radius, this.layers = const [], this.onColor});
  final Color? color;
  final double? radius;
  final List<RasqSkinLayer> layers;

  /// この面の上の文字とアイコンの色(v0.17)。null = テーマのまま。
  final Color? onColor;
}

/// アイコンの差し替え先: 別の Material アイコンか、パックの画像。
@immutable
class RasqSkinIconSpec {
  const RasqSkinIconSpec.material(IconData this.icon) : image = null;
  const RasqSkinIconSpec.image(ImageProvider this.image) : icon = null;
  final IconData? icon;
  final ImageProvider? image;
}

@immutable
class RasqSkin {
  const RasqSkin({required this.id, required this.name, this.only, this.colors = const {}, this.icons = const {}, this.surfaces = const {}});
  final String id;
  final String name;

  /// 効く明るさ。null = 両方。
  final Brightness? only;

  /// 明るさ → ColorScheme のキー → 色。
  final Map<Brightness, Map<String, Color>> colors;

  /// Material アイコンのコードポイント → 差し替え先。
  final Map<int, RasqSkinIconSpec> icons;
  final Map<RasqSkinSurfaceId, RasqSkinSurface> surfaces;

  bool appliesTo(Brightness b) => only == null || only == b;

  RasqSkinSurface? surface(RasqSkinSurfaceId id, Brightness b) => appliesTo(b) ? surfaces[id] : null;

  RasqSkinIconSpec? iconFor(IconData icon) => icon.fontFamily == 'MaterialIcons' ? icons[icon.codePoint] : null;

  /// ColorScheme の上書き(書けるキーは契約 §2.12 の 14 個)。
  ColorScheme applyColors(ColorScheme base) {
    if (!appliesTo(base.brightness)) return base;
    final c = colors[base.brightness];
    if (c == null || c.isEmpty) return base;
    return base.copyWith(
      primary: c['primary'],
      onPrimary: c['onPrimary'],
      secondary: c['secondary'],
      onSecondary: c['onSecondary'],
      tertiary: c['tertiary'],
      error: c['error'],
      surface: c['surface'],
      onSurface: c['onSurface'],
      onSurfaceVariant: c['onSurfaceVariant'],
      surfaceContainer: c['surfaceContainer'],
      surfaceContainerHigh: c['surfaceContainerHigh'],
      surfaceContainerHighest: c['surfaceContainerHighest'],
      outline: c['outline'],
      outlineVariant: c['outlineVariant'],
    );
  }

  /// ThemeData に色を当てる。`app` の面に画像があれば、画面の背景(Scaffold)を透明にして、アプリの一番下に描く面を見せる。
  ThemeData applyTo(ThemeData base) {
    if (!appliesTo(base.brightness)) return base;
    final scheme = applyColors(base.colorScheme);
    final app = surfaces[RasqSkinSurfaceId.app];
    final see = app != null && (app.layers.any((l) => !l.above) || app.color != null);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: see ? Colors.transparent : (colors[base.brightness]?['surface'] ?? base.scaffoldBackgroundColor),
      canvasColor: colors[base.brightness]?['surface'] ?? base.canvasColor,
    );
  }

  /// 面の文字色 (v0.17) を当てたテーマ(onSurface / onSurfaceVariant / アイコン / 本文の色)。
  static ThemeData withOnColor(ThemeData base, Color on) {
    final variant = on.withValues(alpha: 0.75);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(onSurface: on, onSurfaceVariant: variant),
      iconTheme: base.iconTheme.copyWith(color: on),
      textTheme: base.textTheme.apply(bodyColor: on, displayColor: on),
    );
  }

  static const colorKeys = {'primary', 'onPrimary', 'secondary', 'onSecondary', 'tertiary', 'error', 'surface', 'onSurface', 'onSurfaceVariant', 'surfaceContainer', 'surfaceContainerHigh', 'surfaceContainerHighest', 'outline', 'outlineVariant'};

  /// `#RRGGBB` / `#AARRGGBB`(Flutter の Color と同じ並び)。
  static Color? parseColor(Object? raw) {
    if (raw is! String || !raw.startsWith('#')) return null;
    final hex = raw.substring(1);
    if (hex.length != 6 && hex.length != 8) return null;
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return null;
    return Color(hex.length == 6 ? 0xFF000000 | v : v);
  }

  static const _fits = {'cover': BoxFit.cover, 'contain': BoxFit.contain, 'fill': BoxFit.fill, 'fitWidth': BoxFit.fitWidth, 'fitHeight': BoxFit.fitHeight, 'none': BoxFit.none, 'scaleDown': BoxFit.scaleDown};
  static const _alignments = {
    'topLeft': Alignment.topLeft, 'topCenter': Alignment.topCenter, 'topRight': Alignment.topRight,
    'centerLeft': Alignment.centerLeft, 'center': Alignment.center, 'centerRight': Alignment.centerRight,
    'bottomLeft': Alignment.bottomLeft, 'bottomCenter': Alignment.bottomCenter, 'bottomRight': Alignment.bottomRight,
  };
  static const _repeats = {'none': ImageRepeat.noRepeat, 'repeat': ImageRepeat.repeat, 'repeatX': ImageRepeat.repeatX, 'repeatY': ImageRepeat.repeatY};

  /// レイヤーの中身: `asset`(画像)か `gradient`(v0.17)。どちらも無い / 読めない / 両方ある = null(捨てる)。
  static ({ImageProvider? image, Gradient? gradient})? _layerPaint(Map<Object?, Object?> l, ImageProvider? Function(String) image) {
    final asset = l['asset'];
    final g = l['gradient'];
    if ((asset != null) == (g != null)) return null;
    if (asset is String) {
      final img = image(asset);
      return img == null ? null : (image: img, gradient: null);
    }
    if (g is! Map) return null;
    final colors = [for (final c in (g['colors'] as List? ?? const [])) ?parseColor(c)];
    if (colors.length < 2 || colors.length > 8) return null;
    final stops = [for (final s in (g['stops'] as List? ?? const [])) if (s is num) s.toDouble().clamp(0.0, 1.0)];
    return (
      image: null,
      gradient: LinearGradient(
        colors: colors,
        stops: stops.length == colors.length ? stops : null,
        begin: _alignments[g['begin']] ?? Alignment.topCenter,
        end: _alignments[g['end']] ?? Alignment.bottomCenter,
      ),
    );
  }

  /// マニフェストの `theme` を読む。[image] = パックの画像 id → ImageProvider(無い id は null で、その参照は捨てる)。
  /// [materialIcon] = Material のアイコン名 → IconData(アプリの名前表)。知らない名前・形の違う値は黙って捨てる(壊れた宣言で落とさない)。
  static RasqSkin parse({required String id, required String name, required Map<String, Object?> theme, required ImageProvider? Function(String assetId) image, required IconData? Function(String name) materialIcon}) {
    final only = switch (theme['brightness']) { 'light' => Brightness.light, 'dark' => Brightness.dark, _ => null };
    final colors = <Brightness, Map<String, Color>>{};
    if (theme['colors'] case final Map<Object?, Object?> cs) {
      for (final (key, b) in [('light', Brightness.light), ('dark', Brightness.dark)]) {
        if (cs[key] case final Map<Object?, Object?> m) {
          colors[b] = {for (final e in m.entries) if (e.key is String && colorKeys.contains(e.key)) e.key as String: ?parseColor(e.value)};
        }
      }
    }
    final icons = <int, RasqSkinIconSpec>{};
    if (theme['icons'] case final Map<Object?, Object?> m) {
      for (final e in m.entries) {
        final from = e.key is String ? materialIcon(e.key as String) : null;
        final to = e.value;
        if (from == null || to is! String) continue;
        if (to.startsWith('asset:')) {
          if (image(to.substring(6)) case final img?) icons[from.codePoint] = RasqSkinIconSpec.image(img);
        } else if (to.startsWith('material:')) {
          if (materialIcon(to.substring(9)) case final ic?) icons[from.codePoint] = RasqSkinIconSpec.material(ic);
        }
      }
    }
    final surfaces = <RasqSkinSurfaceId, RasqSkinSurface>{};
    if (theme['surfaces'] case final Map<Object?, Object?> m) {
      for (final sid in RasqSkinSurfaceId.values) {
        final raw = m[sid.name];
        if (raw is! Map) continue;
        final layers = <RasqSkinLayer>[
          for (final l in (raw['layers'] as List? ?? const []).take(8))
            if (l is Map)
              if (_layerPaint(l, image) case final paint?)
                RasqSkinLayer(
                  image: paint.image,
                  gradient: paint.gradient,
                  above: l['position'] == 'above',
                  fit: _fits[l['fit']] ?? BoxFit.cover,
                  alignment: _alignments[l['alignment']] ?? Alignment.center,
                  repeat: _repeats[l['repeat']] ?? ImageRepeat.noRepeat,
                  opacity: (l['opacity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 1,
                  height: (l['height'] as num?)?.toDouble().clamp(1.0, 400.0),
                ),
        ];
        final r = (raw['radius'] as num?)?.toDouble();
        surfaces[sid] = RasqSkinSurface(color: parseColor(raw['color']), radius: r?.clamp(0.0, 48.0), layers: layers, onColor: parseColor(raw['onColor']));
      }
    }
    return RasqSkin(id: id, name: name, only: only, colors: colors, icons: icons, surfaces: surfaces);
  }
}

/// 今の着せ替え。無ければ null(何もしない)。
class RasqSkinScope extends InheritedWidget {
  const RasqSkinScope({super.key, required this.skin, required super.child});
  final RasqSkin? skin;

  static RasqSkin? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RasqSkinScope>()?.skin;

  @override
  bool updateShouldNotify(RasqSkinScope oldWidget) => oldWidget.skin != skin;
}

/// 面を着せ替えで描く: 背景色 + 下付きのレイヤー → 中身 → 上付きのレイヤー(触れない)。角丸があれば切り抜く。
/// 着せ替えが無い / その面の宣言が無い / 明るさが合わないときは中身だけ。
class RasqSkinned extends StatelessWidget {
  const RasqSkinned({super.key, required this.surface, required this.child, this.stable = false});
  final RasqSkinSurfaceId surface;
  final Widget child;

  /// 着せ替えの有無で**木の形を変えない** (D-374)。アプリ全体(`app`)と FOW のように中身が大きい面で使う。形が変わると
  /// 中身(ナビゲーターごと)が作り直され、着せ替えを入れた直後に Hero のタグの重複(FAB の既定のタグ)で落ちていた。
  final bool stable;

  static const _contentKey = ValueKey('rasq.skin.content');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = RasqSkinScope.of(context)?.surface(surface, theme.brightness);
    if (stable) return _stable(context, theme, s);
    if (s == null || (s.color == null && s.layers.isEmpty && s.radius == null && s.onColor == null)) return child;
    var content = child;
    // 面の上の文字とアイコンの色 (v0.17)。
    if (s.onColor case final on?) {
      content = Theme(
        data: RasqSkin.withOnColor(theme, on),
        child: DefaultTextStyle.merge(style: TextStyle(color: on), child: IconTheme.merge(data: IconThemeData(color: on), child: content)),
      );
    }
    // passthrough: 中身には親の制約をそのまま渡す(着せ替えの有無で中身の大きさを変えない)。
    Widget out = Stack(fit: StackFit.passthrough, children: [
      if (s.color != null) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: s.color!))),
      for (final l in s.layers) if (!l.above) l.build(),
      content,
      for (final l in s.layers) if (l.above) l.build(),
    ]);
    if (s.radius != null && s.radius! > 0) out = ClipRRect(borderRadius: BorderRadius.circular(s.radius!), child: out);
    return out;
  }

  /// いつも同じ形: Theme → 文字 / アイコンの色 → ClipRRect → Stack(中身は鍵つきで、前後の層が増減しても作り直さない)。
  Widget _stable(BuildContext context, ThemeData theme, RasqSkinSurface? s) {
    final on = s?.onColor;
    final radius = s?.radius ?? 0;
    return Theme(
      data: on == null ? theme : RasqSkin.withOnColor(theme, on),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: on),
        child: IconTheme.merge(
          data: IconThemeData(color: on),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
            child: Stack(fit: StackFit.passthrough, children: [
              if (s?.color != null) Positioned.fill(key: const ValueKey('rasq.skin.color'), child: IgnorePointer(child: ColoredBox(color: s!.color!))),
              for (final (i, l) in (s?.layers ?? const <RasqSkinLayer>[]).indexed) if (!l.above) KeyedSubtree(key: ValueKey('rasq.skin.below.$i'), child: l.build()),
              KeyedSubtree(key: _contentKey, child: child),
              for (final (i, l) in (s?.layers ?? const <RasqSkinLayer>[]).indexed) if (l.above) KeyedSubtree(key: ValueKey('rasq.skin.above.$i'), child: l.build()),
            ]),
          ),
        ),
      ),
    );
  }
}

/// アイコンを着せ替えで描く(差し替えが無ければ [Icon] そのまま)。画像は [size] の正方形に収める(色は付けない)。
class RasqSkinIcon extends StatelessWidget {
  const RasqSkinIcon(this.icon, {super.key, this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final spec = RasqSkinScope.of(context)?.iconFor(icon);
    final s = size ?? IconTheme.of(context).size ?? 24;
    if (spec?.image case final img?) return SizedBox.square(dimension: s, child: Image(image: img, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => Icon(icon, size: s, color: color)));
    return Icon(spec?.icon ?? icon, size: size, color: color);
  }
}
