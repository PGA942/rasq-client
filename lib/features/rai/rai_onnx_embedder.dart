import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'rai_reference.dart';
import 'rai_siglip_tokenizer.dart';

/// SigLIP2 のテキスト塔を端末の onnxruntime で回す埋め込み (D-190)。
/// 入力 `input_ids` int64 [n, 64] → `pooler_output` float [n, 768] を L2 正規化して返す。
/// 検索の契約は [RaiEmbedder] のまま(n-gram 代替 / ゲートウェイと差し替え可能)。
class OnnxRaiEmbedder implements RaiEmbedder {
  OnnxRaiEmbedder._(this._session, this._tokenizer, this.modelPath);
  final OrtSession _session;
  final SentencePieceBpe _tokenizer;
  final String modelPath;
  static bool _envReady = false;

  /// 1 回の推論に載せる文の数(索引の構築は数十文 → 数回に分ける)。
  static const batch = 8;
  static const maxLen = 64;

  @override
  String get name => 'siglip2-onnx';

  static Future<OnnxRaiEmbedder> load({required File model, required SentencePieceBpe tokenizer, int threads = 2}) async {
    if (!_envReady) {
      OrtEnv.instance.init();
      _envReady = true;
    }
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(threads)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final session = OrtSession.fromFile(model, options);
    options.release();
    if (!session.inputNames.contains('input_ids')) {
      session.release();
      throw StateError('SigLIP2 text model: input "input_ids" not found (${session.inputNames})');
    }
    return OnnxRaiEmbedder._(session, tokenizer, model.path);
  }

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    final out = <List<double>>[];
    for (var i = 0; i < texts.length; i += batch) {
      final chunk = texts.sublist(i, math.min(texts.length, i + batch));
      out.addAll(await _run(chunk));
    }
    return out;
  }

  Future<List<List<double>>> _run(List<String> texts) async {
    final rows = [for (final t in texts) Int64List.fromList(_tokenizer.encode(t, maxLen: maxLen))];
    final input = OrtValueTensor.createTensorWithDataList(rows, [texts.length, maxLen]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      // 別 isolate で回す(UI を止めない)。使えない環境では同期実行。
      final got = await (_session.runAsync(runOptions, {'input_ids': input}, ['pooler_output']) ?? Future.value(_session.run(runOptions, {'input_ids': input}, ['pooler_output'])));
      outputs = got;
      final value = got.first!.value as List;
      return [for (final row in value) NgramRaiEmbedder.normalize([for (final v in (row as List)) (v as num).toDouble()])];
    } finally {
      input.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  void dispose() => _session.release();
}
