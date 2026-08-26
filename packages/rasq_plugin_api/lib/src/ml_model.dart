import 'package:meta/meta.dart';

/// Host-function names (PROTOCOL §4 / rasq-sdk-sample schema/host-fn.schema.json).
/// The plugin_runtime dispatcher switches on these.
abstract final class RasqHostFns {
  static const fowOpen = 'fow.open';
  static const fowClose = 'fow.close';
  static const alert = 'alert';
  static const storageGet = 'storage.get';
  static const storageSet = 'storage.set';
  static const storageDelete = 'storage.delete';
  static const netFetch = 'net.fetch';
  static const mlInfer = 'ml.infer';
  static const wasmCall = 'wasm.call';
  static const storeRead = 'store.read';
  static const geometryLookup = 'geometry.lookup';
}

/// Where an `ml.infer` call actually ran (returned to the plugin).
enum MlPlacement { device, server }

enum MlTask { classification, embedding, generation, custom }

/// One ML model a plugin uses through `ml.infer`, parsed from
/// `model-manifest.schema.json`. The manifest lists every runtime the model
/// ships for — on-device (`onnx` = onnx runtime, `llama` = llama.cpp) and
/// server (`server` = Triton Inference Server / vLLM) — and the **host**
/// resolves placement per device/policy (D-018). Plugins reference models by
/// [id] only; they never see endpoints or files.
@immutable
class MlModelManifest {
  const MlModelManifest({
    required this.id,
    required this.version,
    required this.task,
    required this.inputKind,
    required this.outputKind,
    this.labels = const [],
    this.onnx,
    this.llama,
    this.server,
    this.preferredPlacements = const [],
    this.minDeviceRamMb,
    this.allowMeteredDownload = false,
    this.license,
  });

  final String id;
  final String version;
  final MlTask task;

  /// Logical IO (`io.input` / `io.output`): text | texts | tokens | tensors | chat
  /// → labels | text | vector | tensors.
  final String inputKind;
  final String outputKind;
  final List<String> labels;

  final OnnxRuntimeSpec? onnx;
  final LlamaRuntimeSpec? llama;
  final ServerRuntimeSpec? server;

  final List<MlPlacement> preferredPlacements;
  final int? minDeviceRamMb;
  final bool allowMeteredDownload;
  final String? license;

  bool get runsOnDevice => onnx != null || llama != null;
  bool get runsOnServer => server != null;

  factory MlModelManifest.fromJson(Map<String, Object?> json) {
    final io = (json['io'] as Map?)?.cast<String, Object?>() ?? const {};
    final runtimes = (json['runtimes'] as Map?)?.cast<String, Object?>() ?? const {};
    final placement = (json['placement'] as Map?)?.cast<String, Object?>() ?? const {};
    return MlModelManifest(
      id: json['id'] as String,
      version: json['version'] as String,
      task: MlTask.values.asNameMap()[json['task']] ?? MlTask.custom,
      inputKind: io['input'] as String? ?? 'text',
      outputKind: io['output'] as String? ?? 'text',
      labels: [for (final l in (io['labels'] as List? ?? const [])) l as String],
      onnx: runtimes['onnx'] == null ? null : OnnxRuntimeSpec.fromJson((runtimes['onnx'] as Map).cast()),
      llama: runtimes['llama'] == null ? null : LlamaRuntimeSpec.fromJson((runtimes['llama'] as Map).cast()),
      server: runtimes['server'] == null ? null : ServerRuntimeSpec.fromJson((runtimes['server'] as Map).cast()),
      preferredPlacements: [
        for (final p in (placement['prefer'] as List? ?? const []))
          if (MlPlacement.values.asNameMap()[p] != null) MlPlacement.values.asNameMap()[p]!,
      ],
      minDeviceRamMb: (placement['minDeviceRamMb'] as num?)?.toInt(),
      allowMeteredDownload: placement['allowMeteredDownload'] == true,
      license: json['license'] as String?,
    );
  }
}

/// A tensor binding of an ONNX (or Triton) model. [shape] entries are `int`
/// for fixed dims or `String` for symbolic ones ('batch', 'seq', 'labels');
/// [semantic] tells the host how to fill/read it from the logical IO.
@immutable
class MlTensorSpec {
  const MlTensorSpec({required this.name, required this.dtype, required this.shape, this.semantic});

