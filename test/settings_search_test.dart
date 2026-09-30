import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_screen.dart';
import 'package:rasq_client/features/settings/settings_search.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 設定の検索 (D-385)。
void main() {
  Future<String?> fromDisk(String area) async {
    final f = File('assets/settings/$area.rrl.json');
    return f.existsSync() ? f.readAsString() : null;
  }

  test('索引: 節 / 行 / 設定ページの中の項目。当たりは名前が先、節で絞れる', () async {
    final index = await buildSettingsSearchIndex(fromDisk);
    expect(index.where((e) => e.row == null).map((e) => e.title), contains('アプリの外観'), reason: '節');
    // ページの中の項目(モーションの抑制 のページの「モーションを抑制する」)。
    final inPage = index.firstWhere((e) => e.title == 'モーションを抑制する');
    expect(inPage.path, ['アプリの外観', 'モーションの抑制']);
    expect(inPage.route, '/settings/dsl/appearance.motion');

    final hits = searchSettings(index, 'モーション');
    expect(hits.first.entry.title, 'モーションの抑制');
    expect(hits.map((h) => h.entry.title), contains('モーションを抑制する'));
    expect(searchSettings(index, '＋ ボタン').first.entry.title, '＋ ボタンの割り当て');
    expect(searchSettings(index, 'ダークモード').first.entry.route, Routes.settingsTheme, reason: '言い換え(キー)でも当たる');
    expect(searchSettings(index, 'ぜんぜん関係ないことば'), isEmpty);
    // 節で絞る。
    final astellOnly = searchSettings(index, 'トレンド', sections: {'astell'});
    expect(astellOnly, isNotEmpty);
    expect(astellOnly.every((h) => h.entry.sectionId == 'astell'), isTrue);
    expect(searchSettings(index, '', sections: {'rai'}).map((h) => h.entry.title), ['工程グラフの自動表示'], reason: '語が無ければ節の行');
  });

  test('ページの部品から名前を拾う(お知らせの本文は拾わない)', () {
    final labels = settingsPageLabels(jsonDecode('{"t":"Column","c":[{"t":"Notice","p":{"title":"x","text":"長い説明"}},{"t":"SectionHeader","p":{"title":"見出し"}},{"t":"SwitchListTile","k":"a","p":{"title":"スイッチ"}}]}'));
    expect(labels, ['見出し', 'スイッチ']);
  });

  testWidgets('全ての設定の検索欄: トレンドと同じ角丸の欄。入れると当たった設定、押すとそのページ。押すと伸びて節のチップ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (v) => const []))),
        settingsSearchIndexProvider.overrideWith((ref) => buildSettingsSearchIndex(fromDisk)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.settings);
    await tester.pumpAndSettle();

    final box = find.byKey(settingsSearchKey);
    expect(tester.widget<RasqExpandableSearchBox>(box).expanded, isFalse);
    expect(find.text('プラグインの構成'), findsOneWidget, reason: '入れる前は一覧');
    await tester.tap(find.descendant(of: box, matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    expect(tester.widget<RasqExpandableSearchBox>(box).expanded, isTrue, reason: '押すと伸びる');
    expect(find.descendant(of: box, matching: find.text('アプリの外観')), findsOneWidget, reason: '節のチップ');

    await tester.runAsync(() => c.read(settingsSearchIndexProvider.future));
    await tester.enterText(find.descendant(of: box, matching: find.byType(TextField)), 'モーション');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final results = find.byKey(const ValueKey('settings.search.results'));
    expect(results, findsOneWidget);
    expect(find.descendant(of: results, matching: find.text('モーションを抑制する')), findsOneWidget);
    expect(find.descendant(of: results, matching: find.text('アプリの外観 › モーションの抑制')), findsWidgets, reason: 'パンくず');
    await tester.tap(find.byKey(const ValueKey('settings.search.hit.アプリの外観/モーションの抑制')));
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsDslScreen>(find.byType(SettingsDslScreen)).area, 'appearance.motion');
  });
}
