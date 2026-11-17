// ヘッダー(バナー)画像に入れる「RASQ アカウントの手がかり」のコーデック (D-591)。
//
// RASQ のプロフィールで「アカウントを表示」(`showLinksOnSnsProfiles`)にした人の SNS のヘッダーの**上の縁の 1 段**に、
// 輝度 4 段のブロックで RASQ のハンドルを書く。ほかの人が SNS 上でそのプロフィールを見たら、ヘッダーを読んで RASQ アカウントへの
// 入口(チップ)を出す。**誰のページを見たかをサーバーへ送らない**(画像は SNS が配っているものを取るだけ。Central へは、
// チップを押してアカウントページを開くまで何も聞かない)。アイコンの埋め込み(D-577〜D-581)の書き方を土台にした素の Dart。
//
// - 形: ヘッダーを 3:1(書くときは 1440×480)に揃え、上端の 1 段(高さ = 高さの 1/48。480px で 10px)に正方形のブロックを
//   横に [headerHintCols] = 144 個。
//   - **左右の端の 4 個ずつ = 校正**(輝度の 4 段。左は暗 → 明、右は明 → 暗)。
//   - **間の 136 個 = データ**(1 個 2 ビット、輝度の 4 段・グレイ符号 = アイコンの拡張領域と同じ)= 34 バイト。
//     中身 24 バイト + RS(GF(2^8))訂正用 10(5 バイトまで直す)。白色化してから書く。
// - 色: 画像の上端の平均の色相で 4 段を作る([iconThemeRamp]。上の縁に細い帯が乗ったように見える)。輝度だけを読むのは、
//   JPEG の色差の間引き(4:2:0)で 1 段しかない帯の色が下の画素に引っぱられるため。
// - 中身(24 バイト): 印と版 1 / 書いた SNS アカウントの短いハッシュ 1 / ハンドル 22(`a-z 0-9 _` の 37 字 + 詰め物 = 38 進で
//   3 字ずつ 2 バイト。Central のハンドルは 3〜32 字、大小文字を区別しない)。ハッシュは、ほかの人のヘッダーを写して使った
//   ものを見分けるため(偽装の防ぎではない。ハンドルはだれでも書けるので、確かめるのはアカウントページを開いたとき)。
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../theme/icon_theme/icon_theme_codec.dart' show IconThemeRs, IconThemeRsError, iconThemeRamp, iconThemeWhiten;

/// 書くときの大きさ(3:1)。
const headerHintWidth = 1440;
const headerHintHeight = 480;

/// 1 段のブロックの数(= 縦の割り。ブロックは高さの 1/48 の正方形)。
const headerHintCols = 144;
const _blk = headerHintWidth ~/ headerHintCols; // 10
const _cal = 4;
const _nsym = 10;
const _k = 24;
const _magic = 0xB1; // 'B'anner の v1
const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789_';
const _gray = [0, 1, 3, 2];
final _handleRe = RegExp(r'^[a-z0-9_]{1,32}$');

/// 読めた手がかり。
class HeaderHint {
  const HeaderHint({required this.handle, required this.accountHash, this.corrected = 0});

  /// RASQ のハンドル(小文字)。
  final String handle;

  /// 書いた SNS アカウント(`kind:instance:handle`)の短いハッシュ([headerHintAccountHash])。
  final int accountHash;

  /// RS で直したバイトの数。
  final int corrected;

  /// [accountKey] の SNS アカウントのために書いたものか(写したヘッダーなら false)。
  bool writtenFor(String accountKey) => accountHash == headerHintAccountHash(accountKey);

  @override
  String toString() => 'HeaderHint(@$handle, ${accountHash.toRadixString(16)}, corrected $corrected)';
}

/// 書けないハンドル(字種 / 長さ)。
class HeaderHintHandleError implements Exception {
  const HeaderHintHandleError(this.handle);
  final String handle;
  @override
  String toString() => 'handle not embeddable: $handle';
}

/// SNS アカウントの短いハッシュ(FNV-1a 32 を 1 バイトに畳む。大小文字は区別しない)。
int headerHintAccountHash(String accountKey) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(accountKey.toLowerCase())) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return (h ^ (h >> 8) ^ (h >> 16) ^ (h >> 24)) & 0xFF;
}

