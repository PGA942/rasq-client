import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_ml.dart';

class RelationalSettingsStore extends Notifier<RelationalSettings> {
  @override
  RelationalSettings build() => const RelationalSettings();

  void set(RelationalSettings next) => state = next;
}

final relationalSettingsProvider = NotifierProvider<RelationalSettingsStore, RelationalSettings>(RelationalSettingsStore.new);

/// 直近 10 分の HTL 流入投稿数(D-024 追補「HTL アクティブ数」— ローカル
/// SigLIP 実行の可否判定に使う)。
int activeHtlPostCount(Ref ref, {DateTime? now}) {
  final posts = ref.read(timelineProvider(TimelineKind.home)).value?.posts ?? const [];
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(minutes: 10));
  return posts.where((p) => p.createdAt.isAfter(cutoff)).length;
}

/// ML ゲートウェイ (D-024)。`--dart-define=RASQ_ML_BASE_URL=https://…` を
/// 渡すと Triton(+vLLM)実配線、無指定なら null(ルールベースのみで動く)。
/// マニフェストは同梱アセット(assets/models/*.model.json)。
///
/// ローカル SigLIP: `DevicePolicy`(CPU < 75% かつ HTL アクティブ数 ≤ 30)で
/// 判定。サーバー未構成ならローカルへ倒す(試験手段がローカルしか無いため)。
/// デバイス実行器そのもの(onnx runtime + GPU/NPU EP)はモデル実体の配布
/// (M4 ストア)と同時に `device:` へ注入する。
final mlGatewayProvider = FutureProvider<MlGateway?>((ref) async {
  const baseUrl = String.fromEnvironment('RASQ_ML_BASE_URL');
  if (baseUrl.isEmpty) return null;
  final manifests = <String, MlModelManifest>{};
  for (final asset in ['assets/models/gliner-ner.model.json', 'assets/models/siglip-similarity.model.json']) {
    final m = MlModelManifest.fromJson((jsonDecode(await rootBundle.loadString(asset)) as Map).cast<String, Object?>());
    manifests[m.id] = m;
  }
  final base = Uri.parse(baseUrl);
  return MlGateway(
    manifests: manifests,
    triton: TritonExecutor(baseUrl: base),
    vllm: VllmExecutor(baseUrl: base),
    policy: const DevicePolicy(maxCpuUsage: 0.75, maxActiveHtlPosts: 30),
    cpuProbe: const ProcStatCpuProbe(),
    activeHtlPosts: () => activeHtlPostCount(ref),
  );
});

/// EMA の永続化キー(セッションを跨いでフォロイーの話題傾向を持ち回る)。
const relationalEmaStorageKey = 'relational.ema.v1';

/// 復元済み EMA ストア。壊れた保存値は新品にフォールバック。
final relationalEmaStoreProvider = FutureProvider<FolloweeEmbeddingStore>((ref) async {
  try {
    final raw = await ref.watch(sessionStorageProvider).read(relationalEmaStorageKey);
    if (raw != null) {
      return FolloweeEmbeddingStore.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    }
  } catch (_) {}
  return FolloweeEmbeddingStore();
});

/// SigLIP EMA + Louvain の解析結果(ゲートウェイ無し/失敗時は null)。
/// 解析のたびに EMA を保存する。
final relationalMlProvider = FutureProvider<RelationalMlResult?>((ref) async {
  final gateway = await ref.watch(mlGatewayProvider.future);
  if (gateway == null) return null;
  final home = await ref.watch(timelineProvider(TimelineKind.home).future);
  final session = ref.read(currentSnsSessionProvider);
  final supportsLocal = session?.timelines.contains(TimelineKind.local) ?? false;
  final local = supportsLocal ? ref.watch(timelineProvider(TimelineKind.local)).value : null;
  try {
    final store = await ref.watch(relationalEmaStoreProvider.future);
    final pipeline = RelationalMlPipeline(gateway: gateway, store: store);
    final result = await pipeline.analyze(home.posts, extraPosts: local?.posts ?? const []);
    await ref.read(sessionStorageProvider).write(relationalEmaStorageKey, jsonEncode(store.toJson()));
    return result;
  } on MlUnavailableException {
    return null; // サーバー不達 → ルールベースに縮退
  }
});

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
