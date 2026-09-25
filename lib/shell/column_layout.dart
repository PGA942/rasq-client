import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_dsl.dart';

/// 小型 / 大型カラムのサイズ比 (D-320)。幅の広い画面(≥840dp)の第2 / 第3カラムに使う。
///
/// 第3カラムにページが開いている間は第2カラムが小型・第3カラムが大型、空のときは逆 (D-057)。
/// 設定は「アプリの外観 → カラムの幅」、KV `appearance.columns.v1`(`split` / `smallPx` / `largePx`)。
enum ColumnSplit {
  even('1:1', '同じ幅'),
  twoThree('2:3', '小型 2 : 大型 3'),
  threeFive('3:5', '小型 3 : 大型 5'),
  smallFixed('小型カラムの幅を固定', '小型カラムを決めた幅にし、残りを大型カラムに'),
  largeFixed('大型カラムの幅を固定', '大型カラムを決めた幅にし、残りを小型カラムに');

  const ColumnSplit(this.label, this.hint);
  final String label;
  final String hint;

  bool get fixed => this == smallFixed || this == largeFixed;

  static ColumnSplit? byName(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// カラムの最小幅。固定幅が入らない画面では、もう片方をこれ以上残す。
const int kMinColumnWidth = 280;

/// 固定幅として入れられる上限(px)。
const int kMaxColumnWidth = 2000;

/// 既定の小型カラムの幅 = これまでの検索ホーム幅 (D-057)。
const int kDefaultSmallColumnPx = 320;

/// 大型カラム固定を初めて選んだときの幅。
const int kDefaultLargeColumnPx = 720;

class ColumnLayout {
  const ColumnLayout({this.split = ColumnSplit.smallFixed, this.smallPx = kDefaultSmallColumnPx, this.largePx = kDefaultLargeColumnPx});

  /// 既定 = これまでの見た目(小型カラム 320px 固定、残りが大型)。
  static const standard = ColumnLayout();

  final ColumnSplit split;
  final int smallPx;
  final int largePx;

  factory ColumnLayout.fromSettings(Map<String, Object?> v) => ColumnLayout(
        split: ColumnSplit.byName(v['split']) ?? standard.split,
        smallPx: validColumnPx(v['smallPx']) ?? kDefaultSmallColumnPx,
        largePx: validColumnPx(v['largePx']) ?? kDefaultLargeColumnPx,
      );

  @override
  bool operator ==(Object other) => other is ColumnLayout && other.split == split && other.smallPx == smallPx && other.largePx == largePx;

  @override
  int get hashCode => Object.hash(split, smallPx, largePx);
}

/// 保存値 / 入力を固定幅として受け付けるか。整数(文字列も可)で [kMinColumnWidth]〜[kMaxColumnWidth] のときだけ値を返す。
int? validColumnPx(Object? v) {
  final n = switch (v) {
    int i => i,
    double d when d == d.roundToDouble() => d.toInt(),
    String s => int.tryParse(s.trim()),
    _ => null,
  };
  return n != null && n >= kMinColumnWidth && n <= kMaxColumnWidth ? n : null;
}

/// 固定幅の入力の検証。問題なければ null、あれば画面に出す文。
String? columnPxError(String input) {
  final s = input.trim();
  if (s.isEmpty) return '幅を入れてください';
  if (int.tryParse(s) == null) return '数字(整数)で入れてください';
  if (validColumnPx(s) == null) return '$kMinColumnWidth〜$kMaxColumnWidth px の間で入れてください';
  return null;
}

/// カラム 2 つ分の幅 [content](サイドバーのレールを除いた幅)を小型 / 大型に分ける (D-320)。
///
/// 画面が狭くて入らないときの決まり:
/// - 比: 小型が [kMinColumnWidth] より細くなるなら、小型を最小幅に広げる(半分を超えない)。
/// - 小型固定: 小型は半分まで(大型より広くしない)。
/// - 大型固定: 小型を [kMinColumnWidth] 残すところまで縮める(半分より細くはしない)。
/// - どれも、[content] が最小幅 2 つ分に足りなければ半分ずつ。
({double small, double large}) splitColumns(double content, ColumnLayout layout) {
  if (content <= 0) return (small: 0, large: 0);
  final half = content / 2;
  // 小型の最小幅(入らなければ半分)。
  final minSmall = kMinColumnWidth < half ? kMinColumnWidth.toDouble() : half;
  double ratio(int a, int b) => content * a / (a + b);
  final wanted = switch (layout.split) {
    ColumnSplit.even => half,
    ColumnSplit.twoThree => ratio(2, 3),
    ColumnSplit.threeFive => ratio(3, 5),
    ColumnSplit.smallFixed => layout.smallPx.toDouble(),
    ColumnSplit.largeFixed => content - layout.largePx,
  };
  final small = wanted.clamp(minSmall, half).toDouble();
  return (small: small, large: content - small);
}

/// いまのカラムの比の設定。
final columnLayoutProvider = Provider<ColumnLayout>((ref) {
  final v = ref.watch(settingsAreaProvider(columnLayoutArea)).value;
  return v == null ? ColumnLayout.standard : ColumnLayout.fromSettings(v);
});

/// カラムの比の設定の保存先 (D-320)。
const columnLayoutArea = 'appearance.columns';
