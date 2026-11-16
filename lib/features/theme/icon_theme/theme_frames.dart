import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import 'rasq_theme_spec.dart';

/// テーマフレーム (D-563): テーマの背景に置く SVG。テーマのデータは SVG の中身を持たず、**ID で置き場から引く**
/// ([RasqThemeFrameRef.svgId])。置き場は ① アプリに同梱の数個(`assets/theme_frames/<id>.svg`)② 外の置き場
/// ([ThemeSvgRemote]。Central の口の案は docs/THEME_FRAMES.md。rasq-central には未実装なので、今は差し替えた偽物だけ)。
///
/// **消毒**: どこから来た SVG も [SvgLite](D-473 の許可リスト。`script` / `foreignObject` / `image` / `use` / 外部参照 /
/// `on*` / `style` / `href` は捨てる)で読み、さらにテーマ用の上限([themeSvgMaxBytes] 16 KiB・要素 [themeSvgMaxElements]・
/// 数 [themeSvgMaxNumbers])を超えるものは使わない。読めなければその枠は描かない。

/// 1 枚の大きさの上限(UTF-8)。
const themeSvgMaxBytes = 16 * 1024;
const themeSvgMaxElements = 400;
const themeSvgMaxNumbers = 8000;

/// 1 つのテーマに置ける枠の数。
const themeFramesMax = 6;

/// 同梱の SVG の ID。
const bundledThemeSvgIds = ['star', 'sakura', 'wave', 'ring', 'sparkle'];

/// 外の置き場。ID → SVG の文字列(無ければ null)。
abstract class ThemeSvgRemote {
  Future<String?> fetch(String id);
}

/// 外の置き場(既定は無し = 同梱だけ。サーバーの口ができたらここで繋ぐ)。テストで偽物に差し替える。
final themeSvgRemoteProvider = Provider<ThemeSvgRemote?>((ref) => null);

/// 文字列を消毒して読む(上限を超える / 読めなければ null)。
SvgLite? sanitizeThemeSvg(String? source) {
  if (source == null || source.isEmpty) return null;
  final doc = SvgLite.parseStrict(source, maxBytes: themeSvgMaxBytes, maxElements: themeSvgMaxElements, maxNumbers: themeSvgMaxNumbers);
  if (doc == null || doc.shapes.isEmpty) return null;
  return doc;
}

/// ID の SVG(消毒済み)。同梱 → 外の置き場の順に引く。ID の形が違えば引かない。
final themeSvgProvider = FutureProvider.family<SvgLite?, String>((ref, id) async {
  if (!RasqThemeFrameRef.idPattern.hasMatch(id)) return null;
  String? source;
  if (bundledThemeSvgIds.contains(id)) {
    try {
      source = await rootBundle.loadString('assets/theme_frames/$id.svg');
    } catch (e) {
      debugPrint('theme frame: bundled $id unavailable: $e');
    }
  } else {
    final remote = ref.watch(themeSvgRemoteProvider);
    try {
      source = await remote?.fetch(id);
    } catch (e) {
      debugPrint('theme frame: $id unavailable: $e');
    }
  }
  return sanitizeThemeSvg(source);
});

/// テーマの枠を背景に並べる(画面に対する割合で置く)。読めない枠は描かない。
class ThemeFramesLayer extends ConsumerWidget {
  const ThemeFramesLayer({super.key, required this.frames, this.tint});
  final List<RasqThemeFrameRef> frames;

  /// 色を付ける(null = SVG の色のまま)。
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(builder: (context, c) {
        final short = c.biggest.shortestSide;
        return Stack(children: [
          for (final (i, f) in frames.take(themeFramesMax).indexed)
            if (ref.watch(themeSvgProvider(f.svgId)).value case final doc?)
              Positioned(
                key: ValueKey('theme.frame.$i.${f.svgId}'),
                left: f.x * c.maxWidth - short * f.size / 2,
                top: f.y * c.maxHeight - short * f.size / 2,
                width: short * f.size,
                height: short * f.size,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: f.opacity,
                    child: Transform.rotate(
                      angle: f.rotation * 3.141592653589793 / 180,
                      child: tint == null ? SvgLiteView(doc: doc) : ColorFiltered(colorFilter: ColorFilter.mode(tint!, BlendMode.srcIn), child: SvgLiteView(doc: doc)),
                    ),
                  ),
                ),
              ),
        ]);
      });
}
