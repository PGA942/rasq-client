import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 設定ページの宣言 (D-044 / D-482): wasm の SNS プラグインは `sns.settingsPages` でページを返し、
/// [WasmSnsPlugin.loadSettingsPages] が匿名ワーカーで 1 度読んで持つ。同梱の 4 プラグイン
/// (assets/plugins、rasq-sdk-sample から作る)を実物で叩き、設定の「SNSプラグイン」の 4 行がどれも開けることを確かめる。
void main() {
  WasmSnsPlugin plugin(String asset, SnsKind kind) {
    final p = WasmSnsPlugin(
      manifest: PluginManifest(id: 'test.$asset', name: asset, version: '0.1.0', kind: PluginKind.sns, supportedSns: [kind]),
      kind: kind,
      loadBytes: () async => File('../../assets/plugins/$asset').readAsBytes(),
      nativeFetch: false,
    );
    addTearDown(p.dispose);
    return p;
  }

  const bundled = {
    'misskey_wasm_sample.wasm': SnsKind.misskey,
    'mastodon_wasm.wasm': SnsKind.mastodon,
    'bluesky_wasm.wasm': SnsKind.bluesky,
    'mixi2_wasm.wasm': SnsKind.mixi2,
  };

  for (final MapEntry(key: asset, value: kind) in bundled.entries) {
    test('$asset: account / timeline / safety / security を宣言し、書くタイルのキーはどれも既定値を持つ', () async {
      final p = plugin(asset, kind);
      expect(p.settingsPages, isEmpty, reason: '読むまでは空(行は読み込み中は出しておく)');
      final pages = [for (final raw in await p.loadSettingsPages()) (jsonDecode(raw) as Map).cast<String, Object?>()];
      expect([for (final j in pages) j['area']], ['account', 'timeline', 'safety', 'security']);
      expect(p.settingsPages, hasLength(4), reason: '読んだら持つ');
      for (final j in pages) {
        expect(j['schema'], 'rasq.settings-page/1');
        final defaults = (j['defaults'] as Map).cast<String, Object?>();
        for (final n in ((j['root'] as Map)['c'] as List).cast<Map<String, Object?>>()) {
          final on = (n['on'] as Map?)?.values ?? const [];
          if (on.contains('settings.set')) expect(defaults.containsKey(n['k']), isTrue, reason: '${j['area']}.${n['k']}');
        }
      }
      expect(pages.first['source'], 'remote');
      // safety はホストが投稿タイルに当てるので、どのプラグインも同じキー。
      expect((pages[2]['defaults'] as Map).keys.toSet(), {'sensitiveMedia', 'openCw'});
      // 2 回目は読み直さない(同じ Future)。
      expect(identical(p.loadSettingsPages(), p.loadSettingsPages()), isTrue);
      // 表示の言語が変わったら読み直す(言語もキー、D-484 / 契約 v0.24)。同梱は訳の表を持つので en は別の文になる (D-543)。
      final before = p.loadSettingsPages();
      addTearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);
      RasqUiLocale.tag = 'en';
      final after = p.loadSettingsPages();
      expect(identical(before, after), isFalse);
      final en = [for (final raw in await after) (jsonDecode(raw) as Map).cast<String, Object?>()];
      expect([for (final j in en) j['area']], ['account', 'timeline', 'safety', 'security'], reason: '並びと area は言語に依らない');
      expect([for (final j in en) j['defaults']], [for (final j in pages) j['defaults']], reason: '既定値は言語に依らない');
      expect(await after, isNot(await before));
      expect(identical(after, p.loadSettingsPages()), isTrue);
    });
  }

  test('sns.settingsPages を持たない古いプラグイン(C01)はページ無し', () async {
    final p = plugin('hello_rasq_plugin.wasm', SnsKind.misskey);
    expect(await p.loadSettingsPages(), isEmpty);
  });
}
