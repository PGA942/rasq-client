// アイコンに埋め込むテーマ(アイコンチップ)のコーデック (D-561)。
//
// 400×400 のアイコンの四隅に 8px の色ブロックでテーマの DSL を書き、SNS で再圧縮 / リサイズされた画像から読み戻す。
// ユーザーの仮組み(night-2026-11-16/theme_mock_icon_embed.html の `Codec`)の Dart への移植で、**同じ入力から同じ画素・同じ
// 結果**になる(test/icon_theme_codec_test.dart が仮組みの JS で作った値と比べる)。Flutter に依らない素の Dart なので、
// 別の isolate(`compute`)でも動く。
//
// - **パレット領域**(角丸 r=80 の外側の 48 ブロック): 校正ブロック 17(W / K / R / G / B)+ データ 31 = 5 ビットのシンボル
//   (32 色のパレット)× 31。RS(GF(2^5)、訂正用 10)で 5 個まで直す。DSL の記号は `0-f B G T A P S R0-R7 [ ]`。
// - **拡張領域**(角丸の内側で円 r=200 の外側の 396 ブロック): 校正 16(輝度 4 段 × 4)+ データ 380 = 2 ビット(輝度の 4 段、
//   グレイ符号)× 380 = 95 バイト。RS(GF(2^8)、訂正用 30)で 65 バイトの中身: ベクターの形・軌道・スロット(きっかけ = 常時 /
//   クリック / スライド、イージング 2 つの混ぜ)か、プラグインの配信 URL(https:// を省く)。白色化してから書く。
// - **RASQ の予約 3 ビット**(DSL の `R0`〜`R7`): 4 = アイコンのフレーム(1 = 角丸 / 0 = 丸)、2 = 添付メディアの並び(1 = 縦 /
//   0 = 横)、1 = 隙間(1 = 詰める / 0 = そのまま)。
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// JS の `Math.round`(.5 は +∞ の向きへ)。
int _jsRound(double v) => (v + 0.5).floorToDouble().toInt();

/// アイコンの一辺(書き込むときの大きさ)。
const iconThemeSize = 400;
const _blk = 8;
const _n = iconThemeSize ~/ _blk;
const _rad = 80;
const _circ = 200;

const iconThemePaletteHex = [
  '#141414', '#14146e', '#4a1414', '#143814', '#4a385c', '#1414ec', '#923880', '#6e5c14', '#146e14', '#a44a4a', '#805cec', //
  '#ec1414', '#5c806e', '#1480b6', '#ec1480', '#3880ec', '#ec14da', '#c86e14', '#a48092', '#14b626', '#5cb680', '#daa46e', //
  '#92c814', '#eca4ec', '#a4c8ec', '#ecc84a', '#14ec14', '#38ec92', '#14ecec', '#ecdac8', '#c8ec92', '#ecec14',
];

/// 色(0〜255 の RGB)。
typedef Rgb = List<double>;

List<int> _hexToRgb(String h) => [for (final i in const [1, 3, 5]) int.parse(h.substring(i, i + 2), radix: 16)];
final List<List<int>> _palette = [for (final h in iconThemePaletteHex) _hexToRgb(h)];

/// DSL の記号(シンボルの値 → 文字)。
const iconThemeSymbols = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'B', 'G', 'T', 'A', 'P', 'S', 'R0', 'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', '[', ']'];

abstract final class _Op {
  static const b = 16, g = 17, t = 18, a = 19, p = 20, s = 21, start = 30, end = 31;
}

const _argc = {16: 3, 17: 4, 18: 3, 19: 3, 20: 1, 21: 2};
const _ref = {
  'W': [238, 238, 238],
  'K': [18, 18, 18],
  'R': [226, 44, 44],
  'G': [44, 200, 44],
  'B': [44, 44, 226],
};
const _calPlan = [
  ['W', 'K', 'R', 'G', 'B'],
  ['W', 'K', 'R', 'G'],
  ['W', 'K', 'G', 'B'],
  ['W', 'K', 'B', 'R'],
];
const _extTargetY = [46.0, 104.0, 162.0, 220.0];
const _palK = 21, iconThemePalNsym = 10, iconThemeExtNsym = 30, _extMagic = 0x52, _extUrlMagic = 0x55;

// ---------- 色 ----------

