import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// 本物の mixi2 wasm サンプル (D-206) をダミーモードで通す: sns.login(ホスト dummy)→ トークン、
/// sns.timeline → Post ワイヤ、いいね → myReaction / 通知、投稿 → TL の先頭。ネットワークは使わない。
void main() {
  final f = File('assets/plugins/mixi2_wasm.wasm');
  if (!f.existsSync() || f.lengthSync() == 0) {
    test('mixi2 wasm needs to be built', () {}, skip: 'assets/plugins/mixi2_wasm.wasm が無い');
    return;
  }
  Map<String, dynamic> value(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    return (r['value'] as Map).cast<String, dynamic>();
  }

  test('ダミーモード: login → timeline → favorite → createPost → notifications', () {
    var fetches = 0;
    final env = RasqHostEnvironment(
      fetch: (r) {
        fetches++;
        return SyncFetchResponse(status: 500, headers: const {}, bodyText: '');
      },
      storage: <String, Object?>{},
    );
    final c = WasmPluginController(wasmBytes: f.readAsBytesSync(), env: env)..load();
    final login = value(c.invoke('sns.login', {'host': 'dummy', 'identifier': 'me'}));
    final token = (login['session'] as Map)['token'] as String;
    expect(token, startsWith('dummy:'));
    expect((login['me'] as Map)['kind'], 'mixi2');
    final args = {'host': 'dummy', 'token': token};
    final tl = value(c.invoke('sns.timeline', {...args, 'kind': 'home', 'limit': 20}));
    final items = ((tl['page'] as Map)['items'] as List).cast<Map>();
    expect(items.length, 8);
    expect(items.first['bodyFormat'], 'plain');
    expect((items.first['author'] as Map)['kind'], 'mixi2');
    // いいね → myReaction ⭐ + 通知。
    final r = value(c.invoke('sns.performAction', {...args, 'actionId': 'favorite', 'postId': 'd-7', 'args': {}, 'now': '2026-09-13T10:00:00.000Z'}));
    expect((r['result'] as Map)['done'], isTrue);
    expect((value(c.invoke('sns.post', {...args, 'id': 'd-7'}))['post'] as Map)['myReaction'], '⭐');
    final n = value(c.invoke('sns.notifications', {...args}));
    expect((((n['page'] as Map)['items'] as List).first as Map)['kind'], 'reaction');
    // 投稿 → TL の先頭。
    final p = value(c.invoke('sns.createPost', {...args, 'draft': {'text': 'wasm から'}, 'now': '2026-09-13T11:00:00.000Z'}));
    final tl2 = value(c.invoke('sns.timeline', {...args, 'kind': 'home', 'limit': 1}));
    expect((((tl2['page'] as Map)['items'] as List).first as Map)['id'], (p['post'] as Map)['id']);
    // 実モードの資格情報ログインは断る(OAuth)。ダミーはネットワークを一度も使わない。
    expect(c.invoke('sns.login', {'host': 'mixi.social', 'identifier': 'x', 'password': 'y'})['ok'], isFalse);
    expect(fetches, 0);
    expect(value(c.invoke('sns.actions', {}))['actions'], hasLength(4));
  });
}
