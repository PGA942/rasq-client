import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/language_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_screen.dart';
import 'package:rasq_client/features/settings/settings_sections.dart';
import 'package:rasq_client/l10n/l10n.dart';
import 'package:rasq_client/l10n/locale_sync.dart';
import 'package:rasq_client/l10n/ui_locale.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

/// 表示の言語の仕組み (D-484): 言語の決め方と保存、Central / ORGATE への Accept-Language、ORGATE への PATCH /me、
/// gen-l10n の文言が画面に出ること(文言は変えていないので、日本語の文字で探す)。
void main() {
  tearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);

  group('言語の決め方', () {
    const jaEn = [Locale('ja'), Locale('en')];
    test('対応は日本語・英語・中国語(簡体 / 繁体)・韓国語。対応していない言語は日本語', () {
      expect(supportedUiLocales.toSet(), {const Locale('ja'), const Locale('en'), const Locale('ko'), const Locale('zh'), const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')});
      expect(supportedUiLocales.first, const Locale('ja'));
      expect(resolveUiLocale(null, const [Locale('en', 'US'), Locale('fr')]), const Locale('en'));
      expect(resolveUiLocale(null, const [Locale('fr'), Locale('de')]), const Locale('ja'));
      expect(resolveUiLocale(null, const [Locale('ja', 'JP')]), const Locale('ja'));
      expect(resolveUiLocale('fr', const []), const Locale('ja'));
    });
    test('言語を足したとき: 設定 → 端末の言語(言語が同じもの)→ 日本語', () {
      expect(resolveUiLocale(null, const [Locale('en', 'GB')], supported: jaEn), const Locale('en'));
      expect(resolveUiLocale(null, const [Locale('de'), Locale('ja', 'JP')], supported: jaEn), const Locale('ja'));
      expect(resolveUiLocale(null, const [Locale('de')], supported: jaEn), const Locale('ja'));
      expect(resolveUiLocale('en', const [Locale('ja')], supported: jaEn), const Locale('en'));
      expect(resolveUiLocale('system', const [Locale('en')], supported: jaEn), const Locale('en'));
      expect(resolveUiLocale('ko', const [Locale('en')], supported: jaEn), const Locale('en'));
    });
    test('中国語は文字で分ける: 台湾・香港・マカオは繁体、それ以外は簡体', () {
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      const jaZh = [Locale('ja'), Locale('zh'), hant];
      expect(resolveUiLocale(null, const [Locale('zh', 'TW')], supported: jaZh), hant);
      expect(resolveUiLocale(null, const [Locale('zh', 'HK')], supported: jaZh), hant);
      expect(resolveUiLocale(null, const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')], supported: jaZh), hant);
      expect(resolveUiLocale(null, const [Locale('zh', 'CN')], supported: jaZh), const Locale('zh'));
      expect(resolveUiLocale(null, const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'SG')], supported: jaZh), const Locale('zh'));
      expect(resolveUiLocale(null, const [Locale('zh')], supported: jaZh), const Locale('zh'));
      expect(resolveUiLocale('zh-Hant', const [Locale('ja')], supported: jaZh), hant);
      expect(resolveUiLocale('zh', const [Locale('ja')], supported: jaZh), const Locale('zh'));
    });
    test('BCP-47 の読み取り', () {
      expect(rasqLocaleFromTag('en-US'), const Locale('en', 'US'));
      expect(rasqLocaleFromTag('zh-Hant-TW'), const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'));
      expect(rasqLocaleFromTag(''), const Locale('ja'));
    });
  });

  test('保存: KV appearance.language.v1 の locale。読み直しても同じ、system は「システムに合わせる」', () async {
    final storage = MemorySessionStorage({});
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    await c.read(settingsAreaProvider(languageSettingsArea).future);
    expect(c.read(uiLocaleSettingProvider), isNull);
    expect(c.read(uiLocaleTagProvider), 'ja');
    await c.read(settingsAreaProvider(languageSettingsArea).notifier).set('locale', 'ja');
    expect(jsonDecode((await storage.read('appearance.language.v1'))!), {'locale': 'ja'});
    expect(c.read(uiLocaleSettingProvider), 'ja');
    expect(RasqUiLocale.tag, 'ja');

    final c2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c2.dispose);
    await c2.read(settingsAreaProvider(languageSettingsArea).future);
    expect(c2.read(uiLocaleSettingProvider), 'ja');
    await c2.read(settingsAreaProvider(languageSettingsArea).notifier).set('locale', systemLocaleSetting);
    expect(c2.read(uiLocaleSettingProvider), isNull);
  });

  testWidgets('設定 → 言語: システムに合わせる / 対応する言語の一覧。選ぶと端末に保存', (tester) async {
    final storage = MemorySessionStorage({});
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ja'),
        home: LanguageSettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('言語'), findsOneWidget);
    expect(find.text('システムに合わせる'), findsOneWidget);
    expect(find.text('いまは 日本語'), findsOneWidget);
    expect(find.byKey(const ValueKey('language.ja')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language.ja')));
    await tester.pumpAndSettle();
    expect(jsonDecode((await storage.read('appearance.language.v1'))!), {'locale': 'ja'});
    await tester.tap(find.byKey(const ValueKey('language.system')));
    await tester.pumpAndSettle();
    expect(jsonDecode((await storage.read('appearance.language.v1'))!), {'locale': 'system'});
  });

  testWidgets('gen-l10n の文言: 設定のトップと節の行は、前と同じ日本語で出る(delegate の無い画面でも)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({}))],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();
    expect(find.text('全ての設定'), findsOneWidget);
    expect(find.text('アプリの外観'), findsWidgets);
    expect(find.text('プラグインの構成'), findsOneWidget);
    // 節の表はアプリの文言から作る。言語の行は「アプリの外観」に。
    final appearance = settingsSections['appearance']!;
    expect(appearance.title, 'アプリの外観');
    expect(appearance.rows.map((r) => r.title), contains('言語'));
    expect(appL10n.settingsSectionsAboutTitle, 'RASQについて');
    // 部品(rasq_design)の文言と日付の書式。
    expect(RasqTimestamp.format(DateTime(2026, 8, 31), now: DateTime(2026, 10, 1)), '8月31日');
    expect(RasqTimestamp.format(DateTime(2017, 2, 3), now: DateTime(2026, 10, 1)), '2017年2月');
    expect(RasqTimestamp.format(DateTime(2026, 10, 1, 11, 57), now: DateTime(2026, 10, 1, 12)), '3分前');
  });

  test('スロットプラグインのマニフェストの文 (契約 v0.24): 名前 / 説明 / ページの見出し / ボタンのラベルを表示の言語で', () {
    final m = SlotManifest.fromJson({
      'id': 'sample.page',
      'name': 'みんなのボード',
      'description': '説明',
      'slots': ['page', 'post.action'],
      'page': {'title': 'ボード'},
      'actions': [
        {'id': 'like', 'label': 'いいね', 'tags': ['Reaction']},
      ],
      'locales': {
        'en': {
          'name': 'Board',
          'pageTitle': 'Board page',
          'actions': {
            'like': {'label': 'Like'},
          },
        },
      },
    });
    expect((m.name, m.description, m.page!.title, m.actions.single.label), ('みんなのボード', '説明', 'ボード', 'いいね'));
    RasqUiLocale.tag = 'en-US';
    expect((m.name, m.description, m.page!.title, m.actions.single.label), ('Board', '説明', 'Board page', 'Like'));
    expect(m.actions.single.tags, ['Reaction']);
  });

  group('Accept-Language (Central / ORGATE)', () {
    test('OrgateClient の要求には表示の言語が付く(JSON / バイト列 / multipart)', () async {
      final seen = <http.BaseRequest>[];
      final mock = MockClient((r) async {
        seen.add(r);
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });
      final client = OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock);
      await client.getJson('/me');
      RasqUiLocale.tag = 'en-US';
      await client.postJson('/x', {'a': 1});
      await client.getBytes('/b');
      await client.postMultipart('/m', fields: {'a': 'b'});
      await client.withToken(() => 't').getJson('/me');
      expect([for (final r in seen) r.headers['accept-language']], ['ja', 'en-US', 'en-US', 'en-US', 'en-US']);
    });

    test('Central と ORGATE の両方の口(プロバイダーが作るもの)に付く', () async {
      final seen = <String, String?>{};
      final mock = MockClient((r) async {
        seen[r.url.host] = r.headers['accept-language'];
        return http.Response('{}', 200);
      });
      await http.runWithClient(() async {
        final c = ProviderContainer(overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          settingsAreaProvider(backendSettingsArea).overrideWith(() => _FixedSettingsArea({'baseUrl': 'https://orgate.test', 'centralUrl': 'https://central.test'})),
        ]);
        addTearDown(c.dispose);
        await c.read(settingsAreaProvider(backendSettingsArea).future);
        RasqUiLocale.tag = 'ja';
        await c.read(orgateClientProvider)!.getJson('/me');
        await c.read(centralClientProvider)!.getJson('/me');
      }, () => mock);
      expect(seen, {'orgate.test': 'ja', 'central.test': 'ja'});
    });
  });

  group('ORGATE の PATCH /me {locale}', () {
    test('ログインしていれば 1 度送る。言語が同じなら送り直さない。未ログインなら送らない', () async {
      final patches = <Map<String, Object?>>[];
      final mock = MockClient((r) async {
        if (r.method == 'PATCH' && r.url.path == '/api/v1/me') patches.add((jsonDecode(r.body) as Map).cast<String, Object?>());
        return http.Response('{}', 200);
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: mock)),
        orgateAccountProvider.overrideWith(_SignedIn.new),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(localeSyncProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(orgateAccountProvider.future);
      await pumpEventQueue();
      expect(patches, [
        {'locale': 'ja'},
      ]);
      c.invalidate(uiLocaleProvider);
      await pumpEventQueue();
      expect(patches, hasLength(1));
    });

    test('古い ORGATE(locale を知らない 400)でも黙って諦める', () async {
      var calls = 0;
      final mock = MockClient((r) async {
        calls++;
        return http.Response('{"error":{"code":"400","message":"unknown field `locale`"}}', 400);
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: mock)),
        orgateAccountProvider.overrideWith(_SignedIn.new),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(localeSyncProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(orgateAccountProvider.future);
      await pumpEventQueue();
      expect(calls, 1);
    });

    test('未ログインなら送らない', () async {
      var calls = 0;
      final mock = MockClient((r) async {
        calls++;
        return http.Response('{}', 200);
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: mock)),
        orgateAccountProvider.overrideWith(_SignedOut.new),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(localeSyncProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(orgateAccountProvider.future);
      await pumpEventQueue();
      expect(calls, 0);
    });
  });
}

class _FixedSettingsArea extends SettingsAreaStore {
  _FixedSettingsArea(this.values) : super('backend');
  final Map<String, Object?> values;
  @override
  Future<Map<String, Object?>> build() async => values;
}

class _SignedIn extends OrgateAccountNotifier {
  @override
  Future<RasqAccount?> build() async => RasqAccount.fromJson(const {'id': 'acc-1', 'handle': 'neko', 'displayName': 'ねこ'});
}

class _SignedOut extends OrgateAccountNotifier {
  @override
  Future<RasqAccount?> build() async => null;
}
