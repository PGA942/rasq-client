import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'rai_llm.dart';

/// 端末内 LLM の実体 (D-181): flutter_gemma + LiteRT-LM(`.litertlm`)。
///
/// - 初回に `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])`。
/// - モデルは HuggingFace(litert-community、公開)からダウンロードして端末に置く。
/// - 生成は 1 セッションずつ(短い返事 / 温度低め)。失敗はすべて [RaiLlmException] に畳む。
class FlutterGemmaRaiLlm implements RaiLlm {
  FlutterGemmaRaiLlm();

  final _ctrl = StreamController<RaiLlmStatus>.broadcast();
  RaiModelSpec _spec = raiModelSpecs.first;
  RaiLlmStatus _current = RaiLlmStatus.initial;
  InferenceModel? _model;
  Future<void>? _init;

  @override
  RaiLlmStatus get current => _current;
  @override
  Stream<RaiLlmStatus> get statuses => _ctrl.stream;
  @override
  RaiModelSpec get spec => _spec;

  void _set(RaiLlmStatus s) {
    _current = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
  }

  Future<void> _ensureInit() => _init ??= FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()], maxDownloadRetries: 5);

  ModelType get _modelType => ModelType.values.where((t) => t.name == _spec.family).firstOrNull ?? ModelType.general;

  @override
  Future<void> refresh() async {
    try {
      await _ensureInit();
      final installed = await FlutterGemma.isModelInstalled(_spec.fileName);
      _set(RaiLlmStatus(installed ? RaiLlmPhase.ready : RaiLlmPhase.notInstalled, modelId: _spec.id));
    } catch (e) {
      debugPrint('rai llm refresh: $e');
      _set(RaiLlmStatus(RaiLlmPhase.unavailable, message: 'モデルの状態を確認できません: $e', modelId: _spec.id));
    }
  }

  @override
  Future<void> select(RaiModelSpec spec) async {
    if (spec.id == _spec.id) return;
    await release();
    _spec = spec;
    await refresh();
  }

  @override
  Future<void> install({String? hfToken}) async {
    try {
      await _ensureInit();
      _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: 0, modelId: _spec.id));
      await FlutterGemma.installModel(modelType: _modelType, fileType: ModelFileType.litertlm)
          .fromNetwork(_spec.url, token: hfToken)
          .withProgress((p) => _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: p, modelId: _spec.id)))
          .install();
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    } catch (e) {
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: 'ダウンロードに失敗しました: $e', modelId: _spec.id));
      throw RaiLlmException('ダウンロードに失敗しました: $e');
    }
  }

  @override
  Future<void> uninstall() async {
    await release();
    try {
      await _ensureInit();
      await FlutterGemma.uninstallModel(_spec.fileName);
      await FlutterGemma.clearActiveInferenceIdentity();
    } catch (e) {
      debugPrint('rai llm uninstall: $e');
    }
    _set(RaiLlmStatus(RaiLlmPhase.notInstalled, modelId: _spec.id));
  }

  @override
  Future<void> release() async {
    final m = _model;
    _model = null;
    if (m != null) {
      try {
        await m.close();
      } catch (e) {
        debugPrint('rai llm release: $e');
      }
    }
    if (_current.ready || _current.phase == RaiLlmPhase.loading) _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
  }

  Future<InferenceModel> _load() async {
    final cached = _model;
    if (cached != null) return cached;
    _set(RaiLlmStatus(RaiLlmPhase.loading, modelId: _spec.id));
    final m = await FlutterGemma.getActiveModel(maxTokens: 2048, preferredBackend: PreferredBackend.gpu);
    _model = m;
    return m;
  }

  @override
  Stream<String> chat(String prompt, {String? system}) async* {
    if (!_current.ready && _current.phase != RaiLlmPhase.loading) {
      throw RaiLlmException(_current.phase == RaiLlmPhase.notInstalled ? '端末内モデル($raiLocalModelLabel)がまだダウンロードされていません' : (_current.message ?? '端末内モデルを使えません'));
    }
    InferenceModel model;
    try {
      model = await _load();
    } catch (e) {
      _set(RaiLlmStatus(RaiLlmPhase.unavailable, message: 'モデルを読み込めません: $e', modelId: _spec.id));
      throw RaiLlmException('モデルを読み込めません: $e');
    }
    _set(RaiLlmStatus(RaiLlmPhase.generating, modelId: _spec.id));
    try {
      final chat = await model.createChat(temperature: 0.4, topK: 40, systemInstruction: system, maxOutputTokens: 256);
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } catch (e) {
      throw RaiLlmException('生成に失敗しました: $e');
    } finally {
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    }
  }
}
