// 描画確認ハーネス (D-517 / D-518): FOW のフッター(ノートの表示 / 共有)、リアクションのボタンから出る絵文字ピッカー全体、
// トレンドの指向性 / 刺激性(狭い / 広い)と、見た目を揃える元の「このタイムラインから探す」を PNG に(明るい / 暗い)。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/noteview_footer_preview_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
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
      await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  const alice = UserSummary(id: 'u-alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス', bio: '宇宙とカレーが好き');
  const bob = UserSummary(id: 'u-bob', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ');
  Post post(AccountId viewer, String id, String body, {int day = 1, Map<String, int> reactions = const {}, UserSummary? repostedBy, UserSummary author = alice}) =>
      Post(id: id, account: viewer, author: author, createdAt: DateTime(2026, 10, day, 9), body: body, reactions: reactions, repostedBy: repostedBy);
  List<Post> posts(AccountId viewer) => [
        post(viewer, 'a1', '今日の晩ごはんはカレー。スパイスを3種類足してみた', day: 9, reactions: {'👍': 1}),
        post(viewer, 'a2', 'ふざけるな、許せない。むかつく', day: 8, reactions: {'👍': 5}),
        post(viewer, 'a3', 'リノートされた投稿', day: 7, repostedBy: bob),
        post(viewer, 'a4', 'ロケットの打ち上げを見た！明日も楽しみ', day: 6, reactions: {'🚀': 12}),
        for (var i = 0; i < 12; i++) post(viewer, 'b$i', '日記 $i: 散歩して本を読んだ', day: 5, reactions: {'👍': i % 3}),
      ];

  /// [size] = 論理の大きさ(dpr 3 / 2)。
  Future<ProviderContainer> pump(WidgetTester tester, {required bool dark, Size size = const Size(360, 780), Map<String, String> extra = const {}, List<Post> Function(AccountId)? timeline}) async {
    final dpr = size.width >= 600 ? 2.0 : 3.0;
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...extra,
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(localEmojis: const {}, posts: timeline ?? posts));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  final tag = Platform.environment['RASQ_PREVIEW_TAG'] ?? 'after';
  String name(String scene) => 'noteview_${tag}_$scene.png';

  // ── ノートの表示(ユーザーページのタブ)────────────────────────────
  for (final (label, dark, size) in [('phone_light', false, const Size(360, 780)), ('phone_dark', true, const Size(360, 780)), ('narrow_light', false, const Size(300, 720)), ('wide_light', false, const Size(900, 700)), ('wide_dark', true, const Size(900, 700))]) {
    testWidgets('ノートの表示 $label', (tester) async {
      final c = await pump(tester, dark: dark, size: size, extra: {
        'userPageTabs.v1': jsonEncode({
          'posts': {'sort': 'reactions', 'renotes': false, 'stimulus': {'anger': 0.35, 'disgust': 0.5, 'fear': 0.6}, 'directionality': 0.7},
        }),
      });
      c.read(routerProvider).push('/user/${alice.id}', extra: alice);
      await tester.pumpAndSettle();
      final tab = find.descendant(of: find.byType(TabBar), matching: find.text('ノート'));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile(name('userview_$label')));
    });
  }

  // ── 共有 ─────────────────────────────────────────────────────────
  for (final dark in [false, true]) {
    testWidgets('共有 ${dark ? 'dark' : 'light'}', (tester) async {
      await pump(tester, dark: dark);
      await tester.tap(find.byTooltip('共有').first);
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile(name('share_${dark ? 'dark' : 'light'}')));
    });
  }

  // ── 絵文字ピッカー全体(リアクションのボタン → 長押し → その他)───────────
  for (final dark in [false, true]) {
    testWidgets('リアクションのボタンから絵文字ピッカー ${dark ? 'dark' : 'light'}', (tester) async {
      await pump(tester, dark: dark, timeline: (v) => [
            Post(id: 'n1', account: v, author: MockData.douglas, createdAt: DateTime(2026, 10, 20, 9), body: '花火大会おつかれさまでした！写真はあとで上げます', reactions: const {'🎉': 3}),
            Post(id: 'n2', account: v, author: MockData.douglas, createdAt: DateTime(2026, 10, 20, 8), body: '明日の打ち上げは 19 時から'),
            Post(id: 'n3', account: v, author: MockData.douglas, createdAt: DateTime(2026, 10, 20, 7), body: '三つ目の投稿'),
          ]);
      final button = find.byTooltip('リアクション').first;
      final g = await tester.startGesture(tester.getCenter(button));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.more'))));
      await tester.pumpAndSettle();
      await g.up();
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile(name('emoji_more_${dark ? 'dark' : 'light'}')));
      if (!dark) {
        // 検索欄にフォーカス(キーボード 300px)。
        await tester.tap(find.descendant(of: find.byKey(const ValueKey('emoji.search')), matching: find.byType(TextField)));
        tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
        await tester.pumpAndSettle();
        await expectLater(find.byType(RasqApp), matchesGoldenFile(name('emoji_more_keyboard_light')));
        tester.view.resetViewInsets();
      }
    });
  }

  testWidgets('コンポーザーの絵文字のボタンから絵文字ピッカー light', (tester) async {
    await pump(tester, dark: false);
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('composer.tool.emoji')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer.tool.emoji')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile(name('emoji_composer_light')));
  });

  // ── トレンドの指向性 / 刺激性(狭い / 広い)────────────────────────
  for (final (label, dark, size) in [('narrow_light', false, const Size(360, 780)), ('narrow_dark', true, const Size(360, 780)), ('wide_light', false, const Size(900, 700))]) {
    testWidgets('トレンドの指向性 / 刺激性 $label', (tester) async {
      await pump(tester, dark: dark, size: size);
      await tester.tap(find.byTooltip('検索').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('トレンド設定').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('トレンドの指向性/刺激性'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(RasqApp), matchesGoldenFile(name('tendency_$label')));
    });
  }

  // ── 見た目を揃える元: このタイムラインから探す ─────────────────────────
  testWidgets('このタイムラインから探す light', (tester) async {
    await pump(tester, dark: false);
    final tab = find.descendant(of: find.byType(RasqTabs), matching: find.text('フォロー中'));
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile(name('tltemp_light')));
  });
}
