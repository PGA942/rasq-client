import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_ml.dart';

/// 設定の永続化キー(FOW チューニングの実測値をセッションを跨いで保持)。
const relationalSettingsStorageKey = 'relational.settings.v1';

class RelationalSettingsStore extends Notifier<RelationalSettings> {
  @override
  RelationalSettings build() {
    // 同期 build なので保存値は後追いで復元(壊れた値は既定のまま)。
    Future(() async {
      try {
        final raw = await ref.read(sessionStorageProvider).read(relationalSettingsStorageKey);
        if (raw != null) state = RelationalSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (_) {}
    });
    return const RelationalSettings();
  }

  void set(RelationalSettings next) {
    state = next;
    ref.read(sessionStorageProvider).write(relationalSettingsStorageKey, jsonEncode(next.toJson()));
  }

  void reset() => set(const RelationalSettings());
}

final relationalSettingsProvider = NotifierProvider<RelationalSettingsStore, RelationalSettings>(RelationalSettingsStore.new);

/// 遡り表示の窓(分)。0 = 通常(ACTIVE のみ)。リスト末尾(または空の状態)で
/// 引っ張るたびに +30 分ずつ広がり、TTL で沈んだ過去の空リプ会話も表示に
/// 含める(D-028: アクティブフォロイーが少ないとき対策)。リフレッシュで戻る。
class RelationalLookbackStore extends Notifier<int> {
  static const stepMinutes = 30;
  static const maxMinutes = 12 * 60;

  @override
  int build() => 0;

  /// 1 段階(30分)遡る。広がったら true。
  bool extend() {
    if (state >= maxMinutes) return false;
    state = (state + stepMinutes).clamp(0, maxMinutes);
    return true;
  }

  void reset() => state = 0;
}

final relationalLookbackProvider = NotifierProvider<RelationalLookbackStore, int>(RelationalLookbackStore.new);

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
  for (final asset in ['assets/models/gliner-ner.model.json', 'assets/models/siglip-similarity.model.json', 'assets/models/astell-summarizer.model.json']) {
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
  try {
    final store = await ref.watch(relationalEmaStoreProvider.future);
    final pipeline = RelationalMlPipeline(gateway: gateway, store: store);
    final result = await pipeline.analyze(home.posts);
    await ref.read(sessionStorageProvider).write(relationalEmaStorageKey, jsonEncode(store.toJson()));
    return result;
  } on MlUnavailableException {
    return null; // サーバー不達 → ルールベースに縮退
  }
});

/// フォロイーTL(home)から**会話イベント**を組む (D-027)。
/// GTL/LTL 候補の連結は廃止(人気話題が複数コミュニティを誤結合するハブに
/// なるため)。ML 解析があれば SigLIP 類似度と Louvain コミュニティ
/// (事前分布)がリンク採点に入る。
/// イベントの ASTell 要約(D-029)。イベント id ごとに 1 回だけ計算する
/// (`ref.read` なので投稿追加では再要約しない — 実測後に見直し)。
/// ゲートウェイ未構成/実行手段なしは null → カードは要約なしで表示。
final eventSummaryProvider = FutureProvider.family<String?, String>((ref, eventId) async {
  final gateway = await ref.watch(mlGatewayProvider.future);
  if (gateway == null) return null;
  final events = ref.read(conversationEventsProvider).value ?? const [];
  ConversationEvent? event;
  for (final e in events) {
    if (e.id == eventId) {
      event = e;
      break;
    }
  }
  if (event == null) return null;
  final text = [for (final p in event.posts.take(12)) '${p.author.displayName}: ${p.body}'].join('\n');
  return gateway.summarize('次の会話を1文で要約:\n$text');
});

final conversationEventsProvider = Provider<AsyncValue<List<ConversationEvent>>>((ref) {
  final settings = ref.watch(relationalSettingsProvider);
  final lookbackMinutes = ref.watch(relationalLookbackProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home));
  final ml = ref.watch(relationalMlProvider).value;

  return home.whenData((h) {
    final engine = ConversationEngine(settings: settings, semantic: ml?.postSimilarity, communityOf: ml?.communityOf);
    return engine.build(followeePosts: h.posts, lookback: lookbackMinutes > 0 ? Duration(minutes: lookbackMinutes) : null);
  });
});
