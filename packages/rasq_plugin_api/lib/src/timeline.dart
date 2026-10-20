import 'package:meta/meta.dart';

import 'l10n.dart';

/// Timeline identifiers. Plugins declare which ones they support; the host
/// maps them onto the home tabs (おすすめ / フォロー中 / 関連 …).
@immutable
class TimelineKind {
  const TimelineKind(this.id, String this._label, {this.extensible = true});

  /// ホストの決まった TL(名前は表示の言語、D-533)。
  const TimelineKind._builtin(this.id, {this.extensible = true}) : _label = null;

  final String id;
  final String? _label;

  /// タブの名前。ホストの決まった TL([home] など)は表示の言語の名前、ほかは作ったときの名前。
  String get label => _label ?? _builtinLabel(id);

  static String _builtinLabel(String id) {
    final l = rasqPluginApiL10n;
    return switch (id) {
      'home' => l.pluginApiTimelineHome,
      'local' => l.pluginApiTimelineLocal,
      'social' => l.pluginApiTimelineSocial,
      'global' => l.pluginApiTimelineGlobal,
      'recommended' => l.pluginApiTimelineRecommended,
      'relational' => l.pluginApiTimelineRelational,
      'bundle' => l.pluginApiTimelineBundle,
      _ => id,
    };
  }

  /// Whether plugins may add tabs next to it (拡張可能タブ).
  final bool extensible;

  static const home = TimelineKind._builtin('home');
  static const local = TimelineKind._builtin('local');
  static const social = TimelineKind._builtin('social');
  static const global = TimelineKind._builtin('global');
  static const recommended = TimelineKind._builtin('recommended');

  /// リレーショナルTL — reserved (D-011: not implemented yet).
  static const relational = TimelineKind._builtin('relational', extensible: false);

  /// 総合TL (D-088): 総合表示(アカウントバンドル)で全ログインアカウントの
  /// ホームTLが合流するタブ。データ供給はホスト側(プラグインは関与しない)。
  static const bundle = TimelineKind._builtin('bundle', extensible: false);

  /// User-defined list timeline: `list:{listId}`.
  factory TimelineKind.list(String listId, String label) => TimelineKind('list:$listId', label);

  @override
  bool operator ==(Object other) => other is TimelineKind && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
