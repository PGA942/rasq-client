import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';

/// 同梱の SNS プラグインの文言と表示の言語 (D-485 / 契約 v0.24 §4.6): ホストは毎回の call に `args.locale` を載せ
/// ([withHostCallArgs])、プラグインは文を kit の表から引く。いまの同梱は ja の表だけなので、`en` でも日本語のまま、
/// ja のときと同じ結果になる(文言は変えていない)。同梱の wasm(assets/plugins)を実物で叩く。
void main() {
  tearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);

  WasmPluginController load(String asset) {
    final env = RasqHostEnvironment(
      fetch: (r) => SyncFetchResponse(status: 500, headers: const {}, bodyText: ''),
      storage: <String, Object?>{},
    );
    return WasmPluginController(wasmBytes: File('../../assets/plugins/$asset').readAsBytesSync(), env: env)..load();
  }

  Map<String, dynamic> value(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    return (r['value'] as Map).cast<String, dynamic>();
  }

  const bundled = ['misskey_wasm_sample.wasm', 'mastodon_wasm.wasm', 'bluesky_wasm.wasm', 'mixi2_wasm.wasm'];

  for (final asset in bundled) {
    test('$asset: locale=en でも ja と同じ日本語の宣言(設定ページ / アクション / TL)', () {
      final c = load(asset);
      final ja = {for (final f in ['sns.settingsPages', 'sns.actions', 'sns.timelines']) f: value(c.invoke(f))};
      RasqUiLocale.tag = 'en';
      for (final f in ja.keys) {
        expect(value(c.invoke(f)), ja[f], reason: '$f locale=en');
      }
      RasqUiLocale.tag = 'en-US';
      final pages = (value(c.invoke('sns.settingsPages'))['pages'] as List).cast<Map>();
      expect(pages.first['title'], 'アカウント');
    });
  }

  test('mixi2: エラーの文も locale=en で日本語(args.locale を受けて ja の表に落ちる)', () {
    final c = load('mixi2_wasm.wasm');
    RasqUiLocale.tag = 'en';
    final r = c.invoke('sns.login', {'host': 'mixi.social', 'identifier': 'x', 'password': 'y'});
    expect(r['ok'], isFalse);
    expect((r['error'] as Map)['message'], 'mixi2 は OAuth でログインします(RASQ サーバーのブローカー経由)。動作確認はホスト「dummy」で。');
  });

  test('hello_rasq_plugin: 画面の文も locale=en で日本語(snapshot はいちばん新しい call の locale)', () {
    final c = load('hello_rasq_plugin.wasm');
    RasqUiLocale.tag = 'en';
    c.pullSnapshot();
    value(c.invoke('greet'));
    final texts = <String>[];
    void walk(Object? n) {
      if (n is Map) {
        final p = n['p'];
        if (p is Map) texts.addAll([p['text'], p['label']].whereType<String>());
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(c.document?.root.toJson());
    expect(texts, containsAll(['こんにちは!(1 回目)', '挨拶する', 'パネルを開く']));
  });
}