List<double> _rgbToLab(Rgb c) {
  double f(double v) {
    v /= 255;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = f(c[0]), g = f(c[1]), b = f(c[2]);
  var x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047, y = 0.2126 * r + 0.7152 * g + 0.0722 * b, z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double h(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  x = h(x);
  y = h(y);
  z = h(z);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

final _palLab = [for (final p in _palette) _rgbToLab([for (final v in p) v.toDouble()])];
double _luma(Rgb c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];

/// RGB → HSL(h は度、s / l は 0〜1)。仮組みと同じ式(JS の `%` = 符号つきの余り)。
List<double> iconThemeRgbToHsl(List<num> c) {
  final r = c[0] / 255, g = c[1] / 255, b = c[2] / 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b)), l = (mx + mn) / 2, d = mx - mn;
  if (d == 0) return [0, 0, l];
  final s = d / (1 - (2 * l - 1).abs());
  final h = mx == r
      ? ((g - b) / d).remainder(6)
      : mx == g
          ? (b - r) / d + 2
          : (r - g) / d + 4;
  return [(h * 60 + 360).remainder(360), s, l];
}

/// HSL → RGB(0〜255 の整数)。
List<int> iconThemeHslToRgb(List<double> hsl) {
  final h = hsl[0], s = hsl[1], l = hsl[2];
  final c = (1 - (2 * l - 1).abs()) * s, hp = ((h.remainder(360)) + 360).remainder(360) / 60, x = c * (1 - (hp.remainder(2) - 1).abs()), m = l - c / 2;
  final List<double> rgb = hp < 1
      ? [c, x, 0]
      : hp < 2
          ? [x, c, 0]
          : hp < 3
              ? [0, c, x]
              : hp < 4
                  ? [0, x, c]
                  : hp < 5
                      ? [x, 0, c]
                      : [c, 0, x];
  return [for (final v in rgb) _jsRound((v + m) * 255)];
}

/// 拡張領域の 4 段の色(同じ色相で輝度を決まった段に。飾り枠として見える)。[mono] = 灰色。
List<List<int>> iconThemeRamp(List<int> rgb, {bool mono = false}) {
  final hsl = iconThemeRgbToHsl(rgb);
  final sat = mono ? 0.0 : math.min(0.75, math.max(0.35, hsl[1]));
  return [
    for (final t in _extTargetY)
      () {
        var lo = 0.0, hi = 1.0;
        for (var i = 0; i < 18; i++) {
          final mid = (lo + hi) / 2;
          final c = iconThemeHslToRgb([hsl[0], sat, mid]);
          if (_luma([c[0].toDouble(), c[1].toDouble(), c[2].toDouble()]) < t) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        return iconThemeHslToRgb([hsl[0], sat, (lo + hi) / 2]);
      }(),
  ];
}

// ---------- 置き場所 ----------

/// ブロックの並び(仮組みの LAYOUT)。
class IconThemeLayout {
  IconThemeLayout._(this.palCal, this.palData, this.extCal, this.extData);

  /// パレット領域の校正ブロック((bx, by), 基準色)。
  final List<((int, int), String)> palCal;
  final List<(int, int)> palData;

  /// 拡張領域の校正ブロック((bx, by), 段)。
  final List<((int, int), int)> extCal;
  final List<(int, int)> extData;

  int get extBytes => extData.length * 2 ~/ 8;
  int get extK => extBytes - iconThemeExtNsym;

  static final instance = () {
    bool outsideRound(int x, int y) {
      final cx = x < _rad ? _rad : (x > iconThemeSize - _rad ? iconThemeSize - _rad : null);
      final cy = y < _rad ? _rad : (y > iconThemeSize - _rad ? iconThemeSize - _rad : null);
      return cx != null && cy != null && math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2)) > _rad;
    }

    bool outsideCircle(int x, int y) => math.sqrt(math.pow(x - iconThemeSize / 2, 2) + math.pow(y - iconThemeSize / 2, 2)) > _circ;
    final pal = [<(int, int)>[], <(int, int)>[], <(int, int)>[], <(int, int)>[]];
    final ext = [<(int, int)>[], <(int, int)>[], <(int, int)>[], <(int, int)>[]];
    for (var by = 0; by < _n; by++) {
      for (var bx = 0; bx < _n; bx++) {
        final pts = [(bx, by), (bx + 1, by), (bx, by + 1), (bx + 1, by + 1)].map((p) => (p.$1 * _blk, p.$2 * _blk)).toList();
        final corner = (by < _n / 2 ? 0 : 2) + (bx < _n / 2 ? 0 : 1);
        if (pts.every((p) => outsideRound(p.$1, p.$2))) {
          pal[corner].add((bx, by));
        } else if (pts.every((p) => outsideCircle(p.$1, p.$2))) {
          ext[corner].add((bx, by));
        }
      }
    }
    final palCal = <((int, int), String)>[], palData = <(int, int)>[], extCal = <((int, int), int)>[], extData = <(int, int)>[];
    for (var c = 0; c < 4; c++) {
      for (var i = 0; i < pal[c].length; i++) {
        if (i < _calPlan[c].length) {
          palCal.add((pal[c][i], _calPlan[c][i]));
        } else {
          palData.add(pal[c][i]);
        }
      }
    }
    for (final list in ext) {
      for (var i = 0; i < list.length; i++) {
        if (i < 4) {
          extCal.add((list[i], i));
        } else {
          extData.add(list[i]);
        }
      }
    }
    return IconThemeLayout._(palCal, palData, extCal, extData);
  }();
}

// ---------- Reed-Solomon(GF(2^m)) ----------

/// 誤りが訂正の限界を超えた。
class IconThemeRsError implements Exception {
  const IconThemeRsError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// RS の符号 / 復号(仮組みの makeRS と同じ形)。
class IconThemeRs {
  IconThemeRs(this.m, int prim) : _size = (1 << m) - 1 {
    _exp = List.filled(2 * _size, 0);
    _log = List.filled(_size + 1, 0);
    var x = 1;
    for (var i = 0; i < _size; i++) {
      _exp[i] = _exp[i + _size] = x;
      _log[x] = i;
      x <<= 1;
      if (x > _size) x ^= prim;
    }
  }

  final int m;
  final int _size;
  late final List<int> _exp;
  late final List<int> _log;
  final _gens = <int, List<int>>{};

  static final gf5 = IconThemeRs(5, 37);
  static final gf8 = IconThemeRs(8, 0x11d);

