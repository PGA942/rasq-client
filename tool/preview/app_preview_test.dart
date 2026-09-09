// 描画確認用 (D-153〜D-156)。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/app_preview_test.dart --update-goldens
// ignore_for_file: avoid_print
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
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const quotedAcc = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'spacequant');
  MediaItem img(int i) => MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://picsum.photos/seed/rrl$i/400/300'), thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl$i/200/150'));
  final quoted = Post(id: 'q1', account: acc, author: const UserSummary(id: 'u-q', account: quotedAcc, displayName: 'SpaceQuant Barbados'), createdAt: DateTime(2026, 9, 8), body: 'Barbados III has been successfully placed into Earth orbit. Good job @Stratolaunch', media: [for (var i = 0; i < 5; i++) img(i)]);
  final posts = [
    Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'ダグラス'), createdAt: DateTime(2026, 9, 9, 20), body: 'ロケット発射おめでとう！ #打上会 #宇宙', quote: quoted),
    Post(id: 'p2', account: acc, author: const UserSummary(id: 'u2', account: acc, displayName: '山ハヤ'), createdAt: DateTime(2026, 9, 9, 19), body: '今日の晩ごはんはカレー #料理'),
    Post(id: 'p3', account: acc, author: const UserSummary(id: 'u3', account: acc, displayName: 'TiVard'), createdAt: DateTime(2026, 9, 9, 18), body: '打ち上げ中継 #打上会', media: [img(1)]),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('trend profile sheet / tendency fow / genre pick', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('トレンド設定'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_profile_sheet.png'));
    await tester.tap(find.text('トレンドの指向性/刺激性'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pumpAndSettle();
    final radar = find.byKey(const Key('trend.stimulus.radar'));
    await tester.tapAt(tester.getCenter(radar) + const Offset(0, -40)); // 喜び
    await tester.tapAt(tester.getCenter(radar) + const Offset(-30, -30)); // 期待(左上)
    await tester.tapAt(tester.getCenter(radar) + const Offset(20, 24)); // 悲しみ/嫌悪あたり
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_tendency_fow.png'));
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ジャンルを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'ジャンル/キーワードを追加'), '#宇宙');
    await tester.tap(find.byTooltip('ジャンルを追加'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_genre_fow.png'));
    await tester.tap(find.text('最近のアクションから好きなものを選択'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('trend_genre_pick.png'));
  });

  testWidgets('thread with inline frame quote / reactions header', (tester) async {
    await pump(tester);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_quote_tl.png'));
    await tester.tap(find.text('ロケット発射おめでとう！ #打上会 #宇宙'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('thread_inline_frame.png'));
    await tester.tap(find.text('リアクションを表示'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('reactions_inline_frame.png'));
  });
}