/// 書けるハンドルか(小文字にしてから見る)。
bool headerHintCanEmbed(String handle) => _handleRe.hasMatch(handle.toLowerCase());

/// 中身 → 24 バイト。
List<int> headerHintPack(String handle, String accountKey) {
  final h = handle.toLowerCase();
  if (!_handleRe.hasMatch(h)) throw HeaderHintHandleError(handle);
  final out = [_magic, headerHintAccountHash(accountKey)];
  for (var i = 0; i < 33; i += 3) {
    int c(int j) => j < h.length ? _alphabet.indexOf(h[j]) + 1 : 0;
    final v = c(i) * 38 * 38 + c(i + 1) * 38 + c(i + 2);
    out
      ..add(v >> 8)
      ..add(v & 0xFF);
  }
  return out;
}

/// 24 バイト → 中身(印が違う / ハンドルとして読めない → null)。
HeaderHint? headerHintUnpack(List<int> bytes, {int corrected = 0}) {
  if (bytes.length != _k || bytes[0] != _magic) return null;
  final chars = <int>[];
  for (var i = 2; i < _k; i += 2) {
    final v = bytes[i] << 8 | bytes[i + 1];
    if (v >= 38 * 38 * 38) return null;
    chars.addAll([v ~/ (38 * 38), v ~/ 38 % 38, v % 38]);
  }
  final end = chars.indexOf(0);
  final used = end < 0 ? chars : chars.sublist(0, end);
  // 詰め物の後ろに字が続くものは、壊れたものとして捨てる。
  if (end >= 0 && chars.skip(end).any((c) => c != 0)) return null;
  final handle = String.fromCharCodes([for (final c in used) _alphabet.codeUnitAt(c - 1)]);
  if (!_handleRe.hasMatch(handle)) return null;
  return HeaderHint(handle: handle, accountHash: bytes[1], corrected: corrected);
}

