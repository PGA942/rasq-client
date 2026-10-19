// 描画確認ハーネス (D-474 / D-475 / D-477): コンポーザーのアクションバーのテキスト加工プラグインのボタン・ボタンにつながったパネル・# の補完を PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/composer_actionbar_preview_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
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
    // アイコンも描く(無いと □ になる)。flutter test は FLUTTER_ROOT を渡す。
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', '今日は #打ち上げ と #打上会'), post('p2', '#打楽器 の練習')]));
    final fakes = <String, FakeSlotRuntime Function()>{
      'text': () => FakeSlotRuntime(
            manifest: {
              'id': 'sample.composer-text', 'name': 'ハッシュタグ候補', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.text'], 'permissions': ['fow.widget'],
              'actions': [{'id': 'tags', 'slot': 'composer.text', 'label': 'ハッシュタグ候補', 'icon': 'tag', 'tags': ['Text']}],
            },
            handler: (self, fn, args) => fn == 'text.changed' ? {} : null,
          ),
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(slotPluginsProvider.notifier).register('fake:text', bytes: Uint8List.fromList('text'.codeUnits));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('コンポーザー: アクションバーのプラグインのボタン + # の補完 / 長押しのつながったパネル', (tester) async {
    await pump(tester);
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    // バーは横にスクロールする: プラグインのボタン(絵文字の隣)が見えるところまで送る。
    await tester.ensureVisible(find.byKey(const ValueKey('composer.textPlugin.sample.composer-text')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('composer.input')), '花火大会おつかれさま！ #打');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('composer_actionbar_hashtags.png'));
    await tester.longPress(find.byKey(const ValueKey('composer.textPlugin.sample.composer-text')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('composer_actionbar_tethered_panel.png'));
  });

  testWidgets('つながったパネル単体: 下に開く(スケッチのとおり)/ 上に開く / 画面の端のボタン', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget panel(String title, Rect anchor, TetherSide side, IconData icon) => TetheredPanel(
          anchor: anchor,
          preferredSide: side,
          width: 300,
          anchorChild: Icon(icon, size: 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 40, child: Row(children: [TextButton(onPressed: () {}, child: const Text('キャンセル')), Expanded(child: Center(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)))), TextButton(onPressed: () {}, child: const Text('OK'))])),
            const RasqSwitchListTile(title: 'このコンポーザーでオン', value: true),
            Center(child: Container(margin: const EdgeInsets.only(top: 6, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
          ]),
        );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3D7BFF)),
      home: Scaffold(
        body: Stack(children: [
          for (final r in [const Rect.fromLTWH(158, 40, 44, 44), const Rect.fromLTWH(30, 720, 44, 44), const Rect.fromLTWH(312, 260, 44, 44)])
            Positioned.fromRect(rect: r, child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x22000000)))),
          Positioned.fill(child: panel('下に開く', const Rect.fromLTWH(158, 40, 44, 44), TetherSide.below, Icons.tag)),
          Positioned.fill(child: panel('上に開く', const Rect.fromLTWH(30, 720, 44, 44), TetherSide.above, Icons.emoji_emotions_outlined)),
          Positioned.fill(child: panel('端のボタン', const Rect.fromLTWH(312, 260, 44, 44), TetherSide.below, Icons.photo_camera_outlined)),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('tethered_panel_shapes.png'));
  });

  // 1 つずつ大きめに(首の形を詰めるとき用。D-477)。
  for (final (name, anchor, side, icon) in [
    ('below', const Rect.fromLTWH(158, 30, 44, 44), TetherSide.below, Icons.tag),
    ('edge', const Rect.fromLTWH(312, 30, 44, 44), TetherSide.below, Icons.photo_camera_outlined),
    ('above', const Rect.fromLTWH(30, 186, 44, 44), TetherSide.above, Icons.emoji_emotions_outlined),
  ]) {
    testWidgets('つながったパネル単体(拡大): $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 720);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3D7BFF)),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: TetheredPanel(
            anchor: anchor,
            preferredSide: side,
            width: 300,
            anchorChild: Icon(icon, size: 20),
            child: const SizedBox(height: 120, child: Center(child: Text('中身'))),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('tethered_panel_$name.png'));
    });
  }
}
