import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:fllama/fllama.dart' as fl;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'rai_llm.dart';

/// 端末内 LLM の実体 (D-181 / D-182): エンジンをモデルごとに切り替える。
///
/// - GGUF → llama.cpp(fllama、ネイティブアセットで llama.cpp をビルド)。モデルは HF から
///   アプリのサポート領域(`rai_models/`)へ自前でダウンロード(進捗つき)。
/// - .litertlm → LiteRT-LM(flutter_gemma)。macOS は付属 dylib の同梱に Podfile の post_install が
///   要る(パッケージの #247)ので、当面は GGUF を既定にする。
/// 失敗はすべて [RaiLlmException] に畳む。選んだモデル id はファイルに残す。
class DeviceRaiLlm implements RaiLlm {
  DeviceRaiLlm();

  final _ctrl = StreamController<RaiLlmStatus>.broadcast();
  RaiModelSpec _spec = raiModelSpecs.first;
  RaiLlmStatus _current = RaiLlmStatus.initial;
  bool _loadedSelection = false;

  // LiteRT
  InferenceModel? _lrModel;
  Future<void>? _lrInit;

  // GGUF
  int? _ggufRequestId;
  StreamSubscription<List<int>>? _download;

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

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/rai_models');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _ggufFile() async => File('${(await _dir()).path}/${_spec.fileName}');

  Future<void> _restoreSelection() async {
    if (_loadedSelection) return;
    _loadedSelection = true;
    try {
      final f = File('${(await _dir()).path}/selected.txt');
      if (await f.exists()) _spec = raiModelSpecById((await f.readAsString()).trim());
    } catch (e) {
      debugPrint('rai llm selection: $e');
    }
  }

  Future<void> _saveSelection() async {
    try {
      await File('${(await _dir()).path}/selected.txt').writeAsString(_spec.id);
    } catch (e) {
      debugPrint('rai llm selection save: $e');
    }
  }

