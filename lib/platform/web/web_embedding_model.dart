import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../features/emoji/emoji_image_embedder.dart';
import '../../features/emoji/emoji_image_preprocess.dart';
import '../../features/rai/rai_embedding_model.dart';
import '../../features/rai/rai_minilm_tokenizer.dart';
import '../../features/rai/rai_reference.dart';
import '../../features/rai/rai_siglip_tokenizer.dart';
import '../../features/emoji/emoji_image_decode.dart';
import 'ort_web.dart';

/// Web 版の埋め込みモデル (D-302): 端末の [DeviceRaiEmbeddingModel] と同じ契約を、onnxruntime-web + IndexedDB で満たす。
/// トークナイザーと前処理は、端末と同じ Dart のコード。
class WebRaiEmbeddingModel implements RaiEmbeddingModel {
  WebRaiEmbeddingModel({this.spec = raiEmbeddingSpec, this.central});
  @override
  final RaiEmbeddingSpec spec;

  /// RASQ Central の根(Central が配るモデル、D-390)。
  final Uri? Function()? central;
  static const _store = WebModelStore();
  final _ctrl = StreamController<RaiEmbeddingStatus>.broadcast();
  RaiEmbeddingStatus _current = RaiEmbeddingStatus.initial;
  _WebTextEmbedder? _embedder;
  Future<RaiEmbedder?>? _loading;

  @override
  RaiEmbeddingStatus get current => _current;
  @override
  Stream<RaiEmbeddingStatus> get statuses => _ctrl.stream;

  void _set(RaiEmbeddingStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  @override
  Future<void> refresh() async {
    if (_current.phase == RaiEmbeddingPhase.downloading) return;
    try {
      _set(RaiEmbeddingStatus(await _store.has(spec.id) ? RaiEmbeddingPhase.ready : RaiEmbeddingPhase.notInstalled));
    } catch (e) {
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: '$e'));
    }
  }

  @override
  Future<void> install({String? hfToken}) async {
    try {
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: 0));
      final url = spec.downloadUrl(central?.call());
      if (url == null) throw const RaiEmbeddingException('RASQ サーバーの接続先が未設定です');
      await _store.download(spec.id, url,
          token: spec.centralPath != null || hfToken == null || hfToken.isEmpty ? null : hfToken, fallbackTotal: spec.sizeMb * 1000 * 1000, onProgress: (p) => _set(RaiEmbeddingStatus(RaiEmbeddingPhase.downloading, progress: p)));
      _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
    } catch (e) {
      _set(RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled, message: 'ダウンロードに失敗しました: $e'));
      throw RaiEmbeddingException('ダウンロードに失敗しました: $e');
    }
  }

  @override
  Future<void> uninstall() async {
    _store.cancel(spec.id);
    await release();
    try {
      await _store.remove(spec.id);
    } catch (_) {}
    _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.notInstalled));
  }

  /// 画像側 (D-293) のセッション。入っていなければ null。
  Future<WebOrtSession?> openSession() => WebOrtSession.open(spec.id);

  @override
  Future<RaiEmbedder?> embedder() async {
    if (_embedder != null) return _embedder;
    if (spec.kind == RaiEmbeddingKind.siglip2Vision || spec.kind == RaiEmbeddingKind.rasqVision) return null; // 画像側は、文の埋め込み器にはならない
    return _loading ??= () async {
      try {
        if (!await _store.has(spec.id)) return null;
        _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.loading));
        final session = await WebOrtSession.open(spec.id);
        if (session == null) return null;
        if (!session.inputNames.contains('input_ids')) {
          await session.release();
          throw StateError('embedding model: input "input_ids" not found (${session.inputNames})');
        }
        switch (spec.kind) {
          case RaiEmbeddingKind.siglip2:
            final tok = SentencePieceBpe.fromModelBytes((await rootBundle.load(spec.tokenizerAsset)).buffer.asUint8List());
            _embedder = _WebTextEmbedder(session, (t) => tok.encode(t, maxLen: spec.maxLen), 'siglip2-onnx', spec.maxLen, meanPool: false);
          case RaiEmbeddingKind.minilm:
            final tok = UnigramTokenizer.fromTsv(await rootBundle.loadString(spec.tokenizerAsset));
            _embedder = _WebTextEmbedder(session, (t) => tok.encode(t, maxLen: spec.maxLen), 'minilm-onnx', spec.maxLen, meanPool: true);
          case RaiEmbeddingKind.rasqText:
            final tok = UnigramTokenizer.fromTsv(await rootBundle.loadString(spec.tokenizerAsset));
            _embedder = _WebTextEmbedder(session, (t) => tok.encode(t, maxLen: spec.maxLen), 'rasq-minilm-onnx', spec.maxLen, meanPool: true, pooled: true);
          case RaiEmbeddingKind.siglip2Vision || RaiEmbeddingKind.rasqVision:
            return null;
        }
        _set(const RaiEmbeddingStatus(RaiEmbeddingPhase.ready));
        return _embedder;
      } catch (e) {
        _set(RaiEmbeddingStatus(RaiEmbeddingPhase.error, message: 'モデルを読み込めません(onnxruntime-web): $e'));
        return null;
      } finally {
        _loading = null;
      }
    }();
  }

  @override
  Future<void> release() async {
    await _embedder?._session.release();
    _embedder = null;
  }
}

