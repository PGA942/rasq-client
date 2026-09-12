import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_siglip_tokenizer.dart';

/// SigLIP2(Gemma SentencePiece BPE)のトークナイザー (D-190): HF GemmaTokenizerFast の出力
/// (test/fixtures/siglip2_reference.json、transformers 5.16 で生成)と id 列が一致する。
void main() {
  late SentencePieceBpe tok;
  setUpAll(() => tok = SentencePieceBpe.fromModelBytes(File('assets/models/siglip2_tokenizer.model').readAsBytesSync()));

  test('語彙 256000、特殊トークンとバイト片', () {
    expect(tok.vocabSize, 256000);
    expect(tok.idOf('<pad>'), 0);
    expect(tok.idOf('<eos>'), 1);
    expect(tok.idOf('<0x21>'), 250);
    expect(tok.idOf('▁photo'), greaterThan(0));
  });

  test('参照(日本語 / 英語 / 絵文字 / 全角 / 連続空白)と id 列が一致、eos + pad 64', () {
    final ref = (jsonDecode(File('test/fixtures/siglip2_reference.json').readAsStringSync()) as Map).cast<String, Object?>();
    final texts = (ref['texts'] as List).cast<String>();
    final ids = (ref['ids'] as List).map((r) => (r as List).cast<int>()).toList();
    for (var i = 0; i < texts.length; i++) {
      expect(tok.encode(texts[i]), ids[i], reason: '${texts[i]} → ${tok.tokenize(texts[i])}');
      expect(tok.encode(texts[i]).length, 64);
    }
    expect(tok.tokenize('a photo of a cat'), ['a', '▁photo', '▁of', '▁a', '▁cat']);
  });

  test('未知の文字はバイトに落ち、長い文は eos を残して切り詰め', () {
    // 語彙に無い 4 バイト文字を探して → バイト片 4 つ。
    var cp = 0x10000;
    while (tok.idOf(String.fromCharCode(cp)) >= 0) {
      cp++;
    }
    final pieces = tok.tokenize(String.fromCharCode(cp));
    expect(pieces.length, 4);
    expect(pieces.every((p) => p.startsWith('<0x')), isTrue);
    expect(tok.encode(String.fromCharCode(cp)).sublist(0, 4).every((id) => id >= 250), isTrue);
    final long = tok.encode(List.filled(200, 'word').join(' '));
    expect(long.length, 64);
    expect(long.last, 1);
    expect(long.contains(0), isFalse);
    expect(tok.encode(''), [1, ...List.filled(63, 0)]);
  });
}
