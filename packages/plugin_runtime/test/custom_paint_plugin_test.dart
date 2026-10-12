import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 同梱のページ型サンプル「みんなで落書き」(plugin-sample/custom-plugin-paint、契約 v0.22 §2.13、rasq-client D-465)が
/// ホストの渡し方(`now` / `expiresAt` / `media.editor.open` / `edited` / `shared.set` の `ttl` / owner の削除)どおりに動くことの回帰テスト。
void main() {
  final wasmFile = File('../../assets/plugins/custom_plugin_paint.wasm');
  if (!wasmFile.existsSync()) {
    test('custom_plugin_paint.wasm bundled', () {}, skip: 'assets/plugins/custom_plugin_paint.wasm がありません');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());
  const now = 1791936000000;
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400"><path d="M10 10L100 100" fill="none" stroke="#000000" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  test('page.open(セッションの値)→ 自分のマス = media.editor.open → edited = shared.set me.paint + ttl → var で描き直す / owner の削除', () {
    final sent = <(String, Map<String, Object?>)>[];
    final controller = WasmPluginController(
      wasmBytes: bytes,
      env: RasqHostEnvironment(
        permissions: {RasqPermissions.render, RasqPermissions.sharedSession},
        appFns: {RasqHostFns.toast, RasqHostFns.pageRender, RasqHostFns.sharedSet, RasqHostFns.sharedOp, RasqHostFns.sharedCall, RasqHostFns.mediaEditorOpen},
        onAppFn: (fn, args) => sent.add((fn, args)),
      ),
    );
    addTearDown(controller.dispose);
    controller.load();
    final m = controller.invoke('plugin.manifest')['value'] as Map;
    expect((m['id'], (m['page'] as Map)['mode']), ('sample.paint', 'shared'));
    expect(m['slots'], ['page']);
    expect(m['permissions'], ['render', 'shared.session']);

    const token = 't1';
    final open = controller.invoke('page.open', {
      'token': token,
      'surface': 'page',
      'context': <String, Object?>{},
      'me': {'accountId': 'a1', 'handle': 'me', 'displayName': 'あなた'},
      'session': {
        'id': 's1',
        'scope': 'link:s1',
        'role': 'owner',
        'ownerAccountId': 'a1',
        'participants': [
          {'accountId': 'a1', 'handle': 'me', 'displayName': 'あなた'},
          {'accountId': 'a2', 'handle': 'hanako', 'displayName': 'ハナコ'},
        ],
        'vars': {
          '@a2.paint': {'value': {'svg': svg, 'updatedAt': now - 1000, 'ttl': 3600}, 'rev': 1, 'by': 'a2', 'expiresAt': now + 3600000},
        },
      },
      'size': {'width': 400, 'height': 700},
      'now': now,
    });
    expect(open['ok'], isTrue, reason: '$open');
    final root = '${(open['value'] as Map)['root']}';
    // 3:4 のマスを 2 列、ハナコの絵は SVG の data URI、owner なので他人のマスに「削除」。
    expect(root, contains('aspectRatio: 0.75'));
    expect(root, contains('data:image/svg+xml;base64,'));
    expect(root, contains('paint.remove.a2'));

    controller.invoke('paint.edit', {'token': token, 'nodeId': 'x', 'kind': 'tap', 'now': now});
    final editor = sent.lastWhere((x) => x.$1 == RasqHostFns.mediaEditorOpen).$2;
    expect((editor['token'], editor['format'], editor['aspect']), (token, 'svg', '3:4'));

    sent.clear();
    controller.invoke('page.event', {'token': token, 'type': 'edited', 'svg': svg, 'width': 300, 'height': 400, 'now': now + 5});
    final set = sent.singleWhere((x) => x.$1 == RasqHostFns.sharedSet).$2;
    expect((set['key'], set['ttl'], (set['value'] as Map)['svg'], (set['value'] as Map)['updatedAt']), ('me.paint', 86400, svg, now + 5));

    // 反映は var で(期限つき)。
    sent.clear();
    controller.invoke('page.event', {'token': token, 'type': 'var', 'key': '@a1.paint', 'value': set['value'], 'rev': 1, 'by': 'a1', 'expiresAt': now + 86400000, 'now': now + 6});
    final render = sent.lastWhere((x) => x.$1 == RasqHostFns.pageRender).$2;
    expect('${render['root']}', contains('paint.clear'));

    // owner の削除 = 他人の @<id>.paint を value: null で。
    sent.clear();
    controller.invoke('paint.remove.a2', {'token': token, 'nodeId': 'x', 'kind': 'tap', 'now': now + 7});
    final remove = sent.singleWhere((x) => x.$1 == RasqHostFns.sharedSet).$2;
    expect((remove['key'], remove['value'], remove.containsKey('ttl')), ('@a2.paint', null, false));
  });
}
