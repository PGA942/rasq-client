import 'package:flutter/widgets.dart';
import 'package:rasq_design/rasq_design.dart';

/// RAi の幅 (D-185): 入力ウィジェット(バー)・発言・履歴 / モデル FOW・大画面のアシスタントページの
/// コラムを同じ幅に揃える。狭い画面は画面幅いっぱい(左右 8px)、広い画面は 520px。
const raiPanelMaxWidth = 520.0;

double raiPanelWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < raiPanelMaxWidth + RasqSpacing.sm * 2 ? w - RasqSpacing.sm * 2 : raiPanelMaxWidth;
}
