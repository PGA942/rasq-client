import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_minilm_tokenizer.dart';
import 'package:rasq_client/features/rai/rai_onnx_embedder.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';

import '../tool/rai_reference_eval.dart';

/// RASQ MiniLM(文の塔、D-390)。参照 = tokenizer.json + onnxruntime(Python)の id とコサイン行列
/// (test/fixtures/rasq_minilm_reference.json)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ref = (jsonDecode(File('test/fixtures/rasq_minilm_reference.json').readAsStringSync()) as Map).cast<String, Object?>();
  final texts = (ref['texts'] as List).cast<String>();

  test('同梱のトークナイザー(MiniLM と共用)が、モデルの tokenizer.json と同じ id を出す', () {
    final tok = UnigramTokenizer.fromTsv(File('assets/models/minilm_unigram.tsv').readAsStringSync());
    final ids = (ref['ids'] as List).map((r) => (r as List).cast<int>()).toList();
    for (var i = 0; i < texts.length; i++) {
      expect(tok.encode(texts[i], maxLen: 128), ids[i], reason: texts[i]);
    }
  });

  test('配り先: Central の models から。Central が無ければ取れない', () {
    expect(raiEmbeddingSpec.kind, RaiEmbeddingKind.rasqText);
    expect(raiEmbeddingSpec.downloadUrl(Uri.parse('https://central.test/')).toString(), 'https://central.test/api/v1/models/minilm-mobilenet/onnx/text_tower_uint8.onnx');
    expect(postVisionEmbeddingSpec.downloadUrl(Uri.parse('https://central.test')).toString(), 'https://central.test/api/v1/models/minilm-mobilenet/onnx/image_tower_uint8.onnx');
    expect(raiEmbeddingSpec.downloadUrl(null), isNull);
    expect(raiMiniLmL12EmbeddingSpec.downloadUrl(null).toString(), startsWith('https://huggingface.co/'));
    expect(postVisionEmbeddingSpec.dims, raiEmbeddingSpec.dims, reason: '同じ空間');
  });

  // 本物の ONNX(uint8 で量子化し直した 35 MB)と onnxruntime の共有ライブラリがあるときだけ。
  final dir = Platform.environment['RASQ_TEXT_TOWER_DIR'] ?? '/workspace/models/minilm-mobilenet/onnx';
  final model = File('$dir/text_tower_uint8.onnx');
  final lib = Platform.environment['LD_LIBRARY_PATH']?.contains('onnxruntime') ?? false;
  test('端末で回す: 参照のコサイン行列と一致(±0.02)、リファレンス検索の成績', () async {
    final tok = UnigramTokenizer.fromTsv(File('assets/models/minilm_unigram.tsv').readAsStringSync());
    final emb = await OnnxRaiEmbedder.loadRasqText(model: model, tokenizer: tok);
    final dots = (ref['norm_dot'] as List).map((r) => (r as List).cast<num>()).toList();
    final vecs = await emb.embed(texts);
    expect(vecs.first.length, 384);
    for (var i = 0; i < texts.length; i++) {
      for (var j = 0; j < texts.length; j++) {
        expect(cosine(vecs[i], vecs[j]), closeTo(dots[i][j].toDouble(), 0.02), reason: '${texts[i]} × ${texts[j]}');
      }
    }
    final index = await RaiReferenceIndex.fromJsonl(
      functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
      operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
      embedder: emb,
    );
    final r = await evaluate(index, parseJsonl(await rootBundle.loadString(raiEvalAsset)));
    // ignore: avoid_print
    print('rasq-minilm hybrid top1=${(r.top1 * 100).toStringAsFixed(1)}% top3=${(r.topK * 100).toStringAsFixed(1)}%');
    expect(r.topK, greaterThanOrEqualTo(0.6));
    emb.dispose();
  }, skip: model.existsSync() && lib ? false : '本物の ONNX と onnxruntime の共有ライブラリ(LD_LIBRARY_PATH)が要る');
}
