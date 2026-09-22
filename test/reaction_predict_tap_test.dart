import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// リアクションの短押し (D-278): 付けられる予測が無いときは、既定の絵文字(👍)を付けずに、ピッカーを開く。
void main() {
  Future<FakeSnsPlugin> pump(WidgetTester tester, Map<String, int> reactions, {Set<String> localEmojis = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final plugin = FakeSnsPlugin(localEmojis: localEmojis, posts: (viewer) => [Post(id: 'n1', account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: 'こんにちは', reactions: reactions)]);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return plugin;
  }

  List<String?> sent(FakeSnsPlugin p) => [for (final s in p.opened) ...s.reactionsSent];

  testWidgets('だれも付けていなくて履歴も無い → ピッカーが開く(何も送らない)', (tester) async {
    final plugin = await pump(tester, const {});
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsOneWidget);
    expect(sent(plugin), isEmpty);
  });

  testWidgets('予測が他サーバーの絵文字で、同じ名前が自サーバーに無い → ピッカーが開く', (tester) async {
    final plugin = await pump(tester, const {':blob@other.example:': 5});
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsOneWidget);
    expect(sent(plugin), isEmpty);
  });

  testWidgets('予測が他サーバーの絵文字でも、同じ名前が自サーバーにあれば、それを付ける', (tester) async {
    final plugin = await pump(tester, const {':blob@other.example:': 5}, localEmojis: {'blob'});
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsNothing);
    expect(sent(plugin), [':blob:']);
  });

  testWidgets('Unicode の予測は、そのまま付ける', (tester) async {
    final plugin = await pump(tester, const {'🎉': 4});
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(sent(plugin), ['🎉']);
  });

  testWidgets('リアクション済みのボタン / 自分のチップを押すと、確認なしで取り消す。スレッドを開いて戻っても、済みの表示のまま (D-281)', (tester) async {
    final plugin = await pump(tester, const {'🎉': 4});
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(sent(plugin), ['🎉']);
    List<String> performed() => [for (final s in plugin.opened) ...s.performed];
    // スレッドを開いて戻る: 状態が「未リアクション」で上書きされない(ボタンを押すと、付け直しではなく取り消しになる)。
    await tester.tap(find.text('こんにちは').first);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsNothing);
    expect(performed().last, 'reaction:n1:true');
    expect(sent(plugin), ['🎉'], reason: '付け直していない');
    // もう一度付けてから、自分のチップで取り消す。
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqReactionChips), matching: find.text('🎉')).first);
    await tester.pumpAndSettle();
    expect(performed().last, 'reaction:n1:true');
  });

  testWidgets('ピッカーを開いている間に TL へ投稿が足されても、押した投稿にリアクションする (D-282)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    Post make(AccountId viewer, String id, String body) => Post(id: id, account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: body);
    final plugin = FakeSnsPlugin(localEmojis: const {}, posts: (viewer) => [make(viewer, 'old', 'もとの投稿')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    // だれも付けていない → 短押しでピッカーが開く。
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsOneWidget);
    // 開いている間に、上へ新しい投稿が足される。
    for (final session in plugin.opened) {
      session.prepend(make(session.account, 'new', 'あとから来た投稿'));
    }
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    // 表示中の TL がどれでも、取り直す。
    for (final kind in const [TimelineKind.home, TimelineKind.social, TimelineKind.bundle]) {
      await c.read(timelineProvider(kind).notifier).refresh();
    }
    await tester.pumpAndSettle();
    // 新しい投稿は、見ている位置を動かさずに**上へ**足される (D-298)。一覧には入っている。
    expect([for (final kind in const [TimelineKind.home, TimelineKind.social, TimelineKind.bundle]) c.read(timelineProvider(kind)).value?.posts.firstOrNull?.id].contains('new'), isTrue);
    // 絵文字を選ぶ → もとの投稿に付く。
    await tester.tap(find.descendant(of: find.byType(EmojiPanel), matching: find.text('👍')).first);
    await tester.pumpAndSettle();
    expect([for (final s in plugin.opened) ...s.performed], ['reaction:old:false']);
  });
}
