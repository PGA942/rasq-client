import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/home/reaction_mode.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 絵文字リアクションの仕組みが無い投稿 (D-321): ⭐ と数の角丸のチップも、リアクションのピッカーも出さない。数はいいねのボタンに。
/// Misskey でも「いいねのみ」のノートは同じ(ボタンは ❤ で、押すと ❤ を付ける)。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  UserSummary author(String instance) => UserSummary(id: 'u1', account: AccountId(kind: SnsKind.misskey, instance: instance, handle: 'hanako'), displayName: 'ハナコ');
  Post note({String? acceptance, String instance = 'example.test'}) => Post(id: 'n1', account: viewer, author: author(instance), createdAt: DateTime(2026, 9, 25), body: 'b', reactionAcceptance: acceptance);
  const misskeyReaction = ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'リアクション', iconPerPost: true);
  const mastodonFavourite = ActionDescriptor(id: 'favourite', genreTag: 'Reaction', label: 'お気に入り', icon: 'star_border', doneIcon: 'star');

  group('reactionModeOf', () {
    test('絵文字でリアクションできるか = Reaction の宣言の iconPerPost(プラグイン名では決めない)', () {
      expect(reactionModeOf(note(), misskeyReaction), PostReactionMode.emoji);
      expect(reactionModeOf(note(), mastodonFavourite), PostReactionMode.like);
      // 宣言が見つからない面(アクションを持たない)は、これまでどおり。
      expect(reactionModeOf(note(), null), PostReactionMode.emoji);
    });

    test('Misskey の reactionAcceptance: likeOnly はいつでも、…ForRemote は投稿のサーバーの外から見ているときだけ、いいねのみ', () {
      expect(reactionModeOf(note(acceptance: 'likeOnly'), misskeyReaction), PostReactionMode.likeOnly);
      expect(reactionModeOf(note(acceptance: 'likeOnlyForRemote'), misskeyReaction), PostReactionMode.emoji);
      expect(reactionModeOf(note(acceptance: 'likeOnlyForRemote', instance: 'other.example'), misskeyReaction), PostReactionMode.likeOnly);
      expect(reactionModeOf(note(acceptance: 'nonSensitiveOnlyForLocalLikeOnlyForRemote', instance: 'other.example'), misskeyReaction), PostReactionMode.likeOnly);
      expect(reactionModeOf(note(acceptance: 'nonSensitiveOnly'), misskeyReaction), PostReactionMode.emoji);
      // 絵文字の仕組みが無い SNS は、受け方に関係なくいいね。
      expect(reactionModeOf(note(acceptance: 'likeOnly'), mastodonFavourite), PostReactionMode.like);
    });

    test('reactionAcceptance は Post ワイヤで行き来する(プラグインが載せれば効く)', () {
      final p = SnsWire.postFrom({'id': 'n1', 'author': SnsWire.user(author('example.test')), 'createdAt': '2026-09-25T00:00:00Z', 'body': '', 'reactionAcceptance': 'likeOnly'}, account: viewer);
      expect(p.reactionAcceptance, 'likeOnly');
      expect(SnsWire.post(p)['reactionAcceptance'], 'likeOnly');
    });
  });

  group('投稿の行', () {
    Future<FakeSnsPlugin> pump(WidgetTester tester, {required Set<String>? localEmojis, SnsKind kind = SnsKind.misskey, String reactionActionId = 'reaction', Map<String, int> reactions = const {}, Map<String, int> counts = const {}, String? acceptance}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final plugin = FakeSnsPlugin(
        kind: kind,
        localEmojis: localEmojis,
        reactionActionId: reactionActionId,
        posts: (v) => [Post(id: 'n1', account: v, author: author(v.instance), createdAt: DateTime.now(), body: 'こんにちは', reactions: reactions, counts: counts, reactionAcceptance: acceptance)],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return plugin;
    }

    RasqActionBarItem reactionButton(WidgetTester tester, {String id = 'reaction'}) => tester.widget<RasqActionBar>(find.byType(RasqActionBar).first).items.firstWhere((i) => i.id == id);
    List<String?> sent(FakeSnsPlugin p) => [for (final s in p.opened) ...s.reactionsSent];

    testWidgets('Misskey(ふつうのノート): チップが出て、長押しですぐ選べる絵文字(D-512)→「その他」でピッカーが開く', (tester) async {
      await pump(tester, localEmojis: const {}, reactions: const {'🎉': 3});
      expect(find.byType(RasqReactionChips), findsWidgets);
      expect(reactionButton(tester).label, 'リアクション');
      await tester.longPress(find.byTooltip('リアクション').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quickEmoji.more')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quickEmoji.more')));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsOneWidget);
    });

    testWidgets('Misskey の「いいねのみ」: チップもピッカーも出さず、❤ のボタンに数。押すと ❤ を付ける', (tester) async {
      final plugin = await pump(tester, localEmojis: const {}, reactions: const {'❤': 4}, counts: const {'reaction': 4}, acceptance: 'likeOnly');
      expect(find.byType(RasqReactionChips), findsNothing);
      final b = reactionButton(tester);
      expect((b.label, b.icon, b.count, b.showCount, b.iconText, b.mutedIcon), ('いいね', Icons.favorite_border, 4, true, null, false));
      await tester.longPress(find.byTooltip('いいね').first);
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsNothing);
      await tester.tap(find.byTooltip('いいね').first);
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsNothing);
      expect(sent(plugin), [likeOnlyReaction]);
    });

    testWidgets('絵文字の仕組みが無い SNS(Bluesky の ⭐): チップを出さず、数はいいねのボタンに。長押し / 短押しでピッカーを開かない', (tester) async {
      final plugin = await pump(tester, localEmojis: null, kind: SnsKind.bluesky, reactions: const {'⭐': 5});
      expect(find.byType(RasqReactionChips), findsNothing);
      final b = reactionButton(tester);
      expect((b.count, b.showCount, b.iconText, b.mutedIcon), (5, true, null, false));
      await tester.longPress(find.byTooltip('リアクション').first);
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsNothing);
      await tester.tap(find.byTooltip('リアクション').first);
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsNothing);
      // 絵文字は添えない(SNS のいいねをそのまま入り切り)。
      expect(sent(plugin), [null]);
    });

    testWidgets('絵文字の仕組みが無い SNS(Mastodon のお気に入り。チップの元が無い): 数はプラグインの reaction 欄から', (tester) async {
      // ボタンの id(favourite)の数は無く、お気に入り数は reaction 欄に来る(mastodon-wasm の規約)。
      await pump(tester, localEmojis: null, kind: SnsKind.mastodon, reactionActionId: 'favourite', counts: const {'reply': 1, 'reaction': 7});
      expect(find.byType(RasqReactionChips), findsNothing);
      expect(reactionButton(tester, id: 'favourite').count, 7);
    });
  });
}
