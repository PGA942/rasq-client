import 'dart:convert';
import 'dart:io';

import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  test('reaction-predictor: onnx (tokenizer + tensors) + Triton server', () {
    final m = MlModelManifest.fromJson(fixture('reaction-predictor.model.json'));
    expect(m.id, 'rasq.official.misskey/reaction-predictor');
    expect(m.task, MlTask.classification);
    expect(m.inputKind, 'text');
    expect(m.outputKind, 'labels');
    expect(m.runsOnDevice, isTrue);
    expect(m.runsOnServer, isTrue);

    final onnx = m.onnx!;
    expect(onnx.quantization, 'int8');
    expect(onnx.inputs.map((t) => t.semantic), containsAll(['token_ids', 'attention_mask']));
    expect(onnx.inputs.first.shape, [1, 'seq']);
    expect(onnx.outputs.single.semantic, 'logits');
    expect(onnx.tokenizer!.type, 'sentencepiece');
    expect(onnx.tokenizer!.maxTokens, 128);
    expect(onnx.tokenizer!.addBos, isTrue);
    expect(onnx.labelsFile, 'models/reaction_labels.json');

    expect(m.server!.engine, 'triton');
    expect(m.preferredPlacements, [MlPlacement.device, MlPlacement.server]);
    expect(m.minDeviceRamMb, 512);
  });

  test('astell-summarizer: llama.cpp (gguf) + vLLM server', () {
    final m = MlModelManifest.fromJson(fixture('astell-summarizer.model.json'));
    expect(m.task, MlTask.generation);
    expect(m.inputKind, 'chat');
    expect(m.llama!.file, endsWith('.gguf'));
    expect(m.llama!.promptTemplate, contains('{input}'));
    expect(m.llama!.sampling['maxTokens'], 256);
    expect(m.server!.engine, 'vllm');
    expect(m.server!.openaiCompatible, isTrue);
    expect(m.preferredPlacements.first, MlPlacement.server);
  });

  test('host fn name constants match the schema', () {
    expect(RasqHostFns.mlInfer, 'ml.infer');
    expect(RasqHostFns.netFetch, 'net.fetch');
    expect(RasqHostFns.storageSet, 'storage.set');
    expect(RasqHostFns.geometryLookup, 'geometry.lookup');
  });
}
