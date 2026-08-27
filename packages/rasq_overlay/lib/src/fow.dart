import 'package:flutter/foundation.dart';

/// FOW type (原典: UI_Elements「FOWタイプ（3種）」).
enum FowPanelType { widget, interstitial, system }

/// FOW confirm modes (原典: UI_status confirmMode + 何をやる.md Stickオプション).
enum FowConfirmMode { immediate, confirm, saveDiscard, stick }

/// Presentation spec for an entry on the `fow` layer.
///
/// FOWs dock to the bottom edge as resizable panels. When several are open
/// they stack bottom-up: the newest is at the very bottom, older ones are
/// pushed above it (ワイヤーフレーム: コンポーザーの下に絵文字パネル).
class FowSpec {
  FowSpec({
    this.type = FowPanelType.widget,
    this.confirmMode = FowConfirmMode.immediate,
    double initialHeightFactor = 0.45,
    this.minHeightFactor = 0.2,
    this.maxHeightFactor = 0.92,
    this.resizable = true,
    this.title,
    this.cancelText,
    this.confirmText,
    this.showHandle = true,
    this.avoidKeyboard = true,
  }) : heightFactor = ValueNotifier(initialHeightFactor.clamp(minHeightFactor, maxHeightFactor));

  final FowPanelType type;
  final FowConfirmMode confirmMode;

  /// Current height as a fraction of the host height (mutable via the handle).
  final ValueNotifier<double> heightFactor;
  final double minHeightFactor;
  final double maxHeightFactor;
  final bool resizable;

  /// Header row (キャンセル / タイトル / 決定). Absent for stick / headerless widgets.
  final String? title;
  final String? cancelText;
  final String? confirmText;
  final bool showHandle;

  /// Lift the panel above the soft keyboard.
  final bool avoidKeyboard;

  bool get hasHeader => title != null || cancelText != null || confirmText != null;

  /// Interstitial FOWs take the screen: scrim + barrier discard. Widget/system FOWs
  /// leave the content behind them interactive.
  bool get blocksContent => type == FowPanelType.interstitial;

  void resizeBy(double deltaFactor) => heightFactor.value = (heightFactor.value - deltaFactor).clamp(minHeightFactor, maxHeightFactor);
}
