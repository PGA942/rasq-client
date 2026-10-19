// 描画確認ハーネス (D-514): ユーザーページの選んでいるタブにつながった並べ替え・絞り込みのパネルを PNG に(明るい / 暗い)。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/user_tab_view_preview_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
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
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const alice = UserSummary(id: 'u-alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス', bio: '宇宙とカレーが好き');
  const bob = UserSummary(id: 'u-bob', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ');
  Post post(String id, String body, {int day = 1, Map<String, int> reactions = const {}, UserSummary? repostedBy}) =>
      Post(id: id, account: acc, author: alice, createdAt: DateTime(2026, 10, day, 9), body: body, reactions: reactions, repostedBy: repostedBy);
  final posts = [
    post('a1', '今日の晩ごはんはカレー。スパイスを3種類足してみた', day: 9, reactions: {'👍': 1}),
    post('a2', 'ふざけるな、許せない。むかつく', day: 8, reactions: {'👍': 5}),
    post('a3', 'リノートされた投稿', day: 7, repostedBy: bob),
    post('a4', 'ロケットの打ち上げを見た！明日も楽しみ', day: 6, reactions: {'🚀': 12}),
    for (var i = 0; i < 12; i++) post('b$i', '日記 $i: 散歩して本を読んだ', day: 5, reactions: {'👍': i % 3}),
  ];

  for (final dark in [false, true]) {
    testWidgets('ユーザーページのタブのパネル (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        'userPageTabs.v1': jsonEncode({
          'posts': {'sort': 'reactions', 'renotes': false, 'stimulus': {'anger': 0.35, 'disgust': 0.5, 'fear': 0.6}, 'directionality': 0.7},
        }),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts));
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push('/user/${alice.id}', extra: alice);
      await tester.pumpAndSettle();
      if (dark) {
        // 暗いほうは、ヘッダーを畳んでタブがいちばん上に留まった形。
        await tester.drag(find.byType(PostRow).first, const Offset(0, -900));
        await tester.pumpAndSettle();
      }
      await expectLater(find.byType(RasqApp), matchesGoldenFile('user_tab_view_list_${dark ? 'dark' : 'light'}.png'));
      final tab = find.descendant(of: find.byType(TabBar), matching: find.text('ノート'));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      if (dark) {
        // 一覧が下へ進んでいたら 1 回目はいちばん上へ。もう一度でパネル。
        await tester.tap(tab);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(const ValueKey('user.tabView.search')), dark ? '' : '日記');
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile('user_tab_view_panel_${dark ? 'dark' : 'light'}.png'));
    });
  }
}
