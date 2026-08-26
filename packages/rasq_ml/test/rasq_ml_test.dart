import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:test/test.dart';

/// UTF-8 ボディの疑似レスポンス(http.Response(String) は latin-1 固定のため)。
http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

MlModelManifest manifest(String id, {bool device = false, String engine = 'triton'}) => MlModelManifest.fromJson({
      'id': id,
      'version': '0.1.0',
      'task': 'custom',
      'io': {'input': 'texts', 'output': 'tensors'},
      'runtimes': {
        if (device)
          'onnx': {
            'file': 'models/x.onnx',
            'inputs': [
              {'name': 'input_ids', 'dtype': 'int64', 'shape': [1, 'seq'], 'semantic': 'token_ids'},
            ],
            'outputs': [
              {'name': 'logits', 'dtype': 'float32', 'shape': [1, 'labels'], 'semantic': 'logits'},
            ],
          },
        'server': {'engine': engine, 'model': 'server-model'},
      },
      'placement': {
        'prefer': ['device', 'server'],
      },
    });

void main() {
  group('MlGateway', () {
    test('Triton KServe v2: BYTES-JSON 往復と placement 解決(デバイス不可→サーバー)', () async {
      Uri? posted;
      Object? postedBody;
      final gateway = MlGateway(
        manifests: {'m/gliner': manifest('m/gliner')},
        glinerModelId: 'm/gliner',
        triton: TritonExecutor(
          baseUrl: Uri.parse('https://ml.example'),
          post: (url, {headers, body}) async {
            posted = url;
            postedBody = body;
            final out = jsonEncode({
              'entities': [
                [
                  {'text': 'ストラトローンチ', 'label': 'product', 'score': 0.91},
                ],
              ],
            });
            return jsonResponse({
              'outputs': [
                {'name': 'OUTPUT', 'datatype': 'BYTES', 'shape': [1], 'data': [out]},
              ],
            });
          },
        ),
      );

      final entities = await gateway.zeroShotEntities(['ストラトローンチ発射!'], labels: ['product', 'person']);
      expect(posted.toString(), 'https://ml.example/v2/models/server-model/infer');
      final sent = jsonDecode('$postedBody') as Map;
      final inner = jsonDecode(((sent['inputs'] as List).first as Map)['data'].first as String) as Map;
      expect(inner['labels'], ['product', 'person']);
      expect(entities.single.single.text, 'ストラトローンチ');
      expect(entities.single.single.score, closeTo(0.91, 1e-9));
    });

    test('embedTexts は L2 正規化して返す', () async {
      final gateway = MlGateway(
        manifests: {'m/siglip': manifest('m/siglip')},
        siglipModelId: 'm/siglip',
        triton: TritonExecutor(
          baseUrl: Uri.parse('https://ml.example'),
          post: (url, {headers, body}) async => jsonResponse({
            'outputs': [
              {
                'name': 'OUTPUT',
                'datatype': 'BYTES',
                'shape': [1],
                'data': [
                  jsonEncode({
                    'embeddings': [
                      [3.0, 4.0],
                    ],
                  }),
                ],
              },
            ],
          }),
        ),
      );
      final vec = (await gateway.embedTexts(['x'])).single;
      expect(vec[0], closeTo(0.6, 1e-6));
      expect(vec[1], closeTo(0.8, 1e-6));
    });

    test('vLLM: OpenAI 互換 chat', () async {
      final gateway = MlGateway(
        manifests: {'m/gen': manifest('m/gen', engine: 'vllm')},
        vllm: VllmExecutor(
          baseUrl: Uri.parse('https://llm.example'),
          post: (url, {headers, body}) async {
            expect(url.path, '/v1/chat/completions');
            return jsonResponse({
              'choices': [
                {'message': {'role': 'assistant', 'content': '要約です'}},
              ],
            });
          },
        ),
      );
      final r = await gateway.infer('m/gen', {'prompt': 'まとめて'});
      expect(r.output['text'], '要約です');
      expect(r.runtime, 'vllm');
      expect(r.placement, MlPlacement.server);
    });

    test('デバイス実行器があればそちらが優先される', () async {
      final gateway = MlGateway(
        manifests: {'m/x': manifest('m/x', device: true)},
        device: _FakeDevice(),
        triton: TritonExecutor(baseUrl: Uri.parse('https://ml.example'), post: (u, {headers, body}) async => http.Response('should not reach', 500)),
      );
      final r = await gateway.infer('m/x', {'texts': []});
      expect(r.placement, MlPlacement.device);
      expect(r.runtime, 'onnx');
    });

    test('実行先が無ければ MlUnavailableException', () async {
      final gateway = MlGateway(manifests: {'m/x': manifest('m/x')});
      expect(() => gateway.infer('m/x', {}), throwsA(isA<MlUnavailableException>()));
      expect(() => gateway.infer('unknown', {}), throwsA(isA<MlUnavailableException>()));
    });
  });

  group('FolloweeEmbeddingStore (EMA)', () {
    test('EMA が直近の話題へ追従し、類似度は (cos+1)/2', () {
      final store = FolloweeEmbeddingStore(alpha: 0.5);
      store.update('a', [1, 0]);
      store.update('b', [1, 0]);
      store.update('c', [0, 1]);
      expect(store.similarity('a', 'b'), closeTo(1.0, 1e-9));
      expect(store.similarity('a', 'c'), closeTo(0.5, 1e-9));
      // c が a と同じ話題を続けると近づく。
      store.update('c', [1, 0]);
      store.update('c', [1, 0]);
      expect(store.similarity('a', 'c'), greaterThan(0.9));
    });

    test('graph は minSimilarity 未満の辺を落とす', () {
      final store = FolloweeEmbeddingStore();
      store.update('a', [1, 0]);
      store.update('b', [0.9, 0.1]);
      store.update('c', [0, 1]);
      final g = store.graph(minSimilarity: 0.9);
      expect(g['a']!.containsKey('b'), isTrue);
      expect(g['a']!.containsKey('c'), isFalse);
    });
  });

  group('louvain', () {
    test('2 つの密なコミュニティを分離する', () {
      // A: a1-a2-a3 完全グラフ / B: b1-b2-b3 完全グラフ、間は弱い橋 1 本。
      final g = <String, Map<String, double>>{
        'a1': {'a2': 1, 'a3': 1, 'b1': 0.05},
        'a2': {'a1': 1, 'a3': 1},
        'a3': {'a1': 1, 'a2': 1},
        'b1': {'b2': 1, 'b3': 1, 'a1': 0.05},
        'b2': {'b1': 1, 'b3': 1},
        'b3': {'b1': 1, 'b2': 1},
      };
      final c = louvain(g);
      expect(c['a1'], c['a2']);
      expect(c['a2'], c['a3']);
      expect(c['b1'], c['b2']);
      expect(c['b2'], c['b3']);
      expect(c['a1'], isNot(c['b1']));
    });

    test('空グラフと孤立ノード', () {
      expect(louvain({}), isEmpty);
      final c = louvain({'x': {}, 'y': {}});
      expect(c.keys, containsAll(['x', 'y']));
    });
  });
}

class _FakeDevice implements MlDeviceExecutor {
  @override
  bool canRun(MlModelManifest manifest) => manifest.runsOnDevice;

  @override
  Future<Map<String, Object?>> inferJson(MlModelManifest manifest, Map<String, Object?> input) async => {'ok': true};

  @override
  String get runtime => 'onnx';
}
