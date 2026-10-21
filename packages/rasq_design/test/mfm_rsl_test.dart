import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: RasqTheme.light(),
      // disableAnimations: MFM のアニメ系を静止フレームにしてテストを安定させる.
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: SizedBox(width: 380, child: child))),
      ),
    );

void main() {
  group('RasqTransformSpan rendering', () {
    testWidgets('x2 scales the child text style inline (Misskey: plain span, nested x2 half effective)', (tester) async {
      await tester.pumpWidget(wrap(const RasqRichText([
        RasqTextSpan('通常'),
        RasqTransformSpan('x2', children: [
          RasqTextSpan('大きい'),
          RasqTransformSpan('x2', children: [RasqTextSpan('入れ子')]),
        ]),
      ], style: TextStyle(fontSize: 15))));
      final sizes = <String, double?>{};
      tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((s) {
        if (s is TextSpan && s.text != null) sizes[s.text!] = s.style?.fontSize;
        return true;
      });
      expect(sizes, {'通常': 15, '大きい': 30, '入れ子': 45});
      expect(RasqMfmTransform.childStyle('x2', const {}, const TextStyle(fontSize: 15)).fontSize, 30);
    });

    testWidgets('box fns are inline-blocks with their own transform (nested transforms compose)', (tester) async {
      await tester.pumpWidget(wrap(const RasqRichText([
        RasqTransformSpan('position', args: {'y': '-1'}, children: [
          RasqTransformSpan('rotate', args: {'deg': '90'}, children: [RasqTextSpan('箱')]),
        ]),
      ], style: TextStyle(fontSize: 20))));
      final transforms = tester.widgetList<Transform>(find.descendant(of: find.byType(RasqMfmTransform), matching: find.byType(Transform))).toList();
      expect(transforms, hasLength(2));
      expect(transforms.first.transform.storage[13], -20, reason: 'position.y=-1 = -1em');
      expect(transforms.last.transform.storage[1], closeTo(1, 1e-9), reason: 'rotate 90°');
    });

    testWidgets('unknown fn renders children unchanged', (tester) async {
      await tester.pumpWidget(wrap(const RasqRichText([
        RasqTransformSpan('unknown_future_fn', children: [RasqTextSpan('中身')]),
      ])));
      expect(find.text('中身'), findsOneWidget);
    });

    testWidgets('animated fns degrade to static frames when animations are disabled', (tester) async {
      await tester.pumpWidget(wrap(const RasqRichText([
        RasqTransformSpan('spin', args: {'speed': '1.5s'}, children: [RasqTextSpan('回る')]),
        RasqTransformSpan('rainbow', children: [RasqTextSpan('虹')]),
      ])));
      await tester.pumpAndSettle(); // no live tickers → settles
      expect(find.text('回る'), findsOneWidget);
      // rainbow の静止は Misskey と同じく文字にグラデーション(絵文字はそのまま)= 2 枚重ね。
      expect(find.text('虹'), findsWidgets);
    });

    // セキュリティ確認 2026-10-21 の #21 (D-546): 静止の rainbow の入れ子で中身を作る数が倍々にならない。
    group('rainbow nesting / box budget', () {
      final emoji = Uri.parse('https://e.invalid/e.png');
      List<RasqSpan> nested(int depth, List<RasqSpan> leaf) {
        var spans = leaf;
        for (var i = 0; i < depth; i++) {
          spans = [RasqTransformSpan('rainbow', children: spans)];
        }
        return spans;
      }

      testWidgets('20 nested static rainbows build a linear number of layers (not 2^20)', (tester) async {
        await tester.pumpWidget(wrap(RasqRichText(nested(20, [const RasqTextSpan('虹'), RasqEmojiSpan(shortcode: 'e', url: emoji)]))));
        await tester.pump();
        expect(tester.widgetList(find.byType(RasqMfmTransform)).length, lessThanOrEqualTo(2 * 20));
        expect(tester.widgetList(find.byType(RasqRichText)).length, lessThanOrEqualTo(2 * 20 + 1));
        // 重ねるのはいちばん外の 1 回だけ: グラデーションは 1 枚、絵文字は「隠した層」と「見せる層」の 2 つ。
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(find.textContaining('虹', findRichText: true), findsWidgets);
        expect(find.byType(RasqCustomEmoji), findsNWidgets(2));
        final hidden = tester.widgetList<Opacity>(find.ancestor(of: find.byType(RasqCustomEmoji), matching: find.byType(Opacity))).where((o) => o.opacity == 0);
        expect(hidden, hasLength(1), reason: '絵文字はグラデーションの層でだけ隠す(見える絵文字は 1 つ)');
      });

      testWidgets('animated rainbows also nest linearly', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: RasqTheme.light(),
          home: Scaffold(body: RasqRichText(nested(20, [const RasqTextSpan('虹')]))),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.widgetList(find.byType(RasqRichText)).length, 21);
        expect(find.byType(ShaderMask), findsNothing);
        expect(find.byType(ColorFiltered), findsNWidgets(20));
        await tester.pumpWidget(const SizedBox()); // Ticker を止める
      });

      testWidgets('boxes over the budget render as plain text (both rainbow layers share one budget)', (tester) async {
        final many = [for (var i = 0; i < RasqRichText.maxMfmBoxes; i++) RasqTransformSpan('bg', args: const {'color': '00f'}, children: [RasqTextSpan('$i ')])];
        // rainbow の中の箱は 2 枚重ねで 2 回作られるので 2 つと数える → rainbow の中の箱は予算の半分ほどまで。
        await tester.pumpWidget(wrap(RasqRichText([
          RasqTransformSpan('rainbow', children: [
            RasqTransformSpan('rainbow', children: many),
          ]),
          const RasqTextSpan('後ろ'),
          const RasqTransformSpan('bg', children: [RasqTextSpan('予算切れ')]),
        ])));
        await tester.pump();
        final boxes = tester.widgetList(find.byType(RasqMfmTransform)).length;
        expect(boxes, lessThanOrEqualTo(RasqRichText.maxMfmBoxes));
        expect(boxes, greaterThan(RasqRichText.maxMfmBoxes - 4), reason: '予算までは箱を作る');
        expect(tester.widgetList(find.byType(RasqRichText)).length, lessThanOrEqualTo(RasqRichText.maxMfmBoxes + 1));
        expect(find.byType(ShaderMask), findsOneWidget);
        // 外した装飾の中身は文字のまま残る。
        expect(find.textContaining('${RasqRichText.maxMfmBoxes - 1} ', findRichText: true), findsWidgets);
        expect(find.textContaining('予算切れ', findRichText: true), findsOneWidget);
      });

      testWidgets('animated and static count the same budget', (tester) async {
        final many = [for (var i = 0; i < RasqRichText.maxMfmBoxes; i++) RasqTransformSpan('bg', children: [RasqTextSpan('$i')])];
        final spans = [RasqTransformSpan('rainbow', children: many)];
        await tester.pumpWidget(wrap(RasqRichText(spans)));
        final staticBoxes = tester.widgetList<RasqMfmTransform>(find.byType(RasqMfmTransform)).where((t) => t.fn == 'bg').length;
        await tester.pumpWidget(MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: SingleChildScrollView(child: RasqRichText(spans)))));
        await tester.pump(const Duration(milliseconds: 100));
        final animatedBoxes = tester.widgetList<RasqMfmTransform>(find.byType(RasqMfmTransform)).where((t) => t.fn == 'bg').length;
        // 静止は 2 枚重ねで同じ箱が 2 回、動くときは 1 回(どちらも同じ箱だけ残す)。
        expect(staticBoxes, animatedBoxes * 2);
        expect(animatedBoxes, (RasqRichText.maxMfmBoxes - 2) ~/ 2);
        await tester.pumpWidget(const SizedBox());
      });
    });

    test('speedOf / color parsing', () {
      expect(RasqMfmTransform.speedOf(const {'speed': '1.5s'}, Duration.zero), const Duration(milliseconds: 1500));
      expect(RasqMfmTransform.speedOf(const {'speed': 0.5}, Duration.zero), const Duration(milliseconds: 500));
      expect(RasqMfmTransform.speedOf(const {}, const Duration(seconds: 2)), const Duration(seconds: 2));
      expect(RasqMfmTransform.childStyle('fg', const {'color': 'ff0000'}, const TextStyle()).color, const Color(0xFFFF0000));
    });
  });

  group('rsl_json codec', () {
    const wire = [
      {'s': 'text', 'text': 'こんにちは ', 'bold': true},
      {'s': 'emoji', 'shortcode': 'cake'},
      {
        's': 'transform',
        'fn': 'spin',
        'args': {'speed': '1.5s'},
        'c': [
          {'s': 'text', 'text': '回る'},
        ],
      },
      {'s': 'link', 'text': 'example', 'url': 'https://example.com/'},
      {'s': 'hashtag', 'tag': '打上会'},
      {'s': 'mention', 'handle': 'username', 'host': 'misskey.io'},
    ];

    test('decodes the schema wire form (nested transform, emoji cache)', () {
      final spans = rslSpansFromJson(wire, emojis: {'cake': Uri.parse('https://e.invalid/cake.png')});
      expect(spans, hasLength(6));
      expect((spans[0] as RasqTextSpan).bold, isTrue);
      expect((spans[1] as RasqEmojiSpan).url, isNotNull);
      final t = spans[2] as RasqTransformSpan;
      expect(t.fn, 'spin');
      expect(t.args['speed'], '1.5s');
      expect((t.children.single as RasqTextSpan).text, '回る');
      expect((spans[5] as RasqMentionSpan).handle, 'username@misskey.io');
    });

    test('round-trips back to JSON', () {
      final spans = rslSpansFromJson(wire);
      final json = rslSpansToJson(spans);
      expect(json[0], {'s': 'text', 'text': 'こんにちは ', 'bold': true});
      expect((json[2] as Map)['fn'], 'spin');
      expect(((json[2] as Map)['c'] as List).single, {'s': 'text', 'text': '回る'});
      // mention loses no display information (host is folded into handle).
      expect((json[5] as Map)['handle'], 'username@misskey.io');
    });

    testWidgets('decoded spans render (callbacks wire interaction)', (tester) async {
      Uri? tapped;
      final spans = rslSpansFromJson(wire, onLink: (u) => tapped = u);
      await tester.pumpWidget(wrap(RasqRichText(spans)));
      expect(find.textContaining('こんにちは'), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring('example'));
      expect(tapped, Uri.parse('https://example.com/'));
    });
  });
}
