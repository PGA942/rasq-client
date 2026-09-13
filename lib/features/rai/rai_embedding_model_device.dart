import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'rai_embedding_model.dart';
import 'rai_minilm_tokenizer.dart';
import 'rai_onnx_embedder.dart';
import 'rai_reference.dart';
import 'rai_siglip_tokenizer.dart';

/// 端末側の埋め込みモデル (D-190): `ApplicationSupport/rai_models/siglip2/` に ONNX を流し込み、
/// 同梱のトークナイザーと合わせて [OnnxRaiEmbedder] を作る。
class DeviceRaiEmbeddingModel implements RaiEmbeddingModel {
  DeviceRaiEmbeddingModel({this.spec = raiEmbeddingSpec});
  @override
  final RaiEmbeddingSpec spec;
  final _ctrl = StreamController<RaiEmbeddingStatus>.broadcast();
  RaiEmbeddingStatus _current = RaiEmbeddingStatus.initial;
  OnnxRaiEmbedder? _embedder;
  Future<OnnxRaiEmbedder?>? _loading;
  StreamSubscription<List<int>>? _download;

  @override
  RaiEmbeddingStatus get current => _current;
  @override
  Stream<RaiEmbeddingStatus> get statuses => _ctrl.stream;

  void _set(RaiEmbeddingStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  Future<File> _file() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/rai_models/${spec.id}');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/${spec.fileName}');
  }

  @override
  Future<void> refresh() async {
    if (_current.phase == RaiEmbeddingPhase.downloading) return;
    try {
      final f = await _file();
      _set(RaiEmbeddingStatus(await f.exists() ? RaiEmbeddingPhase.ready : RaiEmbeddingPhase.notInstalled));
    } catch (e) {
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: '$e'));
    }
  }

  @override
  Future<void> install({String? hfToken}) async {
    final f = await _file();
    final tmp = File('${f.path}.part');
    final client = http.Client();
    try {
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: 0));
      final req = http.Request('GET', Uri.parse(spec.url));
      if (hfToken != null && hfToken.isNotEmpty) req.headers['Authorization'] = 'Bearer $hfToken';
      final res = await client.send(req);
      if (res.statusCode != 200) throw RaiEmbeddingException('HTTP ${res.statusCode}');
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
      await tmp.rename(f.path);
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled, message: 'ダウンロードに失敗しました: $e'));
      throw RaiEmbeddingException('ダウンロードに失敗しました: $e');
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
        final f = await _file();
        if (!await f.exists()) return null;
        _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.loading));
        switch (spec.kind) {
          case RaiEmbeddingKind.siglip2:
            final tok = SentencePieceBpe.fromModelBytes((await rootBundle.load(spec.tokenizerAsset)).buffer.asUint8List());
            _embedder = await OnnxRaiEmbedder.load(model: f, tokenizer: tok, maxLen: spec.maxLen);
          case RaiEmbeddingKind.minilm:
            final tok = UnigramTokenizer.fromTsv(await rootBundle.loadString(spec.tokenizerAsset));
            _embedder = await OnnxRaiEmbedder.loadMiniLm(model: f, tokenizer: tok, maxLen: spec.maxLen);
        }
        _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
        return _embedder;
      } catch (e) {
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: 'モデルを読み込めません(onnxruntime): $e'));
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
