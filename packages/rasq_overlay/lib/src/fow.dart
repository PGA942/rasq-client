import 'package:flutter/widgets.dart';

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
    this.headerTrailing,
    this.showHandle = true,
    this.avoidKeyboard = true,
    this.dockAboveFooter = false,
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

  /// ヘッダー右側の空きスペースに置くコントロール (D-045: コンポーザーの
  /// 公開設定など)。[confirmText] より優先して右端に描画される。
  final Widget? headerTrailing;
  final bool showHandle;

  /// Lift the panel above the soft keyboard.
  final bool avoidKeyboard;

  /// stick FOW (D-047): キーボードが閉じているとき、根本をフッターメニューの
  /// **上**にドックする(通常 FOW は画面最下端まで覆う)。インセット値は
  /// [OverlayHost.fowDockInset] がレイアウトから供給する。
  final bool dockAboveFooter;

  bool get hasHeader => title != null || cancelText != null || confirmText != null;

  /// Interstitial FOWs take the screen: scrim + barrier discard. Widget/system FOWs
  /// leave the content behind them interactive.
  bool get blocksContent => type == FowPanelType.interstitial;

  void resizeBy(double deltaFactor) => heightFactor.value = (heightFactor.value - deltaFactor).clamp(minHeightFactor, maxHeightFactor);
}
