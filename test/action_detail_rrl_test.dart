import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/home/action_bar_edit_sheet.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 詳細 FOW の RRL 木 (D-210): 上部 = ストアのページの見出し(アイコン / 名前 / 提供元 / 評価)、下 = アクションの詳細。
void main() {
  test('actionDetailRrl: 見出し + セクション + 詳細タイル', () {
    const a = ActionDescriptor(id: 'reply', genreTag: 'Reply', label: '返信', icon: 'reply', countSource: CountSource.self);
    final n = actionDetailRrl(action: a, pluginId: 'rasq.official.misskey', pluginName: 'Misskey', developer: 'RASQ', iconUrl: Uri.parse('https://example.test/i.png'), rating: 4.5, downloads: 120, summary: '公式', tags: const ['Reply']);
    expect(n.t, 'Column');
    final head = n.c.first;
    expect(head.t, 'Row');
    expect(head.c.first.t, 'Image');
    expect(head.c.first.p['src'], 'https://example.test/i.png');
    final title = head.c[1];
    expect(title.c.map((x) => x.p['text']), ['Misskey', 'RASQ', '★4.5 ・ 120 DL']);
    expect(n.c.map((x) => x.t), containsAll(['SectionHeader', 'ListTile']));
    final label = n.c.firstWhere((x) => x.k == 'label');
    expect(label.p['subtitle'], 'id: reply');
    expect(n.c.firstWhere((x) => x.k == 'slot').p['subtitle'], 'Reply');
    expect(n.c.firstWhere((x) => x.k == 'tags').p['subtitle'], 'Reply');
    // ストアに無いプラグイン: アイコン無し → Icon、提供元は id。
    final m = actionDetailRrl(action: a, pluginId: 'x.y', pluginName: 'X');
    expect(m.c.first.c.first.t, 'Icon');
    expect(m.c.first.c[1].c[1].p['text'], 'x.y');
  });
}
