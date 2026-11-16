import 'dart:math' as math;

import 'icon_theme_codec.dart';
import 'rasq_theme_spec.dart';

/// テーマ編集の部品の表 (D-581)。形と軌道は仮組みの SHAPES / ORBITS と同じ(0〜31 の格子)。
/// 形を 2 つのスロットで使っても、拡張領域には 1 つだけ入る(表の番号で引く)。

List<IconThemeCmd> _poly(int n, double ro, double ri) => [
      for (var i = 0; i < n * 2; i++)
        () {
          final a = -math.pi / 2 + i * math.pi / n, r = i.isOdd ? ri : ro;
          return IconThemeCmd(i == 0 ? 'M' : 'L', [(16 + math.cos(a) * r + 0.5).floor(), (16 + math.sin(a) * r + 0.5).floor()]);
        }(),
      const IconThemeCmd('Z'),
    ];

/// 形(基本パーティクルの番号 1〜5 と同じ: 雪 / 桜 / 星 / ハート / 泡)。
class IconThemeShapeDef {
  const IconThemeShapeDef(this.id, this.cmds, {required this.sway, required this.spin, required this.orbit});
  final int id;
  final List<IconThemeCmd> cmds;
  final int sway;
  final int spin;
  final String orbit;
}

final iconThemeShapes = <int, IconThemeShapeDef>{
  1: IconThemeShapeDef(1, _poly(6, 14, 7), sway: 6, spin: 2, orbit: 'fall'),
  2: const IconThemeShapeDef(2, [IconThemeCmd('M', [16, 30]), IconThemeCmd('Q', [2, 18, 10, 5]), IconThemeCmd('L', [16, 10]), IconThemeCmd('L', [22, 5]), IconThemeCmd('Q', [30, 18, 16, 30]), IconThemeCmd('Z')], sway: 9, spin: 8, orbit: 'drift'),
  3: IconThemeShapeDef(3, _poly(5, 14, 6), sway: 2, spin: 3, orbit: 'fall'),
  4: const IconThemeShapeDef(4, [IconThemeCmd('M', [16, 29]), IconThemeCmd('Q', [1, 17, 4, 9]), IconThemeCmd('Q', [7, 2, 16, 9]), IconThemeCmd('Q', [25, 2, 28, 9]), IconThemeCmd('Q', [31, 17, 16, 29]), IconThemeCmd('Z')], sway: 4, spin: 1, orbit: 'rise'),
  5: const IconThemeShapeDef(5, [IconThemeCmd('M', [16, 3]), IconThemeCmd('Q', [29, 3, 29, 16]), IconThemeCmd('Q', [29, 29, 16, 29]), IconThemeCmd('Q', [3, 29, 3, 16]), IconThemeCmd('Q', [3, 3, 16, 3]), IconThemeCmd('Z')], sway: 7, spin: 0, orbit: 'rise'),
};

/// 軌道(2 次ベジエ)。
const iconThemeOrbits = <String, List<int>>{
  'fall': [16, 0, 16, 16, 16, 31],
  'drift': [4, 0, 27, 12, 13, 31],
  'rise': [16, 31, 7, 16, 20, 0],
  'flow': [0, 9, 16, 22, 31, 13],
};

/// 編集中のスロット(形と軌道は表の鍵で持つ)。
class IconThemeSlotDraft {
  IconThemeSlotDraft({this.trigger = IconThemeTrigger.always, this.shape = 3, this.orbit = 'fall', this.rand = 8, this.angleRand = 6, this.easeA = 1, this.easeB = 0, this.mix = 0});
  IconThemeTrigger trigger;
  int shape;
  String orbit;
  int rand;
  int angleRand;
  int easeA;
  int easeB;
  int mix;
}

/// スロットの下書き → 拡張の中身(同じ形 / 軌道は 1 つにまとめる。仮組みの readExt と同じ)。
IconThemeExt iconThemeExtFromDrafts(List<IconThemeSlotDraft> slots, {int angle = 6, int anim = 1, int animSpeed = 3}) {
  final shapeIds = <int>[], orbitIds = <String>[];
  final out = <IconThemeSlot>[];
  for (final s in slots) {
    if (!shapeIds.contains(s.shape)) shapeIds.add(s.shape);
    if (!orbitIds.contains(s.orbit)) orbitIds.add(s.orbit);
    final lib = iconThemeShapes[s.shape]!;
    out.add(IconThemeSlot(trigger: s.trigger, shape: shapeIds.indexOf(s.shape), path: orbitIds.indexOf(s.orbit), rand: s.rand, angleRand: s.angleRand, easeA: s.easeA, easeB: s.easeB, mix: s.mix, sway: lib.sway, spin: lib.spin));
  }
  return IconThemeExt(shapes: [for (final i in shapeIds) iconThemeShapes[i]!.cmds], paths: [for (final k in orbitIds) iconThemeOrbits[k]!], angle: angle, anim: anim, animSpeed: animSpeed, slots: out);
}

/// アイコンのテーマの背景の枠 (D-579): アイコンには SVG の ID を入れる余地が無いので、**基本パーティクルの種類から**決まった
/// 枠を置く(雪 → 輪、桜 → 桜、星 → 星ときらめき、ハート / 泡 → 輪)。JSON で配るテーマ(コミュハッシュタグ / Atmos)は
/// [RasqThemeSpec.frames] に好きな ID を書ける。
List<RasqThemeFrameRef> iconThemeFramesFor(IconThemeBasic t) => switch (t.particle) {
      1 => const [RasqThemeFrameRef(svgId: 'ring', x: 0.85, y: 0.12, size: 0.35, opacity: 0.25), RasqThemeFrameRef(svgId: 'ring', x: 0.1, y: 0.9, size: 0.25, opacity: 0.2)],
      2 => const [RasqThemeFrameRef(svgId: 'sakura', x: 0.88, y: 0.1, size: 0.28, opacity: 0.45, rotation: 18), RasqThemeFrameRef(svgId: 'sakura', x: 0.08, y: 0.82, size: 0.22, opacity: 0.35, rotation: -24)],
      3 => const [RasqThemeFrameRef(svgId: 'star', x: 0.86, y: 0.1, size: 0.18, opacity: 0.4), RasqThemeFrameRef(svgId: 'sparkle', x: 0.12, y: 0.86, size: 0.2, opacity: 0.35), RasqThemeFrameRef(svgId: 'sparkle', x: 0.9, y: 0.7, size: 0.1, opacity: 0.3)],
      4 || 5 => const [RasqThemeFrameRef(svgId: 'ring', x: 0.12, y: 0.12, size: 0.3, opacity: 0.25), RasqThemeFrameRef(svgId: 'wave', x: 0.5, y: 0.94, size: 0.9, opacity: 0.2)],
      _ => const [],
    };
