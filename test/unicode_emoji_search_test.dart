import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/compose_providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/emoji/unicode_emoji_names.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

/// システムの絵文字を名前で探す (D-558)。
void main() {
  final names = UnicodeEmojiNames.fromGzip(File(unicodeEmojiNamesAsset).readAsBytesSync());

  test('索引は @misskey-dev/emoji-data 17.0.3 の 1915 個(並びは emojilist の順)、ライセンスを同梱', () {
    expect(names.entries.length, 1915);
    expect(names.entries.first.char, '😀');
    final cat = names.entries.firstWhere((e) => e.char == '🐱');
    expect(cat.name, 'cat');
    expect(cat.ja.first, 'ネコの顔');
    final licenses = File('assets/emoji/LICENSES.txt').readAsStringSync();
    expect(licenses, contains('UNICODE LICENSE V3'));
    expect(licenses, contains('Mu-An Chiou'));
    expect(File(unicodeEmojiNamesAsset).lengthSync(), lessThan(120 * 1024), reason: 'データは控えめに');
  });

  test('日本語(漢字 / カタカナ / ひらがな)・英語・ショートコードで引ける', () {
    for (final q in ['ねこ', '猫', 'ネコ', 'cat', 'Cat', 'meow']) {
      expect(names.search(q), contains('🐱'), reason: q);
    }
    for (final q in ['寿司', 'すし', 'sushi']) {
      expect(names.search(q), contains('🍣'), reason: q);
    }
    expect(names.search('サムズアップ'), isNotEmpty);
    expect(names.search('thumbsup').first, '👍');
    expect(names.search('zzzzqqq'), isEmpty);
    expect(names.search('  '), isEmpty);
  });

  test('名前どおりのものを先に、語の途中の一致は後ろに。英字 1 字は頭からだけ', () {
    final cat = names.search('cat');
    expect(cat.first, '🐱', reason: 'ショートコードが cat');
    expect(cat.indexOf('🐈'), greaterThan(0));
    final neko = names.search('ネコ');
    expect(neko.first, '🐈', reason: 'CLDR の名前が「ネコ」');
    // `c` で頭から(cat / cactus …)は出るが、`ac` の途中(face の c など)だけのものは出ない。
    final c = names.search('c');
    expect(c, contains('🐱'));
    expect(c, isNot(contains('😀')), reason: '😀 の語は face / smile / happy / joy … で、c で始まる語が無い');
  });

  testWidgets('アセットから読める(rootBundle)', (tester) async {
    final data = await tester.runAsync(() => rootBundle.load(unicodeEmojiNamesAsset));
    expect(UnicodeEmojiNames.fromGzip(data!.buffer.asUint8List()).entries.length, 1915);
  });

  testWidgets('ピッカー: 検索すると「絵文字」の節に名前で見つかったシステムの絵文字が並び、押すと入る', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final picked = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        customEmojisProvider.overrideWith((ref) async => [EmojiInfo(name: 'neko_dance', url: Uri.parse('https://e/n.webp'))]),
        unicodeEmojiNamesProvider.overrideWith((ref) async => names),
      ],
      child: MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: EmojiPanel(onPick: picked.add, height: 1100))),
    ));
    await tester.pumpAndSettle();
    Finder cell(String e) => find.byWidgetPredicate((w) => w is RasqCustomEmoji && w.url == null && w.fallbackText == e);
    // 検索していないときは、これまでどおりの「デフォルト」(猫の顔も入っている)。
    expect(find.text('デフォルト'), findsOneWidget);
    expect(find.text('絵文字'), findsNothing);
    await tester.enterText(find.byType(TextField), 'ねこ');
    await tester.pumpAndSettle();
    expect(find.text('デフォルト'), findsNothing, reason: '検索中は並びの決まった「デフォルト」を出さない');
    expect(find.text('絵文字'), findsOneWidget);
    expect(cell('🐈'), findsOneWidget);
    expect(cell('😺'), findsOneWidget);
    expect(cell('🍣'), findsNothing);
    // サーバーの絵文字の検索はこれまでどおり(英字の名前の部分一致)。
    await tester.enterText(find.byType(TextField), 'neko');
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is RasqCustomEmoji && w.url != null), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sushi');
    await tester.pumpAndSettle();
    await tester.tap(cell('🍣'));
    expect(picked, ['🍣']);
  });
}
