import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/emoji/emoji_image_embedder_onnx.dart';
import '../features/emoji/emoji_index_providers.dart';
import '../features/rai/rai_embedding_model.dart';
import '../features/rai/rai_embedding_model_device.dart';
import '../features/rai/rai_llm.dart';
import '../features/rai/rai_llm_device.dart';

/// 端末の実装: RAi の端末内モデル (D-181) は flutter_gemma(LiteRT-LM)、埋め込みは onnxruntime。テストは既定(使えない骨格)か偽物。
List<Override> deviceOverrides() => [
      raiLlmProvider.overrideWith((_) => DeviceRaiLlm()),
      deviceRamReaderProvider.overrideWithValue(deviceRamReader),
      raiEmbeddingModelProvider.overrideWith((_) => DeviceRaiEmbeddingModel()),
      // 絵文字の画像検索 (D-293): SigLIP2 のテキスト側 + 画像側。
      emojiTextModelProvider.overrideWith((_) => DeviceRaiEmbeddingModel(spec: raiSiglip2EmbeddingSpec)),
      emojiVisionModelProvider.overrideWith((_) => DeviceRaiEmbeddingModel(spec: emojiVisionEmbeddingSpec)),
      emojiImageEmbedderLoaderProvider.overrideWithValue((model) async {
        if (model is! DeviceRaiEmbeddingModel) return null;
        final file = await model.installedFile();
        if (file == null) return null;
        final e = await OnnxEmojiImageEmbedder.load(model: file);
        return (embedder: e, dispose: e.dispose);
      }),
    ];

/// 起動時の支度。端末では何もしない(Web 版は zstd の wasm を読み込む)。
Future<void> prepareDeviceRuntime() async {}