  int _mul(int a, int b) => a != 0 && b != 0 ? _exp[_log[a] + _log[b]] : 0;
  int _div(int a, int b) => a != 0 ? _exp[(_log[a] + _size - _log[b]) % _size] : 0;
  int _pow(int a, int p) => _exp[(((_log[a] * p) % _size) + _size) % _size];
  int _inv(int a) => _exp[_size - _log[a]];
  List<int> _pScale(List<int> p, int x) => [for (final c in p) _mul(c, x)];
  List<int> _pAdd(List<int> p, List<int> q) {
    final r = List.filled(math.max(p.length, q.length), 0);
    for (var i = 0; i < p.length; i++) {
      r[i + r.length - p.length] = p[i];
    }
    for (var i = 0; i < q.length; i++) {
      r[i + r.length - q.length] ^= q[i];
    }
    return r;
  }

  List<int> _pMul(List<int> p, List<int> q) {
    final r = List.filled(p.length + q.length - 1, 0);
    for (var j = 0; j < q.length; j++) {
      for (var i = 0; i < p.length; i++) {
        r[i + j] ^= _mul(p[i], q[j]);
      }
    }
    return r;
  }

  int _pEval(List<int> p, int x) {
    var y = 0;
    for (final c in p) {
      y = _mul(y, x) ^ c;
    }
    return y;
  }

  List<int> _gen(int nsym) => _gens.putIfAbsent(nsym, () {
        var g = [1];
        for (var i = 0; i < nsym; i++) {
          g = _pMul(g, [1, _pow(2, i)]);
        }
        return g;
      });

  /// [msg] に訂正用の [nsym] 個を足す。
  List<int> encode(List<int> msg, int nsym) {
    final g = _gen(nsym), out = [...msg, ...List.filled(nsym, 0)];
    for (var i = 0; i < msg.length; i++) {
      final c = out[i];
      if (c != 0) {
        for (var j = 1; j < g.length; j++) {
          out[i + j] ^= _mul(g[j], c);
        }
      }
    }
    for (var i = 0; i < msg.length; i++) {
      out[i] = msg[i];
    }
    return out;
  }

  List<int> _syndromes(List<int> msg, int nsym) => [0, for (var i = 0; i < nsym; i++) _pEval(msg, _pow(2, i))];

  /// 復号して (中身, 直した数)。直せなければ [IconThemeRsError]。
  (List<int>, int) decode(List<int> recv, int nsym) {
    var msg = [...recv];
    final synd = _syndromes(msg, nsym);
    if (synd.every((s) => s == 0)) return (msg.sublist(0, msg.length - nsym), 0);
    final fs = synd.sublist(1);
    var loc = [1], old = [1];
    for (var i = 0; i < nsym; i++) {
      var delta = fs[i];
      for (var j = 1; j < loc.length; j++) {
        delta ^= _mul(loc[loc.length - (j + 1)], fs[i - j]);
      }
      old.add(0);
      if (delta != 0) {
        if (old.length > loc.length) {
          final nl = _pScale(old, delta);
          old = _pScale(loc, _inv(delta));
          loc = nl;
        }
        loc = _pAdd(loc, _pScale(old, delta));
      }
    }
    var lead = 0;
    while (lead < loc.length && loc[lead] == 0) {
      lead++;
    }
    loc = loc.sublist(lead);
    final errs = loc.length - 1;
    if (errs * 2 > nsym) throw const IconThemeRsError('too many errors');
    final rev = loc.reversed.toList(), pos = <int>[];
    for (var i = 0; i < msg.length; i++) {
      if (_pEval(rev, _pow(2, i)) == 0) pos.add(msg.length - 1 - i);
    }
    if (pos.length != errs) throw const IconThemeRsError('locator mismatch');
    final coefPos = [for (final p in pos) msg.length - 1 - p];
    var eLoc = [1];
    for (final i in coefPos) {
      eLoc = _pMul(eLoc, _pAdd([1], [_pow(2, i), 0]));
    }
    final prod = _pMul(synd.reversed.toList(), eLoc);
    final errEval = prod.sublist(prod.length - eLoc.length).reversed.toList();
    final xs = [for (final c in coefPos) _pow(2, c - _size)];
    final e = List.filled(msg.length, 0);
    for (var i = 0; i < xs.length; i++) {
      final xiInv = _inv(xs[i]);
      var prime = 1;
      for (var j = 0; j < xs.length; j++) {
        if (j != i) prime = _mul(prime, 1 ^ _mul(xiInv, xs[j]));
      }
      if (prime == 0) throw const IconThemeRsError('forney');
      final y = _mul(xs[i], _pEval(errEval.reversed.toList(), xiInv));
      e[pos[i]] = _div(y, prime);
    }
    msg = [for (var i = 0; i < msg.length; i++) msg[i] ^ e[i]];
    if (_syndromes(msg, nsym).any((s) => s != 0)) throw const IconThemeRsError('residual');
    return (msg.sublist(0, msg.length - nsym), errs);
  }
}

// ---------- DSL ----------

/// 背景の塗り方。
enum IconThemeBg { solid, gradient }

/// アイコンに埋め込む基本テーマ(パレット領域の DSL)。色は 4 ビット × 3(`#rgb`、17 刻み)。
class IconThemeBasic {
  const IconThemeBasic({
    this.bgMode = IconThemeBg.solid,
    this.gradient = 0,
    this.bg = const [17, 17, 17],
    this.text = const [255, 255, 255],
    this.accent = const [0, 204, 255],
    this.particle = 0,
    this.amount = 8,
    this.speed = 4,
    this.hint,
  });

  final IconThemeBg bgMode;

  /// グラデーションの種類(0 = 縦に沈む / 1 = 斜めに色相 / 2 = 中心から放射 / 3 = オーロラ)。
  final int gradient;
  final List<int> bg;
  final List<int> text;
  final List<int> accent;

