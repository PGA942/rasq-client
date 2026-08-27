import 'package:meta/meta.dart';

/// Timeline identifiers. Plugins declare which ones they support; the host
/// maps them onto the home tabs (おすすめ / フォロー中 / 関連 …).
@immutable
class TimelineKind {
  const TimelineKind(this.id, this.label, {this.extensible = true});

  final String id;
  final String label;

  /// Whether plugins may add tabs next to it (拡張可能タブ).
  final bool extensible;

  static const home = TimelineKind('home', 'フォロー中');
  static const local = TimelineKind('local', 'ローカル');
  static const social = TimelineKind('social', 'ソーシャル');
  static const global = TimelineKind('global', 'グローバル');
  static const recommended = TimelineKind('recommended', 'おすすめ');

  /// リレーショナルTL — reserved (D-011: not implemented yet).
  static const relational = TimelineKind('relational', '関連', extensible: false);

  /// User-defined list timeline: `list:{listId}`.
  factory TimelineKind.list(String listId, String label) => TimelineKind('list:$listId', label);

  @override
  bool operator ==(Object other) => other is TimelineKind && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
