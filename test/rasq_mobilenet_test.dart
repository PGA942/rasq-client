import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/emoji/emoji_image_embedder_onnx.dart';

/// RASQ MobileNet(画像の塔、D-390 / D-522)を端末の onnxruntime(1.15)で読めて、1 枚埋め込めるか。
/// 本物の ONNX(`tool/requantize_uint8.py` で uint8 に直したもの)と onnxruntime の共有ライブラリがあるときだけ。
void main() {
  final dir = Platform.environment['RASQ_IMAGE_TOWER_DIR'] ?? '/workspace/models/minilm-mobilenet/onnx';
  final model = File('$dir/image_tower_uint8.onnx');
  final lib = Platform.environment['LD_LIBRARY_PATH']?.contains('onnxruntime') ?? false;
  test('端末で回す: 384 次元・正規化済みのベクトルが出る', () async {
    final emb = await OnnxEmojiImageEmbedder.load(model: model);
    expect(emb.name, 'rasq-mobilenet-onnx');
    final png = File('assets/images/rai_icon.png').readAsBytesSync();
    final out = await emb.embedImages([png, png]);
    final v = out.first!;
    expect(v.length, 384);
    expect(v.every((x) => x.isFinite), isTrue);
    expect(math.sqrt(v.fold<double>(0, (s, x) => s + x * x)), closeTo(1, 1e-3));
    expect(out[1], v, reason: '同じ絵は同じベクトル');
    emb.dispose();
  }, skip: model.existsSync() && lib ? false : '本物の ONNX と onnxruntime の共有ライブラリ(LD_LIBRARY_PATH)が要る');
}
