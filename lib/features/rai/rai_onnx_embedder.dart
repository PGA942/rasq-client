import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'rai_minilm_tokenizer.dart';
import 'rai_reference.dart';
import 'rai_siglip_tokenizer.dart';

/// 端末の onnxruntime で回す文埋め込み (D-190 / D-193 / D-390)。3 つの形:
/// - SigLIP2 テキスト塔: `input_ids`[n,64] → `pooler_output`[n,768]
/// - MiniLM(sentence-transformers): `input_ids` / `attention_mask` / `token_type_ids` → `last_hidden_state` を
///   attention_mask で平均(mean pooling)
/// - RASQ MiniLM(D-390): `input_ids`(int64)/ `attention_mask`(**float32**)→ `embedding`[n,384](モデルの中で平均済み)
/// どれも L2 正規化して返す。検索の契約は [RaiEmbedder] のまま。
enum OnnxTextShape { siglip, meanPool, pooled }

class OnnxRaiEmbedder implements RaiEmbedder {
  OnnxRaiEmbedder._(this._session, this._encode, this.modelPath, this.name, this._maxLen, this._shape);
  final OrtSession _session;
  final List<int> Function(String text) _encode;
  final String modelPath;
  @override
  final String name;
  final int _maxLen;
  final OnnxTextShape _shape;
  bool get _meanPool => _shape != OnnxTextShape.siglip;
  static bool _envReady = false;

  /// 1 回の推論に載せる文の数(索引の構築は数十文 → 数回に分ける)。
  static const batch = 8;

  static OrtSession _open(File model, int threads) {
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
      throw StateError('embedding model: input "input_ids" not found (${session.inputNames})');
    }
    return session;
  }

  /// SigLIP2 テキスト塔(固定長 64、pooler_output)。
  static Future<OnnxRaiEmbedder> load({required File model, required SentencePieceBpe tokenizer, int threads = 2, int maxLen = 64}) async =>
      OnnxRaiEmbedder._(_open(model, threads), (t) => tokenizer.encode(t, maxLen: maxLen), model.path, 'siglip2-onnx', maxLen, OnnxTextShape.siglip);

  /// MiniLM 系(可変長、mean pooling)。
  static Future<OnnxRaiEmbedder> loadMiniLm({required File model, required UnigramTokenizer tokenizer, int threads = 2, int maxLen = 128}) async =>
      OnnxRaiEmbedder._(_open(model, threads), (t) => tokenizer.encode(t, maxLen: maxLen), model.path, 'minilm-onnx', maxLen, OnnxTextShape.meanPool);

  /// RASQ MiniLM(D-390、可変長、モデルの中で平均済みの `embedding`)。名前は MiniLM と違えて、索引を作り直させる。
  static Future<OnnxRaiEmbedder> loadRasqText({required File model, required UnigramTokenizer tokenizer, int threads = 2, int maxLen = 128}) async =>
      OnnxRaiEmbedder._(_open(model, threads), (t) => tokenizer.encode(t, maxLen: maxLen), model.path, 'rasq-minilm-onnx', maxLen, OnnxTextShape.pooled);

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
    final encoded = [for (final t in texts) _encode(t)];
    // SigLIP は固定長(pad 済み)、MiniLM はバッチ内の最長に右詰め。
    final len = _meanPool ? encoded.fold<int>(1, (m, e) => math.max(m, e.length)) : _maxLen;
    final ids = [for (final e in encoded) Int64List.fromList([...e, ...List.filled(len - e.length, _meanPool ? UnigramTokenizer.padId : SentencePieceBpe.padId)])];
    final mask = [for (final e in encoded) Int64List.fromList([...List.filled(e.length, 1), ...List.filled(len - e.length, 0)])];
    final inputs = <String, OrtValue>{'input_ids': OrtValueTensor.createTensorWithDataList(ids, [texts.length, len])};
    if (_shape == OnnxTextShape.pooled) {
      inputs['attention_mask'] = OrtValueTensor.createTensorWithDataList([for (final m in mask) Float32List.fromList([for (final x in m) x.toDouble()])], [texts.length, len]);
    } else if (_meanPool) {
      final names = _session.inputNames;
      if (names.contains('attention_mask')) inputs['attention_mask'] = OrtValueTensor.createTensorWithDataList(mask, [texts.length, len]);
      if (names.contains('token_type_ids')) inputs['token_type_ids'] = OrtValueTensor.createTensorWithDataList([for (final _ in encoded) Int64List(len)], [texts.length, len]);
    }
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      final outName = switch (_shape) { OnnxTextShape.siglip => 'pooler_output', OnnxTextShape.meanPool => 'last_hidden_state', OnnxTextShape.pooled => 'embedding' };
      // 別 isolate で回す(UI を止めない)。使えない環境では同期実行。
      final got = await (_session.runAsync(runOptions, inputs, [outName]) ?? Future.value(_session.run(runOptions, inputs, [outName])));
      outputs = got;
      final value = got.first!.value as List;
      if (_shape != OnnxTextShape.meanPool) return [for (final row in value) NgramRaiEmbedder.normalize([for (final v in (row as List)) (v as num).toDouble()])];
      final out = <List<double>>[];
      for (var b = 0; b < texts.length; b++) {
        final rows = value[b] as List; // [len][dims]
        final dims = (rows.first as List).length;
        final sum = List<double>.filled(dims, 0);
        var count = 0;
        for (var t = 0; t < len; t++) {
          if (mask[b][t] == 0) continue;
          count++;
          final r = rows[t] as List;
          for (var d = 0; d < dims; d++) {
            sum[d] += (r[d] as num).toDouble();
          }
        }
        out.add(NgramRaiEmbedder.normalize([for (final x in sum) x / math.max(1, count)]));
      }
      return out;
    } finally {
      for (final v in inputs.values) {
        v.release();
      }
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
