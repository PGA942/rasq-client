import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_ml.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
final now = DateTime(2026, 8, 25, 12);

Post post(String id, String author, String body, {Duration age = Duration.zero}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: now.subtract(age),
      body: body,
    );

/// SigLIP の疑似埋め込み: ロケット系 → [1,0]、ごはん系 → [0,1]。
List<double> fakeEmbedding(String text) => text.contains('ロケット') ? [1.0, 0.0] : (text.contains('ごはん') ? [0.0, 1.0] : [0.7, 0.7]);

MlGateway fakeGateway() {
  final manifest = MlModelManifest.fromJson({
    'id': 'rasq.official.search/siglip-similarity',
    'version': '0.1.0',
    'task': 'embedding',
    'io': {'input': 'tensors', 'output': 'vector'},
    'runtimes': {
      'server': {'engine': 'triton', 'model': 'siglip'},
    },
  });
  return MlGateway(
    manifests: {manifest.id: manifest},
    triton: TritonExecutor(
      baseUrl: Uri.parse('https://ml.example'),
      post: (url, {headers, body}) async {
        final sent = jsonDecode('$body') as Map;
        final input = jsonDecode(((sent['inputs'] as List).first as Map)['data'].first as String) as Map;
        final texts = (input['texts'] as List).cast<String>();
        final out = jsonEncode({'embeddings': [for (final t in texts) fakeEmbedding(t)]});
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'outputs': [
              {'name': 'OUTPUT', 'datatype': 'BYTES', 'shape': [1], 'data': [out]},
            ],
          })),
          200,
        );
      },
    ),
  );
}

void main() {
  test('SigLIP EMA → Louvain → コミュニティ制限つきクラスタリング (D-024)', () async {
    // 全員が同じ #daily を使う → ルールベースだけなら束なってしまう状況。
    final followees = [
      post('r1', 'rocketA', '#daily ロケットの話', age: const Duration(minutes: 5)),
      post('r2', 'rocketB', '#daily ロケット打ち上げ', age: const Duration(minutes: 4)),
      post('f1', 'foodC', '#daily 今日のごはん', age: const Duration(minutes: 3)),
      post('f2', 'foodD', '#daily ごはんが美味しい', age: const Duration(minutes: 2)),
    ];

    final pipeline = RelationalMlPipeline(gateway: fakeGateway());
    final ml = await pipeline.analyze(followees);

    // Louvain: ロケット組とごはん組が別コミュニティに分かれる。
    final c = ml.communityOf;
    expect(c['misskey:misskey.io:rocketA'], c['misskey:misskey.io:rocketB']);
    expect(c['misskey:misskey.io:foodC'], c['misskey:misskey.io:foodD']);
    expect(c['misskey:misskey.io:rocketA'], isNot(c['misskey:misskey.io:foodC']));

    // 投稿間類似度は実 cos(直交 → 0.5、同方向 → 1.0)。
    expect(ml.postSimilarity(followees[0], followees[1]), closeTo(1.0, 1e-6));
    expect(ml.postSimilarity(followees[0], followees[2]), closeTo(0.5, 1e-6));

    // エンジン: コミュニティ制限 + SigLIP 類似度 → 2 クラスタに分かれる
    // (ルールベースなら #daily 共有で 1 つに潰れる)。
    const engine = RelationalEngine(settings: RelationalSettings(threshold: 75, staleMinutes: 60));
    final ruleBased = engine.build(followeePosts: followees, now: now);
    expect(ruleBased, hasLength(1), reason: '前提: ルールベースだと 1 束');

    final restricted = RelationalEngine(
      settings: const RelationalSettings(threshold: 75, staleMinutes: 60),
      similarity: ml.postSimilarity,
    ).build(followeePosts: followees, communityOf: ml.communityOf, now: now);
    expect(restricted, hasLength(2));
    for (final cluster in restricted) {
      final authors = cluster.members.map((u) => u.displayName).toSet();
      expect(authors, anyOf(equals({'rocketA', 'rocketB'}), equals({'foodC', 'foodD'})));
    }
  });

  test('EMA はセッションを通して追従する(store 持ち回り)', () async {
    final pipeline = RelationalMlPipeline(gateway: fakeGateway());
    await pipeline.analyze([post('1', 'a', 'ロケット', age: const Duration(minutes: 2))]);
    final before = pipeline.store.emaOf('misskey:misskey.io:a')!;
    expect(before[0], closeTo(1.0, 1e-6));
    // 同じ著者がごはんの話を続ける → EMA が動く。
    await pipeline.analyze([post('2', 'a', 'ごはん', age: const Duration(minutes: 1))]);
    final after = pipeline.store.emaOf('misskey:misskey.io:a')!;
    expect(after[1], greaterThan(0.2));
  });
}
