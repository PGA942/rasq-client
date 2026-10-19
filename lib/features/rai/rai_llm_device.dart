import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart' as lc;
import 'package:path_provider/path_provider.dart';

import 'rai_bundled.dart';
import 'rai_llm.dart';
import '../../l10n/l10n.dart';

/// 端末の RAM(device_info_plus)。iOS / Android は MB、macOS は bytes で返るので MB に揃える。
Future<({int? totalMb, int? availableMb})> deviceRamReader() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final d = await info.iosInfo;
      return (totalMb: d.physicalRamSize, availableMb: d.availableRamSize);
    }
    if (Platform.isAndroid) {
      final d = await info.androidInfo;
      return (totalMb: d.physicalRamSize, availableMb: d.availableRamSize);
    }
    if (Platform.isMacOS) {
      final d = await info.macOsInfo;
      final v = d.memorySize;
      return (totalMb: v > 10000000 ? v ~/ (1024 * 1024) : v, availableMb: null);
    }
  } catch (e) {
    debugPrint('device ram: $e');
  }
  return (totalMb: null, availableMb: null);
}

/// llama.cpp のビルド番号 (D-188 → D-217): **llama_cpp_dart 0.9.0-dev.12 のバインディングは b10182
/// (afeebe10)向け**(Qwen3.5 系 = Agents-A1 4B が読める)。他のビルドは構造体の ABI が違い、
/// `llama_model_default_params` でクラッシュ / ゴミ値でメモリが膨れる。macOS は SwiftPM で組み込まれた
/// xcframework(プロセス内)→ パッケージ同梱の `bin/MAC_ARM64` → この番号の GitHub Releases の順。
const llamaCppReleaseTag = 'b10182';
const llamaCppDartVersion = '0.9.0-dev.12';

