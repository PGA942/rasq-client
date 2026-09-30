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

  /// SigLIP2 の**画像側** (D-293): pixel_values[n,3,224,224] → pooler_output。文の埋め込み器にはならない(`embedder()` は null)。
  /// 絵文字の絵を埋め込むのに使う。ダウンロード / 削除の管理だけを、文のモデルと共用する。
  siglip2Vision,

  /// RASQ の MiniLM(文、D-390): paraphrase-multilingual-MiniLM-L12-v2 の空間へ蒸留した小さな文の塔。
  /// input_ids(int64)/ attention_mask(**float32**、詰め物は 0)→ `embedding`[n,384](正規化済み)。トークナイザーは MiniLM と同じ。
  rasqText,

  /// RASQ の MobileNet(画像、D-390): 同じ 384 次元の空間へ蒸留した画像の塔。pixel_values[n,3,224,224]([-1,1]、SigLIP と同じ前処理)
  /// → `embedding`。**文の塔と同じ空間**なので、投稿の本文と画像をそのまま比べられる。文の埋め込み器にはならない。
  rasqVision,
}

@immutable
class RaiEmbeddingSpec {
  const RaiEmbeddingSpec({required this.id, required this.label, required this.fileName, required this.url, required this.sizeMb, required this.tokenizerAsset, required this.dims, this.kind = RaiEmbeddingKind.minilm, this.maxLen = 128, this.centralPath});

  /// RASQ Central が配るモデル (D-390): `<Central>/api/v1/models/<centralPath>` から取る(このときは [url] を使わない)。
  final String? centralPath;

  /// 取りに行く URL。Central が配るものは [central](Central の API の根)から作る。Central が無ければ null。
  Uri? downloadUrl(Uri? central) {
    final path = centralPath;
    if (path == null) return Uri.parse(url);
    if (central == null) return null;
    final base = central.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/v1/models/$path');
  }
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

/// 既定 (D-390): RASQ の MiniLM(文の塔、35 MB)。paraphrase-multilingual-MiniLM-L12-v2 の空間へ蒸留したもの。
/// RAi の評価 395 問(ベクトルだけ)で、1 位正解 40.5% / 上位 3 件 57.0%(元の MiniLM-L12 int8 118 MB は 41.3% / 59.7%)= ほぼ同じで 1/3 の大きさ。
/// 配られた int8 版は畳み込みが ConvInteger(int8 の重み)で、端末の onnxruntime 1.15 に実装が無く読めないので、
/// **重みを uint8 で量子化し直した版**(`*_uint8.onnx`、精度は同じ)を配る。
/// 投稿の画像の塔([postVisionEmbeddingSpec])と同じ空間なので、投稿の本文と画像を比べられる。RASQ Central が配る。
const raiEmbeddingSpec = RaiEmbeddingSpec(
  id: 'rasq-minilm-text-int8',
  label: 'RASQ MiniLM(文)',
  fileName: 'text_tower_uint8.onnx',
  url: '',
  centralPath: 'minilm-mobilenet/onnx/text_tower_uint8.onnx',
  sizeMb: 35,
  tokenizerAsset: 'assets/models/minilm_unigram.tsv',
  dims: 384,
  kind: RaiEmbeddingKind.rasqText,
  maxLen: 128,
);

/// 以前の既定 (D-193): paraphrase-multilingual-MiniLM-L12-v2(多言語の文埋め込み、int8 118 MB)。差し替え用に残す。
const raiMiniLmL12EmbeddingSpec = RaiEmbeddingSpec(
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

/// 投稿の画像 (D-390): RASQ の MobileNet(画像の塔、int8 32 MB)。[raiEmbeddingSpec] と同じ 384 次元の空間。
/// 関連 TL / TL のアルゴリズム(似ている投稿)で、投稿の画像も本文と一緒に比べる。RASQ Central が配る。
const postVisionEmbeddingSpec = RaiEmbeddingSpec(
  id: 'rasq-mobilenet-vision-int8',
  label: 'RASQ MobileNet(投稿の画像)',
  fileName: 'image_tower_uint8.onnx',
  url: '',
  centralPath: 'minilm-mobilenet/onnx/image_tower_uint8.onnx',
  sizeMb: 32,
  tokenizerAsset: '',
  dims: 384,
  kind: RaiEmbeddingKind.rasqVision,
  maxLen: 0,
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

/// SigLIP2 の画像側 (D-293)。int8。絵文字の絵を、SigLIP2 のテキスト側と同じ空間に埋め込む。
const emojiVisionEmbeddingSpec = RaiEmbeddingSpec(
  id: 'siglip2-base-vision-int8',
  label: 'SigLIP2 base(画像側・int8)',
  fileName: 'vision_model_int8.onnx',
  url: 'https://huggingface.co/onnx-community/siglip2-base-patch16-224-ONNX/resolve/main/onnx/vision_model_int8.onnx',
  sizeMb: 95,
  tokenizerAsset: '',
  dims: 768,
  kind: RaiEmbeddingKind.siglip2Vision,
  maxLen: 0,
);

final raiEmbeddingModelProvider = Provider<RaiEmbeddingModel>((_) => const UnavailableRaiEmbeddingModel());

/// 絵文字の画像検索 (D-293) の 2 つのモデル: 文を埋め込む SigLIP2 のテキスト側と、絵を埋め込む画像側。
/// **同じ SigLIP2 の組でないと、文と絵を比べられない**(RAi の検索の既定は MiniLM なので、別に持つ)。
/// 実機では main が端末の実装に差し替える。既定(テスト)は「使えない」。
final emojiTextModelProvider = Provider<RaiEmbeddingModel>((_) => const UnavailableRaiEmbeddingModel());
final emojiVisionModelProvider = Provider<RaiEmbeddingModel>((_) => const UnavailableRaiEmbeddingModel());

StreamProvider<RaiEmbeddingStatus> _statusOf(Provider<RaiEmbeddingModel> p) => StreamProvider<RaiEmbeddingStatus>((ref) async* {
      final m = ref.watch(p);
      yield m.current;
      unawaited(m.refresh());
      yield* m.statuses;
    });

final emojiTextStatusProvider = _statusOf(emojiTextModelProvider);
final emojiVisionStatusProvider = _statusOf(emojiVisionModelProvider);

/// 投稿の画像の塔 (D-390)。文は RAi の埋め込み([raiEmbeddingModelProvider])と共用(同じ空間)。実機では main が差し替える。
final postVisionModelProvider = Provider<RaiEmbeddingModel>((_) => const UnavailableRaiEmbeddingModel());
final postVisionStatusProvider = _statusOf(postVisionModelProvider);

final raiEmbeddingStatusProvider = StreamProvider<RaiEmbeddingStatus>((ref) async* {
  final m = ref.watch(raiEmbeddingModelProvider);
  yield m.current;
  unawaited(m.refresh());
  yield* m.statuses;
});