/// 文の埋め込み。形は端末の `OnnxRaiEmbedder` と同じ(SigLIP2 = 固定長 + pooler_output、MiniLM = 可変長 + mean pooling)。名前も同じにして、索引を共用できる形にする。
class _WebTextEmbedder implements RaiEmbedder {
  _WebTextEmbedder(this._session, this._encode, this.name, this._maxLen, {required this.meanPool, this.pooled = false});

  /// RASQ MiniLM (D-390): attention_mask は float、出力は平均済みの `embedding`。
  final bool pooled;
  final WebOrtSession _session;
  final List<int> Function(String text) _encode;
  @override
  final String name;
  final int _maxLen;
  final bool meanPool;
  static const batch = 8;

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    final out = <List<double>>[];
    for (var i = 0; i < texts.length; i += batch) {
      out.addAll(await _run(texts.sublist(i, math.min(texts.length, i + batch))));
    }
    return out;
  }

  Future<List<List<double>>> _run(List<String> texts) async {
    final encoded = [for (final t in texts) _encode(t)];
    final len = meanPool ? encoded.fold<int>(1, (m, e) => math.max(m, e.length)) : _maxLen;
    final n = texts.length;
    final ids = Int32List(n * len)..fillRange(0, n * len, meanPool ? UnigramTokenizer.padId : SentencePieceBpe.padId);
    final mask = Int32List(n * len);
    for (var b = 0; b < n; b++) {
      for (var t = 0; t < encoded[b].length && t < len; t++) {
        ids[b * len + t] = encoded[b][t];
        mask[b * len + t] = 1;
      }
    }
    final ints = <String, (Int32List, List<int>)>{'input_ids': (ids, [n, len])};
    if (pooled) {
      final (data, dims) = await _session.run(ints: ints, floats: {'attention_mask': (Float32List.fromList([for (final m in mask) m.toDouble()]), [n, len])}, output: 'embedding');
      final d = dims.last;
      return [for (var b = 0; b < n; b++) NgramRaiEmbedder.normalize([for (var k = 0; k < d; k++) data[b * d + k]])];
    }
    if (meanPool) {
      if (_session.inputNames.contains('attention_mask')) ints['attention_mask'] = (mask, [n, len]);
      if (_session.inputNames.contains('token_type_ids')) ints['token_type_ids'] = (Int32List(n * len), [n, len]);
    }
    final (data, dims) = await _session.run(ints: ints, output: meanPool ? 'last_hidden_state' : 'pooler_output');
    final d = dims.last;
    if (!meanPool) return [for (var b = 0; b < n; b++) NgramRaiEmbedder.normalize([for (var k = 0; k < d; k++) data[b * d + k]])];
    final out = <List<double>>[];
    for (var b = 0; b < n; b++) {
      final sum = List<double>.filled(d, 0);
      var count = 0;
      for (var t = 0; t < len; t++) {
        if (mask[b * len + t] == 0) continue;
        count++;
        final base = (b * len + t) * d;
        for (var k = 0; k < d; k++) {
          sum[k] += data[base + k];
        }
      }
      out.add(NgramRaiEmbedder.normalize([for (final x in sum) x / math.max(1, count)]));
    }
    return out;
  }
}

/// 絵の埋め込み (D-293) の Web 版。前処理は端末と同じ。
class WebEmojiImageEmbedder implements EmojiImageEmbedder {
  WebEmojiImageEmbedder._(this._session, this._output, this.name);
  final WebOrtSession _session;
  final String _output;
  static const size = 224;
  static const batch = 4;

  /// 絵文字 = SigLIP2 の画像側、投稿の画像 (D-390) = RASQ MobileNet。
  @override
  final String name;

  static Future<WebEmojiImageEmbedder?> load(WebRaiEmbeddingModel model) async {
    final session = await model.openSession();
    if (session == null) return null;
    final out = ['pooler_output', 'image_embeds', 'embedding'].where(session.outputNames.contains).firstOrNull;
    if (!session.inputNames.contains('pixel_values') || out == null) {
      await session.release();
      throw StateError('image model: unexpected inputs / outputs (${session.inputNames} → ${session.outputNames})');
    }
    return WebEmojiImageEmbedder._(session, out, out == 'embedding' ? 'rasq-mobilenet-onnx' : 'siglip2-vision-onnx');
  }

  @override
  Future<List<List<double>?>> embedImages(List<Uint8List> encoded) async {
    final out = List<List<double>?>.filled(encoded.length, null);
    for (var i = 0; i < encoded.length; i += batch) {
      final end = math.min(encoded.length, i + batch);
      final pixels = <Float32List>[];
      final slots = <int>[];
      for (var k = i; k < end; k++) {
        final rgba = await decodeEmojiRgba(encoded[k], size: size);
        if (rgba == null) continue;
        pixels.add(emojiPixelValues(rgba, size: size));
        slots.add(k);
      }
      if (pixels.isEmpty) continue;
      final per = 3 * size * size;
      final flat = Float32List(pixels.length * per);
      for (var p = 0; p < pixels.length; p++) {
        flat.setRange(p * per, (p + 1) * per, pixels[p]);
      }
      final (data, dims) = await _session.run(floats: {'pixel_values': (flat, [pixels.length, 3, size, size])}, output: _output);
      final d = dims.last;
      for (var k = 0; k < slots.length; k++) {
        out[slots[k]] = NgramRaiEmbedder.normalize([for (var x = 0; x < d; x++) data[k * d + x]]);
      }
    }
    return out;
  }

  Future<void> dispose() => _session.release();
}
