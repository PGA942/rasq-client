import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';

/// 同梱の SNS プラグインの文言と表示の言語 (D-485 / 契約 v0.24 §4.6): ホストは毎回の call に `args.locale` を載せ
/// ([withHostCallArgs])、プラグインは文を kit の表から引く。同梱は ja / en / zh-Hans / zh-Hant / ko の表を持つ (D-543)。
/// 表の無い言語(`fr`)は ja と同じ結果に落ち、`en` は訳した文になる。同梱の wasm(assets/plugins)を実物で叩く。
void main() {
  tearDown(() {
    RasqUiLocale.tag = RasqUiLocale.defaultTag;
    RasqLangOverride.clear();
  });

  WasmPluginController load(String asset, {String? pluginId}) {
    final env = RasqHostEnvironment(
      fetch: (r) => SyncFetchResponse(status: 500, headers: const {}, bodyText: ''),
      storage: <String, Object?>{},
    );
    return WasmPluginController(wasmBytes: File('../../assets/plugins/$asset').readAsBytesSync(), env: env, pluginId: pluginId)..load();
  }

  Map<String, dynamic> value(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    return (r['value'] as Map).cast<String, dynamic>();
  }

  const bundled = ['misskey_wasm_sample.wasm', 'mastodon_wasm.wasm', 'bluesky_wasm.wasm', 'mixi2_wasm.wasm'];

  for (final asset in bundled) {
    test('$asset: 表の無い言語は ja と同じ宣言、en は訳(設定ページ / アクション / TL)', () {
      final c = load(asset);
      final ja = {for (final f in ['sns.settingsPages', 'sns.actions', 'sns.timelines']) f: value(c.invoke(f))};
      expect((ja['sns.settingsPages']!['pages'] as List).cast<Map>().first['title'], 'アカウント');
      RasqUiLocale.tag = 'fr';
      for (final f in ja.keys) {
        expect(value(c.invoke(f)), ja[f], reason: '$f locale=fr');
      }
      RasqUiLocale.tag = 'en-US';
      final pages = (value(c.invoke('sns.settingsPages'))['pages'] as List).cast<Map>();
      expect(pages.first['title'], 'Account');
      RasqUiLocale.tag = 'zh-Hant-TW';
      expect((value(c.invoke('sns.settingsPages'))['pages'] as List).cast<Map>().first['title'], isNot('アカウント'));
    });
  }

  // 言語パック (D-592 / 契約 v0.26): ホストが args.localeStrings で渡した文を、kit の表より先に引く。
  // 差し込み {name} の組が違う文は使わない。パックを外せば同梱の文に戻る。
  for (final (asset, id) in const [
    ('misskey_wasm_sample.wasm', 'misskey-wasm-sample'),
    ('mastodon_wasm.wasm', 'rasq.official.mastodon'),
    ('bluesky_wasm.wasm', 'rasq.official.bluesky'),
    ('mixi2_wasm.wasm', 'rasq.official.mixi2'),
  ]) {
    test('$asset: 言語パックの文(args.localeStrings)が kit の表より先に効く', () {
      final c = load(asset, pluginId: id);
      String title() => (value(c.invoke('sns.settingsPages'))['pages'] as List).cast<Map>().first['title'] as String;
      expect(title(), 'アカウント');
      RasqLangOverride.pluginStrings = (pluginId, locale) => pluginId == id && locale == 'ja' ? {'account.title': 'おなまえ'} : null;
      expect(title(), 'おなまえ');
      // ほかのプラグイン宛ての表は効かない。
      RasqLangOverride.pluginStrings = (pluginId, locale) => pluginId == 'someone.else' ? {'account.title': 'ちがう'} : null;
      expect(title(), 'アカウント');
      // 表示の言語が en なら en の表(パックの文は en の分だけ)。
      RasqUiLocale.tag = 'en';
      RasqLangOverride.pluginStrings = (pluginId, locale) => pluginId == id && locale == 'en' ? {'account.title': 'Profile'} : null;
      expect(title(), 'Profile');
      RasqLangOverride.clear();
      expect(title(), 'Account');
    });
  }

  test('mastodon: 差し込みの組が違う文は使わない', () {
    final c = load('mastodon_wasm.wasm', pluginId: 'rasq.official.mastodon');
    String home() => ((value(c.invoke('sns.timelines'))['timelines'] as List).cast<Map>().firstWhere((t) => t['id'] == 'home')['label'] as String);
    final base = home();
    RasqLangOverride.pluginStrings = (_, _) => {'timeline.home': '{oops} ホーム'};
    expect(home(), base);
    RasqLangOverride.pluginStrings = (_, _) => {'timeline.home': 'おうち'};
    expect(home(), 'おうち');
  });

  test('mixi2: エラーの文も args.locale で引く(en は訳、表の無い言語は ja)', () {
    final c = load('mixi2_wasm.wasm');
    String message() => ((c.invoke('sns.login', {'host': 'mixi.social', 'identifier': 'x', 'password': 'y'})['error'] as Map)['message'] as String);
    RasqUiLocale.tag = 'fr';
    expect(message(), 'mixi2 は OAuth でログインします(RASQ サーバーのブローカー経由)。動作確認はホスト「dummy」で。');
    RasqUiLocale.tag = 'en';
    expect(message(), startsWith('mixi2 signs in with OAuth'));
  });

  test('hello_rasq_plugin: 画面の文も locale=en で訳(snapshot はいちばん新しい call の locale)', () {
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
    expect(texts, contains('Hello! (#1)'));
  });
}
