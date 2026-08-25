import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/text/inline_spans.dart';
import 'package:rasq_design/rasq_design.dart';

void main() {
  test('parses url / mention / hashtag / emoji leaf tokens', () {
    final spans = InlineSpans.parse('Hi @taro@misskey.io #打上会 :blobcat: https://example.com/x', emojis: {'blobcat': Uri.parse('https://e/blobcat.png')});
    expect(spans.whereType<RasqMentionSpan>().single.handle, 'taro@misskey.io');
    expect(spans.whereType<RasqHashtagSpan>().single.tag, '打上会');
    expect(spans.whereType<RasqEmojiSpan>().single.url.toString(), 'https://e/blobcat.png');
    expect(spans.whereType<RasqLinkSpan>().single.text, 'example.com/x');
    expect(InlineSpans.emojiShortcodes(':a: text :b@.:'), {'a', 'b@.'});
  });

  test('MFM functions become structural transform spans (nested, with args)', () {
    final spans = InlineSpans.parse(r'前 $[spin.left,speed=1.5s $[x2 回る]] 後');
    expect((spans[0] as RasqTextSpan).text, '前 ');
    final spin = spans[1] as RasqTransformSpan;
    expect(spin.fn, 'spin');
    expect(spin.args, {'left': true, 'speed': '1.5s'});
    final x2 = spin.children.single as RasqTransformSpan;
    expect(x2.fn, 'x2');
    expect((x2.children.single as RasqTextSpan).text, '回る');
    expect((spans[2] as RasqTextSpan).text, ' 後');
  });

  test('MFM content keeps leaf tokens; unbalanced input degrades to text', () {
    final spans = InlineSpans.parse(r'$[tada #祝 :party:]');
    final tada = spans.single as RasqTransformSpan;
    expect(tada.children.whereType<RasqHashtagSpan>().single.tag, '祝');
    expect(tada.children.whereType<RasqEmojiSpan>().single.shortcode, 'party');

    final broken = InlineSpans.parse(r'$[spin こわれてる');
    expect(broken.whereType<RasqTransformSpan>(), isEmpty);
    expect(broken.map((s) => s is RasqTextSpan ? s.text : '').join(), contains('こわれてる'));
  });

  test('**bold** marks nested text spans bold', () {
    final spans = InlineSpans.parse('a **太字 #tag** b');
    expect((spans[1] as RasqTextSpan).bold, isTrue);
    expect(spans.whereType<RasqHashtagSpan>().single.tag, 'tag');
    expect((spans.last as RasqTextSpan).text, ' b');
  });
}
