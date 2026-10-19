// 描画確認ハーネス (D-512 / D-513): 長押しして滑らせて選ぶパネル(途中の指の下が光っているところ)と、ボタンにつながった形にした FOW を PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf [RASQ_PREVIEW_EMOJI_FONT=/path/to/NotoColorEmoji.ttf] \
//     flutter test tool/preview/longpress_preview_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fakes.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    final emojiPath = Platform.environment['RASQ_PREVIEW_EMOJI_FONT'];
    final emoji = emojiPath != null && File(emojiPath).existsSync() ? File(emojiPath).readAsBytesSync() : null;
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      // 絵文字のフォントを渡したときは、同じ家族に足す(テストの描画では家族の後のフォントが勝つので、日本語は □ になる。
      // 絵文字を見る用の PNG は名前の末尾に `_emoji`)。
      await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
      if (emoji != null) await (FontLoader(family)..addFont(Future.value(ByteData.view(emoji.buffer)))).load();
    }
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  Future<void> pump(WidgetTester tester, {required bool dark}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final plugin = FakeSnsPlugin(
      localEmojis: const {},
      posts: (viewer) => [
        Post(id: 'n1', account: viewer, author: MockData.douglas, createdAt: DateTime(2026, 10, 20, 9), body: '花火大会おつかれさまでした！写真はあとで上げます', reactions: const {'🎉': 3, '👍': 1}),
        Post(id: 'n2', account: viewer, author: MockData.douglas, createdAt: DateTime(2026, 10, 20, 8), body: '明日の打ち上げは 19 時から'),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<TestGesture> hold(WidgetTester tester, Finder button) async {
    final g = await tester.startGesture(tester.getCenter(button));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    return g;
  }

  final emojiRun = (Platform.environment['RASQ_PREVIEW_EMOJI_FONT'] ?? '').isNotEmpty;
  for (final dark in [false, true]) {
    final suffix = '${dark ? 'dark' : 'light'}${emojiRun ? '_emoji' : ''}';

    testWidgets('リアクションの長押し: すぐ選べる絵文字(指の下が光る)$suffix', (tester) async {
      await pump(tester, dark: dark);
      final g = await hold(tester, find.byTooltip('リアクション').first);
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.🎉'))));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('longpress_reaction_$suffix.png'));
      await g.moveTo(const Offset(10, 770));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('リノートの長押し: バンドルを滑らせて選ぶ $suffix', (tester) async {
      await pump(tester, dark: dark);
      final g = await hold(tester, find.byTooltip('リノート').first);
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('actionbar.bundle.pick.quote'))));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('longpress_repost_$suffix.png'));
      await g.moveTo(const Offset(10, 770));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('コンポーザーの絵文字のボタンの長押し(上に開く)$suffix', (tester) async {
      await pump(tester, dark: dark);
      await openHomeComposer(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('composer.tool.emoji')));
      await tester.pumpAndSettle();
      final g = await hold(tester, find.byKey(const ValueKey('composer.tool.emoji')));
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.🎉'))));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('longpress_composer_$suffix.png'));
      await g.moveTo(const Offset(10, 60));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('ボタンにつながった FOW: 共有 / 「…」$suffix', (tester) async {
      await pump(tester, dark: dark);
      await tester.tap(find.byTooltip('共有').first);
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('tethered_share_$suffix.png'));
      await tester.tap(find.byKey(const ValueKey('rasqOverlay.tether.hit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('メニュー').at(1));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('tethered_post_menu_$suffix.png'));
    });
  }
}
