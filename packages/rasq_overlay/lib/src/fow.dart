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
    this.columnIndex = 0,
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

  // ---- 横ドッキング (D-062/D-063) --------------------------------------
  // FOW はカラムの中心に揃い、**カラム枠内に収まる幅**でドックする。
  // FOW 内ヘッダー/フッター([FowMoveGrip])を掴んで左右へ動かすと隣の
  // カラムへ移動し、**両端の壁に 50px 以上めり込ませると壁付けピン**になる。
  // ドラッグハンドルは縦リサイズ専用(横の誤爆を防ぐ役割分担)。

  /// ドラッグ中の横追従量([FowMoveGrip] が書く。離すとホストが精算)。
  final ValueNotifier<double> moveDx = ValueNotifier(0);

  /// 所属カラム(ホストの列スロット index。範囲外は clamp される)。
  int columnIndex;

  /// 壁付けピン (D-063): -1 = 左の壁 / 1 = 右の壁 / 0 = なし。壁へ 50px
  /// 以上めり込ませると確定し、壁側に**最大高さ・検索ホーム幅**で張り付く
  /// (元画面を覆う中央最大化はしない)。内側へしきい値以上動かすと
  /// カラム揃えへ戻る。
  int pinnedWall = 0;

  /// カラム/最大化の変更をホストのレイアウトへ伝えるカウンター。
  final ValueNotifier<int> geometryRev = ValueNotifier(0);

  /// 離したときの精算(ホストが列スロット幾何を知っているので毎ビルド
  /// 差し込む)。[FowMoveGrip] が onPanEnd で呼ぶ。
  void Function(double dx)? settleMove;

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

/// FOW の列スロット (D-062): ホストのカラム幾何(左端 x とカラム幅)。
/// アプリのレイアウト([OverlayHost.fowColumns])が供給する。
class FowColumnSlot {
  const FowColumnSlot({required this.x, required this.width});
  final double x;
  final double width;
}

/// FOW 内ヘッダー/フッターに被せる「掴んで左右カラム間移動」グリップ
/// (D-062)。**横**ドラッグだけを拾う(縦のスクロール・リサイズやタップは
/// 子へ通す — ハンドルの縦リサイズとの役割分担)。離すとホストが精算し、
/// カラム中心へスナップ / 壁へ 50px 以上めり込んでいれば壁付けピンになる。
class FowMoveGrip extends StatelessWidget {
  const FowMoveGrip({super.key, required this.spec, required this.child});
  final FowSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          spec.dragging.value = true;
          spec.moveDx.value = 0;
        },
        onHorizontalDragUpdate: (d) => spec.moveDx.value += d.delta.dx,
        onHorizontalDragEnd: (_) {
          spec.dragging.value = false;
          final dx = spec.moveDx.value;
          spec.moveDx.value = 0;
          spec.settleMove?.call(dx);
        },
        onHorizontalDragCancel: () {
          spec.dragging.value = false;
          spec.moveDx.value = 0;
        },
        child: child,
      );
}
