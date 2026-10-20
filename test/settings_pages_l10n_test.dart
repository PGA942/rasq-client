import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/l10n/asset_strings.dart';
import 'package:rasq_client/l10n/asset_strings.g.dart';
import 'package:rasq_client/l10n/l10n.dart';

/// 設定の静的なページの文言 (D-535): `assets/settings/*.rrl.json` の文言の参照が全部引けて、日本語が残っていない。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  final japanese = RegExp(r'[　-ヿ㐀-䶿一-鿿＀-￯]');
  final pages = {
    for (final f in Directory('assets/settings').listSync().whereType<File>().where((f) => f.path.endsWith('.rrl.json')))
      f.uri.pathSegments.last: jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
  };

  Iterable<String> refs(Object? j) sync* {
    switch (j) {
      case String s when s.startsWith(assetStringPrefix):
        yield s.substring(assetStringPrefix.length);
      case {r'$l10n': final String key}:
        yield key;
      case Map m:
        for (final v in m.values) {
          yield* refs(v);
        }
      case List xs:
        for (final x in xs) {
          yield* refs(x);
        }
    }
  }

  Iterable<String> strings(Object? j) sync* {
    switch (j) {
      case String s:
        yield s;
      case Map m:
        for (final v in m.values) {
          yield* strings(v);
        }
      case List xs:
        for (final x in xs) {
          yield* strings(x);
        }
    }
  }

  test('画面のページ(doc の無いもの)は日本語を直接持たず、参照は全部引ける', () {
    final used = <String>{};
    for (final MapEntry(key: name, value: page) in pages.entries) {
      if (page.containsKey('doc')) continue;
      for (final s in strings(page)) {
        expect(japanese.hasMatch(s), isFalse, reason: '$name: $s');
      }
      for (final key in refs(page)) {
        used.add(key);
        expect(appAssetString(ja, key), isNotNull, reason: '$name: $key');
      }
      final resolved = resolveAssetStrings(page, ja);
      expect(jsonEncode(resolved).contains(assetStringPrefix), isFalse, reason: name);
      expect(jsonEncode(resolved).contains(r'$l10n'), isFalse, reason: name);
    }
    // 部品の settings_pages のキーは、どれかのページが使っている(使わないキーを残さない)。
    final part = jsonDecode(File('lib/l10n/parts/settings_pages.ja.arb').readAsStringSync()) as Map<String, Object?>;
    expect({for (final k in part.keys) if (!k.startsWith('@')) k}.difference(used), isEmpty);
  });

  test('引数のある参照は args の値を差し込む', () {
    final page = pages['plugins.telemetry.rrl.json']!;
    final text = jsonEncode(resolveAssetStrings(page, ja));
    expect(text, contains('送るもの: 例 {host: misskey.example'));
  });

  test('文書のページは表示の言語のファイル → 言語だけ → 日本語の元の順に探す', () {
    expect(settingsPageAssetPaths('about.terms', 'ja'), ['assets/settings/about.terms.rrl.json']);
    expect(settingsPageAssetPaths('about.terms', 'en-US'), ['assets/settings/en-US/about.terms.rrl.json', 'assets/settings/en/about.terms.rrl.json', 'assets/settings/about.terms.rrl.json']);
    expect(settingsPageAssetPaths('about.terms', 'en'), ['assets/settings/en/about.terms.rrl.json', 'assets/settings/about.terms.rrl.json']);
  });
}
