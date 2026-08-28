import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/compose_providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

void main() {
  testWidgets('ピッカー: サーバー絵文字はジャンル毎に省略表示、∨ で展開 (D-043)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final emojis = [
      for (var i = 0; i < 20; i++) EmojiInfo(name: 'a$i', url: Uri.parse('https://e/a$i.webp'), category: 'ジャンルA'),
      for (var i = 0; i < 3; i++) EmojiInfo(name: 'b$i', url: Uri.parse('https://e/b$i.webp'), category: 'ジャンルB'),
      EmojiInfo(name: 'c0', url: Uri.parse('https://e/c0.webp')),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        customEmojisProvider.overrideWith((ref) async => emojis),
      ],
      child: MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: EmojiPanel(onPick: (_) {}, height: 1100))),
    ));
    await tester.pumpAndSettle();

    // セクション見出しとジャンル行(カテゴリ無しは「その他」)。
    expect(find.text('デフォルト'), findsOneWidget);
    expect(find.text('サーバー'), findsOneWidget);
    expect(find.textContaining('ジャンルA'), findsOneWidget);
    expect(find.textContaining('ジャンルB'), findsOneWidget);
    expect(find.textContaining('その他'), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // ジャンルA の件数

    // 折りたたみ時は先頭 collapsedCount(12)件だけ → 展開で増える。
    final genreA = find.textContaining('ジャンルA');
    final before = tester.widgetList(find.byType(RasqCustomEmoji)).length;
    await tester.tap(genreA);
    await tester.pumpAndSettle();
    final after = tester.widgetList(find.byType(RasqCustomEmoji)).length;
    expect(after, greaterThan(before));

    // もう一度タップで折りたたみに戻る。
    await tester.tap(genreA);
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(RasqCustomEmoji)).length, before);
  });
}
