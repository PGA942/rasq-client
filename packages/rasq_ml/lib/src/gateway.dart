import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// One zero-shot entity from GLiNER.
@immutable
class MlEntity {
  const MlEntity({required this.text, required this.label, this.score = 0});
  final String text;
  final String label;
  final double score;

  factory MlEntity.fromJson(Map<String, Object?> json) =>
      MlEntity(text: '${json['text']}', label: '${json['label']}', score: (json['score'] as num?)?.toDouble() ?? 0);
}

/// Result envelope (host-fn schema の `ml.infer` value と同形)。
@immutable
class MlResult {
  const MlResult({required this.output, required this.placement, required this.runtime});
  final Map<String, Object?> output;
  final MlPlacement placement;
  final String runtime; // onnx | llama | triton | vllm
}

class MlUnavailableException implements Exception {
  MlUnavailableException(this.message);
  final String message;
  @override
  String toString() => 'MlUnavailableException: $message';
}

/// デバイス側実行器(onnx runtime / llama.cpp)。
///
/// 実行プロバイダ(CUDA / CoreML / NNAPI / CPU)の選択とモデルファイルの
/// ロードは実装側の責務。onnx runtime の FFI バインディングを持つ実装を
/// [MlGateway.device] に注入する — 本体はモデル実体の配布(ストア審査,
/// M4)と一緒に載る。JSON-in/JSON-out はサーバー側と同じ論理IOを使う。
abstract class MlDeviceExecutor {
  /// この端末でこのマニフェストを実行できるか(RAM・EP・ファイル有無)。
  bool canRun(MlModelManifest manifest);

  Future<Map<String, Object?>> inferJson(MlModelManifest manifest, Map<String, Object?> input);

  /// 実際に使ったランタイム名(onnx / llama)。
  String get runtime;
}

/// HTTP POST(テストで差し替え)。
typedef MlHttpPost = Future<http.Response> Function(Uri url, {Map<String, String>? headers, Object? body});

Future<http.Response> _defaultPost(Uri url, {Map<String, String>? headers, Object? body}) =>
    http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

/// Triton Inference Server (KServe v2 REST)。
///
/// 前処理/後処理(トークナイズ・スパン復号)はサーバー側の ensemble /
/// python backend が担い、論理IOを **BYTES テンソル 1 本の JSON** で受け渡す
/// (manifest §runtimes.server の運用契約)。GPU はサーバー側。
class TritonExecutor {
  TritonExecutor({required this.baseUrl, MlHttpPost? post}) : _post = post ?? _defaultPost;

  /// 例: `https://ml.rasq.example`(認証・経路はホストの構成、プラグインからは不可視)。
  final Uri baseUrl;
  final MlHttpPost _post;

  Future<Map<String, Object?>> inferJson(String model, Map<String, Object?> input) async {
    final url = baseUrl.resolve('/v2/models/$model/infer');
    final body = jsonEncode({
      'inputs': [
        {
          'name': 'INPUT',
          'datatype': 'BYTES',
          'shape': [1],
          'data': [jsonEncode(input)],
        }
      ],
      'outputs': [
        {'name': 'OUTPUT'}
      ],
    });
    final res = await _post(url, headers: {'Content-Type': 'application/json'}, body: body);
    if (res.statusCode != 200) {
      throw MlUnavailableException('Triton $model: HTTP ${res.statusCode} ${utf8.decode(res.bodyBytes, allowMalformed: true)}');
    }
    // charset ヘッダ無しの JSON を latin-1 で読まないよう bodyBytes を明示デコード。
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final outputs = decoded['outputs'] as List;
    final data = ((outputs.first as Map)['data'] as List).first;
    return (jsonDecode('$data') as Map).cast<String, Object?>();
  }
}

/// vLLM (OpenAI 互換 chat/completions) — generation タスク用。
class VllmExecutor {
  VllmExecutor({required this.baseUrl, MlHttpPost? post}) : _post = post ?? _defaultPost;

  final Uri baseUrl;
  final MlHttpPost _post;