  // ── LiteRT ──
  Future<void> _lrEnsureInit() => _lrInit ??= FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()], maxDownloadRetries: 5);
  ModelType get _lrModelType => ModelType.values.where((t) => t.name == _spec.family).firstOrNull ?? ModelType.general;

  @override
  Future<void> refresh() async {
    await _restoreSelection();
    try {
      final bool installed;
      if (_spec.engine == RaiEngine.gguf) {
        final f = await _ggufFile();
        installed = await f.exists() && (await f.length()) > 1024 * 1024;
      } else {
        await _lrEnsureInit();
        installed = await FlutterGemma.isModelInstalled(_spec.fileName);
      }
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
    await _saveSelection();
    await refresh();
  }

  @override
  Future<void> install({String? hfToken}) async {
    if (_spec.engine == RaiEngine.litertlm) return _lrInstall(hfToken);
    return _ggufInstall(hfToken);
  }

  Future<void> _lrInstall(String? hfToken) async {
    try {
      await _lrEnsureInit();
      _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: 0, modelId: _spec.id));
      await FlutterGemma.installModel(modelType: _lrModelType, fileType: ModelFileType.litertlm)
          .fromNetwork(_spec.url, token: hfToken)
          .withProgress((p) => _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: p, modelId: _spec.id)))
          .install();
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    } catch (e) {
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: 'ダウンロードに失敗しました: $e', modelId: _spec.id));
      throw RaiLlmException('ダウンロードに失敗しました: $e');
    }
  }

  /// HF から GGUF を流し込む(進捗は Content-Length 基準、無ければ想定サイズ)。
  Future<void> _ggufInstall(String? hfToken) async {
    final f = await _ggufFile();
    final tmp = File('${f.path}.part');
    final client = http.Client();
    try {
      _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: 0, modelId: _spec.id));
      final req = http.Request('GET', Uri.parse(_spec.url));
      if (hfToken != null && hfToken.isNotEmpty) req.headers['Authorization'] = 'Bearer $hfToken';
      final res = await client.send(req);
      if (res.statusCode != 200) throw RaiLlmException('HTTP ${res.statusCode}');
      final total = res.contentLength ?? _spec.sizeMb * 1000 * 1000;
      final sink = tmp.openWrite();
      var got = 0;
      var lastPct = -1;
      final done = Completer<void>();
      _download = res.stream.listen(
        (chunk) {
          sink.add(chunk);
          got += chunk.length;
          final pct = (got * 100 ~/ total).clamp(0, 99);
          if (pct != lastPct) {
            lastPct = pct;
            _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: pct, modelId: _spec.id));
          }
        },
        onError: done.completeError,
        onDone: done.complete,
        cancelOnError: true,
      );
      await done.future;
      await sink.close();
      await tmp.rename(f.path);
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: 'ダウンロードに失敗しました: $e', modelId: _spec.id));
      throw RaiLlmException('ダウンロードに失敗しました: $e');
    } finally {
      _download = null;
      client.close();
    }
  }

  @override
  Future<void> uninstall() async {
    await _download?.cancel();
    _download = null;
    await release();
    try {
      if (_spec.engine == RaiEngine.gguf) {
        final f = await _ggufFile();
        if (await f.exists()) await f.delete();
      } else {
        await _lrEnsureInit();
        await FlutterGemma.uninstallModel(_spec.fileName);
        await FlutterGemma.clearActiveInferenceIdentity();
      }
    } catch (e) {
      debugPrint('rai llm uninstall: $e');
    }
    _set(RaiLlmStatus(RaiLlmPhase.notInstalled, modelId: _spec.id));
  }

  @override
  Future<void> release() async {
    final id = _ggufRequestId;
    _ggufRequestId = null;
    if (id != null) {
      try {
        fl.fllamaCancelInference(id);
      } catch (e) {
        debugPrint('rai llm cancel: $e');
      }
    }
    final m = _lrModel;
    _lrModel = null;
    if (m != null) {
      try {
        await m.close();
      } catch (e) {
        debugPrint('rai llm release: $e');
      }
    }
    if (_current.ready || _current.phase == RaiLlmPhase.loading) _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
  }

  @override
  Stream<String> chat(String prompt, {String? system}) {
    if (!_current.ready && _current.phase != RaiLlmPhase.loading) {
      return Stream.error(RaiLlmException(_current.phase == RaiLlmPhase.notInstalled ? '端末内モデル($raiLocalModelLabel)がまだダウンロードされていません' : (_current.message ?? '端末内モデルを使えません')));
    }
    return _spec.engine == RaiEngine.gguf ? _ggufChat(prompt, system) : _lrChat(prompt, system);
  }

  Stream<String> _ggufChat(String prompt, String? system) {
    final out = StreamController<String>();
    () async {
      final f = await _ggufFile();
      if (!await f.exists()) {
        out.addError(RaiLlmException('モデルファイルがありません: ${f.path}'));
        await out.close();
        return;
      }
      _set(RaiLlmStatus(RaiLlmPhase.generating, modelId: _spec.id));
      var emitted = '';
      try {
        final request = fl.OpenAiRequest(
          maxTokens: 256,
          messages: [
            if (system != null && system.isNotEmpty) fl.Message(fl.Role.system, system),
            fl.Message(fl.Role.user, prompt),
          ],
          numGpuLayers: 99,
          modelPath: f.path,
          frequencyPenalty: 0.0,
          presencePenalty: 1.1,
          topP: 0.95,
          contextSize: 2048,
          temperature: 0.4,
          logger: (log) => debugPrint('[llama.cpp] $log'),
        );
        _ggufRequestId = await fl.fllamaChat(request, (response, openAiJson, done) {
          if (out.isClosed) return;
          if (fl.fllamaOutputIndicatesLoadError(response)) {
            out.addError(RaiLlmException('モデルを読み込めません(llama.cpp): $response'));
            out.close();
            return;
          }
          // fllama は累積の文章を返すので差分だけ流す。
          if (response.length > emitted.length && response.startsWith(emitted)) {
            out.add(response.substring(emitted.length));
            emitted = response;
          } else if (response != emitted) {
            emitted = response;
          }
          if (done) out.close();
        });
      } catch (e) {
        if (!out.isClosed) {
          out.addError(RaiLlmException('生成に失敗しました: $e'));
          await out.close();
        }
      }
    }();
    out.onCancel = () {
      final id = _ggufRequestId;
      if (id != null) fl.fllamaCancelInference(id);
    };
    return out.stream.transform(StreamTransformer.fromHandlers(handleDone: (sink) {
      _ggufRequestId = null;
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
      sink.close();
    }));
  }

  Future<InferenceModel> _lrLoad() async {
    final cached = _lrModel;
    if (cached != null) return cached;
    _set(RaiLlmStatus(RaiLlmPhase.loading, modelId: _spec.id));
    final m = await FlutterGemma.getActiveModel(maxTokens: 2048, preferredBackend: PreferredBackend.gpu);
    _lrModel = m;
    return m;
  }

  Stream<String> _lrChat(String prompt, String? system) async* {
    InferenceModel model;
    try {
      model = await _lrLoad();
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
