import 'dart:async';

import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';

/// テスト用の埋め込みモデル (D-190): ダウンロードは即完了、埋め込み器は n-gram(名前だけ 'fake-siglip')。
class FakeRaiEmbeddingModel implements RaiEmbeddingModel {
  FakeRaiEmbeddingModel({RaiEmbeddingPhase phase = RaiEmbeddingPhase.notInstalled}) : _current = RaiEmbeddingStatus(phase);
  final _ctrl = StreamController<RaiEmbeddingStatus>.broadcast();
  RaiEmbeddingStatus _current;
  int installs = 0;
  int released = 0;

  @override
  RaiEmbeddingSpec get spec => raiEmbeddingSpec;
  @override
  RaiEmbeddingStatus get current => _current;
  @override
  Stream<RaiEmbeddingStatus> get statuses => _ctrl.stream;
  void set(RaiEmbeddingStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> install({String? hfToken}) async {
    installs++;
    set(const RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: 40));
    set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
  }

  @override
  Future<void> uninstall() async => set(const RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled));
  @override
  Future<RaiEmbedder?> embedder() async => _current.ready ? const _FakeSiglip() : null;
  @override
  Future<void> release() async => released++;
}

class _FakeSiglip extends NgramRaiEmbedder {
  const _FakeSiglip();
  @override
  String get name => 'fake-siglip';
}
