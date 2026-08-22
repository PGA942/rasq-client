/// Spacing tokens. Item spacing / section margins are **app-fixed** — plugins
/// cannot change them (原典: UI_Elements「Listレイアウトルール」).
abstract final class RasqSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Vertical gap between list items (renderer-enforced).
  static const double listItemGap = 0;

  /// Vertical margin between list sections (renderer-enforced).
  static const double sectionMargin = 12;

  /// Horizontal page padding.
  static const double page = 16;

  /// Gap between tiles in MediaGrid (審査制約「メディア間の余白を確保」).
  static const double mediaGap = 4;
}