  /// 基本のパーティクル(0 = なし / 1 = 雪 / 2 = 桜 / 3 = 星 / 4 = ハート / 5 = 泡)。
  final int particle;
  final int amount;
  final int speed;

  /// RASQ の予約 3 ビット(null = 入れない)。[IconThemeHint] で読む。
  final int? hint;

  IconThemeHint? get hints => hint == null ? null : IconThemeHint(hint!);

  @override
  bool operator ==(Object other) =>
      other is IconThemeBasic &&
      other.bgMode == bgMode &&
      other.gradient == gradient &&
      _listEq(other.bg, bg) &&
      _listEq(other.text, text) &&
      _listEq(other.accent, accent) &&
      other.particle == particle &&
      other.amount == amount &&
      other.speed == speed &&
      other.hint == hint;

  @override
  int get hashCode => Object.hash(bgMode, gradient, Object.hashAll(bg), Object.hashAll(text), Object.hashAll(accent), particle, amount, speed, hint);

  Map<String, Object?> toJson() => {'bgMode': bgMode == IconThemeBg.gradient ? 'grad' : 'solid', 'grad': gradient, 'bg': bg, 'text': text, 'accent': accent, 'particle': particle, 'amount': amount, 'speed': speed, 'hint': hint};
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// RASQ の予約 3 ビット。
class IconThemeHint {
  const IconThemeHint(this.bits);
  final int bits;

  /// アイコンのフレームを角丸に(false = 丸)。
  bool get roundedFrame => bits & 4 != 0;

  /// 添付メディアを縦に並べる(false = 横)。
  bool get verticalMedia => bits & 2 != 0;

  /// 隙間を詰める(false = そのまま)。
  bool get packMedia => bits & 1 != 0;

  static int of({required bool roundedFrame, required bool verticalMedia, required bool packMedia}) => (roundedFrame ? 4 : 0) | (verticalMedia ? 2 : 0) | (packMedia ? 1 : 0);
}

List<int> _hex3(List<int> c) => [for (final v in c.take(3)) _jsRound(v / 17)];
List<int> _from3(List<int> a) => [for (final v in a) v * 17];

/// テーマ → DSL のシンボル。
List<int> iconThemeToSymbols(IconThemeBasic t) => [
      _Op.start,
      if (t.bgMode == IconThemeBg.gradient) ...[_Op.g, t.gradient & 15, ..._hex3(t.bg)] else ...[_Op.b, ..._hex3(t.bg)],
      _Op.t, ..._hex3(t.text),
      _Op.a, ..._hex3(t.accent),
      _Op.p, t.particle & 15,
      _Op.s, t.amount & 15, t.speed & 15,
      if (t.hint != null) 22 + (t.hint! & 7),
      _Op.end,
    ];

/// DSL のシンボル → テーマ(読めなければ null)。
IconThemeBasic? iconThemeFromSymbols(List<int> sym) {
  if (sym.isEmpty || sym[0] != _Op.start) return null;
  var bgMode = IconThemeBg.solid, grad = 0, particle = 0, amount = 8, speed = 4;
  var bg = const [17, 17, 17], text = const [255, 255, 255], accent = const [0, 204, 255];
  int? hint;
  var i = 1, closed = false;
  while (i < sym.length) {
    final op = sym[i++];
    if (op == _Op.end) {
      closed = true;
      break;
    }
    final argc = _argc[op];
    if (argc == null) {
      if (op < 16) return null;
      if (op >= 22 && op <= 29) hint = op - 22;
      continue;
    }
    final a = sym.sublist(i, math.min(sym.length, i + argc));
    i += argc;
    if (a.length < argc || a.any((v) => v > 15)) return null;
    switch (op) {
      case _Op.b:
        bgMode = IconThemeBg.solid;
        bg = _from3(a);
      case _Op.g:
        bgMode = IconThemeBg.gradient;
        grad = a[0];
        bg = _from3(a.sublist(1));
      case _Op.t:
        text = _from3(a);
      case _Op.a:
        accent = _from3(a);
      case _Op.p:
        particle = a[0];
      case _Op.s:
        amount = a[0];
        speed = a[1];
    }
  }
  return closed ? IconThemeBasic(bgMode: bgMode, gradient: grad, bg: bg, text: text, accent: accent, particle: particle, amount: amount, speed: speed, hint: hint) : null;
}

/// シンボル → 読める DSL の文(`[ G 2 1 2 4 T f f f … ]`)。
String iconThemeSymbolsToText(List<int> sym) {
  final out = <String>[];
  for (final s in sym) {
    out.add(iconThemeSymbols[s]);
    if (s == _Op.end) break;
  }
  return out.join(' ');
}

// ---------- 拡張領域の中身 ----------

/// 形の 1 命令(0〜31 の格子)。`M x y` / `L x y` / `Q cx cy x y` / `Z`。
class IconThemeCmd {
  const IconThemeCmd(this.op, [this.args = const []]);
  final String op;
  final List<int> args;
  @override
  bool operator ==(Object other) => other is IconThemeCmd && other.op == op && _listEq(other.args, args);
  @override
  int get hashCode => Object.hash(op, Object.hashAll(args));
  List<Object> toJson() => [op, ...args];
}

/// きっかけ。
enum IconThemeTrigger { always, tap, slide }

/// スロット 1 つ(形 × 軌道 × きっかけ × 動き)。
class IconThemeSlot {
  const IconThemeSlot({required this.trigger, required this.shape, required this.path, this.rand = 8, this.angleRand = 0, this.easeA = 0, this.easeB = 0, this.mix = 0, this.sway = 4, this.spin = 0});
  final IconThemeTrigger trigger;

