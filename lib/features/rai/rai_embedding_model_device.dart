import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'rai_bundled.dart' show flutterAssetsDirOf;
import 'rai_embedding_model.dart';
import 'rai_minilm_tokenizer.dart';
import 'rai_onnx_embedder.dart';
import 'rai_reference.dart';
import 'rai_siglip_tokenizer.dart';
import '../../l10n/l10n.dart';

/// 端末側の埋め込みモデル (D-190): `ApplicationSupport/rai_models/<id>/` に ONNX を置き、
/// 同梱のトークナイザーと合わせて [OnnxRaiEmbedder] を作る。
/// **同梱のモデル (D-522)**: [RaiEmbeddingSpec.bundledAsset] がアプリに入っていれば、ネットワークを使わずに
/// それを置き場へ写して使う(onnxruntime はファイルの道を要る)。写すのは初めて使うとき 1 回だけ。
/// 長さ(と分かっていれば sha256)を確かめ、壊れていれば写しを捨てて、ダウンロードできる状態に戻す。
/// アセットが無いビルド(Web 版 / 取り込む前の開発のビルド)は従来どおりダウンロードする。
class DeviceRaiEmbeddingModel implements RaiEmbeddingModel {
  DeviceRaiEmbeddingModel({
    this.spec = raiEmbeddingSpec,
    this.central,
    AssetBundle? bundle,
    Future<Directory> Function()? baseDir,
    Future<Set<String>> Function()? assets,
    String? Function()? flutterAssetsDir,
    http.Client Function()? httpClient,
  })  : _bundle = bundle ?? rootBundle,
        _baseDir = baseDir ?? getApplicationSupportDirectory,
        _assetsOverride = assets,
        _flutterAssetsDir = flutterAssetsDir ?? (() => flutterAssetsDirOf(Platform.resolvedExecutable)),
        _httpClient = httpClient ?? http.Client.new;
  @override
  final RaiEmbeddingSpec spec;

  /// RASQ Central の根(Central が配るモデル、D-390)。
  final Uri? Function()? central;
  final AssetBundle _bundle;
  final Future<Directory> Function() _baseDir;
  final Future<Set<String>> Function()? _assetsOverride;
  final String? Function() _flutterAssetsDir;
  final http.Client Function() _httpClient;
  final _ctrl = StreamController<RaiEmbeddingStatus>.broadcast();
  RaiEmbeddingStatus _current = RaiEmbeddingStatus.initial;
  OnnxRaiEmbedder? _embedder;
  Future<OnnxRaiEmbedder?>? _loading;
  StreamSubscription<List<int>>? _download;
  Future<File?>? _copying;
  bool? _hasAsset;

  /// 同梱のものが壊れていた(長さ / sha256 が違う)。この起動の間はダウンロードに任せる。
  bool _bundleBroken = false;

  @override
  RaiEmbeddingStatus get current => _current;
  @override
  Stream<RaiEmbeddingStatus> get statuses => _ctrl.stream;