  Future<String> chat(String model, List<Map<String, String>> messages, {double? temperature, int? maxTokens}) async {
    final res = await _post(
      baseUrl.resolve('/v1/chat/completions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': ?temperature,
        'max_tokens': ?maxTokens,
      }),
    );
    if (res.statusCode != 200) {
      throw MlUnavailableException('vLLM $model: HTTP ${res.statusCode} ${utf8.decode(res.bodyBytes, allowMalformed: true)}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return '${(((decoded['choices'] as List).first as Map)['message'] as Map)['content']}';
  }
}

/// モデルマニフェストを解決し、配置(デバイス/サーバー)を決めて推論する
/// ゲートウェイ(D-018: 配置はホストが解決、プラグインは id しか知らない)。
class MlGateway {
  MlGateway({
    required this.manifests,
    this.device,
    this.triton,
    this.vllm,
    this.glinerModelId = 'rasq.official.search/gliner-ner',
    this.siglipModelId = 'rasq.official.search/siglip-similarity',
  });

  final Map<String, MlModelManifest> manifests;
  final MlDeviceExecutor? device;
  final TritonExecutor? triton;
  final VllmExecutor? vllm;
  final String glinerModelId;
  final String siglipModelId;

  MlModelManifest manifestOf(String modelId) {
    final m = manifests[modelId];
    if (m == null) throw MlUnavailableException('unknown model: $modelId');
    return m;
  }

  /// `ml.infer` 相当: 配置を解決して JSON 論理IOで推論する。
  /// 優先順は manifest.placement.prefer(既定: device → server)。
  Future<MlResult> infer(String modelId, Map<String, Object?> input, {MlPlacement? hint}) async {
    final manifest = manifestOf(modelId);
    final prefer = <MlPlacement>[
      ?hint,
      ...manifest.preferredPlacements,
      MlPlacement.device,
      MlPlacement.server,
    ];
    final tried = <String>[];
    for (final placement in prefer) {
      switch (placement) {
        case MlPlacement.device:
          final d = device;
          if (d != null && manifest.runsOnDevice && d.canRun(manifest)) {
            return MlResult(output: await d.inferJson(manifest, input), placement: MlPlacement.device, runtime: d.runtime);
          }
          tried.add('device');
        case MlPlacement.server:
          final server = manifest.server;
          if (server != null) {
            if (server.engine == 'vllm') {
              final v = vllm;
              if (v != null) {
                final text = await v.chat(server.model, [
                  {'role': 'user', 'content': '${input['prompt'] ?? jsonEncode(input)}'},
                ]);
                return MlResult(output: {'text': text}, placement: MlPlacement.server, runtime: 'vllm');
              }
            } else {
              final t = triton;
              if (t != null) {
                return MlResult(output: await t.inferJson(server.model, input), placement: MlPlacement.server, runtime: 'triton');
              }
            }
          }
          tried.add('server');
      }
    }
    throw MlUnavailableException('$modelId: no runnable placement (tried: ${tried.toSet().join(', ')})');
  }

  /// GLiNER(多言語ゼロショット NER): texts × labels → entities。
  Future<List<List<MlEntity>>> zeroShotEntities(List<String> texts, {required List<String> labels}) async {
    final result = await infer(glinerModelId, {'texts': texts, 'labels': labels});
    final rows = result.output['entities'] as List? ?? const [];
    return [
      for (final row in rows)
        [for (final e in (row as List? ?? const [])) MlEntity.fromJson((e as Map).cast<String, Object?>())],
    ];
  }

  /// SigLIP(多言語)テキスト埋め込み。返りは L2 正規化済みベクトル。
  Future<List<Float32List>> embedTexts(List<String> texts) async {
    final result = await infer(siglipModelId, {'texts': texts});
    final rows = result.output['embeddings'] as List? ?? const [];
    return [for (final row in rows) _normalize([for (final v in (row as List)) (v as num).toDouble()])];
  }

  static Float32List _normalize(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = norm == 0 ? 1 : math.sqrt(norm);
    return Float32List.fromList([for (final x in v) x / norm]);
  }
}
