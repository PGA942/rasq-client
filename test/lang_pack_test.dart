import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show withHostCallArgs, hostLocaleStringsArgKey;
import 'package:rasq_client/features/rai/prompts/rai_prompts.dart';
import 'package:rasq_client/features/settings/language_screen.dart';
import 'package:rasq_client/l10n/l10n.dart';
import 'package:rasq_client/l10n/langpack/icu.dart';
import 'package:rasq_client/l10n/langpack/lang_pack_store.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/session/session_providers.dart' show sessionStorageProvider;
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

// 言語パック (D-592): 非公式の言語パック(.rasqlang)を読み込み、文言のクラスの上書きの層が先に引く。

Uint8List _pack({
  String id = 'com.example.test',
  Map<String, Object?> locales = const {'ja': {}},
  Map<String, Object?> strings = const {},
  Map<String, Object?> extra = const {},
}) =>
    Uint8List.fromList(utf8.encode(jsonEncode({
      'format': langPackFormat,
      'formatVersion': 1,
      'id': id,
      'name': {'ja': 'テストのパック', 'en': 'Test pack'},
      'version': '1.2.3',
      'authors': ['tester'],
      'official': true,
      'locales': locales,
      'strings': strings,
      ...extra,
    })));

LangPack _parse(Uint8List bytes) => LangPack.parse(bytes, appLangPackSchema, appVersion: appVersionForLangPacks);

