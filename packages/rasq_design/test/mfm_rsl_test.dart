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
    testWidgets('x2 scales the child text style', (tester) async {
      await tester.pumpWidget(wrap(const RasqRichText([
        RasqTextSpan('通常'),
        RasqTransformSpan('x2', children: [RasqTextSpan('大きい')]),
      ], style: TextStyle(fontSize: 15))));
      expect(find.text('大きい'), findsOneWidget);
      final inner = tester.widget<RasqRichText>(find.byType(RasqRichText).last);
      expect(RasqMfmTransform.childStyle('x2', const {}, const TextStyle(fontSize: 15)).fontSize, 30);
      expect(inner.style!.fontSize, 30);
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
      expect(find.text('虹'), findsOneWidget);
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
