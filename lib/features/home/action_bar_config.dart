import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// アクションバーのユーザー構成 (2026-08-25 ワイヤー「アクションバー編集」)。
///
/// プラグインが登録した `ActionDescriptor` はそのままに、**ホスト側の構成**
/// として並び順と表示/非表示を持つ(プラグイン無変更で編集できる)。v1 は
/// 投稿タイル面のみ。コンポーザ/全画面ヘッダー面と「アクションリスト化」
/// (複数アクションを 1 ボタンに束ねる)は次段。永続化も次段(メモリ保持)。
@immutable
class ActionBarConfig {
  const ActionBarConfig({this.order = const [], this.hidden = const {}});

  /// 明示された並び順(先頭から)。載っていない id は登録順で後ろに続く。
  final List<String> order;

  /// 非表示にしたアクション id。
  final Set<String> hidden;

  bool get dirty => order.isNotEmpty || hidden.isNotEmpty;

  /// 構成を適用: 並び替え + 非表示除外。
  List<ActionDescriptor> apply(List<ActionDescriptor> actions) {
    final byId = {for (final a in actions) a.id: a};
    final out = <ActionDescriptor>[
      for (final id in order)
        if (byId.containsKey(id) && !hidden.contains(id)) byId[id]!,
    ];
    for (final a in actions) {
      if (!order.contains(a.id) && !hidden.contains(a.id)) out.add(a);
    }
    return out;
  }

  ActionBarConfig copyWith({List<String>? order, Set<String>? hidden}) =>
      ActionBarConfig(order: order ?? this.order, hidden: hidden ?? this.hidden);
}

class ActionBarConfigStore extends Notifier<ActionBarConfig> {
  @override
  ActionBarConfig build() => const ActionBarConfig();

  void set(ActionBarConfig next) => state = next;

  void reset() => state = const ActionBarConfig();
}

/// 投稿タイル面の構成(アカウント/面ごとの分離は永続化と同時に)。
final actionBarConfigProvider = NotifierProvider<ActionBarConfigStore, ActionBarConfig>(ActionBarConfigStore.new);
