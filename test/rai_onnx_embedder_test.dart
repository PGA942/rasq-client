import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_onnx_embedder.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/rai/rai_siglip_tokenizer.dart';

import '../tool/rai_reference_eval.dart';

/// SigLIP2 テキスト塔の端末実行 (D-190)。本物の ONNX(283 MB)が要るので、
/// `RASQ_SIGLIP_DIR=<text_model_int8.onnx のあるディレクトリ>` と onnxruntime 1.15.1 の共有ライブラリ
/// (`LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/onnxruntime-1.4.1/linux`)があるときだけ回す。
/// 参照(transformers + onnxruntime の Python)とコサイン行列が一致し、eval.jsonl の top-1 を出す。
void main() {
  final dir = Platform.environment['RASQ_SIGLIP_DIR'];
  final model = dir == null ? null : File('$dir/text_model_int8.onnx');
  final available = model != null && model.existsSync();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('参照ベクトルと一致(コサイン行列 ±0.02)、リファレンス検索の top-1', () async {
    final tok = SentencePieceBpe.fromModelBytes(File('assets/models/siglip2_tokenizer.model').readAsBytesSync());
    final emb = await OnnxRaiEmbedder.load(model: model!, tokenizer: tok);
    final ref = (jsonDecode(File('test/fixtures/siglip2_reference.json').readAsStringSync()) as Map).cast<String, Object?>();
    final texts = (ref['texts'] as List).cast<String>();
    final dots = (ref['norm_dot'] as List).map((r) => (r as List).cast<num>()).toList();
    final vecs = await emb.embed(texts);
    expect(vecs.length, texts.length);
    expect(vecs.first.length, 768);
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
    final evals = parseJsonl(await rootBundle.loadString(raiEvalAsset));
    final r = await evaluate(index, evals);
    // ignore: avoid_print
    print('siglip2 top1=${(r.top1 * 100).toStringAsFixed(1)}% top3=${(r.topK * 100).toStringAsFixed(1)}% misses=${r.misses.map((m) => '${m.query}→${m.got}').join('; ')}');
    // 言い換え(タグに無い語)でも引ける = ベクトル側の効き。
    final hits = await index.searchOperations('友達にこっそりメッセージ');
    // ignore: avoid_print
    print('paraphrase: ${index.traces.first}');
    expect(hits, isNotEmpty);
    expect(r.top1, greaterThanOrEqualTo(0.8));
    emb.dispose();
  }, skip: available ? false : 'RASQ_SIGLIP_DIR が無い(本物の SigLIP2 ONNX が要る)');
}
