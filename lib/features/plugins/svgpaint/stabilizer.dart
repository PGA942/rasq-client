import 'dart:ui';

/// 手ぶれ補正 (D-473): 糸で引く筆(lazy brush / pulled string)。
///
/// 筆は指から半径 [radius] の糸の先にあり、指が糸の長さより離れたときだけ、指の方へ(離れた分だけ)引かれる。
/// 半径より小さな震えは筆に伝わらず、速く動かしたときは筆が糸の向きにまっすぐ付いていく(遅れは最大で半径)。
/// 半径 0 なら補正なし(指の点そのまま)。描き終えたら [finish] で指の最後の位置まで引き寄せる(線は指を離したところで終わる)。
class Stabilizer {
  Stabilizer(this.radius, Offset start) : _b = start;

  /// 糸の長さ(viewBox の単位。画面の px で決めて紙の拡大率で割る)。
  final double radius;
  Offset _b;

  /// 筆の位置。
  Offset get position => _b;

  /// 指が [p] へ動いた → 筆の新しい位置(動かなければ null)。
  Offset? add(Offset p) {
    final d = (p - _b).distance;
    if (d <= radius) return null;
    _b = radius == 0 ? p : _b + (p - _b) * ((d - radius) / d);
    return _b;
  }

  /// 指を離した → 指の位置まで引き寄せる(筆がもう指の上なら null)。
  Offset? finish(Offset p) {
    if ((p - _b).distance < 0.05) return null;
    _b = p;
    return p;
  }

  /// 画面の px で決めた強さ(0〜10)→ 糸の長さ(viewBox の単位)。1 段 = 1.6 px。
  static double radiusFor(int strength, double pxPerUnit) => strength <= 0 ? 0 : strength * 1.6 / (pxPerUnit <= 0 ? 1 : pxPerUnit);
}
