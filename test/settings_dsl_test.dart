import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_section_screen.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';

/// 設定ページだけを提供するフェイクプラグイン (D-044)。
class _PagesPlugin extends SnsPlugin {
  _PagesPlugin(this.pages);
  final List<String> pages;
  @override
  SnsKind get kind => SnsKind.misskey;
  @override
  PluginManifest get manifest => const PluginManifest(id: 'test.fake', name: 'Fake', version: '0.0.1', kind: PluginKind.sns);
  @override
  List<String> get settingsPages => pages;
  @override
  Future<ServerInfo> inspectServer(String host) => throw UnimplementedError();
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnimplementedError();
  @override
  SnsSession open(AccountSession session) => throw UnimplementedError();
}

/// wasm のプラグインのように、ページを後から(非同期で)返し、セッションも開けるフェイク (D-482)。
class _AsyncPagesPlugin extends SnsPlugin {
  _AsyncPagesPlugin(this.id, this.pages, {this.session});
  final String id;
  final List<String> pages;
  final _SettingsSession? session;
  int loads = 0;
  @override
  SnsKind get kind => SnsKind.mastodon;
  @override
  PluginManifest get manifest => PluginManifest(id: id, name: id, version: '0.0.1', kind: PluginKind.sns);
  @override
  Future<List<String>> loadSettingsPages() async {
    loads++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return pages;
  }

  @override
  Future<ServerInfo> inspectServer(String host) => throw UnimplementedError();
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnimplementedError();
  @override
  SnsSession open(AccountSession s) => session ?? (throw UnimplementedError());
}

class _SettingsSession extends SnsSessionBase {
  final applied = <(String, Map<String, Object?>)>[];
  final wrote = <(String, String, Object?)>[];
  _SettingsSession({this.pluginId = 'test.fake', this.account = const AccountId(kind: SnsKind.misskey, instance: 'i.test', handle: 'me')});
  Map<String, Object?> remote = {'isCat': true};

  @override
  final AccountId account;
  @override
  final String pluginId;
  @override
  Future<void> applySettings(String area, Map<String, Object?> values) async => applied.add((area, values));
  @override
  Future<Map<String, Object?>> settingsRead(String area) async => remote;
  @override
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) async {
    wrote.add((area, key, value));
    remote = {...remote, key: value};
    return remote;
  }
}

final _localPage = jsonEncode({
  'schema': 'rasq.settings-page/1',
  'area': 'timeline',
  'title': 'タイムライン',
  'defaults': {'withRenotes': true},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SwitchListTile', 'k': 'withRenotes', 'p': {'title': 'リノートを表示', 'value': r'$.settings.withRenotes'}, 'on': {'change': 'settings.set'}},
    ],
  },
});

final _remotePage = jsonEncode({
  'schema': 'rasq.settings-page/1',
  'area': 'account',
  'title': 'アカウント',
  'source': 'remote',
  'defaults': {'isCat': false},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SwitchListTile', 'k': 'isCat', 'p': {'title': 'Catにする', 'value': r'$.settings.isCat'}, 'on': {'change': 'settings.set'}},
    ],
  },
});

