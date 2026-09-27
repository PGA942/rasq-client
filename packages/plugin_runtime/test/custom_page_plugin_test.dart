import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 同梱のページ型サンプル「みんなのボード」(plugin-sample/custom-page-plugin、契約 v0.18 §2.13、rasq-client D-357)が
/// ホストの渡し方(平らな args、`page.render` / `shared.*` の token)どおりに動くことの回帰テスト。
void main() {
  final wasmFile = File('../../assets/plugins/custom_page_plugin.wasm');
  if (!wasmFile.existsSync()) {
    test('custom_page_plugin.wasm bundled', () {}, skip: 'assets/plugins/custom_page_plugin.wasm がありません');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());

  test('マニフェスト → page.open(セッションの値)→ ボタン = shared.op / 投票 = shared.set / 🎉 = shared.call → page.event で描き直す', () {
    final sent = <(String, Map<String, Object?>)>[];
    final controller = WasmPluginController(
      wasmBytes: bytes,
      env: RasqHostEnvironment(
        permissions: {RasqPermissions.render, RasqPermissions.sharedSession, RasqPermissions.storageSafe},
        appFns: {RasqHostFns.toast, RasqHostFns.pageRender, RasqHostFns.sharedSet, RasqHostFns.sharedOp, RasqHostFns.sharedCall},
        onAppFn: (fn, args) => sent.add((fn, args)),
      ),
    );
    addTearDown(controller.dispose);
    controller.load();
    final m = controller.invoke('plugin.manifest')['value'] as Map;
    expect(m['id'], 'sample.board');
    expect(m['slots'], ['page']);
    expect((m['page'] as Map)['mode'], 'shared');

    const token = 't1';
    final open = controller.invoke('page.open', {
      'token': token,
      'surface': 'astell',
      'context': {'roomId': 'r1'},
      'me': {'accountId': 'a1', 'handle': 'me', 'displayName': 'あなた'},
      'session': {
        'id': 's1',
        'scope': 'room:r1',
        'role': 'owner',
        'participants': [{'accountId': 'a1', 'handle': 'me', 'displayName': 'あなた'}],
        'vars': {'counter': {'value': 7, 'rev': 7, 'by': 'a2'}},
      },
      'size': {'width': 400, 'height': 700},
    });
    expect(open['ok'], isTrue, reason: '$open');
    expect('${(open['value'] as Map)['root']}', contains('7'));

    controller.invoke('counter.incr', {'token': token, 'nodeId': 'x', 'kind': 'tap'});
    controller.invoke('poll.vote', {'token': token, 'nodeId': 'x', 'kind': 'change', 'value': 1});
    controller.invoke('celebrate', {'token': token, 'nodeId': 'x', 'kind': 'tap'});
    controller.invoke('gb.send', {'token': token, 'nodeId': 'x', 'kind': 'submit', 'text': 'おつかれ'});
    final ops = [for (final (fn, a) in sent) if (fn.startsWith('shared.')) (fn, a['key'] ?? a['fn'], a['token'])];
    expect(ops, [('shared.op', 'counter', token), ('shared.set', 'me.vote', token), ('shared.call', 'celebrate', token), ('shared.op', 'guestbook', token)]);

    sent.clear();
    controller.invoke('page.event', {'token': token, 'type': 'var', 'key': 'counter', 'value': 8, 'rev': 8, 'by': 'a1'});
    final render = sent.where((x) => x.$1 == RasqHostFns.pageRender).single.$2;
    expect(render['token'], token);
    expect('${render['root']}', contains('8'));
  });
}
