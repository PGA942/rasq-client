import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:onnxruntime/onnxruntime.dart';

import '../rai/rai_reference.dart' show NgramRaiEmbedder;
import 'emoji_image_preprocess.dart';

/// 画像の埋め込みの契約 (D-293)。返りは L2 正規化済み。読めなかった絵は null。
/// いまは SigLIP2 の画像側。第二期に、MiniLM の空間へ写した CNN 系(mobilenet)へ置き換える予定 —
/// そのときは [name] が変わり、索引は作り直しになる。
abstract class EmojiImageEmbedder {
  String get name;
  Future<List<List<double>?>> embedImages(List<Uint8List> encoded);
}

/// 端末の onnxruntime で回す SigLIP2 の画像側: `pixel_values`[n,3,224,224] → `pooler_output`[n,768]。
/// **同じ SigLIP2 のテキスト側**(`siglip2-onnx`)で作った文のベクトルと、内積で比べられる。
class OnnxEmojiImageEmbedder implements EmojiImageEmbedder {
  OnnxEmojiImageEmbedder._(this._session, this._output);
  final OrtSession _session;
  final String _output;
  static const size = 224;
  static const batch = 4;
  static bool _envReady = false;

  @override
  String get name => 'siglip2-vision-onnx';

  static Future<OnnxEmojiImageEmbedder> load({required File model, int threads = 2}) async {
    if (!_envReady) {
      OrtEnv.instance.init();
      _envReady = true;
    }
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(threads)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final session = OrtSession.fromFile(model, options);
    options.release();
    if (!session.inputNames.contains('pixel_values')) {
      final names = session.inputNames;
      session.release();
      throw StateError('image model: input "pixel_values" not found ($names)');
    }
    // 出力の名前は、書き出し方で違う(pooler_output / image_embeds)。どちらも無ければ、読み込みを断る。
    final out = ['pooler_output', 'image_embeds'].where(session.outputNames.contains).firstOrNull;
    if (out == null) {
      final names = session.outputNames;
      session.release();
      throw StateError('image model: no pooled output ($names)');
    }
    return OnnxEmojiImageEmbedder._(session, out);
  }

  /// 絵(PNG / WebP / GIF …)→ 224×224 の RGBA。動く絵は 1 コマ目。読めなければ null。
  static Future<Uint8List?> decodeRgba(Uint8List encoded) async {
    try {
      final codec = await ui.instantiateImageCodec(encoded, targetWidth: size, targetHeight: size, allowUpscaling: true);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      frame.image.dispose();
      codec.dispose();
      final bytes = data?.buffer.asUint8List();
      return bytes == null || bytes.length != size * size * 4 ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<List<double>?>> embedImages(List<Uint8List> encoded) async {
    final out = List<List<double>?>.filled(encoded.length, null);
    for (var i = 0; i < encoded.length; i += batch) {
      final end = math.min(encoded.length, i + batch);
      final pixels = <Float32List>[];
      final slots = <int>[];
      for (var k = i; k < end; k++) {
        final rgba = await decodeRgba(encoded[k]);
        if (rgba == null) continue;
        pixels.add(emojiPixelValues(rgba, size: size));
        slots.add(k);
      }
      if (pixels.isEmpty) continue;
      final vectors = await _run(pixels);
      for (var k = 0; k < slots.length && k < vectors.length; k++) {
        out[slots[k]] = vectors[k];
      }
    }
    return out;
  }

  Future<List<List<double>>> _run(List<Float32List> pixels) async {
    final flat = Float32List(pixels.length * 3 * size * size);
    for (var i = 0; i < pixels.length; i++) {
      flat.setRange(i * 3 * size * size, (i + 1) * 3 * size * size, pixels[i]);
    }
    final inputs = <String, OrtValue>{'pixel_values': OrtValueTensor.createTensorWithDataList(flat, [pixels.length, 3, size, size])};
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      // 別 isolate で回す(UI を止めない)。使えない環境では同期実行。
      final got = await (_session.runAsync(runOptions, inputs, [_output]) ?? Future.value(_session.run(runOptions, inputs, [_output])));
      outputs = got;
      final value = got.first!.value as List;
      return [for (final row in value) NgramRaiEmbedder.normalize([for (final v in (row as List)) (v as num).toDouble()])];
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
