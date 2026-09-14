import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

ActionDescriptor action(String id) => ActionDescriptor(id: id, genreTag: 'x', label: id);

void main() {
  final actions = [action('reply'), action('renote'), action('reaction'), action('favorite')];

  test('既定構成は登録順のまま', () {
    final entries = const ActionBarConfig().apply(actions);
    expect(entries.whereType<SingleActionEntry>().map((e) => e.action.id), ['reply', 'renote', 'reaction', 'favorite']);
  });

  test('並び替え(非表示は廃止 D-208: 保存済みの hidden は無視される)', () {
    const config = ActionBarConfig(order: ['reaction', 'reply'], hidden: {'favorite'});
    final ids = [for (final e in config.apply(actions)) (e as SingleActionEntry).action.id];
    expect(ids, ['reaction', 'reply', 'renote', 'favorite']); // order 先頭 → 残りは登録順、favorite も残る
  });

  test('リスト束ね: メンバーはバーから消え、リストが 1 枠になる', () {
    const config = ActionBarConfig(
      order: ['reply', 'list:l1'],
      lists: [ActionListDef(id: 'l1', name: 'よく使う', memberIds: ['renote', 'reaction'])],
    );
    final entries = config.apply(actions);
    expect(entries, hasLength(3)); // reply, list, favorite
    expect((entries[0] as SingleActionEntry).action.id, 'reply');
    final list = entries[1] as ActionListEntry;
    expect(list.list.name, 'よく使う');
    expect(list.members.map((a) => a.id), ['renote', 'reaction']);
    expect((entries[2] as SingleActionEntry).action.id, 'favorite');
  });

  test('order に無いリストは末尾、空リスト(メンバー未登録)は出ない', () {
    const config = ActionBarConfig(lists: [
      ActionListDef(id: 'l1', name: 'A', memberIds: ['renote']),
      ActionListDef(id: 'empty', name: 'B', memberIds: ['missing']),
    ]);
    final entries = config.apply(actions);
    expect(entries.whereType<ActionListEntry>().single.list.id, 'l1');
    // order 指定なし → リストは残りの単体より前(lists ループが先)。
    expect(entries.first, isA<ActionListEntry>());
    expect((entries.last as SingleActionEntry).action.id, 'favorite');
  });

  test('JSON 往復(永続化形式)', () {
    const config = ActionBarConfig(
      order: ['list:l1', 'reply'],
      hidden: {'favorite'},
      lists: [ActionListDef(id: 'l1', name: 'よく使う', memberIds: ['renote', 'reaction'])],
    );
    final restored = ActionBarConfig.fromJson((jsonDecode(jsonEncode(config.toJson())) as Map).cast<String, Object?>());
    expect(restored.order, config.order);
    expect(restored.hidden, config.hidden);
    expect(restored.lists.single.memberIds, ['renote', 'reaction']);
    // 適用結果も一致。
    expect(
      [for (final e in restored.apply(actions)) e.runtimeType],
      [for (final e in config.apply(actions)) e.runtimeType],
    );
  });
}
