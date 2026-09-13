import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rai_reference.dart';

/// リファレンス検索の埋め込みモデル (D-190): SigLIP2 のテキスト塔(int8 ONNX、283 MB)を端末に
/// ダウンロードして onnxruntime で回す。トークナイザー(4 MB)はアプリに同梱。
/// 未ダウンロード / 失敗時は n-gram 代替(同じ契約)で検索する。
/// 埋め込みモデルの種類(トークナイザーと入出力の形が違う)。
enum RaiEmbeddingKind {
  /// SigLIP2 テキスト塔: input_ids[n,64] → pooler_output(D-190)。
  siglip2,

  /// 文埋め込み(MiniLM 系): input_ids / attention_mask / token_type_ids → last_hidden_state を平均(D-193)。
  minilm,
}

@immutable
class RaiEmbeddingSpec {
  const RaiEmbeddingSpec({required this.id, required this.label, required this.fileName, required this.url, required this.sizeMb, required this.tokenizerAsset, required this.dims, this.kind = RaiEmbeddingKind.minilm, this.maxLen = 128});
  final String id;
  final RaiEmbeddingKind kind;
  final int maxLen;
  final String label;
  final String fileName;
  final String url;
  final int sizeMb;
  final String tokenizerAsset;
  final int dims;
}

/// 既定 (D-193): paraphrase-multilingual-MiniLM-L12-v2(多言語の文埋め込み、int8 118 MB)。
/// 投稿の埋め込みにも使う想定で、fastText 蒸留版などに差し替えられるよう `kind` で形を分ける。
const raiEmbeddingSpec = RaiEmbeddingSpec(
  id: 'minilm-l12-multilingual-int8',
  label: 'MiniLM-L12 多言語(paraphrase, int8)',
  fileName: 'model_quantized.onnx',
  url: 'https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/onnx/model_quantized.onnx',
  sizeMb: 118,
  tokenizerAsset: 'assets/models/minilm_unigram.tsv',
  dims: 384,
  kind: RaiEmbeddingKind.minilm,
  maxLen: 128,
);

/// SigLIP2 テキスト塔 (D-190)。計測では言い換えに弱かったので既定から外した(差し替え可)。
const raiSiglip2EmbeddingSpec = RaiEmbeddingSpec(
  id: 'siglip2-base-text-int8',
  label: 'SigLIP2 base(テキスト塔・int8)',
  fileName: 'text_model_int8.onnx',
  url: 'https://huggingface.co/onnx-community/siglip2-base-patch16-224-ONNX/resolve/main/onnx/text_model_int8.onnx',
  sizeMb: 283,
  tokenizerAsset: 'assets/models/siglip2_tokenizer.model',
  dims: 768,
  kind: RaiEmbeddingKind.siglip2,
  maxLen: 64,
);

enum RaiEmbeddingPhase { notInstalled, downloading, ready, loading, error }

@immutable
class RaiEmbeddingStatus {
  const RaiEmbeddingStatus(this.phase, {this.progress, this.message});
  final RaiEmbeddingPhase phase;
  final int? progress;
  final String? message;
  bool get ready => phase == RaiEmbeddingPhase.ready;
  static const initial = RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled);

  String get label => switch (phase) {
        RaiEmbeddingPhase.notInstalled => '未ダウンロード',
        RaiEmbeddingPhase.downloading => 'ダウンロード中 ${progress ?? 0}%',
        RaiEmbeddingPhase.ready => '準備完了',
        RaiEmbeddingPhase.loading => '読み込み中',
        RaiEmbeddingPhase.error => '失敗: ${message ?? ''}',
      };
}

abstract class RaiEmbeddingModel {
  RaiEmbeddingSpec get spec;
  RaiEmbeddingStatus get current;
  Stream<RaiEmbeddingStatus> get statuses;
  Future<void> refresh();
  Future<void> install({String? hfToken});
  Future<void> uninstall();

  /// ダウンロード済みなら埋め込み器(初回は読み込む)。無ければ null。
  Future<RaiEmbedder?> embedder();

  /// 読み込んだモデルを解放する。
  Future<void> release();
}

/// 端末実行の無い環境(テスト / 未配線)。
class UnavailableRaiEmbeddingModel implements RaiEmbeddingModel {
  const UnavailableRaiEmbeddingModel();
  @override
  RaiEmbeddingSpec get spec => raiEmbeddingSpec;
  @override
  RaiEmbeddingStatus get current => RaiEmbeddingStatus.initial;
  @override
  Stream<RaiEmbeddingStatus> get statuses => const Stream.empty();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> install({String? hfToken}) async => throw const RaiEmbeddingException('この環境では端末内の埋め込みモデルを使えません');
  @override
  Future<void> uninstall() async {}
  @override
  Future<RaiEmbedder?> embedder() async => null;
  @override
  Future<void> release() async {}
}

class RaiEmbeddingException implements Exception {
  const RaiEmbeddingException(this.message);
  final String message;
  @override
  String toString() => message;
}

final raiEmbeddingModelProvider = Provider<RaiEmbeddingModel>((_) => const UnavailableRaiEmbeddingModel());

final raiEmbeddingStatusProvider = StreamProvider<RaiEmbeddingStatus>((ref) async* {
  final m = ref.watch(raiEmbeddingModelProvider);
  yield m.current;
  unawaited(m.refresh());
  yield* m.statuses;
});
