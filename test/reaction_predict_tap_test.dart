import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
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
}