void main() {
  tearDown(() {
    ActiveLangPack.apply(null);
    RasqUiLocale.tag = RasqUiLocale.defaultTag;
  });

  group('ICU', () {
    test('差し込み・plural・select', () {
      final m = IcuMessage.parse('{name}: {count, plural, =0{なし} one{1 つ} other{{count} 個}} {kind, select, a{A} other{?}}');
      expect(m.names, {'name', 'count', 'kind'});
      expect(m.format({'name': 'x', 'count': 0, 'kind': 'a'}, 'en'), 'x: なし A');
      expect(m.format({'name': 'x', 'count': 1, 'kind': 'b'}, 'en'), 'x: 1 つ ?');
      expect(m.format({'name': 'x', 'count': 5, 'kind': 'a'}, 'en'), 'x: 5 個 A');
      // 名前でない { はそのまま。
      expect(IcuMessage.parse('a {-b').format(const {}, 'ja'), 'a {-b');
    });

    test('読めない文', () {
      expect(() => IcuMessage.parse('{n, plural, one{a}}'), throwsFormatException);
      expect(() => IcuMessage.parse('{name'), throwsFormatException);
      expect(() => IcuMessage.parse('a}'), throwsFormatException);
    });
  });

  group('読み込みと検証', () {
    test('壊れたキーだけ捨て、知らないキーは無視する', () {
      final p = _parse(_pack(strings: {
        'ja': {
          'app': {
            'languageSelfName': 'にほんご',
            'languageSettingsSystemCurrent': 'いま: {language}',
            'langPackApplied': '{count, plural, other{{count} けん}}',
            'langPackLoaded': '{nope} を読んだ', // 無いプレースホルダ
            'langPackHeader': '{count, plural, one{a}}', // other が無い
            'noSuchKey': 'x',
          },
          'rai': {'assistantSystem': 'やさしく答えて', 'planLine': '{nope}'},
          'plugin:rasq.official.mastodon': {'timeline.home': 'おうち', 'manifest.name': 'マストドン', 'manifest.bogus': 'x'},
          'unknownDomain': {'a': 'b'},
        },
      }));
      expect(p.id, 'com.example.test');
      expect(p.claimsOfficial, isTrue); // 自己申告(信用しない)
      expect(p.nameFor('en-US'), 'Test pack');
      expect(p.nameFor('ko'), 'テストのパック');
      expect(p.report.applied, 6);
      expect(p.report.unknown, 2);
      expect(p.report.rejected.map((i) => i.key), unorderedEquals(['langPackLoaded', 'langPackHeader', 'planLine', 'manifest.bogus']));
      expect(p.report.coverage['ja'], greaterThan(0));
    });

    test('パック全体が読めないとき', () {
      expect(() => _parse(Uint8List.fromList(utf8.encode('not json'))), throwsA(isA<LangPackException>().having((e) => e.error, 'error', LangPackError.notPack)));
      expect(() => _parse(_pack(extra: {'formatVersion': 99})), throwsA(isA<LangPackException>().having((e) => e.error, 'error', LangPackError.unsupportedVersion)));
      expect(() => _parse(_pack(extra: {'version': 'one'})), throwsA(isA<LangPackException>().having((e) => e.detail, 'detail', 'version')));
      expect(() => _parse(_pack(extra: {'authors': []})), throwsA(isA<LangPackException>().having((e) => e.detail, 'detail', 'authors')));
      // 同梱に無い言語で base が無い / Material の訳が無い言語だけ。
      expect(() => _parse(_pack(locales: {'fr': {}})), throwsA(isA<LangPackException>().having((e) => e.error, 'error', LangPackError.noLocales)));
      expect(() => _parse(_pack(locales: {'tlh': {'base': 'en'}})), throwsA(isA<LangPackException>().having((e) => e.error, 'error', LangPackError.noLocales)));
    });

    test('新しいアプリ向けのパック', () {
      expect(_parse(_pack(extra: {'app': {'min': '99.0.0'}})).report.needsNewerApp, isTrue);
      expect(_parse(_pack(extra: {'app': {'min': '0.1.0'}})).report.needsNewerApp, isFalse);
    });

    test('appVersionForLangPacks は pubspec.yaml の版と同じ', () {
      final v = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(appVersionForLangPacks, v);
    });
  });

  test('同梱の文言(公式パックの写し)を全部パックにしても、捨てる文が無い(実行時の ICU の読み手が gen-l10n と同じ範囲を読める)', () {
    const dirs = {
      'app': 'lib/l10n/parts',
      'rasq_design': 'packages/rasq_design/lib/l10n/parts',
      'rasq_models': 'packages/rasq_models/lib/l10n/parts',
      'rasq_plugin_api': 'packages/rasq_plugin_api/lib/l10n/parts',
      'sns_misskey': 'packages/sns_misskey/lib/l10n/parts',
      'rai': 'lib/features/rai/prompts/parts',
    };
    final strings = <String, Map<String, Map<String, String>>>{};
    var total = 0;
    for (final e in dirs.entries) {
      for (final f in Directory(e.value).listSync().whereType<File>()) {
        final m = RegExp(r'^[a-z_]+\.([a-zA-Z_]+)\.(arb|json)$').firstMatch(f.uri.pathSegments.last);
        if (m == null) continue;
        final values = {for (final x in (jsonDecode(f.readAsStringSync()) as Map).entries) if (!'${x.key}'.startsWith('@')) '${x.key}': '${x.value}'};
        total += values.length;
        ((strings[m.group(1)!] ??= {})[e.key] ??= {}).addAll(values);
      }
    }
    final p = _parse(_pack(locales: {for (final l in strings.keys) l: {}}, strings: strings));
    expect(p.report.rejected, isEmpty);
    expect(p.report.unknown, 0);
    expect(p.report.applied, total);
    expect(p.report.coverage['ja'], 1.0);
    // 同じ文言を上書きの層で引いても、同梱と同じ文になる。
    ActiveLangPack.apply(p);
    for (final tag in ['ja', 'en', 'ko']) {
      final l = appL10nFor(Locale(tag));
      final base = lookupAppLocalizations(Locale(tag));
      expect(l.languageSettingsSystemCurrent('X'), base.languageSettingsSystemCurrent('X'));
      expect(l.langPackApplied(1), base.langPackApplied(1));
      expect(l.langPackApplied(7), base.langPackApplied(7));
      expect(raiPromptsFor(tag).functionsBlock(['a', 'b']), raiPromptCatalogs[tag]!.functionsBlock(['a', 'b']));
    }
  });

  group('上書きの層', () {
    test('アプリ・部品・Flutter に依らない部品の文言', () {
      ActiveLangPack.apply(_parse(_pack(strings: {
        'ja': {
          'app': {'languageSelfName': 'にほんご', 'languageSettingsSystemCurrent': 'いま: {language}', 'langPackApplied': '{count, plural, other{{count} けん}}'},
          'rasq_design': {'designSearchHint': 'さがす'},
          'rasq_models': {'modelsErrorFamilyHttp': 'えいちてぃーてぃーぴー'},
        },
      })));
      final l = appL10nFor(const Locale('ja'));
      expect(l, isA<AppLocalizationsOverlay>());
      expect(l.languageSelfName, 'にほんご');
      expect(l.languageSettingsSystemCurrent('英語'), 'いま: 英語');
      expect(l.langPackApplied(3), '3 けん');
      // パックに無いキーは同梱の文言。
      expect(l.languageSettingsTitle, '言語');
      // ほかの言語(パックに無い)は同梱のまま。
      expect(appL10nFor(const Locale('en')).languageSelfName, 'English');
      expect(rasqDesignL10nFor(const Locale('ja')).designSearchHint, 'さがす');
      expect(rasqModelsL10n.modelsErrorFamilyHttp, 'えいちてぃーてぃーぴー');
      // 外せば同梱に戻る。
      ActiveLangPack.apply(null);
      expect(appL10nFor(const Locale('ja')).languageSelfName, '日本語');
      expect(rasqModelsL10n.modelsErrorFamilyHttp, 'HTTP');
    });

    test('パックが足した言語: 足りないキーは base の言語', () {
      final p = _parse(_pack(locales: {'fr': {'base': 'en', 'name': 'Français'}}, strings: {
        'fr': {
          'app': {'languageSettingsTitle': 'Langue'},
          'rai': {'languageName': 'français'},
        },
      }));
      ActiveLangPack.apply(p);
      expect(p.addedLocales.single.tag, 'fr');
      final l = appL10nFor(const Locale('fr'));
      expect(l.languageSettingsTitle, 'Langue');
      expect(l.languageSettingsSystem, lookupAppLocalizations(const Locale('en')).languageSettingsSystem);
      final rai = raiPromptsFor('fr');
      expect(rai.tag, 'fr');
      expect(rai.languageName, 'français');
      expect(rai.assistantSystem, const RaiPromptsEn().assistantSystem);
    });

    test('繁体字は簡体字のパックに倒さない', () {
      ActiveLangPack.apply(_parse(_pack(locales: {'zh': {}}, strings: {
        'zh': {'app': {'languageSettingsTitle': '简体'}},
      })));
      expect(appL10nFor(const Locale('zh')).languageSettingsTitle, '简体');
      expect(appL10nFor(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')).languageSettingsTitle, isNot('简体'));
    });

    test('RAi の指示の文: 差し込みと関数の一覧', () {
      final usage = const RaiPromptsJa().functionUsage;
      final p = _parse(_pack(strings: {
        'ja': {
          'rai': {
            'planLine': '\nTODO: {plan}',
            'functionUsage': [for (final u in usage) u.replaceFirst(': ', ':: ')].join('\n'),
          },
        },
      }));
      ActiveLangPack.apply(p);
      final rai = raiPromptsFor('ja');
      expect(rai.planLine(['a', 'b']), '\nTODO: a / b');
      expect(rai.functionUsage, hasLength(usage.length));
      // 関数名が変わる一覧は捨てる。
      final bad = _parse(_pack(strings: {
        'ja': {'rai': {'functionUsage': 'nope(): x'}},
      }));
      expect(bad.report.rejected.single.reason, 'function-names-differ');
    });

    test('プラグインの文: マニフェストと args.localeStrings', () {
      ActiveLangPack.apply(_parse(_pack(strings: {
        'ja': {
          'plugin:sample.like': {'manifest.name': 'いいね!', 'manifest.actions.like.label': 'すき', 'button.like': 'すきすき'},
        },
      })));
      final m = PluginManifest.fromJson({'id': 'sample.like', 'name': 'いいねボタン', 'version': '1.0.0', 'kind': 'action', 'actions': [{'id': 'like', 'genreTag': 'Reaction', 'label': 'いいね'}]});
      expect(m.name, 'いいね!');
      expect(m.baseName, 'いいねボタン');
      expect(m.actions.single.label, 'すき');
      final args = withHostCallArgs({'a': 1, hostLocaleStringsArgKey: 'spoofed'}, pluginId: 'sample.like');
      expect(args[hostLocaleStringsArgKey], {'button.like': 'すきすき'});
      expect(withHostCallArgs({hostLocaleStringsArgKey: 'spoofed'}, pluginId: 'other').containsKey(hostLocaleStringsArgKey), isFalse);
      expect(withHostCallArgs(const {'a': 1}).containsKey(hostLocaleStringsArgKey), isFalse);
    });
  });

  group('設定の画面', () {
    testWidgets('読み込む → 結果と未審査の印 → 外す', (tester) async {
      final dir = Directory.systemTemp.createTempSync('langpack_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bytes = _pack(strings: {
        'ja': {'app': {'langPackHeader': 'ことばパック', 'langPackLoaded': '{nope}'}},
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          langPackDirProvider.overrideWithValue(() async => dir),
          langPackPickerProvider.overrideWithValue(() async => bytes),
        ],
        child: const MaterialApp(locale: Locale('ja'), home: LanguageSettingsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('langpack.official')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('langpack.import')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('langpack.import')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('langpack.active.com.example.test')), findsOneWidget);
      expect(find.textContaining('未審査'), findsOneWidget);
      // 画面の文言がパックの文に(delegate の無い画面は appL10n = 上書きの層)。
      expect(find.text('ことばパック'), findsOneWidget);
      expect(find.textContaining('1 件は形が合わない'), findsOneWidget);
      // 読み込みの知らせ(SnackBar)が消えるのを待つ。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('langpack.issues')));
      await tester.tap(find.byKey(const ValueKey('langpack.issues')));
      await tester.pumpAndSettle();
      expect(find.textContaining('langPackLoaded: unknown-placeholder nope'), findsOneWidget);
      expect(File('${dir.path}/${LangPackNotifier.fileName}').existsSync(), isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('langpack.remove')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('langpack.remove')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('langpack.official')), findsOneWidget);
      expect(find.text('言語パック'), findsWidgets);
      expect(File('${dir.path}/${LangPackNotifier.fileName}').existsSync(), isFalse);
    });

    testWidgets('読めないファイルは知らせて、いまのパックはそのまま', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          langPackDirProvider.overrideWithValue(() async => Directory.systemTemp.createTempSync('langpack_test2')),
          langPackPickerProvider.overrideWithValue(() async => Uint8List.fromList(utf8.encode('{}'))),
        ],
        child: const MaterialApp(locale: Locale('ja'), home: LanguageSettingsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('langpack.import')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('langpack.import')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('言語パック(.rasqlang)ではありません'), findsOneWidget);
      expect(find.byKey(const ValueKey('langpack.official')), findsOneWidget);
    });
  });
}