double _luma(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

/// 1440×480 の RGBA [d] の上端の平均の色(帯の色相を決める)。
List<int> headerHintTopColor(Uint8List d) {
  var r = 0, g = 0, b = 0, n = 0;
  for (var y = 0; y < _blk; y++) {
    for (var x = 0; x < headerHintWidth; x += 2) {
      final i = (y * headerHintWidth + x) * 4;
      r += d[i];
      g += d[i + 1];
      b += d[i + 2];
      n++;
    }
  }
  return [r ~/ n, g ~/ n, b ~/ n];
}

/// ブロック [i] の輝度の段 → 置く列(左の校正 / データ / 右の校正)。
int _calLevelAt(int col) => col < _cal ? col : headerHintCols - 1 - col;

/// 1440×480 の RGBA [d] の上端の 1 段に手がかりを書く(その場で書き換える)。[ramp] を省けば、上端の平均の色から作る。
void headerHintEncode(Uint8List d, String handle, String accountKey, {List<List<int>>? ramp}) {
  assert(d.length == headerHintWidth * headerHintHeight * 4);
  final colors = ramp ?? iconThemeRamp(headerHintTopColor(d));
  final cw = iconThemeWhiten(IconThemeRs.gf8.encode(headerHintPack(handle, accountKey), _nsym));
  for (var col = 0; col < headerHintCols; col++) {
    final int level;
    if (col < _cal || col >= headerHintCols - _cal) {
      level = _calLevelAt(col);
    } else {
      final i = col - _cal;
      level = _gray[(cw[i >> 2] >> (6 - 2 * (i & 3))) & 3];
    }
    final c = colors[level];
    for (var y = 0; y < _blk; y++) {
      for (var x = col * _blk; x < (col + 1) * _blk; x++) {
        final p = (y * headerHintWidth + x) * 4;
        d[p] = c[0];
        d[p + 1] = c[1];
        d[p + 2] = c[2];
        d[p + 3] = 255;
      }
    }
  }
}

int _jsRound(double v) => (v + 0.5).floor();

/// 任意の大きさ [w]×[h] の RGBA [d](3:1 の書いたものを、そのまま縮め / 伸ばしたもの)から手がかりを読む。
/// 校正の 4 段が順に並んでいない / RS が通らない / 印やハンドルが違う → null。
HeaderHint? headerHintDecode(Uint8List d, int w, int h) {
  if (w < 288 || h < 48 || d.length < w * h * 4) return null;
  // ブロックの真ん中(書いた 10px のうち 3〜7px)の輝度。
  final y0 = _jsRound(3 / headerHintHeight * h), y1 = math.max(y0 + 1, _jsRound(7 / headerHintHeight * h));
  double at(int col) {
    final x0 = _jsRound((col * _blk + 3) / headerHintWidth * w), x1 = math.max(x0 + 1, _jsRound((col * _blk + 7) / headerHintWidth * w));
    var s = 0.0, n = 0;
    for (var y = y0; y < y1 && y < h; y++) {
      for (var x = x0; x < x1 && x < w; x++) {
        final i = (y * w + x) * 4;
        s += _luma(d[i], d[i + 1], d[i + 2]);
        n++;
      }
    }
    return n == 0 ? 0 : s / n;
  }

  final lv = [<double>[], <double>[], <double>[], <double>[]];
  for (var col = 0; col < _cal; col++) {
    lv[col].add(at(col));
    lv[col].add(at(headerHintCols - 1 - col));
  }
  final mean = [for (final a in lv) (a[0] + a[1]) / 2];
  // 左右で同じ段が同じに見えて、4 段が順に並び、暗と明が十分離れている(ふつうのヘッダーで重い復号を回さない)。
  if (!(mean[0] < mean[1] && mean[1] < mean[2] && mean[2] < mean[3] && mean[3] - mean[0] > 60)) return null;
  for (final a in lv) {
    if ((a[0] - a[1]).abs() > 40) return null;
  }
  // 段ごとに近い順の候補(Chase 復号に使う。アイコンのパレット領域と同じ考え方)。
  final cands = <List<(int, double)>>[];
  for (var col = _cal; col < headerHintCols - _cal; col++) {
    final y = at(col);
    cands.add([for (var k = 0; k < 4; k++) (k, (y - mean[k]).abs())]..sort((a, b) => a.$2.compareTo(b.$2)));
  }
  List<int> bytesOf(List<int> levels) {
    final cw = List.filled(_k + _nsym, 0);
    for (var i = 0; i < levels.length; i++) {
      cw[i >> 2] |= _gray[levels[i]] << (6 - 2 * (i & 3));
    }
    return cw;
  }

  HeaderHint? attempt(List<int> levels, int flipped) {
    try {
      final (bytes, n) = IconThemeRs.gf8.decode(iconThemeWhiten(bytesOf(levels)), _nsym);
      return headerHintUnpack(bytes, corrected: n + flipped);
    } on IconThemeRsError {
      return null;
    } on RangeError {
      return null;
    }
  }

  final raw = [for (final c in cands) c.first.$1];
  final first = attempt(raw, 0);
  if (first != null) return first;
  // 自信の無いブロック(1 番と 2 番の候補が近いもの)を 2 番目の候補に替えて試す。替える数の少ない順に。
  final order = [for (var i = 0; i < cands.length; i++) i]..sort((a, b) => (cands[a][1].$2 - cands[a][0].$2).compareTo(cands[b][1].$2 - cands[b][0].$2));
  final weak = order.take(_chaseWidth).toList();
  final masks = [for (var m = 1; m < 1 << weak.length; m++) m]..sort((a, b) => _bitCount(a).compareTo(_bitCount(b)));
  for (final m in masks) {
    final levels = [...raw];
    for (var k = 0; k < weak.length; k++) {
      if (m & (1 << k) != 0) levels[weak[k]] = cands[weak[k]][1].$1;
    }
    final r = attempt(levels, _bitCount(m));
    if (r != null) return r;
  }
  return null;
}

const _chaseWidth = 8;

int _bitCount(int v) {
  var c = 0;
  for (var x = v; x != 0; x &= x - 1) {
    c++;
  }
  return c;
}
