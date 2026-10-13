// 描画確認用 (D-470): トレンドの指向性/刺激性(2 カラム)と、トレンドプラグインのノードを置いた TL / トレンドページ。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/trend_nodes_preview_test.dart --update-goldens
// → tool/preview/trend_nodes_<phone|wide>_<tendency|home|search>.png
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fake_slot_runtime.dart';
import '../../test/support/fakes.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  final posts = [
    Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'ダグラス'), createdAt: DateTime(2026, 9, 9, 20), body: 'ロケット発射おめでとう！ #打上会 #宇宙'),
    Post(id: 'p2', account: acc, author: const UserSummary(id: 'u2', account: acc, displayName: '山ハヤ'), createdAt: DateTime(2026, 9, 9, 19), body: '今日の晩ごはんはカレー #料理'),
    Post(id: 'p3', account: acc, author: const UserSummary(id: 'u3', account: acc, displayName: 'TiVard'), createdAt: DateTime(2026, 9, 9, 18), body: '打ち上げ中継の写真 #打上会'),
  ];

  Future<ProviderContainer> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = fakeSession().account.key;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts));
    final fakes = <String, FakeSlotRuntime Function()>{
      'trend': () => FakeSlotRuntime(
            manifest: {'id': 'sample.trend', 'name': 'トレンドサジェスト', 'version': '0.1.0', 'kind': 'trend', 'slots': ['trend.suggest'], 'permissions': <String>[]},
            handler: (_, fn, args) => fn == 'trend.suggest'
                ? {
                    'suggestions': [
                      {'text': '写真', 'reason': '「打上会」と一緒によく使われます'},
                      {'text': '反省会', 'reason': '「打上会」と一緒によく使われます'},
                      {'text': '雑談', 'reason': '定番のタグ'},
                    ],
                  }
                : null,
          ),
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(slotPluginsProvider.notifier).register('store:sample.trend', bytes: Uint8List.fromList('trend'.codeUnits));
    // 開いたときのタブ(テストの SNS はソーシャル)に、トレンドプラグインのノードを置く: トレンドを取得 → Today → 本体の TL。
    const cfg = TlConfig(sources: [
      TlSourceComponent(tl: '${trendPluginKindPrefix}sample.trend', form: TrendNodeForm.tiles, limit: 3),
      TlSourceComponent(tl: '${trendPluginKindPrefix}sample.trend', form: TrendNodeForm.today, limit: 2),
      TlSourceComponent(tl: 'social'),
    ]);
    await c.read(settingsAreaProvider(nodeprogAreaFor(key, 'tl.social')).notifier).set('tlcfg', jsonEncode(cfg.toJson()));
    await tester.pumpAndSettle();
    return c;
  }

  for (final (name, size) in [('phone', const Size(1080, 2340)), ('wide', const Size(2400, 1600))]) {
    testWidgets('after: $name', (tester) async {
      await pump(tester, size);
      await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_nodes_${name}_home.png'));
      await tester.tap(find.byTooltip('検索').first);
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_nodes_${name}_search.png'));
      await tester.tap(find.byTooltip('トレンド設定').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('トレンドの指向性/刺激性'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_nodes_${name}_tendency.png'));
    });
  }
}
