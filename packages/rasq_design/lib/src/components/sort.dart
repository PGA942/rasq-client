/// Sort orders offered by the `∨` sort/filter component
/// (原典: UI_Elements「ソート/フィルターコンポーネント: 昇順・降順・カスタム項目(未指定なら「デフォルト」)」).
enum RasqSortOrder {
  defaultOrder('デフォルト'),
  reactionsDesc('リアクション数(降順)'),
  reactionsAsc('リアクション数(昇順)');

  const RasqSortOrder(this.label);
  final String label;
}