  final String name;
  final String dtype;
  final List<Object> shape;
  final String? semantic;

  factory MlTensorSpec.fromJson(Map<String, Object?> json) => MlTensorSpec(
        name: json['name'] as String,
        dtype: json['dtype'] as String,
        shape: [for (final d in (json['shape'] as List? ?? const [])) d as Object],
        semantic: json['semantic'] as String?,
      );
}

/// Tokenizer declaration for on-device text models.
@immutable
class MlTokenizerSpec {
  const MlTokenizerSpec({
    required this.type,
    this.file,
    this.maxTokens,
    this.lowercase = false,
    this.addBos = false,
    this.addEos = false,
    this.padding = 'none',
    this.special = const {},
  });

  /// sentencepiece | bpe | wordpiece | hf-tokenizer-json | none.
  final String type;
  final String? file;
  final int? maxTokens;
  final bool lowercase;
  final bool addBos;
  final bool addEos;

  /// none | max | longest.
  final String padding;

  /// bos/eos/pad/unk/cls/sep/mask → token text.
  final Map<String, String> special;

  factory MlTokenizerSpec.fromJson(Map<String, Object?> json) => MlTokenizerSpec(
        type: json['type'] as String,
        file: json['file'] as String?,
        maxTokens: (json['maxTokens'] as num?)?.toInt(),
        lowercase: json['lowercase'] == true,
        addBos: json['addBos'] == true,
        addEos: json['addEos'] == true,
        padding: json['padding'] as String? ?? 'none',
        special: (json['special'] as Map?)?.cast<String, String>() ?? const {},
      );
}

/// On-device execution via onnx runtime.
@immutable
class OnnxRuntimeSpec {
  const OnnxRuntimeSpec({required this.file, this.quantization, required this.inputs, required this.outputs, this.tokenizer, this.labelsFile, this.executionProviders = const ['cpu']});

  final String file;
  final String? quantization;
  final List<MlTensorSpec> inputs;
  final List<MlTensorSpec> outputs;
  final MlTokenizerSpec? tokenizer;
  final String? labelsFile;

  /// 実行プロバイダの希望順(GPU/NPU: cuda / tensorrt / coreml / nnapi / qnn / cpu)。
  final List<String> executionProviders;

  factory OnnxRuntimeSpec.fromJson(Map<String, Object?> json) => OnnxRuntimeSpec(
        file: json['file'] as String,
        quantization: json['quantization'] as String?,
        inputs: [for (final t in (json['inputs'] as List? ?? const [])) MlTensorSpec.fromJson((t as Map).cast())],
        outputs: [for (final t in (json['outputs'] as List? ?? const [])) MlTensorSpec.fromJson((t as Map).cast())],
        tokenizer: json['tokenizer'] == null ? null : MlTokenizerSpec.fromJson((json['tokenizer'] as Map).cast()),
        labelsFile: json['labelsFile'] as String?,
        executionProviders: [for (final e in (json['executionProviders'] as List? ?? const ['cpu'])) e as String],
      );
}

/// On-device execution via llama.cpp (GGUF).
@immutable
class LlamaRuntimeSpec {
  const LlamaRuntimeSpec({required this.file, this.promptTemplate, this.contextTokens, this.sampling = const {}});

  final String file;
  final String? promptTemplate;
  final int? contextTokens;

  /// temperature / topP / topK / maxTokens / stop.
  final Map<String, Object?> sampling;

  factory LlamaRuntimeSpec.fromJson(Map<String, Object?> json) => LlamaRuntimeSpec(
        file: json['file'] as String,
        promptTemplate: json['promptTemplate'] as String?,
        contextTokens: (json['contextTokens'] as num?)?.toInt(),
        sampling: (json['sampling'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

/// Server-side execution. The host owns endpoints and credentials.
@immutable
class ServerRuntimeSpec {
  const ServerRuntimeSpec({required this.engine, required this.model, this.openaiCompatible = false});

  /// triton | vllm.
  final String engine;

  /// Model name as registered on the serving stack.
  final String model;
  final bool openaiCompatible;

  factory ServerRuntimeSpec.fromJson(Map<String, Object?> json) => ServerRuntimeSpec(
        engine: json['engine'] as String,
        model: json['model'] as String,
        openaiCompatible: json['openaiCompatible'] == true,
      );
}
