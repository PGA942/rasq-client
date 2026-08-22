import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/text/inline_spans.dart';
import 'package:rasq_design/rasq_design.dart';

void main() {
  test('parses url / mention / hashtag / emoji and strips MFM functions', () {
    final spans = InlineSpans.parse('Hi @taro@misskey.io #打上会 :blobcat: https://example.com/x \$[spin wow]', emojis: {'blobcat': Uri.parse('https://e/blobcat.png')});
    expect(spans.whereType<RasqMentionSpan>().single.handle, 'taro@misskey.io');
    expect(spans.whereType<RasqHashtagSpan>().single.tag, '打上会');
    expect(spans.whereType<RasqEmojiSpan>().single.url.toString(), 'https://e/blobcat.png');
    expect(spans.whereType<RasqLinkSpan>().single.text, 'example.com/x');
    expect(spans.whereType<RasqTextSpan>().map((s) => s.text).join(), contains('wow'));
    expect(InlineSpans.emojiShortcodes(':a: text :b@.:'), {'a', 'b@.'});
  });
}
