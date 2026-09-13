import 'dart:async';

import 'package:rasq_client/features/rai/rai_llm.dart';

/// テスト用の端末内 LLM (D-181): 状態を手で切り替え、返事は固定の文字列をトークンに割って流す。
class FakeRaiLlm implements RaiLlm {
  FakeRaiLlm({RaiLlmPhase phase = RaiLlmPhase.notInstalled, this.reply = 'はい、RASQ の RAi です。'}) : _current = RaiLlmStatus(phase, modelId: raiModelSpecs.first.id);
  final _ctrl = StreamController<RaiLlmStatus>.broadcast();
  RaiLlmStatus _current;
  RaiModelSpec _spec = raiModelSpecs.first;
  String reply;
  final List<String> prompts = [];
  final List<String?> systems = [];
  int released = 0;
  int installs = 0;

  @override
  RaiLlmStatus get current => _current;
  @override
  Stream<RaiLlmStatus> get statuses => _ctrl.stream;
  @override
  RaiModelSpec get spec => _spec;
  void set(RaiLlmStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> select(RaiModelSpec spec) async {
    _spec = spec;
    set(RaiLlmStatus(_current.phase, modelId: spec.id));
  }

  @override
  Future<void> install({String? hfToken}) async {
    installs++;
    set(RaiLlmStatus(RaiLlmPhase.downloading, progress: 50, modelId: _spec.id));
    set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
  }

  @override
  Future<void> uninstall() async => set(RaiLlmStatus(RaiLlmPhase.notInstalled, modelId: _spec.id));
  @override
  Future<void> release() async => released++;

  @override
  Stream<String> chat(String prompt, {String? system}) async* {
    prompts.add(prompt);
    systems.add(system);
    if (!_current.ready) throw RaiLlmException('端末内モデル(${_spec.codename})がまだダウンロードされていません');
    set(RaiLlmStatus(RaiLlmPhase.generating, modelId: _spec.id));
    for (final ch in reply.split('')) {
      yield ch;
    }
    set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
  }
}
