/// Size tokens.
abstract final class RasqSizes {
  /// Minimum tap target (P5: 44×44dp, renderer-enforced).
  static const double minTap = 44;

  static const double avatarXs = 20;
  static const double avatarSm = 28;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
  static const double avatarXl = 64;
  static const double avatarXxl = 96;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  static const double headerHeight = 56;
  static const double navHeight = 56;
  static const double searchBarHeight = 36;

  /// Tablet breakpoint: sidebar fixed + 2 panes (原典: UI_Elements「レイアウト」).
  static const double tabletBreakpoint = 840;

  /// Max height ratio for horizontal scroll sections (< 50% of screen height).
  static const double hScrollMaxHeightRatio = 0.5;

  /// Minimum height of the opposite side area before a FOW widget may be
  /// swiped to the other edge (ワイヤーフレーム注釈「最低表示高(120pxぐらい)」).
  static const double fowSwapMinHeight = 120;
}
