import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';

import '../child_safe/child_safe_providers.dart';
import '../relational/relational_providers.dart';
import 'rai_embedding_model.dart';
import 'rai_reference.dart';

/// リファレンスの置き場(jsonl アセット、D-189)。
const raiFunctionsAsset = 'assets/rai/functions.jsonl';
const raiOperationsAsset = 'assets/rai/operations.jsonl';
const raiEvalAsset = 'assets/rai/eval.jsonl';

/// SigLIP のテキスト塔(ML ゲートウェイ `embedTexts`)を [RaiEmbedder] に載せる。
class GatewayRaiEmbedder implements RaiEmbedder {
  const GatewayRaiEmbedder(this.gateway);
  final MlGateway gateway;
  @override
  String get name => 'siglip';
  @override
  Future<List<List<double>>> embed(List<String> texts) async => [for (final v in await gateway.embedTexts(texts)) v.toList()];
}

/// 埋め込み (D-190): 端末内の SigLIP2(ダウンロード済み)→ ML ゲートウェイの SigLIP → n-gram(同じ契約)。
/// 端末内モデルの状態が変わる(ダウンロード完了 / 削除)と索引も組み直す。
final raiEmbedderProvider = FutureProvider<RaiEmbedder>((ref) async {
  final st = ref.watch(raiEmbeddingStatusProvider).value;
  if (st != null && st.ready) {
    final e = await ref.watch(raiEmbeddingModelProvider).embedder();
    if (e != null) return e;
  }
  MlGateway? gw;
  try {
    gw = await ref.watch(mlGatewayProvider.future);
  } catch (_) {
    gw = null;
  }
  return gw == null ? const NgramRaiEmbedder() : GatewayRaiEmbedder(gw);
});

/// 関数 / 操作リファレンスを読み込んで索引を組む(アプリで 1 回)。絞らない元の索引(案内には [raiReferenceProvider])。
final raiReferenceBaseProvider = FutureProvider<RaiReferenceIndex>((ref) async {
  final embedder = await ref.watch(raiEmbedderProvider.future);
  return RaiReferenceIndex.fromJsonl(
    functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
    operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
    embedder: embedder,
  );
});

/// RAi が使う索引 (D-309): 見守り中 (D-307) は、保護者が許していないまとまり / 機能 / 画面の関数と、それを手順に使う
/// 操作を隠す([RaiReferenceIndex.restrictTo]、[ChildGate.raiGuideAllowed])。検索の結果・操作の案内・`reference.get`・
/// 候補の一覧はどれもここから引くので、止めた操作へ子を案内しない。見守られていなければ元の索引そのもの。
/// 制限が変わったとき(と見守りの時間の出入り)だけ絞り直す(埋め込みは組み直さない)。
final raiReferenceProvider = FutureProvider<RaiReferenceIndex>((ref) async {
  ref.watch(childGateProvider.select((g) => g.raiGuideSignature));
  final base = await ref.watch(raiReferenceBaseProvider.future);
  final gate = ref.read(childGateProvider);
  if (!gate.supervised) return base;
  return base.restrictTo(allowFunction: (f) => gate.raiGuideAllowed(f.id, f.group, f.route), allowRoute: gate.raiGuideRouteAllowed);
});
