import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// SDK の最小サンプル hello-rasq-plugin (D-077) が SDK ドキュメントどおりに
/// 動き続けることの回帰テスト(サンプル = 仕様のショーケース)。
/// hello プラグインが宣言する権限 (D-004)。
const _helloPermissions = {RasqPermissions.storageSafe};

void main() {
  final wasmFile = File('../../../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/hello_rasq_plugin.wasm');
  if (!wasmFile.existsSync()) {
    test('hello-rasq-plugin built', () {}, skip: 'build hello-rasq-plugin first (docs/GETTING_STARTED.md)');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'me');

  test('RRL 画面 + storage + 本体 patch(挨拶する)', () {
    final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: _helloPermissions));
    addTearDown(controller.dispose);
    controller.load();
    expect(controller.document!.root.findByKey('greeting')!.p['text'], 'こんにちは、RASQ!');

    controller.handleEvent('scope:greet-btn', 'tap', fn: 'greet');
    expect(controller.document!.root.findByKey('greeting')!.p['text'], 'こんにちは!(1 回目)');
    controller.handleEvent('scope:greet-btn', 'tap', fn: 'greet');
    expect(controller.document!.root.findByKey('greeting')!.p['text'], 'こんにちは!(2 回目)');
    expect(controller.env.storage.values, contains(2)); // storage.safe に永続化
  });

  test('FOW surface + surface patch + 閉時通知(パネルを開く → +1)', () async {
    final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: _helloPermissions));
    addTearDown(controller.dispose);
    controller.load();
    WasmFowRequest? opened;
    controller.onFowOpen = (req) => opened = req;

    controller.handleEvent('scope:panel-btn', 'tap', fn: 'openPanel');
    expect(opened!.id, 'hello-panel');
    expect(opened!.spec['title'], 'hello パネル');
    expect(opened!.onClosed, 'panelClosed');

    controller.handleEvent('scope:panel-plus', 'tap', fn: 'panelPlus');
    expect(controller.fowDocument('hello-panel')!.root.findByKey('panel-count')!.p['text'], '1 回');

    controller.notifyFowClosed('hello-panel', reason: 'dismissed');
    await Future<void>.delayed(Duration.zero);
    final n = controller.invoke('lastNotify');
    expect((n['value'] as Map)['fn'], 'lifecycle'); // panelClosed の後に unmount が届く
  });

  test('SNS 抽象関数(canned): sns.timeline / actions / performAction', () async {
    final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: _helloPermissions));
    addTearDown(controller.dispose);
    controller.load();
    final session = WasmSnsSession(account: viewer, invoke: (fn, args) async => controller.invoke(fn, args));

    await session.loadActions();
    expect(session.actions.single.id, 'wave');

    final page = await session.timeline(TimelineKind.local);
    expect(page.items, hasLength(2));
    expect(page.items.first.author.displayName, 'hello プラグイン');
    expect(page.items.first.reactions['👋'], 1);

    final r = await session.performAction('wave', 'h1');
    expect(r.done, isTrue);
  });
}
