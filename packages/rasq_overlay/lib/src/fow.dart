import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    this.headerLeading,
    this.showHandle = true,
    this.avoidKeyboard = true,
    this.dockAboveFooter = false,
    this.columnIndex = 0,
    this.maxWidth,
    this.bodyMove = true,
    List<double> heightStops = const [],
    this.freeAboveStops = false,
    this.freeBelowStops = false,
    this.theme,
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

  /// ヘッダー左側(キャンセルの代わり。共有 FOW のアカウント選択、D-170)。
  final Widget? headerLeading;
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

  /// パネルのテーマ (D-202): 指定するとクローム(ハンドル / ヘッダー / 背景)と本体をこのテーマで描く
  /// (黒背景のビューワーに置くダークモードの FOW など)。null = アプリのテーマ。
  final ThemeData Function(BuildContext context)? theme;

  /// ユーザーがハンドルでサイズ変更したか(呼び出し側の自動フィットが
  /// 手動調整を上書きしないための印。段階が切り替わったらリセットしてよい)。
  bool userResized = false;

  /// パネル**内部**のハンドル(D-053: リアクションピッカーの外縁ハンドル等、
  /// [showHandle] を消してコンテンツ側に置いたもの)がドラッグ中か。true の
  /// 間はホストが高さを即時反映する(アニメの追従遅延を出さない)。
  final ValueNotifier<bool> dragging = ValueNotifier(false);

  // ---- ドッキング (D-062/D-063/D-065) ----------------------------------
  // FOW はカラムの中心に揃い、**カラム枠内に収まる幅**でドックする。
  // FOW 内ヘッダー/フッター([FowMoveGrip])を掴んで動かすと:
  //  横 = 隣のカラムへ移動(**両端の壁に 50px 以上めり込ませると壁付けピン**)
  //  縦 = 付け先の切り替え(アプリヘッダー下付き ⇄ フッター/画面下端。
  //       アンカー FOW は上付き ⇄ 下付きの反転)— 左右と同じ 1 割で確定。
  // ドラッグハンドルは縦リサイズ専用(+クリックで FOW スイッチャー)。

  /// 本体(ヘッダー/フッター以外)も掴んで動かせるか (D-161)。既定 true。
  /// 本体全面がジェスチャーを取る部品(キャンバス等)なら false にする。
  bool bodyMove;

  /// ドラッグ中の横追従量([FowMoveGrip] が書く。離すとホストが精算)。
  final ValueNotifier<double> moveDx = ValueNotifier(0);

  /// ドラッグ中の縦追従量 (D-065)。
  final ValueNotifier<double> moveDy = ValueNotifier(0);

  /// 所属カラム(ホストの列スロット index。範囲外は clamp される)。
  int columnIndex;

  /// パネルの最大幅 (D-185): カラムより狭ければカラムの中央に置く(RAi の入力ウィジェット幅に揃える等)。
  final double? maxWidth;

  /// アプリヘッダーへの下付き (D-065)。false = 従来のフッター上/画面下端。
  /// FOW 内ヘッダー/フッターを縦へウィンドウ高さの 1 割以上動かすと切替。
  bool attachTop = false;

  /// 実物アクションボタン/バーへのアンカー (D-065、グローバル矩形)。
  /// 基本は下付き(ボタンの下辺に FOW 上辺)、下の余白が足りなければ
  /// 上付き。**別カラムへ動かした時点で壁付き表示に変更**(anchor は
  /// 解除され [pinnedWall] になる)。
  Rect? anchor;

  /// アンカーの下(true)/上(false)。null = 自動(余白で判定)。
  /// 縦ドラッグで確定する。
  bool? anchorBelow;

  /// 壁付けピン (D-063): -1 = 左の壁 / 1 = 右の壁 / 0 = なし。壁へ 50px
  /// 以上めり込ませると確定し、壁側に**最大高さ・検索ホーム幅**で張り付く
  /// (元画面を覆う中央最大化はしない)。内側へしきい値以上動かすと
  /// カラム揃えへ戻る。
  int pinnedWall = 0;

  /// カラム/最大化の変更をホストのレイアウトへ伝えるカウンター。
  final ValueNotifier<int> geometryRev = ValueNotifier(0);

  /// 離したときの精算(ホストが列スロット幾何を知っているので毎ビルド
  /// 差し込む)。[FowMoveGrip] が onPanEnd で呼ぶ(dx = 横、dy = 縦)。
  void Function(double dx, double dy)? settleMove;

  // ---- 親子 FOW の回避伸縮 (D-068) --------------------------------------
  // 子 FOW(ownerId = この FOW の entry id)が付いている側と高さを
  // ホストのレイアウトがリアルタイムに書く。FOW ウィジェット内に置いた
  // [FowChildGap](高さ可変 padding)がこれを高さにして、アクションバーや
  // 入力部を子の反対側へ押し出す。子がいないときは 0。

  /// 上側(ヘッダー側)に付いている子 FOW の高さ。
  final ValueNotifier<double> childGapTop = ValueNotifier(0);

  /// 下側(フッター側)に付いている子 FOW の高さ。
  final ValueNotifier<double> childGapBottom = ValueNotifier(0);

  // ---- FOW スイッチャーのプレビュー (D-066) -----------------------------

  /// パネルを包む RepaintBoundary のキー。スイッチャーを開く直前にホストが
  /// ここからキャプチャする(名前だけでは判別しづらい、の対応)。
  final GlobalKey previewBoundaryKey = GlobalKey();

  /// 直近のキャプチャ。スイッチャーのカードに縮小表示される。
  ui.Image? switcherPreview;

  /// ✕/キャンセルの割り込み (D-066): 設定時、クロームのキャンセルボタンは
  /// **閉じずに**これを呼ぶ。プラグイン FOW が「画面そのままの確認
  /// ポップアップ」を出すための口(PROTOCOL `fow.open` の `onCancel` —
  /// プラグインは確認 FOW を開き、自分で `fow.close` する)。
  VoidCallback? interceptCancel;

  bool get hasHeader => title != null || cancelText != null || confirmText != null || headerLeading != null || headerTrailing != null;

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

