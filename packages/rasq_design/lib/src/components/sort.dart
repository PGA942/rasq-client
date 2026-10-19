import '../l10n/design_l10n.dart';

/// Sort orders offered by the `∨` sort/filter component
/// (原典: UI_Elements「ソート/フィルターコンポーネント: 昇順・降順・カスタム項目(未指定なら「デフォルト」)」).
enum RasqSortOrder {
  defaultOrder,
  reactionsDesc,
  reactionsAsc;

  /// 表示の名前(いまの表示の言語、D-484)。
  String get label => switch (this) {
        RasqSortOrder.defaultOrder => rasqDesignL10n.designSortDefault,
        RasqSortOrder.reactionsDesc => rasqDesignL10n.designSortReactionsDesc,
        RasqSortOrder.reactionsAsc => rasqDesignL10n.designSortReactionsAsc,
      };
}
