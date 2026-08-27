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
    // ホスト付きショートコードは name に落としてプリフェッチ(`:b@.:` = ローカル)。
    expect(InlineSpans.emojiShortcodes(':a: text :b@.:'), {'a', 'b'});
  });

  test('emoji with host suffix falls back to the bare-name cache entry', () {
    final spans = InlineSpans.parse(':blobcat@.: と :party@remote.example:', emojis: {'blobcat': Uri.parse('https://e/b.png'), 'party': Uri.parse('https://e/p.png')});
    final emoji = spans.whereType<RasqEmojiSpan>().toList();
    expect(emoji[0].url.toString(), 'https://e/b.png');
    expect(emoji[1].url.toString(), 'https://e/p.png');
  });

  group('MFM markdown', () {
    test('inline: *italic* / ~~strike~~ / `code` / [text](url)', () {
      final spans = InlineSpans.parse(r'*斜体* ~~消し~~ `x = 1` [リンク](https://example.com/a)');
      expect((spans[0] as RasqTextSpan).italic, isTrue);
      expect(spans.whereType<RasqTextSpan>().where((s) => s.strike).single.text, '消し');
      expect(spans.whereType<RasqTextSpan>().where((s) => s.code).single.text, 'x = 1');
      final link = spans.whereType<RasqLinkSpan>().single;
      expect(link.text, 'リンク');
      expect(link.url.toString(), 'https://example.com/a');
    });

    test('tags: <b> <s> <small> <plain> <center>', () {
      final spans = InlineSpans.parse('<b>太い</b><s>消す</s><small>小さい</small><plain>**そのまま** :emoji:</plain><center>中央</center>');
      expect((spans[0] as RasqTextSpan).bold, isTrue);
      expect((spans[1] as RasqTextSpan).strike, isTrue);
      expect((spans[2] as RasqTextSpan).small, isTrue);
      expect((spans[3] as RasqTextSpan).text, '**そのまま** :emoji:'); // plain は未解析
      final center = spans[4] as RasqTransformSpan;
      expect(center.fn, 'center');
    });

    test('blocks: ```code``` と > 引用(連続行を束ね、中はインライン解析)', () {
      final spans = InlineSpans.parse('前\n```dart\nfinal a = 1;\n```\n> 引用1行目 #tag\n> 引用2行目\n後');
      final block = spans.whereType<RasqTransformSpan>().firstWhere((s) => s.fn == 'code_block');
      expect((block.children.single as RasqTextSpan).text, 'final a = 1;');
      expect((block.children.single as RasqTextSpan).code, isTrue);
      final quote = spans.whereType<RasqTransformSpan>().firstWhere((s) => s.fn == 'quote');
      expect(quote.children.whereType<RasqHashtagSpan>().single.tag, 'tag');
      expect(quote.children.whereType<RasqTextSpan>().map((s) => s.text).join(), contains('引用2行目'));
      expect((spans.last as RasqTextSpan).text, contains('後'));
    });

    test('unbalanced markers degrade to literal text', () {
      final spans = InlineSpans.parse('a * b ` c ~~ d');
      expect(spans.whereType<RasqTransformSpan>(), isEmpty);
      expect(spans.map((s) => s is RasqTextSpan ? s.text : '?').join(), 'a * b ` c ~~ d');
    });
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
