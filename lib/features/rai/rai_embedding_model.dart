import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rai_reference.dart';

/// リファレンス検索の埋め込みモデル (D-190): SigLIP2 のテキスト塔(int8 ONNX、283 MB)を端末に
/// ダウンロードして onnxruntime で回す。トークナイザー(4 MB)はアプリに同梱。
/// 未ダウンロード / 失敗時は n-gram 代替(同じ契約)で検索する。
@immutable
class RaiEmbeddingSpec {
  const RaiEmbeddingSpec({required this.id, required this.label, required this.fileName, required this.url, required this.sizeMb, required this.tokenizerAsset, required this.dims});
  final String id;
  final String label;
  final String fileName;
  final String url;
  final int sizeMb;
  final String tokenizerAsset;
  final int dims;
}

const raiEmbeddingSpec = RaiEmbeddingSpec(
  id: 'siglip2-base-text-int8',
  label: 'SigLIP2 base(テキスト塔・int8)',
  fileName: 'text_model_int8.onnx',
  url: 'https://huggingface.co/onnx-community/siglip2-base-patch16-224-ONNX/resolve/main/onnx/text_model_int8.onnx',
  sizeMb: 283,
  tokenizerAsset: 'assets/models/siglip2_tokenizer.model',
  dims: 768,
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
