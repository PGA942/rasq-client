// 描画確認ハーネス (D-140): 実フォントで VC ホーム / FOW を PNG に出す。
// `flutter test` の既定対象(test/)には入れない。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/vc_preview_test.dart --update-goldens
// → tool/preview/*.png(git には入れない)。フォント未指定ならスキップ。
// テストの既定フォント(Ahem)では日本語が □ になり、実機の崩れが見えないため。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
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
    // テストの既定ファミリー(Roboto)へ実フォントを差し込む → 全テキストに効く。
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
  }

  testWidgets('vc home', (tester) async {
    await pump(tester);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_home.png'));
  });

  testWidgets('preview + room fow', (tester) async {
    await pump(tester);
    await tester.tap(find.text('見てみる').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_preview.png'));
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こんばんは');
    await tester.tap(find.byTooltip('共有する'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room.png'));
  });

  testWidgets('create fow', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('VC を作成'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_create.png'));
  });
}