/// FOW ウィジェット内に置く**高さ可変 padding** (D-068)。子 FOW がその側に
/// 付いている間はその高さに伸び(いなければ 0px)、アクションバーや入力部を
/// 子の反対側へ押し出して被らないようにする。コンポーザーはアクションバーの
/// 前後に 1 つずつ置く(子の付く方向は親側指定 — 親の付け先が変われば
/// 伸びる側も切り替わる)。
class FowChildGap extends StatelessWidget {
  const FowChildGap({super.key, required this.spec, this.top = false});
  final FowSpec spec;

  /// true = 上側(ヘッダー側)の子に反応する。false = 下側(フッター側)。
  final bool top;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: top ? spec.childGapTop : spec.childGapBottom,
        builder: (context, gap, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: gap,
        ),
      );
}

/// FOW の列スロット (D-062): ホストのカラム幾何(左端 x とカラム幅)。
/// アプリのレイアウト([OverlayHost.fowColumns])が供給する。
class FowColumnSlot {
  const FowColumnSlot({required this.x, required this.width});
  final double x;
  final double width;
}

/// FOW 内ヘッダー/フッターに被せる「掴んで移動」グリップ (D-062/D-065)。
/// pan で縦横どちらも拾う(タップは子へ通す)。離すとホストが精算し、
/// 横 = カラム中心へスナップ / 壁へ 50px 以上で壁付けピン、
/// 縦 = 付け先の切り替え(ヘッダー下付き ⇄ 下側 / アンカーの上付き ⇄
/// 下付き)。ハンドルの縦**リサイズ**とは掴む場所で役割分担する。
class FowMoveGrip extends StatelessWidget {
  const FowMoveGrip({super.key, required this.spec, required this.child});
  final FowSpec spec;
  final Widget child;

  void _reset() {
    spec.dragging.value = false;
    spec.moveDx.value = 0;
    spec.moveDy.value = 0;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          spec.dragging.value = true;
          spec.moveDx.value = 0;
          spec.moveDy.value = 0;
        },
        onPanUpdate: (d) {
          spec.moveDx.value += d.delta.dx;
          spec.moveDy.value += d.delta.dy;
        },
        onPanEnd: (_) {
          final dx = spec.moveDx.value;
          final dy = spec.moveDy.value;
          _reset();
          spec.settleMove?.call(dx, dy);
        },
        onPanCancel: _reset,
        child: child,
      );
}