void main() {
  Widget wrap(SessionStorage storage, Widget child) => ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(theme: RasqTheme.light(), home: child),
      );

  testWidgets('設定DSL画面: アセットを描画し、変更が KV `<area>.v1` へ永続化される (D-031/D-035)', (tester) async {
    final storage = MemorySessionStorage();
    await tester.pumpWidget(wrap(storage, const SettingsDslScreen(area: 'appearance.motion')));
    await tester.pumpAndSettle();

    expect(find.text('モーションの抑制'), findsOneWidget);
    expect(find.text('モーションを抑制する'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final saved = jsonDecode((await storage.read('appearance.motion.v1'))!) as Map;
    expect(saved['reduceMotion'], isTrue);
  });

  testWidgets('設定DSL画面: 保存値が既定値より優先されて復元される', (tester) async {
    final storage = MemorySessionStorage({'appearance.display.v1': jsonEncode({'textScale': 120})});
    await tester.pumpWidget(wrap(storage, const SettingsDslScreen(area: 'appearance.display')));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 120);
  });

  testWidgets('設定DSL画面: 不明な area は空表示に縮退する(クラッシュしない)', (tester) async {
    await tester.pumpWidget(wrap(MemorySessionStorage(), const SettingsDslScreen(area: 'no-such-area')));
    await tester.pumpAndSettle();
    expect(find.text('設定ページを読み込めません'), findsOneWidget);
  });

  Widget wrapPlugin(SessionStorage storage, _SettingsSession session, Widget child) => ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(_PagesPlugin([_localPage, _remotePage]))),
          currentSnsSessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp(theme: RasqTheme.light(), home: child),
      );

  testWidgets('プラグイン設定ページ (D-044): KV `sns.<pluginId>.<area>.v1` へ保存し applySettings が呼ばれる', (tester) async {
    final storage = MemorySessionStorage();
    final session = _SettingsSession();
    await tester.pumpWidget(wrapPlugin(storage, session, const SettingsDslScreen(area: 'sns.timeline')));
    await tester.pumpAndSettle();

    expect(find.text('タイムライン'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue); // defaults

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final saved = jsonDecode((await storage.read('sns.test.fake.timeline.v1'))!) as Map;
    expect(saved['withRenotes'], isFalse);
    final (area, values) = session.applied.last;
    expect(area, 'timeline');
    expect(values, {'withRenotes': false});
  });

  testWidgets('remote ページ (D-044): settingsRead から表示し、変更は settingsWrite へ', (tester) async {
    final session = _SettingsSession(); // remote: isCat = true
    await tester.pumpWidget(wrapPlugin(MemorySessionStorage(), session, const SettingsDslScreen(area: 'sns.account')));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue); // サーバー値が defaults に勝つ
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(session.wrote.single, ('account', 'isCat', false));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  // ── D-482: プラグインが宣言したページだけ行に出す / 宣言は非同期でもよい / 設定するアカウントのプラグインから ──

  Widget wrapRegistry(PluginRegistry registry, SnsSession? session, Widget child) => ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
          pluginRegistryProvider.overrideWithValue(registry),
          currentSnsSessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp(theme: RasqTheme.light(), home: child),
      );

  testWidgets('SNSプラグインの節 (D-482): プラグインが宣言したページの行だけ出す(アプリの行はそのまま)', (tester) async {
    final registry = PluginRegistry()..register(_PagesPlugin([_localPage, _remotePage]));
    await tester.pumpWidget(wrapRegistry(registry, _SettingsSession(), const SettingsSectionScreen(sectionId: 'sns')));
    await tester.pumpAndSettle();
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('タイムライン'), findsOneWidget);
    expect(find.text('セキュリティ'), findsNothing);
    expect(find.text('プライバシーとセーフモード'), findsNothing);
    expect(find.text('リスト'), findsOneWidget);
    expect(find.text('ミュート/ブロック'), findsOneWidget);
  });

  testWidgets('ページを持たないプラグイン (D-482): 4 つの行を出さず、直接開いてもエラーではなく「このページはありません」', (tester) async {
    final registry = PluginRegistry()..register(_AsyncPagesPlugin('test.fake', const []));
    await tester.pumpWidget(wrapRegistry(registry, _SettingsSession(), const SettingsSectionScreen(sectionId: 'sns')));
    await tester.pumpAndSettle();
    for (final t in ['アカウント', 'タイムライン', 'セキュリティ', 'プライバシーとセーフモード']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    expect(find.text('チャイルドセーフ'), findsOneWidget);

    await tester.pumpWidget(wrapRegistry(registry, _SettingsSession(), const SettingsDslScreen(area: 'sns.account')));
    await tester.pumpAndSettle();
    expect(find.text('このページはありません'), findsOneWidget);
    expect(find.text('設定ページを読み込めません'), findsNothing);
  });

  testWidgets('非同期の宣言 (D-482, wasm の sns.settingsPages): 読み込み後にページが開き、宣言は 1 度だけ読む', (tester) async {
    final plugin = _AsyncPagesPlugin('test.fake', [_localPage, _remotePage]);
    final session = _SettingsSession();
    await tester.pumpWidget(wrapRegistry(PluginRegistry()..register(plugin), session, const SettingsDslScreen(area: 'sns.account')));
    await tester.pumpAndSettle();
    expect(find.text('アカウント'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue); // settingsRead の値
    await tester.pumpWidget(wrapRegistry(PluginRegistry()..register(plugin), session, const SettingsDslScreen(area: 'sns.timeline')));
    await tester.pumpAndSettle();
    expect(find.text('リノートを表示'), findsOneWidget);
    expect(plugin.loads, 2); // ProviderScope を作り直したぶんだけ(同じスコープでは 1 回)
  });

  testWidgets('設定するアカウントの切替 (D-131 / D-482): ページは切り替えた先のアカウントのプラグインから', (tester) async {
    // 現在のアカウント = ページを持たないプラグイン、切り替えた先 = ページを持つプラグイン(iPad の Misskey の報告の形)。
    const otherAccount = AccountId(kind: SnsKind.misskey, instance: 'misskey.test', handle: 'Xepos');
    final other = _SettingsSession(pluginId: 'test.misskey', account: otherAccount);
    final registry = PluginRegistry()
      ..register(_AsyncPagesPlugin('test.bare', const []))
      ..register(_AsyncPagesPlugin('test.misskey', [_remotePage], session: other));
    final current = _SettingsSession(pluginId: 'test.bare');
    await tester.pumpWidget(wrapRegistry(registry, current, const SettingsDslScreen(area: 'sns.account')));
    await tester.pumpAndSettle();
    expect(find.text('このページはありません'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsDslScreen)));
    container.read(settingsAccountOverrideProvider.notifier).set(AccountSession(account: otherAccount, pluginId: 'test.misskey', token: 't', createdAt: DateTime(2026)));
    await tester.pumpAndSettle();
    expect(find.text('Catにする'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(other.wrote.single, ('account', 'isCat', false));
  });

  testWidgets('文字の欄 (D-482): Input の「保存」で settingsWrite(payload.text)、空でも送れる', (tester) async {
    final page = jsonEncode({
      'schema': 'rasq.settings-page/1',
      'area': 'account',
      'title': 'アカウント',
      'source': 'remote',
      'defaults': {'name': ''},
      'root': {
        't': 'Column',
        'c': [
          {
            't': 'Input',
            'k': 'name',
            'p': {'label': '名前', 'value': r'$.settings.name', 'submitLabel': '保存', 'clearOnSubmit': false, 'allowEmpty': true, 'pad': 16},
            'on': {'submit': 'settings.set'},
          },
        ],
      },
    });
    final session = _SettingsSession()..remote = {'name': '古い名前'};
    await tester.pumpWidget(wrapRegistry(PluginRegistry()..register(_PagesPlugin([page])), session, const SettingsDslScreen(area: 'sns.account')));
    await tester.pumpAndSettle();
    expect(find.text('名前'), findsOneWidget); // 欄の名前(label)
    expect(find.text('古い名前'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新しい名前');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(session.wrote.last, ('account', 'name', '新しい名前'));
    expect(find.text('新しい名前'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(session.wrote.last, ('account', 'name', ''));
  });

  test('Misskey の 4 ページは SettingsPageSpec として読める (D-044)', () {
    final specs = [for (final raw in MisskeyPlugin().settingsPages) SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>())];
    expect([for (final s in specs) s.area], ['account', 'timeline', 'safety', 'security']);
    expect(specs.first.isRemote, isTrue);
    expect(specs[1].defaults, {'withRenotes': true, 'withReplies': false});
  });
}
