import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../settings/settings_dsl.dart';
import 'rai_llm.dart' show raiSettingsArea;

/// RAi の幅 (D-185): 入力ウィジェット(バー)・発言・履歴 / モデル FOW・大画面のアシスタントページの
/// コラムを同じ幅に揃える。狭い画面は画面幅いっぱい(左右 8px)、広い画面は 520px。
const raiPanelMaxWidth = 520.0;

double raiPanelWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < raiPanelMaxWidth + RasqSpacing.sm * 2 ? w - RasqSpacing.sm * 2 : raiPanelMaxWidth;
}

/// アシスタントのチャット列の幅 (D-232): カラム幅 600px 未満なら最大幅、それ以上なら増えた分の 1/2 まで広げる。
const raiChatBaseWidth = 600.0;
double raiChatWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < raiChatBaseWidth ? w : raiChatBaseWidth + (w - raiChatBaseWidth) / 2;
}

/// 入力タイルの置き場 (D-233): カラム(列スロットの番号)と縦位置(0 = ヘッダーの下、1 = フッターの上、間は自由)。
/// 大きさは変えない。設定エリア `rai` の `barColumn` / `barY` に保存。
@immutable
class RaiBarPlacement {
  const RaiBarPlacement({this.column = 0, this.y = 1});
  final int column;
  final double y;
  bool get atTop => y <= 0.02;
  bool get atBottom => y >= 0.98;
  RaiBarPlacement copyWith({int? column, double? y}) => RaiBarPlacement(column: column ?? this.column, y: y ?? this.y);
  @override
  bool operator ==(Object other) => other is RaiBarPlacement && other.column == column && other.y == y;
  @override
  int get hashCode => Object.hash(column, y);
}

class RaiBarPlacementStore extends Notifier<RaiBarPlacement> {
  @override
  RaiBarPlacement build() {
    final v = ref.watch(settingsAreaProvider(raiSettingsArea)).value ?? const <String, Object?>{};
    return RaiBarPlacement(column: (v['barColumn'] as num?)?.toInt() ?? 0, y: ((v['barY'] as num?)?.toDouble() ?? 1).clamp(0, 1));
  }

  /// 離したときの精算 (D-233): 縦は端から 15% 以内なら端に吸着。
  void set(RaiBarPlacement p) {
    final y = p.y < 0.15 ? 0.0 : (p.y > 0.85 ? 1.0 : p.y);
    final next = RaiBarPlacement(column: p.column, y: y);
    state = next;
    final store = ref.read(settingsAreaProvider(raiSettingsArea).notifier);
    store.set('barColumn', next.column);
    store.set('barY', next.y);
  }
}

final raiBarPlacementProvider = NotifierProvider<RaiBarPlacementStore, RaiBarPlacement>(RaiBarPlacementStore.new);
