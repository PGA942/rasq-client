/// Overlay layers, back → front (原典: UI_Elements「オーバーレイ系（階層順）」).
///
/// ```
/// 最前面  rai        Raiレイヤー（常に最前面）
///   ↑    modal      モーダル（アラート・確認ダイアログ）
///   ↑    bottomSheet ボトムシート（コンポーザー・共有シート・コンテキストメニュー）
///   ↑    vcVideo    VC・動画オーバーレイ（VCは常駐、動画は昇格時のみ）
///   ↑    dropdown   ドロップダウン（アカウント切り替えなど）
///   ↑    sidebar    サイドバー
///   ↑    fow        FOWオーバーレイ（ウィジェット初回起動時のみ）
/// 背面   (content)  通常コンテンツ — not managed here
/// ```
enum OverlayLayer {
  fow,
  sidebar,
  dropdown,
  vcVideo,
  bottomSheet,
  modal,
  rai;

  /// Z-order; higher is closer to the viewer.
  int get z => index;

  /// 同時表示ルール.
  OverlayStacking get stacking => switch (this) {
        OverlayLayer.modal => OverlayStacking.stack,
        OverlayLayer.bottomSheet => OverlayStacking.stack,
        OverlayLayer.dropdown => OverlayStacking.exclusive,
        OverlayLayer.rai => OverlayStacking.coexist,
        // Sidebar / FOW / VC: one at a time (a new request replaces the old).
        OverlayLayer.sidebar => OverlayStacking.exclusive,
        OverlayLayer.fow => OverlayStacking.exclusive,
        OverlayLayer.vcVideo => OverlayStacking.exclusive,
      };

  /// クローズ挙動 (what a tap on the barrier does).
  OverlayBarrierBehavior get barrierBehavior => switch (this) {
        // 明示的操作必須、背面タップ無効
        OverlayLayer.modal => OverlayBarrierBehavior.ignore,
        // 背面タップ or キャンセルボタンで変更破棄
        OverlayLayer.bottomSheet => OverlayBarrierBehavior.dismissDiscard,
        OverlayLayer.dropdown => OverlayBarrierBehavior.dismissDiscard,
        // 背面タップで閉じる
        OverlayLayer.sidebar => OverlayBarrierBehavior.dismiss,
        // No barrier: content stays interactive underneath.
        OverlayLayer.fow => OverlayBarrierBehavior.none,
        OverlayLayer.vcVideo => OverlayBarrierBehavior.none,
        OverlayLayer.rai => OverlayBarrierBehavior.none,
      };

  /// Whether a scrim is painted behind entries of this layer.
  bool get hasScrim => switch (this) {
        OverlayLayer.modal || OverlayLayer.bottomSheet || OverlayLayer.sidebar => true,
        _ => false,
      };
}

enum OverlayStacking {
  /// Multiple entries may be open; new ones go on top.
  stack,

  /// Opening a new entry auto-closes the previous one in the same layer.
  exclusive,

  /// Always coexists with everything, never blocks anything (Rai).
  coexist,
}

enum OverlayBarrierBehavior {
  /// Barrier absorbs taps but does nothing (modal).
  ignore,

  /// Barrier tap closes the entry (sidebar).
  dismiss,

  /// Barrier tap closes the entry **and discards pending changes**
  /// (bottom sheet / dropdown). The entry receives `reason == discard`.
  dismissDiscard,

  /// No barrier at all.
  none,
}