  /// 形 / 軌道の表の何番目か。
  final int shape;
  final int path;

  /// 出現のばらつき(0〜15)・角度のばらつき(0〜15、× 6°)。
  final int rand;
  final int angleRand;

  /// 動き A / B(0 = 直線 / 1 = イーズ / 2 = バネ / 3 = ガム)と B の割合(0〜7)。
  final int easeA;
  final int easeB;
  final int mix;

  /// 横揺れ・回転(0〜15)。
  final int sway;
  final int spin;

  @override
  bool operator ==(Object other) =>
      other is IconThemeSlot && other.trigger == trigger && other.shape == shape && other.path == path && other.rand == rand && other.angleRand == angleRand && other.easeA == easeA && other.easeB == easeB && other.mix == mix && other.sway == sway && other.spin == spin;
  @override
  int get hashCode => Object.hash(trigger, shape, path, rand, angleRand, easeA, easeB, mix, sway, spin);
}

/// 拡張領域の中身: ベクターの形・軌道・スロット([url] が null のとき)か、プラグインの配信 URL(https:// を省いたもの)。
class IconThemeExt {
  const IconThemeExt({this.shapes = const [], this.paths = const [], this.angle = 0, this.anim = 0, this.animSpeed = 0, this.slots = const [], this.url});
  const IconThemeExt.url(String this.url) : shapes = const [], paths = const [], angle = 0, anim = 0, animSpeed = 0, slots = const [];

  final List<List<IconThemeCmd>> shapes;

  /// 軌道(2 次ベジエ x0 y0 cx cy x1 y1、0〜31)。
  final List<List<int>> paths;

  /// 背景のグラデの角度(0〜15、× 22.5°)・アニメ(0 = なし / 1 = 角度が回る / 2 = 色相がゆらぐ / 3 = 明るさが脈打つ)・速さ(0〜7)。
  final int angle;
  final int anim;
  final int animSpeed;
  final List<IconThemeSlot> slots;
  final String? url;

  bool get isUrl => url != null;

  @override
  bool operator ==(Object other) {
    if (other is! IconThemeExt || other.url != url || other.angle != angle || other.anim != anim || other.animSpeed != animSpeed) return false;
    if (other.shapes.length != shapes.length || other.paths.length != paths.length || other.slots.length != slots.length) return false;
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].length != other.shapes[i].length) return false;
      for (var j = 0; j < shapes[i].length; j++) {
        if (shapes[i][j] != other.shapes[i][j]) return false;
      }
    }
    for (var i = 0; i < paths.length; i++) {
      if (!_listEq(paths[i], other.paths[i])) return false;
    }
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != other.slots[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(url, angle, anim, animSpeed, shapes.length, paths.length, slots.length);
}

/// 中身が容量を超えた。
class IconThemeCapacityError implements Exception {
  const IconThemeCapacityError(this.used, this.capacity);
  final int used;
  final int capacity;
  @override
  String toString() => 'icon theme: $used / $capacity bytes';
}

class _BitW {
  final bits = <int>[];
  void put(int v, int n) {
    for (var i = n - 1; i >= 0; i--) {
      bits.add((v >> i) & 1);
    }
  }

