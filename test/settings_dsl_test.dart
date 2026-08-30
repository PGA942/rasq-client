import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
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

class _SettingsSession extends SnsSessionBase {
  final applied = <(String, Map<String, Object?>)>[];
  final wrote = <(String, String, Object?)>[];
  Map<String, Object?> remote = {'isCat': true};

  @override
  AccountId get account => const AccountId(kind: SnsKind.misskey, instance: 'i.test', handle: 'me');
  @override
  String get pluginId => 'test.fake';
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

  test('Misskey の 4 ページは SettingsPageSpec として読める (D-044)', () {
    final specs = [for (final raw in MisskeyPlugin().settingsPages) SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>())];
    expect([for (final s in specs) s.area], ['account', 'timeline', 'safety', 'security']);
    expect(specs.first.isRemote, isTrue);
    expect(specs[1].defaults, {'withRenotes': true, 'withReplies': false});
  });
}
