import 'dart:math' as math;

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
    List<double> heightStops = const [],
    this.freeAboveStops = false,
    this.freeBelowStops = false,
  })  : heightStops = [...heightStops]..sort(),
        heightFactor = ValueNotifier(initialHeightFactor.clamp(minHeightFactor, maxHeightFactor));

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

  /// 高さの段階 (D-049): factor の昇順配列。ドラッグを離すと最も近い段階へ
  /// スナップする。空 = 段階なし(従来のシームレスな連続リサイズ)。
  /// 呼び出し側が実測から動的に差し替えてよい(コンポーザーの
  /// 「全部ピッタリ」段階など)。
  List<double> heightStops;

  /// 最上段より上へ**シームレスに**動かせるか(false = 最上段で止まる)。
  final bool freeAboveStops;

  /// 最下段より下へ**シームレスに**動かせるか(false = 最下段で止まる)。
  final bool freeBelowStops;

  /// ユーザーがハンドルでサイズ変更したか(呼び出し側の自動フィットが
  /// 手動調整を上書きしないための印。段階が切り替わったらリセットしてよい)。
  bool userResized = false;

  /// パネル**内部**のハンドル(D-053: リアクションピッカーの外縁ハンドル等、
  /// [showHandle] を消してコンテンツ側に置いたもの)がドラッグ中か。true の
  /// 間はホストが高さを即時反映する(アニメの追従遅延を出さない)。
  final ValueNotifier<bool> dragging = ValueNotifier(false);

  bool get hasHeader => title != null || cancelText != null || confirmText != null;

  /// Interstitial FOWs take the screen: scrim + barrier discard. Widget/system FOWs
  /// leave the content behind them interactive.
  bool get blocksContent => type == FowPanelType.interstitial;

  void resizeBy(double deltaFactor) {
    userResized = true;
    var lo = minHeightFactor;
    var hi = maxHeightFactor;
    if (heightStops.isNotEmpty) {
      // 段階の外側: free 指定が無い側は端の段階で止まる (D-049)。
      if (!freeBelowStops) lo = math.max(lo, heightStops.first);
      if (!freeAboveStops) hi = math.min(hi, heightStops.last);
    }
    heightFactor.value = (heightFactor.value - deltaFactor).clamp(lo, hi);
  }

  /// ドラッグ終了時: 段階の**間**にいるなら最も近い段階へスナップする。
  /// free 側の外側にいる場合はそのまま(シームレス)。
  void snapToStops() {
    if (heightStops.isEmpty) return;
    final v = heightFactor.value;
    if (freeBelowStops && v < heightStops.first) return;
    if (freeAboveStops && v > heightStops.last) return;
    var best = heightStops.first;
    for (final s in heightStops) {
      if ((v - s).abs() < (v - best).abs()) best = s;
    }
    heightFactor.value = best.clamp(minHeightFactor, maxHeightFactor);
  }
}