  void _set(RaiEmbeddingStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  Future<File> _file() async {
    final base = await _baseDir();
    final d = Directory('${base.path}/rai_models/${spec.id}');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/${spec.fileName}');
  }

  /// このビルドにモデルが同梱されているか(AssetManifest に載っているか)。
  Future<bool> bundled() async {
    final asset = spec.bundledAsset;
    if (asset == null || _bundleBroken) return false;
    if (_hasAsset == null) {
      try {
        final list = await (_assetsOverride?.call() ?? AssetManifest.loadFromAssetBundle(_bundle).then((m) => m.listAssets().toSet()));
        _hasAsset = list.contains(asset);
      } catch (_) {
        _hasAsset = false;
      }
    }
    return _hasAsset!;
  }

  /// 置き場のモデルのファイル。無くて同梱されていれば、ここで写す。どちらも無ければ null。
  Future<File?> _ensureFile() async {
    final f = await _file();
    if (await f.exists()) return f;
    if (!await bundled()) return null;
    return _copying ??= _copyBundled(f).whenComplete(() => _copying = null);
  }

  /// 同梱のアセットを [f] へ写す (D-522)。デスクトップは flutter_assets のファイルを写し、モバイルは rootBundle で読む。
  /// 長さ(と [RaiEmbeddingSpec.sha256])を確かめてから名前を付け替える。壊れていたら null(ダウンロードできる状態にする)。
  Future<File?> _copyBundled(File f) async {
    final asset = spec.bundledAsset!;
    final tmp = File('${f.path}.part');
    try {
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.loading, bundled: true));
      final dir = _flutterAssetsDir();
      final src = dir == null ? null : File('$dir/$asset');
      final int expected;
      if (src != null && await src.exists()) {
        expected = await src.length();
        await src.copy(tmp.path);
      } else {
        final data = await _bundle.load(asset);
        expected = data.lengthInBytes;
        await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      if (await tmp.length() != expected) throw RaiEmbeddingException(appL10n.raiModelsSizeMismatch);
      await _verifySha(tmp);
      await tmp.rename(f.path);
      return f;
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      _bundleBroken = true;
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled, message: '$e'));
      return null;
    }
  }

  /// [RaiEmbeddingSpec.sha256] が分かっていれば、ファイルの sha256 と比べる。違えば [RaiEmbeddingException]。
  Future<void> _verifySha(File file) async {
    final want = spec.sha256;
    if (want == null) return;
    final got = (await crypto.sha256.bind(file.openRead()).first).toString();
    if (got != want.toLowerCase()) throw RaiEmbeddingException(appL10n.raiModelsChecksumMismatch);
  }

  /// 置き場のモデルのファイル(無ければ null。同梱なら写してから返す)。画像側 (D-293) は、これを絵文字の埋め込み器が読む。
  Future<File?> installedFile() => _ensureFile();

  @override
  Future<void> refresh() async {
    if (_current.phase == RaiEmbeddingPhase.downloading || _copying != null) return;
    try {
      final f = await _file();
      final inBundle = await bundled();
      if (await f.exists() || inBundle) {
        // 同梱なら、写す前から「準備完了」(初めて使うときに写す)。
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.ready, bundled: inBundle));
      } else {
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled, message: _bundleBroken ? _current.message : null));
      }
    } catch (e) {
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: '$e'));
    }
  }

  @override
  Future<void> install({String? hfToken}) async {
    if (await bundled()) {
      // ネットワークは使わない。写せなければ(壊れている)ダウンロードへ進む。
      if (await _ensureFile() != null) {
        _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready, bundled: true));
        return;
      }
    }
    final f = await _file();
    final tmp = File('${f.path}.part');
    final client = _httpClient();
    try {
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: 0));
      final url = spec.downloadUrl(central?.call());
      if (url == null) throw RaiEmbeddingException(appL10n.raiModelsCentralNotConfigured);
      final req = http.Request('GET', url);
      if (spec.centralPath == null && hfToken != null && hfToken.isNotEmpty) req.headers['Authorization'] = 'Bearer $hfToken';
      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) throw RaiEmbeddingException('HTTP ${res.statusCode} ($url)');
      final total = res.contentLength ?? spec.sizeMb * 1000 * 1000;
      final sink = tmp.openWrite();
      var got = 0;
      var last = -1;
      final done = Completer<void>();
      _download = res.stream.listen((chunk) {
        sink.add(chunk);
        got += chunk.length;
        final pct = (got * 100 ~/ total).clamp(0, 99);
        if (pct != last) {
          last = pct;
          _set(RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: pct));
        }
      }, onError: done.completeError, onDone: done.complete, cancelOnError: true);
      await done.future;
      await sink.close();
      // 途中で切れた応答を、出来上がったモデルとして置かない。
      if (res.contentLength != null && got != res.contentLength) throw RaiEmbeddingException(appL10n.raiModelsSizeMismatch);
      await _verifySha(tmp);
      await tmp.rename(f.path);
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled, message: appL10n.raiModelsDownloadFailed('$e')));
      throw RaiEmbeddingException(appL10n.raiModelsDownloadFailed('$e'));
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
    // 同梱のモデルは消さない(メモリを解放するだけ)。消せるのはダウンロードしたものだけ (D-522)。
    if (await bundled()) {
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready, bundled: true));
      return;
    }
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled));
  }

  @override
  Future<RaiEmbedder?> embedder() async {
    if (_embedder != null) return _embedder;
    return _loading ??= () async {
      try {
        final f = await _ensureFile();
        if (f == null) return null;
        final inBundle = await bundled();
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.loading, bundled: inBundle));
        switch (spec.kind) {
          case RaiEmbeddingKind.siglip2:
            final tok = SentencePieceBpe.fromModelBytes((await rootBundle.load(spec.tokenizerAsset)).buffer.asUint8List());
            _embedder = await OnnxRaiEmbedder.load(model: f, tokenizer: tok, maxLen: spec.maxLen);
          case RaiEmbeddingKind.minilm:
            final tok = UnigramTokenizer.fromTsv(await rootBundle.loadString(spec.tokenizerAsset));
            _embedder = await OnnxRaiEmbedder.loadMiniLm(model: f, tokenizer: tok, maxLen: spec.maxLen);
          case RaiEmbeddingKind.rasqText:
            final tok = UnigramTokenizer.fromTsv(await rootBundle.loadString(spec.tokenizerAsset));
            _embedder = await OnnxRaiEmbedder.loadRasqText(model: f, tokenizer: tok, maxLen: spec.maxLen);
          case RaiEmbeddingKind.siglip2Vision || RaiEmbeddingKind.rasqVision:
            // 画像側は、文の埋め込み器にはならない(絵文字 / 投稿の画像の埋め込み器が [installedFile] から読む)。
            _set(RaiEmbeddingStatus(RaiEmbeddingPhase.ready, bundled: inBundle));
            return null;
        }
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.ready, bundled: inBundle));
        return _embedder;
      } catch (e) {
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: appL10n.raiModelsLoadFailedOnnx('$e')));
        return null;
      } finally {
        _loading = null;
      }
    }();
  }

  @override
  Future<void> release() async {
    _embedder?.dispose();
    _embedder = null;
  }
}
