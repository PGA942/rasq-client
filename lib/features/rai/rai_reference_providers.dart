import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';

import '../relational/relational_providers.dart';
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

/// 埋め込み: ゲートウェイがあれば SigLIP、無ければ n-gram(同じ契約)。テストで差し替える。
final raiEmbedderProvider = FutureProvider<RaiEmbedder>((ref) async {
  MlGateway? gw;
  try {
    gw = await ref.watch(mlGatewayProvider.future);
  } catch (_) {
    gw = null;
  }
  return gw == null ? const NgramRaiEmbedder() : GatewayRaiEmbedder(gw);
});

/// 関数 / 操作リファレンスを読み込んで索引を組む(アプリで 1 回)。
final raiReferenceProvider = FutureProvider<RaiReferenceIndex>((ref) async {
  final embedder = await ref.watch(raiEmbedderProvider.future);
  return RaiReferenceIndex.fromJsonl(
    functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
    operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
    embedder: embedder,
  );
});
