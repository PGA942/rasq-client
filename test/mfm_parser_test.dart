import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/text/mfm/mfm_node.dart';
import 'package:rasq_client/text/mfm/mfm_parser.dart';

/// mfm.js の移植 (D-509) を mfm.js と突き合わせる。
///
/// - test/fixtures/mfm/mfmjs_cases.json: mfm.js 0.27.0 の test/parser.ts の全ケース(168 件)の入力と期待する木。
///   作り方: mfm.js の test/parser.ts を vitest / assert / mfm の差し替えで node で回し、`parse()` / `parseSimple()` に
///   渡した入力と `assert.deepStrictEqual` の期待値を書き出す(実物の mfm-js 0.27.0 の出力とも一致を確かめ済み)。
/// - test/fixtures/mfm/rasq_mfm_samples.json: 確かめ用の MFM(花の MFM アート・入れ子のアニメーション・ruby・
///   unixtime・border・fg/bg・font・flip・入れ子の position/rotate …)と、npm の mfm-js 0.27.0 の `parse()` の出力。
///   描画のテスト(mfm_render_test.dart)も同じ入力を使う。
void main() {
  List<Map<String, dynamic>> load(String name) => (jsonDecode(File('test/fixtures/mfm/$name').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  List<Object?> tree(List<MfmNode> nodes) => jsonDecode(jsonEncode([for (final n in nodes) n.toJson()])) as List;

  group('mfm.js の test/parser.ts', () {
    final cases = load('mfmjs_cases.json');
    test('ケースが揃っている', () => expect(cases.length, greaterThanOrEqualTo(160)));
    for (final (i, c) in cases.indexed) {
      test('${c['name']} #$i', () {
        final input = c['input'] as String;
        final opts = c['opts'] as Map<String, dynamic>?;
        final nodes = c['fn'] == 'parseSimple' ? Mfm.parseSimple(input) : Mfm.parse(input, nestLimit: (opts?['nestLimit'] as int?) ?? 20);
        expect(tree(nodes), c['output'], reason: 'input: ${jsonEncode(input)}');
      });
    }
  });

  group('確かめ用の MFM(mfm-js 0.27.0 の出力と同じ木)', () {
    for (final c in load('rasq_mfm_samples.json')) {
      test(c['name'] as String, () => expect(tree(Mfm.parse(c['input'] as String)), c['output']));
    }
  });

  group('RASQ の拡張', () {
    test('emojiHost: `:name@host:` / `:name@.:` も絵文字(既定では mfm.js どおり文字)', () {
      expect(tree(Mfm.parse(':blobcat@.: :party@remote.example:', emojiHost: true)), [
        {'type': 'emojiCode', 'props': {'name': 'blobcat@.'}},
        {'type': 'text', 'props': {'text': ' '}},
        {'type': 'emojiCode', 'props': {'name': 'party@remote.example'}},
      ]);
      expect(Mfm.parse(':blobcat@.:').where((n) => n.type == 'emojiCode'), isEmpty);
    });

    test('htmlFns: HTML 風の MFM のタグ → fn(属性 = 引数、ruby の <rt>)。既定では文字', () {
      final spin = Mfm.parse('<spin speed="1s" left>回る</spin>', htmlFns: true).single;
      expect(spin.fnName, 'spin');
      expect(spin.fnArgs, {'speed': '1s', 'left': true});
      final ruby = Mfm.parse('<ruby>本<rt>ほん</rt></ruby>', htmlFns: true).single;
      expect((ruby.fnName, ruby.fnArgs['rt'], ruby.children!.single.text), ('ruby', 'ほん', '本'));
      final nested = Mfm.parse('<x2><flip h>a<flip v>b</flip></flip></x2>', htmlFns: true).single;
      expect(nested.children!.single.children!.last.fnArgs, {'v': true});
      expect(Mfm.parse('<spin>回る</spin>').single.type, 'text');
      expect(Mfm.parse('<spin>閉じていない', htmlFns: true).single.type, 'text');
    });
  });
}