  List<int> bytes() => [
        for (var i = 0; i < bits.length; i += 8)
          () {
            var b = 0;
            for (var j = 0; j < 8; j++) {
              b = (b << 1) | (i + j < bits.length ? bits[i + j] : 0);
            }
            return b;
          }(),
      ];
}

class _BitR {
  _BitR(this.b);
  final List<int> b;
  var p = 0;
  int get(int n) {
    var v = 0;
    for (var i = 0; i < n; i++, p++) {
      final byte = (p >> 3) < b.length ? b[p >> 3] : 0;
      v = (v << 1) | ((byte >> (7 - (p & 7))) & 1);
    }
    return v;
  }
}

const _cmdOps = 'MLQZ';
const _cmdArgc = {'M': 2, 'L': 2, 'Q': 4, 'Z': 0};

/// 拡張の中身 → 65 バイト(と使った数)。超えたら [IconThemeCapacityError]。
(List<int>, int) iconThemePackExt(IconThemeExt ext) {
  final capacity = IconThemeLayout.instance.extK;
  if (ext.url != null) {
    final u = utf8.encode(ext.url!), used = u.length + 2;
    if (used > capacity) throw IconThemeCapacityError(used, capacity);
    return ([_extUrlMagic, u.length, ...u, ...List.filled(capacity - used, 0)], used);
  }
  final w = _BitW()..put(ext.shapes.length, 3);
  for (final sh in ext.shapes) {
    w.put(sh.length, 5);
    for (final c in sh) {
      w.put(_cmdOps.indexOf(c.op), 2);
      for (final a in c.args) {
        w.put(a & 31, 5);
      }
    }
  }
  w.put(ext.paths.length, 3);
  for (final p in ext.paths) {
    for (final v in p) {
      w.put(v & 31, 5);
    }
  }
  w
    ..put(ext.angle & 15, 4)
    ..put(ext.anim & 7, 3)
    ..put(ext.animSpeed & 7, 3)
    ..put(ext.slots.length, 3);
  for (final s in ext.slots) {
    w
      ..put(s.trigger.index, 2)
      ..put(s.shape, 2)
      ..put(s.path, 2)
      ..put(s.rand, 4)
      ..put(s.angleRand, 4)
      ..put(s.easeA, 2)
      ..put(s.easeB, 2)
      ..put(s.mix, 3)
      ..put(s.sway, 4)
      ..put(s.spin, 4);
  }
  final body = w.bytes(), used = body.length + 2;
  if (used > capacity) throw IconThemeCapacityError(used, capacity);
  return ([_extMagic, body.length, ...body, ...List.filled(capacity - used, 0)], used);
}

/// 65 バイト → 拡張の中身(読めなければ null)。
IconThemeExt? iconThemeUnpackExt(List<int> bytes) {
  if (bytes.length < 2) return null;
  if (bytes[0] == _extUrlMagic) {
    if (2 + bytes[1] > bytes.length) return null;
    try {
      return IconThemeExt.url(const Utf8Decoder().convert(bytes.sublist(2, 2 + bytes[1])));
    } catch (_) {
      return null;
    }
  }
  if (bytes[0] != _extMagic) return null;
  final len = bytes[1];
  if (2 + len > bytes.length) return null;
  final r = _BitR(bytes.sublist(2, 2 + len));
  final ns = r.get(3);
  if (ns > 4) return null;
  final shapes = <List<IconThemeCmd>>[];
  for (var k = 0; k < ns; k++) {
    final n = r.get(5), shape = <IconThemeCmd>[];
    for (var i = 0; i < n; i++) {
      final op = _cmdOps[r.get(2)];
      shape.add(IconThemeCmd(op, [for (var j = 0; j < _cmdArgc[op]!; j++) r.get(5)]));
    }
    shapes.add(shape);
  }
  final np = r.get(3);
  if (np > 4) return null;
  final paths = [
    for (var k = 0; k < np; k++) [for (var i = 0; i < 6; i++) r.get(5)],
  ];
  final angle = r.get(4), anim = r.get(3), animSpeed = r.get(3), nl = r.get(3);
  final slots = <IconThemeSlot>[];
  for (var k = 0; k < nl; k++) {
    final trig = r.get(2), shape = r.get(2), path = r.get(2);
    final s = (rand: r.get(4), arand: r.get(4), ea: r.get(2), eb: r.get(2), mix: r.get(3), sway: r.get(4), spin: r.get(4));
    if (shape >= ns || path >= np || trig > 2) return null;
    slots.add(IconThemeSlot(trigger: IconThemeTrigger.values[trig], shape: shape, path: path, rand: s.rand, angleRand: s.arand, easeA: s.ea, easeB: s.eb, mix: s.mix, sway: s.sway, spin: s.spin));
  }
  return IconThemeExt(shapes: shapes, paths: paths, angle: angle, anim: anim, animSpeed: animSpeed, slots: slots);
}

/// 白色化(仮組みの xorshift。JS の 32 ビットの演算をそのまま)。同じ関数で戻る。
List<int> iconThemeWhiten(List<int> bytes) {
  var s = 0x9e3779b9.toSigned(32);
  return [
    for (final b in bytes)
      () {
        s = (s ^ (s << 13).toSigned(32)).toSigned(32);
        s = (s ^ ((s & 0xFFFFFFFF) >> 17)).toSigned(32);
        s = (s ^ (s << 5).toSigned(32)).toSigned(32);
        return b ^ (s & 255);
      }(),
  ];
}

const _gray = [0, 1, 3, 2];

// ---------- 書き込み ----------

/// 書き込みの結果。
class IconThemeEncodeInfo {
  const IconThemeEncodeInfo({required this.symbols, required this.text, required this.palBlocks, required this.extBlocks, required this.extUsed, required this.extCapacity});
  final List<int> symbols;
  final String text;
  final int palBlocks;
  final int extBlocks;
  final int extUsed;
  final int extCapacity;
}

void _fillBlock(Uint8List d, int bx, int by, List<int> c) {
  for (var y = by * _blk; y < (by + 1) * _blk; y++) {
    for (var x = bx * _blk; x < (bx + 1) * _blk; x++) {
      final i = (y * iconThemeSize + x) * 4;
      d[i] = c[0];
      d[i + 1] = c[1];
      d[i + 2] = c[2];
      d[i + 3] = 255;
    }
  }
}

/// 400×400 の RGBA [d] の四隅にテーマを書く(その場で書き換える)。[ramp] = 拡張領域の 4 段の色([iconThemeRamp])。
IconThemeEncodeInfo iconThemeEncode(Uint8List d, IconThemeBasic theme, {IconThemeExt? ext, List<List<int>>? ramp}) {
  assert(d.length == iconThemeSize * iconThemeSize * 4);
  final layout = IconThemeLayout.instance;
  final sym = iconThemeToSymbols(theme);
  if (sym.length > _palK) throw StateError('DSL too long');
  final code = IconThemeRs.gf5.encode([...sym, ...List.filled(_palK - sym.length, _Op.end)], iconThemePalNsym);
  for (final (b, ref) in layout.palCal) {
    _fillBlock(d, b.$1, b.$2, _ref[ref]!);
  }
  for (var i = 0; i < layout.palData.length; i++) {
    _fillBlock(d, layout.palData[i].$1, layout.palData[i].$2, _palette[code[i]]);
  }
  var extBlocks = 0, extUsed = 0;
  if (ext != null) {
    final colors = ramp ?? iconThemeRamp(theme.accent);
    final (bytes, used) = iconThemePackExt(ext);
    final cw = iconThemeWhiten(IconThemeRs.gf8.encode(bytes, iconThemeExtNsym));
    for (final (b, level) in layout.extCal) {
      _fillBlock(d, b.$1, b.$2, colors[level]);
    }
    for (var i = 0; i < layout.extData.length; i++) {
      final two = (cw[i >> 2] >> (6 - 2 * (i & 3))) & 3;
      _fillBlock(d, layout.extData[i].$1, layout.extData[i].$2, colors[_gray[two]]);
    }
    extBlocks = layout.extCal.length + layout.extData.length;
    extUsed = used;
  }
  return IconThemeEncodeInfo(symbols: sym, text: iconThemeSymbolsToText(sym), palBlocks: layout.palCal.length + layout.palData.length, extBlocks: extBlocks, extUsed: extUsed, extCapacity: layout.extK);
}

// ---------- 読み戻し ----------

/// 読み戻しの結果。
class IconThemeDecoded {
  const IconThemeDecoded({required this.ok, this.theme, this.text, this.palCorrected = 0, this.palTotal = 0, this.ext, this.extCorrected = 0, this.error});
  final bool ok;
  final IconThemeBasic? theme;
  final String? text;
  final int palCorrected;
  final int palTotal;

