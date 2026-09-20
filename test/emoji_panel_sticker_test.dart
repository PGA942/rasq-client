import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 絵文字ピッカーをステッカーのピッカーとして使う (D-273: RASQ の投稿のキュー)。
void main() {
  testWidgets('パックごとの一覧 / 本文と既存のキューからの予測 / 検索 / 選ぶと key が返る。絵文字(デフォルト / サーバー)は出ない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('rasq-d273');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = File('${dir.path}/a.png')..writeAsBytesSync(const [0x89, 0x50, 0x4E, 0x47]);
    EmojiPanelSticker s(String pack, String id, String label, [List<String> tags = const []]) => EmojiPanelSticker(key: '$pack|$id', group: pack == 'a' ? 'どうぶつ' : 'きごう', label: label, tags: tags, file: png.path);
    final picked = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry())],
      child: MaterialApp(
        home: Scaffold(
          body: EmojiPanel(
            onPick: picked.add,
            predictionContext: 'うちのねこが寝ている',
            existingReactions: const {'b|star': 3},
            stickers: [s('a', 'cat', 'ねこ', ['猫']), s('a', 'dog', 'いぬ'), s('b', 'star', 'ほし'), s('b', 'heart', 'ハート')],
          ),
        ),
      ),
    ));
    await tester.pump();
    // パックごと(2 つあるので見出しが出る)。絵文字の欄は出ない。
    expect(find.text('・どうぶつ'), findsOneWidget);
    expect(find.text('・きごう'), findsOneWidget);
    expect(find.text('デフォルト'), findsNothing);
    expect(find.text('サーバー'), findsNothing);
    // 予測: 本文に「ねこ」→ ねこ、既に付いている → ほし。
    expect(find.text('予測'), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji.sticker.a|cat')), findsNWidgets(2)); // 予測 + パック
    expect(find.byKey(const ValueKey('emoji.sticker.b|star')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('emoji.sticker.a|dog')), findsOneWidget);
    // 検索: ラベル / タグ / パック名。
    await tester.enterText(find.byType(TextField), '猫');
    await tester.pump();
    expect(find.text('検索結果'), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji.sticker.a|cat')), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji.sticker.b|star')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('emoji.sticker.a|cat')));
    await tester.pump();
    expect(picked, ['a|cat']);
  });
}
