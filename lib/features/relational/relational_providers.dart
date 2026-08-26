import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_ml.dart';

class RelationalSettingsStore extends Notifier<RelationalSettings> {
  @override
  RelationalSettings build() => const RelationalSettings();

  void set(RelationalSettings next) => state = next;
}

final relationalSettingsProvider = NotifierProvider<RelationalSettingsStore, RelationalSettings>(RelationalSettingsStore.new);

/// ML ゲートウェイ (D-024)。`--dart-define=RASQ_ML_BASE_URL=https://…` を
/// 渡すと Triton(+vLLM)実配線、無指定なら null(ルールベースのみで動く)。
/// マニフェストは同梱アセット(assets/models/*.model.json)。
final mlGatewayProvider = FutureProvider<MlGateway?>((ref) async {
  const baseUrl = String.fromEnvironment('RASQ_ML_BASE_URL');
  if (baseUrl.isEmpty) return null;
  final manifests = <String, MlModelManifest>{};
  for (final asset in ['assets/models/gliner-ner.model.json', 'assets/models/siglip-similarity.model.json']) {
    final m = MlModelManifest.fromJson((jsonDecode(await rootBundle.loadString(asset)) as Map).cast<String, Object?>());
    manifests[m.id] = m;
  }
  final base = Uri.parse(baseUrl);
  // デバイス実行器(onnx runtime + GPU EP)はモデル配布(M4 ストア)と一緒に
  // 注入する — それまでは常にサーバー配置(Triton/vLLM 側 GPU)。
  return MlGateway(manifests: manifests, triton: TritonExecutor(baseUrl: base), vllm: VllmExecutor(baseUrl: base));
});

/// SigLIP EMA + Louvain の解析結果(ゲートウェイ無し/失敗時は null)。
final relationalMlProvider = FutureProvider<RelationalMlResult?>((ref) async {
  final gateway = await ref.watch(mlGatewayProvider.future);
  if (gateway == null) return null;
  final home = await ref.watch(timelineProvider(TimelineKind.home).future);
  final session = ref.read(currentSnsSessionProvider);
  final supportsLocal = session?.timelines.contains(TimelineKind.local) ?? false;
  final local = supportsLocal ? ref.watch(timelineProvider(TimelineKind.local)).value : null;
  try {
    final pipeline = ref.watch(relationalPipelineProvider(gateway));
    return await pipeline.analyze(home.posts, extraPosts: local?.posts ?? const []);
  } on MlUnavailableException {
    return null; // サーバー不達 → ルールベースに縮退
  }
});

/// EMA ストアを持ち回るためのパイプラインのキャッシュ。
final relationalPipelineProvider = Provider.family<RelationalMlPipeline, MlGateway>((ref, gateway) => RelationalMlPipeline(gateway: gateway));

/// フォロイーTL(home)+ 候補(local があれば)からクラスタを組む。
/// ML 解析があれば SigLIP 類似度 + Louvain コミュニティ制限で、無ければ
/// ルールベースで束ねる。
final relationalClustersProvider = Provider<AsyncValue<List<RelationalCluster>>>((ref) {
  final settings = ref.watch(relationalSettingsProvider);
  final session = ref.watch(currentSnsSessionProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home));
  final supportsLocal = session?.timelines.contains(TimelineKind.local) ?? false;
  final local = supportsLocal ? ref.watch(timelineProvider(TimelineKind.local)) : null;
  final ml = ref.watch(relationalMlProvider).value;

  return home.whenData((h) {
    final followeePosts = h.posts;
    final followeeKeys = {for (final p in followeePosts) p.key};
    final candidates = [
      for (final p in local?.value?.posts ?? const <Post>[])
        if (!followeeKeys.contains(p.key)) p,
    ];
    final engine = RelationalEngine(settings: settings, similarity: ml?.postSimilarity);
    return engine.build(followeePosts: followeePosts, candidatePosts: candidates, communityOf: ml?.communityOf);
  });
});
