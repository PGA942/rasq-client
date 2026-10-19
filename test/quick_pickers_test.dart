import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/compose/quick_emoji_picker.dart';
import 'package:rasq_client/features/home/reaction_history.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-512: 長押しして滑らせて選ぶ(リアクションのすぐ選べる絵文字 / リノートのバンドル / コンポーザーの絵文字)と、その設定。
/// D-513: ボタンから開く FOW(バンドル / 共有 / 「…」)はボタンにつながった形。
void main() {
  late FakeSnsPlugin plugin;
  late MemorySessionStorage storage;

  Future<void> pump(WidgetTester tester, {Map<String, Object?> extra = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      for (final e in extra.entries) e.key: jsonEncode(e.value),
    });
    plugin = FakeSnsPlugin(localEmojis: const {}, posts: (viewer) => [Post(id: 'n1', account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: 'こんにちは')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  List<String?> sent() => [for (final s in plugin.opened) ...s.reactionsSent];
  List<String> performed() => [for (final s in plugin.opened) ...s.performed];

  /// ボタンを長押しして、離さずにいる(パネルが開いたところで止める)。
  Future<TestGesture> hold(WidgetTester tester, Finder button) async {
    final g = await tester.startGesture(tester.getCenter(button));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    return g;
  }

  String headerText(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(ValueKey('$id.header.text'))).data!;

  group('リアクションの長押し: すぐ選べる絵文字 (D-512)', () {
    testWidgets('長押しでボタンにつながったパネル(検索欄なし)。滑らせると見出しに :名前:、離した絵文字でリアクション', (tester) async {
      await pump(tester);
      final g = await hold(tester, find.byTooltip('リアクション').first);
      expect(find.byType(TetheredPanel), findsOneWidget);
      expect(find.byType(EmojiPanel), findsNothing, reason: 'ピッカー全体(検索欄つき)ではない');
      expect(find.byKey(const ValueKey('quickEmoji.👍')), findsOneWidget, reason: '既定のプリセット');
      expect(find.byKey(const ValueKey('quickEmoji.more')), findsOneWidget);
      final id = find.byType(HoldSlidePicker<String>);
      final pickerId = (tester.widget<HoldSlidePicker<String>>(id)).idPrefix;
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.🎉'))));
      await tester.pump();
      expect(headerText(tester, pickerId), ':tada:');
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.👀'))));
      await tester.pump();
      expect(headerText(tester, pickerId), ':eyes:');
      await g.up();
      await tester.pumpAndSettle();
      expect(sent(), ['👀']);
      expect(find.byType(TetheredPanel), findsNothing);
    });

    testWidgets('滑らせて外で離すと何もしない / 滑らせずに離すと開いたまま →「その他」でピッカー全体', (tester) async {
      await pump(tester);
      var g = await hold(tester, find.byTooltip('リアクション').first);
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('quickEmoji.🎉'))));
      await tester.pump();
      await g.moveTo(const Offset(20, 760));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(sent(), isEmpty);
      expect(find.byType(TetheredPanel), findsNothing);

      g = await hold(tester, find.byTooltip('リアクション').first);
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byType(TetheredPanel), findsOneWidget, reason: '滑らせずに離したら開いたまま(タップで選べる)');
      await tester.tap(find.byKey(const ValueKey('quickEmoji.more')));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsOneWidget);
      expect(sent(), isEmpty);
    });

    testWidgets('設定のプリセットが先頭に並び、最近使った絵文字が続く。設定は保存される', (tester) async {
      await pump(tester, extra: {
        'plugins.reaction.v1': {
          quickEmojisSettingsKey: ['🍣', '🐱'],
        },
      });
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      expect(c.read(quickEmojisProvider), ['🍣', '🐱']);
      await c.read(reactionHistoryProvider.notifier).record('🚀');
      var g = await hold(tester, find.byTooltip('リアクション').first);
      expect(find.byKey(const ValueKey('quickEmoji.👍')), findsNothing, reason: '既定は使わない');
      final xs = [for (final k in ['🍣', '🐱', '🚀']) tester.getCenter(find.byKey(ValueKey('quickEmoji.$k'))).dx];
      expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue, reason: 'プリセット → 最近使ったもの');
      await g.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quickEmoji.🐱')));
      await tester.pumpAndSettle();
      expect(sent(), ['🐱']);

      // 書くと KV に残る(読み直しても同じ)。null で既定に戻る。
      await c.read(settingsAreaProvider(reactionSettingsArea).notifier).set(quickEmojisSettingsKey, ['🔥']);
      final raw = jsonDecode((await storage.read('plugins.reaction.v1'))!) as Map;
      expect(raw[quickEmojisSettingsKey], ['🔥']);
      expect(c.read(quickEmojisProvider), ['🔥']);
      await c.read(settingsAreaProvider(reactionSettingsArea).notifier).set(quickEmojisSettingsKey, null);
      expect(c.read(quickEmojisProvider), defaultQuickEmojis);
      g = await hold(tester, find.byTooltip('リアクション').first);
      expect(find.byKey(const ValueKey('quickEmoji.👍')), findsOneWidget);
      await g.up();
    });

    test('候補: プリセット → 最近 → 履歴の多い順。重複なし、使えないカスタム絵文字は落とす', () {
      final out = quickEmojiCandidates(
        presets: ['👍', ':blob:', ':nope:'],
        recent: ['🎉', '👍'],
        history: {'🍣': 1, '🚀': 5},
        custom: [EmojiInfo(name: 'blob', url: Uri.parse('https://example.test/blob.png'))],
      );
      expect(out, ['👍', ':blob:', '🎉', '🚀', '🍣']);
      expect(quickEmojiCandidates(presets: [':blob:'], recent: const [], history: const {}, custom: null), isEmpty, reason: '一覧が読めていなければカスタム絵文字は出さない');
      expect(emojiShortName(':blob@other.example:'), ':blob:');
      expect(emojiShortName('❤️'), ':heart:');
      expect(emojiShortName('🫠'), '🫠');
    });
  });

  group('リノートの長押し: バンドルを滑らせて選ぶ (D-512)', () {
    testWidgets('長押し → 滑らせて「リノート」で離すとリノート。見出しは指の下の操作の名前', (tester) async {
      await pump(tester);
      final g = await hold(tester, find.byTooltip('リノート').first);
      expect(find.byType(TetheredPanel), findsOneWidget);
      final pickerId = tester.widget<HoldSlidePicker<String>>(find.byType(HoldSlidePicker<String>)).idPrefix;
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('actionbar.bundle.pick.quote'))));
      await tester.pump();
      expect(headerText(tester, pickerId), '引用ノート');
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('actionbar.bundle.pick.renote'))));
      await tester.pump();
      expect(headerText(tester, pickerId), 'リノート');
      await g.up();
      await tester.pumpAndSettle();
      expect(performed().where((p) => p.startsWith('renote:n1')), hasLength(1));
      expect(find.byType(TetheredPanel), findsNothing);
    });

    testWidgets('長押し → 「引用ノート」で離すと引用のコンポーザー', (tester) async {
      await pump(tester);
      final g = await hold(tester, find.byTooltip('リノート').first);
      await g.moveTo(tester.getCenter(find.byKey(const ValueKey('actionbar.bundle.pick.quote'))));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('引用'), findsOneWidget);
    });
  });

  group('ボタンにつながった FOW (D-513)', () {
    testWidgets('リノート(タップ)/ 共有 / 「…」は、ボタンにつながった形で開き、中身はそのまま', (tester) async {
      await pump(tester);
      Future<void> expectTethered(Finder button, Finder inside) async {
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(TetheredPanel), findsOneWidget);
        expect(inside, findsOneWidget);
        final panel = tester.getRect(find.byKey(kTetherPanelKey));
        final b = tester.getCenter(button);
        // ボタンのすぐ下(上)に、ボタンの真ん中に寄せて置かれる。
        expect(panel.top > b.dy || panel.bottom < b.dy, isTrue);
        expect(panel.left <= b.dx && b.dx <= panel.right, isTrue);
        // 首(元のボタン)を押すと閉じる。
        await tester.tap(find.byKey(const ValueKey('rasqOverlay.tether.hit')));
        await tester.pumpAndSettle();
        expect(find.byType(TetheredPanel), findsNothing);
      }

      await expectTethered(find.byTooltip('リノート').first, find.byKey(const ValueKey('actionbar.bundle.pick.renote')));
      await expectTethered(find.byTooltip('共有').first, find.byKey(const ValueKey('post.share.copyLink')));
      await expectTethered(find.byTooltip('メニュー').first, find.text('リンクをコピー'));
    });

    testWidgets('コンポーザーの絵文字のボタン: 長押しで上に開き、滑らせて離した絵文字を入れる', (tester) async {
      await pump(tester);
      await openHomeComposer(tester);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('composer.tool.emoji'));
      final g = await hold(tester, button);
      expect(find.byType(TetheredPanel), findsOneWidget);
      final cell = find.byKey(const ValueKey('quickEmoji.🎉'));
      expect(tester.getCenter(cell).dy, lessThan(tester.getCenter(button).dy), reason: 'バーは下なので上に開く');
      await g.moveTo(tester.getCenter(cell));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byType(TetheredPanel), findsNothing);
      final input = tester.widget<TextField>(find.byKey(const ValueKey('composer.input')));
      expect(input.controller!.text, contains('🎉'));
    });
  });
}