/// 端末内 LLM の実体 (D-181 / D-182 / D-183): エンジンをモデルごとに切り替える。
///
/// - GGUF → llama.cpp(**llama_cpp_dart**、MIT)。ネイティブは macOS ならランタイムに GitHub
///   Releases から取得、iOS / Android はアプリに組み込んだもの(xcframework / jniLibs)を探す。
///   モデルは HF から `ApplicationSupport/rai_models/` へ自前でダウンロード(進捗つき)。
/// - .litertlm → LiteRT-LM(flutter_gemma)。
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

  // llama.cpp
  lc.LlamaEngine? _llama;
  String? _llamaModelPath;
  Future<String?>? _libReady;
  StreamSubscription<List<int>>? _download;

  @override
  RaiLlmStatus get current => _current;
  @override
  int get contextTokens => 2048; // _llamaLoad の nCtx と同じ
  @override
  Stream<RaiLlmStatus> get statuses => _ctrl.stream;
  @override
  RaiModelSpec get spec => _spec;

  void _set(RaiLlmStatus s) {
    _current = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
  }

  Future<Directory> _dir([String sub = 'rai_models']) async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/$sub');
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

  // ── llama.cpp のネイティブライブラリ ──

  /// 使えるライブラリのパス(null = プロセスに組み込み済み)。無ければ例外。
  Future<String?> _ensureLlamaLib() => _libReady ??= _resolveLlamaLib().catchError((Object e, StackTrace st) {
        _libReady = null;
        Error.throwWithStackTrace(e, st);
      });

  Future<String?> _resolveLlamaLib() async {
    if (Platform.isMacOS) {
      // 0) SwiftPM で組み込まれた xcframework (D-217: 0.9 系はプラグインとして Runner に入る)。
      try {
        DynamicLibrary.process().lookup<NativeFunction<Void Function()>>('llama_backend_init');
        return null;
      } catch (_) {}
      // 1) パッケージ同梱の dylib(ABI が確実に一致)。開発ビルド(サンドボックス無し)なら pub cache を読める。
      for (final base in [Platform.environment['PUB_CACHE'], '${Platform.environment['HOME']}/.pub-cache']) {
        if (base == null) continue;
        final packaged = Directory('$base/hosted/pub.dev/llama_cpp_dart-$llamaCppDartVersion/bin/MAC_ARM64');
        if (await File('${packaged.path}/libllama.dylib').exists()) {
          await _unquarantine(packaged);
          _preloadLlamaDeps(packaged);
          return '${packaged.path}/libllama.dylib';
        }
      }
      // 2) 同じビルド番号のプレビルトを取得。
      final dir = Directory('${(await _dir('llama_cpp')).path}/$llamaCppReleaseTag');
      final lib = File('${dir.path}/libllama.dylib');
      if (!await lib.exists()) {
        _set(RaiLlmStatus(RaiLlmPhase.loading, message: appL10n.raiModelsLlamaFetching(llamaCppReleaseTag), modelId: _spec.id));
        await _downloadLlamaRuntime(dir);
      }
      // Gatekeeper (D-184): 取得した dylib には隔離属性が付き「開いていません」で弾かれるので、
      // 属性を外して ad-hoc 署名する(毎回、失敗は無視 — 前回の展開分にも効かせる)。
      await _unquarantine(dir);
      // 依存 dylib (D-186): libmtmd → @rpath/libllama.0.dylib → @rpath/libggml*.0.dylib は app の
      // Frameworks からは見つからないので、先に絶対パスで順に読み込んでおく(同じ install name の
      // 読み込み済みイメージが使われる)。
      _preloadLlamaDeps(dir);
      return lib.path;
    }
    // iOS / Android: アプリに組み込まれているかを探る(iOS = xcframework、Android = jniLibs)。
    try {
      if (Platform.isAndroid) {
        DynamicLibrary.open('libllama.so');
        return 'libllama.so';
      }
      DynamicLibrary.process().lookup<NativeFunction<Void Function()>>('llama_backend_init');
      return null;
    } catch (_) {
      throw RaiLlmException(Platform.isIOS ? appL10n.raiModelsLlamaMissingIos : appL10n.raiModelsLlamaMissing);
    }
  }

  static const _llamaDepOrder = ['libggml-base', 'libggml-cpu', 'libggml-blas', 'libggml-metal', 'libggml-rpc', 'libggml', 'libllama'];

  void _preloadLlamaDeps(Directory dir) {
    for (final name in _llamaDepOrder) {
      // パッケージ同梱は無印、Releases は .0 付き。
      final f = [File('${dir.path}/$name.0.dylib'), File('${dir.path}/$name.dylib')].where((f) => f.existsSync()).firstOrNull;
      if (f == null) continue;
      try {
        DynamicLibrary.open(f.path);
      } catch (e) {
        debugPrint('llama runtime preload $name: $e');
      }
    }
  }

  Future<void> _unquarantine(Directory dir) async {
    try {
      // nosemgrep: rasq-client-subprocess — macOS で取得した llama のライブラリの隔離属性を外す。コマンドは固定パス、引数は配列。
      await Process.run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', dir.path]);
    } catch (e) {
      debugPrint('llama runtime xattr: $e');
    }
    try {
      await for (final f in dir.list()) {
        if (f is File && f.path.contains('.dylib')) {
          // nosemgrep: rasq-client-subprocess — 同上 (ad hoc 署名)。コマンドは固定パス、引数は配列。
          await Process.run('/usr/bin/codesign', ['--force', '--sign', '-', f.path]);
        }
      }
    } catch (e) {
      debugPrint('llama runtime codesign: $e');
    }
  }

  Future<void> _downloadLlamaRuntime(Directory dir) async {
    final url = 'https://github.com/ggml-org/llama.cpp/releases/download/$llamaCppReleaseTag/llama-$llamaCppReleaseTag-bin-macos-arm64.tar.gz';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) throw RaiLlmException(appL10n.raiModelsLlamaFetchFailed(res.statusCode));
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(res.bodyBytes));
    await dir.create(recursive: true);
    final links = <String, String>{};
    for (final f in archive) {
      final name = f.name.split('/').last;
      if (name.isEmpty || !name.contains('.dylib')) continue;
      if (f.isSymbolicLink) {
        links[name] = f.symbolicLink!.split('/').last;
        continue;
      }
      if (!f.isFile) continue;
      await File('${dir.path}/$name').writeAsBytes(f.content as List<int>, flush: true);
    }
    // シンボリックリンクは実体のコピーで代用(tar の順序に依らないよう後から)。
    for (final e in links.entries) {
      final target = File('${dir.path}/${e.value}');
      final link = File('${dir.path}/${e.key}');
      if (await target.exists() && !await link.exists()) await target.copy(link.path);
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
      _set(RaiLlmStatus(installed ? RaiLlmPhase.ready : RaiLlmPhase.notInstalled, modelId: _spec.id, bundled: !installed && await _isBundled()));
    } catch (e) {
      debugPrint('rai llm refresh: $e');
      _set(RaiLlmStatus(RaiLlmPhase.unavailable, message: appL10n.raiModelsStateCheckFailed('$e'), modelId: _spec.id));
    }
  }

  @override
  Future<void> select(RaiModelSpec spec) async {
    if (spec.id == _spec.id || spec.cloud) return;
    await release();
    _spec = spec;
    await _saveSelection();
    await refresh();
  }

  @override
  Future<void> install({String? hfToken}) async {
    if (_spec.engine == RaiEngine.litertlm) return _lrInstall(hfToken);
    if (await _isBundled()) return _bundledInstall();
    return _ggufInstall(hfToken);
  }

  // ── 同梱モデル (D-216) ──
  Set<String>? _assets;

  Future<bool> _isBundled() async {
    if (_spec.engine != RaiEngine.gguf) return false;
    try {
      _assets ??= (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
    } catch (_) {
      return false;
    }
    return _assets!.contains(raiBundledAsset(_spec));
  }

  /// 同梱の gzip を `rai_models/` へ伸長する。デスクトップは flutter_assets のファイルを流す。
  /// モバイルは rootBundle で読む(丸ごとメモリに載るので 1.2 GB を超えるものは対象外 → ダウンロード)。
  Future<void> _bundledInstall() async {
    final f = await _ggufFile();
    final asset = raiBundledAsset(_spec);
    try {
      _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: 0, message: appL10n.raiModelsExtracting, modelId: _spec.id, bundled: true));
      final dir = flutterAssetsDirOf(Platform.resolvedExecutable);
      final src = dir == null ? null : File('$dir/$asset');
      if (src != null && await src.exists()) {
        var lastPct = -1;
        await gunzipToFile(src, f, onProgress: (done, total) {
          final pct = (done * 100 ~/ (total == 0 ? 1 : total)).clamp(0, 99);
          if (pct != lastPct) {
            lastPct = pct;
            _set(RaiLlmStatus(RaiLlmPhase.downloading, progress: pct, message: appL10n.raiModelsExtracting, modelId: _spec.id, bundled: true));
          }
        });
      } else {
        if (_spec.sizeMb > 1200) throw RaiLlmException(appL10n.raiModelsExtractTooLarge);
        final bytes = await rootBundle.load(asset);
        final out = gzip.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        final tmp = File('${f.path}.part');
        await tmp.writeAsBytes(out, flush: true);
        await tmp.rename(f.path);
      }
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    } catch (e) {
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: appL10n.raiModelsExtractFailed('$e'), modelId: _spec.id, bundled: true));
      throw RaiLlmException(appL10n.raiModelsExtractFailed('$e'));
    }
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
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: appL10n.raiModelsDownloadFailed('$e'), modelId: _spec.id));
      throw RaiLlmException(appL10n.raiModelsDownloadFailed('$e'));
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
      final res = await client.send(req).timeout(const Duration(seconds: 60));
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
      _set(RaiLlmStatus(RaiLlmPhase.notInstalled, message: appL10n.raiModelsDownloadFailed('$e'), modelId: _spec.id));
      throw RaiLlmException(appL10n.raiModelsDownloadFailed('$e'));
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
    final l = _llama;
    _llama = null;
    _llamaModelPath = null;
    if (l != null) {
      try {
        await l.dispose();
      } catch (e) {
        debugPrint('rai llm llama dispose: $e');
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
  Future<void> warmUp() async {
    if (_current.phase != RaiLlmPhase.ready) return;
    try {
      if (_spec.engine == RaiEngine.gguf) {
        final f = await _ggufFile();
        if (!await f.exists()) return;
        await _llamaLoad(f.path);
      } else {
        await _lrLoad();
      }
      if (_current.phase == RaiLlmPhase.loading) _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    } catch (e) {
      debugPrint('rai llm warmUp: $e');
      if (_current.phase == RaiLlmPhase.loading) _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    }
  }

  @override
  Stream<String> chat(String prompt, {String? system, int? maxTokens}) {
    if (!_current.ready && _current.phase != RaiLlmPhase.loading) {
      return Stream.error(RaiLlmException(_current.phase == RaiLlmPhase.notInstalled ? appL10n.raiModelsNotDownloaded(_spec.codename) : (_current.message ?? appL10n.raiModelsDeviceUnavailable)));
    }
    return _spec.engine == RaiEngine.gguf ? _ggufChat(prompt, system, maxTokens: maxTokens) : _lrChat(prompt, system);
  }

  /// 読み込み (D-217: llama_cpp_dart 0.9 系 = `LlamaEngine`)。ggml の動的バックエンドはライブラリと同じ
  /// フォルダーから `LlamaLibrary.load` が読む(`ggml_backend_load_all_from_path`)。プロセスに組み込み済み
  /// (SwiftPM の xcframework)なら `spawnFromProcess`。
  Future<lc.LlamaEngine> _llamaLoad(String modelPath) async {
    final cached = _llama;
    if (cached != null && _llamaModelPath == modelPath) return cached;
    await release();
    _set(RaiLlmStatus(RaiLlmPhase.loading, modelId: _spec.id));
    final lib = await _ensureLlamaLib();
    final gpu = Platform.isMacOS || Platform.isIOS; // Metal。GPU が無い環境は main_gpu = -1 でないと読めない
    final modelParams = lc.ModelParams(path: modelPath, gpuLayers: gpu ? 99 : 0, mainGpu: gpu ? 0 : -1);
    // D-216: 200 文字程度の返事 + リファレンスの文脈が入る長さ。
    const contextParams = lc.ContextParams(nCtx: 2048, nBatch: 256, nUbatch: 256, nThreads: 4, nThreadsBatch: 4);
    final engine = lib == null
        ? await lc.LlamaEngine.spawnFromProcess(modelParams: modelParams, contextParams: contextParams)
        : await lc.LlamaEngine.spawn(libraryPath: lib, modelParams: modelParams, contextParams: contextParams);
    _llama = engine;
    _llamaModelPath = modelPath;
    return engine;
  }

  Stream<String> _ggufChat(String prompt, String? system, {int? maxTokens}) {
    final out = StreamController<String>();
    StreamSubscription<lc.GenerationEvent>? events;
    lc.EngineSession? session;
    Timer? firstToken;
    Timer? overall;
    Future<void> cleanup() async {
      firstToken?.cancel();
      overall?.cancel();
      await events?.cancel();
      final s = session;
      session = null;
      try {
        await s?.dispose();
      } catch (_) {}
    }
    () async {
      try {
        final f = await _ggufFile();
        if (!await f.exists()) throw RaiLlmException(appL10n.raiModelsFileMissing(f.path));
        final engine = await _llamaLoad(f.path);
        _set(RaiLlmStatus(RaiLlmPhase.generating, modelId: _spec.id));
        // ChatML(Agents-A1 / Qwen 系)。system + user を渡し、assistant を開けておく。
        // 思考モードは切る (D-217): Qwen3 / Qwen3.5 のテンプレートが enable_thinking=false のときに出す
        // **空の think ブロック**を assistant の先頭に置く(`/no_think` だけでは思考だけで枠を使い切って
        // 返事が空になった)。念のため <think>…</think> は出力からも落とす。
        final formatted = chatMlPrompt(system: system, user: prompt);
        final think = ThinkFilter();
        var visibleChars = 0;
        // 無応答の見張り (D-216): 最初の見える文字が 30 秒来なければ / 全体で 150 秒を超えたら打ち切って
        // フォールアップへ(ほぼ全部のモデルが返事無しで止まる症状の逃げ道)。
        Future<void> abort(String why) async {
          if (out.isClosed) return;
          out.addError(RaiLlmException(why));
          await out.close();
          await cleanup();
        }
        firstToken = Timer(const Duration(seconds: 30), () => abort(appL10n.raiModelsTimeoutFirstToken));
        overall = Timer(const Duration(seconds: 150), () => abort(appL10n.raiModelsTimeoutOverall));
        final sess = await engine.createSession();
        session = sess;
        events = sess
            .generate(
              prompt: formatted,
              addSpecial: true,
              sampler: const lc.SamplerParams(temperature: 0.4, topP: 0.95, repeatPenalty: 1.1),
              maxTokens: maxTokens ?? 512,
            )
            .listen(
          (e) {
            if (out.isClosed) return;
            switch (e) {
              case lc.TokenEvent():
                final visible = think.push(e.text);
                if (visible.isNotEmpty) {
                  visibleChars += visible.length;
                  firstToken?.cancel();
                  out.add(visible);
                }
              case lc.DoneEvent():
                firstToken?.cancel();
                overall?.cancel();
                if (visibleChars == 0) out.addError(RaiLlmException(appL10n.raiModelsOnlyThinking));
                out.close();
              case lc.ShiftEvent():
                break;
            }
          },
          onError: (Object e) {
            if (out.isClosed) return;
            out.addError(RaiLlmException(appL10n.raiModelsGenerateFailed('$e')));
            out.close();
          },
          onDone: () {
            if (!out.isClosed) out.close();
          },
        );
      } catch (e) {
        if (!out.isClosed) {
          final msg = '$e';
          final hint = msg.contains('disallowed by system policy')
              ? '\n${appL10n.raiModelsHintSystemPolicy}'
              : msg.contains('dlopen') || msg.contains('Failed to load dynamic library') || msg.contains('failed to open')
                  ? '\n${appL10n.raiModelsHintGatekeeper}'
                  : '';
          out.addError(e is RaiLlmException ? e : RaiLlmException('${appL10n.raiModelsLoadFailedLlama(msg)}$hint'));
          await out.close();
        }
      }
    }();
    out.onCancel = cleanup;
    return out.stream.transform(StreamTransformer.fromHandlers(handleDone: (sink) {
      cleanup();
      if (_current.phase == RaiLlmPhase.generating) _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
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
      _set(RaiLlmStatus(RaiLlmPhase.unavailable, message: appL10n.raiModelsLoadFailed('$e'), modelId: _spec.id));
      throw RaiLlmException(appL10n.raiModelsLoadFailed('$e'));
    }
    _set(RaiLlmStatus(RaiLlmPhase.generating, modelId: _spec.id));
    try {
      final chat = await model.createChat(temperature: 0.4, topK: 40, systemInstruction: system, maxOutputTokens: 256);
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } catch (e) {
      throw RaiLlmException(appL10n.raiModelsGenerateFailed('$e'));
    } finally {
      _set(RaiLlmStatus(RaiLlmPhase.ready, modelId: _spec.id));
    }
  }
}

/// ChatML のプロンプト (D-217): system / user のあと assistant を開け、空の think ブロックで思考を封じる。
String chatMlPrompt({String? system, required String user}) {
  final b = StringBuffer();
  if (system != null && system.trim().isNotEmpty) b.write('<|im_start|>system\n${system.trim()}<|im_end|>\n');
  b.write('<|im_start|>user\n$user<|im_end|>\n');
  b.write('<|im_start|>assistant\n<think>\n\n</think>\n\n');
  return b.toString();
}

/// `<think>…</think>` を流れてくるトークンから取り除く(タグはトークンをまたぐので溜めて判定)。
class ThinkFilter {
  var _buf = '';
  var _inside = false;

  String push(String token) {
    _buf += token;
    var out = '';
    while (true) {
      if (_inside) {
        final end = _buf.indexOf('</think>');
        if (end < 0) {
          // 閉じタグの途中かもしれない分だけ残す
          _buf = _buf.length > 8 ? _buf.substring(_buf.length - 8) : _buf;
          return out;
        }
        _buf = _buf.substring(end + 8);
        _inside = false;
        // 思考のあとの改行は捨てる
        _buf = _buf.replaceFirst(RegExp(r'^\s+'), '');
        continue;
      }
      final start = _buf.indexOf('<think>');
      if (start >= 0) {
        out += _buf.substring(0, start);
        _buf = _buf.substring(start + 7);
        _inside = true;
        continue;
      }
      // 開きタグの途中かもしれない末尾(最大 6 文字)は保留
      final keep = _pendingTagLength(_buf);
      out += _buf.substring(0, _buf.length - keep);
      _buf = _buf.substring(_buf.length - keep);
      return out;
    }
  }

  static int _pendingTagLength(String s) {
    for (var n = 6; n > 0; n--) {
      if (s.length >= n && '<think>'.startsWith(s.substring(s.length - n))) return n;
    }
    return 0;
  }
}
