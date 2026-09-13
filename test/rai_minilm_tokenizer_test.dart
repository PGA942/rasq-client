import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_minilm_tokenizer.dart';

/// MiniLM(XLM-R Unigram)のトークナイザー (D-193): HF PreTrainedTokenizerFast の出力
/// (test/fixtures/minilm_reference.json)と id 列が一致する。
void main() {
  late UnigramTokenizer tok;
  setUpAll(() => tok = UnigramTokenizer.fromTsv(File('assets/models/minilm_unigram.tsv').readAsStringSync()));

  test('語彙 250002、特殊トークン', () {
    expect(tok.vocabSize, 250002);
    expect(tok.idOf('<s>'), 0);
    expect(tok.idOf('<pad>'), 1);
    expect(tok.idOf('</s>'), 2);
    expect(tok.idOf('<unk>'), 3);
    expect(tok.idOf('▁photo'), greaterThan(3));
  });

  test('参照(日本語 / 英語 / 絵文字 / 全角 / NFKC)と id 列が一致', () {
    final ref = (jsonDecode(File('test/fixtures/minilm_reference.json').readAsStringSync()) as Map).cast<String, Object?>();
    final texts = (ref['texts'] as List).cast<String>();
    final ids = (ref['ids'] as List).map((r) => (r as List).cast<int>().where((i) => i != 1).toList()).toList();
    final tokens = (ref['tokens'] as List).map((r) => (r as List).cast<String>()).toList();
    for (var i = 0; i < texts.length; i++) {
      expect(tok.tokenize(texts[i]), tokens[i].sublist(1, tokens[i].length - 1), reason: texts[i]);
      expect(tok.encode(texts[i]), ids[i], reason: texts[i]);
    }
  });

  test('長い文は </s> を残して切り詰め、空文は <s></s>', () {
    final long = tok.encode(List.filled(200, 'word').join(' '), maxLen: 32);
    expect(long.length, 32);
    expect(long.first, 0);
    expect(long.last, 2);
    expect(tok.encode(''), [0, 2]);
  });
}
