import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 本物の wasm(plugin-sample の dist/)を同期コントローラで動かし、スロット契約
/// (D-167)の ABI が rasq-plugin-kit の export で通ることを確かめる。ビルドが無ければスキップ。
void main() {
  final dist = Directory('../plugin-sample/dist');
  Future<WasmPluginController?> load(String name, RasqHostEnvironment env) async {
    final f = File('${dist.path}/$name.wasm');
    if (!f.existsSync()) return null;
    final c = WasmPluginController(wasmBytes: f.readAsBytesSync(), env: env)..load();
    return c;
  }

  Map<String, dynamic> value(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    return (r['value'] as Map).cast<String, dynamic>();
  }

  test('timeline-plugin: plugin.manifest / tl.timelines / tl.sort', () async {
    final c = await load('timeline_plugin', RasqHostEnvironment());
    if (c == null) return markTestSkipped('plugin-sample/dist not built');
    final m = value(c.invoke('plugin.manifest', const {}));
    expect(m['id'], 'sample.timeline');
    expect(m['slots'], ['tl']);
    expect(value(c.invoke('tl.timelines', const {}))['timelines'], [{'id': 'unicode-asc', 'label': 'Unicode 順', 'base': 'home'}]);
    // パラメーター (契約 v0.2): tl.params の RRL と既定値、tl.sort の params。
    final params = value(c.invoke('tl.params', {'id': 'unicode-asc'}));
    expect(params['defaults'], {'order': 'asc', 'key': 'body'});
    expect(jsonEncode(params['root']), contains(r'$.settings.order'));
    expect(value(c.invoke('tl.sort', {'id': 'unicode-asc', 'posts': [{'id': 'a', 'body': 'ん'}, {'id': 'b', 'body': 'あ'}], 'params': {'order': 'desc'}}))['order'], ['a', 'b']);
    final sorted = value(c.invoke('tl.sort', {'id': 'unicode-asc', 'posts': [{'id': 'a', 'body': 'ん'}, {'id': 'b', 'body': 'あ'}, {'id': 'c', 'body': 'abc'}]}));
    expect(sorted['order'], ['c', 'b', 'a']);
    expect(c.invoke('tl.sort', {'id': 'nope', 'posts': []})['ok'], isFalse);
    c.dispose();
  });

  test('post-process-plugin: 今日 → 日付(JST)', () async {
    final c = await load('post_process_plugin', RasqHostEnvironment());
    if (c == null) return markTestSkipped('plugin-sample/dist not built');
    final v = value(c.invoke('post.transform', {'posts': [{'id': 'p', 'body': '今日は晴れ https://example.com/今日', 'createdAt': '2026-09-10T15:30:00.000Z'}, {'id': 'q', 'body': 'なし', 'createdAt': '2026-09-10T00:00:00Z'}]}));
    expect((v['posts'] as Map)['p']['body'], '9/11(今日)は晴れ https://example.com/今日');
    expect((v['posts'] as Map).containsKey('q'), isFalse);
    c.dispose();
  });

  test('composer-text-plugin: # → fow.open、pick → composer.text.replace(アプリ向けホスト関数の中継)', () async {
    final app = <(String, Map<String, Object?>)>[];
    final fows = <(String, Map<String, Object?>)>[];
    final env = RasqHostEnvironment(
      onFow: (fn, args) {
        fows.add((fn, args));
        return null;
      },
      appFns: {RasqHostFns.composerTextReplace, RasqHostFns.toast},
      onAppFn: (fn, args) => app.add((fn, args)),
    );
    final c = await load('composer_text_plugin', env);
    if (c == null) return markTestSkipped('plugin-sample/dist not built');
    expect(value(c.invoke('plugin.manifest', const {}))['slots'], ['composer.text']);
    value(c.invoke('text.changed', {'token': 't1', 'text': 'こんにちは #打', 'selectionStart': 8, 'selectionEnd': 8, 'trigger': '#打'}));
    expect(fows.single.$1, 'fow.open');
    final root = jsonEncode(fows.single.$2['root']);
    expect(root, contains('打上会'));
    value(c.invoke('pick.0', {'nodeId': 'x', 'kind': 'tap'}));
    final rep = app.where((x) => x.$1 == RasqHostFns.composerTextReplace).single.$2;
    expect(rep['token'], 't1');
    expect(rep['start'], 6);
    expect(rep['end'], 8);
    expect(rep['text'], '#打上会 ');
    expect(fows.last.$1, 'fow.close');
    c.dispose();
  });

  test('post-share-plugin (§2.8): post.share → fow.open、テンプレート → composer.open、post.share.close → fow.close', () async {
    final app = <(String, Map<String, Object?>)>[];
    final fows = <(String, Map<String, Object?>)>[];
    final env = RasqHostEnvironment(
      onFow: (fn, args) {
        fows.add((fn, args));
        return null;
      },
      appFns: {RasqHostFns.composerOpen, RasqHostFns.clipboardSet, RasqHostFns.urlOpen, RasqHostFns.astellShare, RasqHostFns.toast},
      onAppFn: (fn, args) => app.add((fn, args)),
    );
    final c = await load('post_share_plugin', env);
    if (c == null) return markTestSkipped('plugin-sample/dist not built');
    final m = value(c.invoke('plugin.manifest', const {}));
    expect(m['id'], 'sample.post-share');
    expect(m['slots'], ['post.share']);
    value(c.invoke('post.share', {
      'token': 'tk1',
      'post': {'url': 'https://example.test/notes/p1', 'sns': 'misskey', 'instance': 'example.test', 'postId': 'p1', 'author': '作者', 'handle': 'author', 'body': '本文です', 'media': []},
      'account': {'sns': 'misskey', 'instance': 'example.test', 'handle': 'me'},
      'link': 'https://example.test/notes/p1',
    }));
    expect(fows.single.$1, 'fow.open');
    expect(fows.single.$2['id'], 'share-template');
    expect(jsonEncode(fows.single.$2['root']), contains('引用(本文つき)'));
    value(c.invoke('tpl.quote', {'nodeId': 'x', 'kind': 'tap'}));
    value(c.invoke('share.composer', {'nodeId': 'x', 'kind': 'tap'}));
    final open = app.where((x) => x.$1 == RasqHostFns.composerOpen).single.$2;
    expect(open['token'], 'tk1');
    expect(open['text'], '「本文です」\nhttps://example.test/notes/p1');
    value(c.invoke('post.share.close', {'token': 'tk1'}));
    expect(fows.last.$1, 'fow.close');
    c.dispose();
  });
}
