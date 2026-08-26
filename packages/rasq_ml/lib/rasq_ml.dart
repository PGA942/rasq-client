/// RASQ ML gateway (D-022 / D-024)。
///
/// - [MlGateway]: モデルマニフェスト(`model-manifest.schema.json`)を解決し、
///   デバイス(onnx runtime, GPU EP)/ サーバー(Triton / vLLM, GPU)へ配置して
///   推論する。プラグイン/画面はマニフェスト id しか知らない(D-018)。
/// - [FolloweeEmbeddingStore]: フォロイー毎の SigLIP 特徴量の指数移動平均(EMA)。
/// - [louvain]: 重み付き Louvain 法 — EMA 類似グラフをコミュニティ分割し、
///   リレーショナルTL の類似判定をコミュニティ内に限定して計算量を削減する。
library;

export 'src/ema_store.dart';
export 'src/gateway.dart';
export 'src/louvain.dart';