  /// 拡張領域(読めなければ null。基本テーマだけで描く)。
  final IconThemeExt? ext;
  final int extCorrected;
  final String? error;

  static const none = IconThemeDecoded(ok: false);
}

Rgb Function((int, int)) _sampler(Uint8List d, int w, int h) => (b) {
      final (bx, by) = b;
      final x0 = _jsRound((bx * _blk + 2.5) / iconThemeSize * w), y0 = _jsRound((by * _blk + 2.5) / iconThemeSize * h);
      final x1 = math.max(x0 + 1, _jsRound((bx * _blk + 5.5) / iconThemeSize * w)), y1 = math.max(y0 + 1, _jsRound((by * _blk + 5.5) / iconThemeSize * h));
      var r = 0.0, g = 0.0, bl = 0.0, n = 0;
      for (var y = y0; y < y1 && y < h; y++) {
        for (var x = x0; x < x1 && x < w; x++) {
          final i = (y * w + x) * 4;
          r += d[i];
          g += d[i + 1];
          bl += d[i + 2];
          n++;
        }
      }
      return n > 0 ? [r / n, g / n, bl / n] : [0.0, 0.0, 0.0];
    };

List<double>? _solve4(List<List<double>> a, List<double> y) {
  final m = [for (var i = 0; i < 4; i++) [...a[i], y[i]]];
  for (var c = 0; c < 4; c++) {
    var p = c;
    for (var r = c + 1; r < 4; r++) {
      if (m[r][c].abs() > m[p][c].abs()) p = r;
    }
    if (m[p][c].abs() < 1e-6) return null;
    final t = m[c];
    m[c] = m[p];
    m[p] = t;
    for (var r = 0; r < 4; r++) {
      if (r != c) {
        final f = m[r][c] / m[c][c];
        for (var k = c; k < 5; k++) {
          m[r][k] -= f * m[c][k];
        }
      }
    }
  }
  return [for (var i = 0; i < 4; i++) m[i][4] / m[i][i]];
}

/// 校正ブロックから、見えた色 → 本当の色 のアフィン写像(最小二乗)。
Rgb Function(Rgb)? _fitCorrection(Map<String, Rgb> obs) {
  final keys = _ref.keys.where(obs.containsKey).toList();
  final rows = [for (final k in keys) [...obs[k]!, 1.0]];
  final ata = [
    for (var i = 0; i < 4; i++) [for (var j = 0; j < 4; j++) rows.fold<double>(0, (s, r) => s + r[i] * r[j])],
  ];
  final mtx = <List<double>>[];
  for (var ch = 0; ch < 3; ch++) {
    final sol = _solve4([for (final r in ata) [...r]], [for (var i = 0; i < 4; i++) rows.indexed.fold<double>(0, (s, e) => s + e.$2[i] * _ref[keys[e.$1]]![ch])]);
    if (sol == null) return null;
    mtx.add(sol);
  }
  return (c) => [for (final m in mtx) math.min(255.0, math.max(0.0, m[0] * c[0] + m[1] * c[1] + m[2] * c[2] + m[3]))];
}

/// 任意の大きさ [w]×[h] の RGBA [d] からテーマを読み戻す(正方形のアイコンを、そのまま縦横に縮め / 伸ばしたもの)。
IconThemeDecoded iconThemeDecode(Uint8List d, int w, int h) {
  if (w < 32 || h < 32 || d.length < w * h * 4) return IconThemeDecoded.none;
  final layout = IconThemeLayout.instance;
  final at = _sampler(d, w, h);
  final acc = <String, List<Rgb>>{};
  for (final (b, ref) in layout.palCal) {
    acc.putIfAbsent(ref, () => []).add(at(b));
  }
  final obs = {
    for (final e in acc.entries) e.key: [for (var i = 0; i < 3; i++) e.value.fold<double>(0, (s, v) => s + v[i]) / e.value.length],
  };
  // テーマを埋め込んだ画像か: 校正ブロックの白が黒より十分明るく、同じ基準色のブロックどうしが揃っている。違えば何もしない
  // (ふつうのアイコンで、重い復号を回さない)。
  if (!_calibrationLooksRight(acc)) return const IconThemeDecoded(ok: false, error: 'calibration');
  final fix = _fitCorrection(obs) ?? (Rgb c) => c;
  // シンボルごとに、近い順の候補(パレットの番号と Lab の距離)。
  final cands = [
    for (final b in layout.palData)
      () {
        final lab = _rgbToLab(fix(at(b)));
        final ds = [
          for (var i = 0; i < _palLab.length; i++) (i, math.pow(_palLab[i][0] - lab[0], 2) + math.pow(_palLab[i][1] - lab[1], 2) + math.pow(_palLab[i][2] - lab[2], 2)),
        ]..sort((a, b) => a.$2.compareTo(b.$2));
        return ds.take(3).toList();
      }(),
  ];
  final raw = [for (final c in cands) c.first.$1];
  final palDecoded = _decodePalette(raw, cands);
  if (palDecoded == null) return const IconThemeDecoded(ok: false, error: 'palette');
  final (data, corrected, theme) = palDecoded;
  // 拡張領域: 輝度の 4 段が順に並んでいて、RS が通り、頭の印が合ったときだけ。
  IconThemeExt? ext;
  var extCorrected = 0;
  final lv = [<double>[], <double>[], <double>[], <double>[]];
  for (final (b, level) in layout.extCal) {
    lv[level].add(_luma(fix(at(b))));
  }
  final mean = [for (final a in lv) a.isEmpty ? 0.0 : a.reduce((x, y) => x + y) / a.length];
  if (mean[0] < mean[1] && mean[1] < mean[2] && mean[2] < mean[3] && mean[3] - mean[0] > 60) {
    final cw = List.filled(layout.extBytes, 0);
    for (var i = 0; i < layout.extData.length; i++) {
      if ((i >> 2) >= cw.length) break;
      final y = _luma(fix(at(layout.extData[i])));
      var best = 0;
      for (var k = 1; k < 4; k++) {
        if ((y - mean[k]).abs() < (y - mean[best]).abs()) best = k;
      }
      cw[i >> 2] |= _gray[best] << (6 - 2 * (i & 3));
    }
    try {
      final (bytes, n) = IconThemeRs.gf8.decode(iconThemeWhiten(cw), iconThemeExtNsym);
      ext = iconThemeUnpackExt(bytes);
      extCorrected = n;
    } on IconThemeRsError {
      ext = null;
    }
  }
  return IconThemeDecoded(ok: true, theme: theme, text: iconThemeSymbolsToText(data), palCorrected: corrected, palTotal: raw.length, ext: ext, extCorrected: ext == null ? 0 : extCorrected);
}


/// パレット領域の復号。まず近い色そのままで RS にかけ、通らなければ**自信の無いシンボル**(1 番と 2 番の候補の距離が近いもの)を
/// 2 番目の候補に替えて試す(Chase 復号。小さく縮めて強く再圧縮した画像では、色の滲みで 31 個中 10 個ほどが隣の色に寄る。
/// 替えてみる [_chaseWidth] か所の組み合わせの中で RS が通り、DSL として読めたものを採る)。書き込みの形は仮組みと同じまま。
/// 校正ブロックが基準色らしく見えないとき(= テーマを埋め込んでいない画像)は、ここまで来ない([_calibrationLooksRight])。
(List<int>, int, IconThemeBasic)? _decodePalette(List<int> raw, List<List<(int, num)>> cands) {
  (List<int>, int, IconThemeBasic)? attempt(List<int> sym, int flipped) {
    try {
      final (data, n) = IconThemeRs.gf5.decode(sym, iconThemePalNsym);
      final theme = iconThemeFromSymbols(data);
      return theme == null ? null : (data, n + flipped, theme);
    } on IconThemeRsError {
      return null;
    }
  }

  final first = attempt(raw, 0);
  if (first != null) return first;
  // 自信の無い順に 8 か所。
  final order = [for (var i = 0; i < cands.length; i++) i]..sort((a, b) => (cands[a][1].$2 - cands[a][0].$2).compareTo(cands[b][1].$2 - cands[b][0].$2));
  final weak = order.take(_chaseWidth).toList();
  // 替える数の少ない順に(誤って通る見込みを減らす)。
  final masks = [for (var m = 1; m < 1 << weak.length; m++) m]..sort((a, b) => _bitCount(a).compareTo(_bitCount(b)));
  for (final m in masks) {
    final sym = [...raw];
    for (var k = 0; k < weak.length; k++) {
      if (m & (1 << k) != 0) sym[weak[k]] = cands[weak[k]][1].$1;
    }
    final r = attempt(sym, _bitCount(m));
    if (r != null) return r;
  }
  return null;
}

const _chaseWidth = 10;

int _bitCount(int v) {
  var c = 0;
  for (var x = v; x != 0; x &= x - 1) {
    c++;
  }
  return c;
}

/// 校正ブロック(W / K / R / G / B が四隅に 17 個)が基準色らしいか。白と黒の輝度の差が 100 より大きく、同じ基準色の
/// ブロックどうしの色の違いが小さい(四隅で同じ色に見える)。R / G / B は、その色の成分がいちばん強い。
bool _calibrationLooksRight(Map<String, List<Rgb>> acc) {
  double mean(String k, int ch) => acc[k]!.fold<double>(0, (s, v) => s + v[ch]) / acc[k]!.length;
  if (!_ref.keys.every(acc.containsKey)) return false;
  final w = [for (var i = 0; i < 3; i++) mean('W', i)], k = [for (var i = 0; i < 3; i++) mean('K', i)];
  if (_luma(w) - _luma(k) < 100) return false;
  for (final (key, ch) in const [('R', 0), ('G', 1), ('B', 2)]) {
    final c = [for (var i = 0; i < 3; i++) mean(key, i)];
    for (var o = 0; o < 3; o++) {
      if (o != ch && c[o] >= c[ch]) return false;
    }
  }
  for (final e in acc.entries) {
    for (final v in e.value) {
      for (final other in e.value) {
        final d = (v[0] - other[0]).abs() + (v[1] - other[1]).abs() + (v[2] - other[2]).abs();
        if (d > 150) return false;
      }
    }
  }
  return true;
}

