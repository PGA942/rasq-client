import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../theme/icon_theme/icon_theme_reader.dart' show iconThemeFetcherProvider;
import 'header_hint_codec.dart';

/// ヘッダーの「RASQ アカウントの手がかり」を読む / 書く (D-591)。中身の形は [headerHintEncode]。
///
/// - 読む: SNS のユーザーページで、ヘッダーの画像を取り直して上の縁を読む(画像の取り口はアイコンのテーマと同じ
///   [iconThemeFetcherProvider]。SNS が配っている画像を取るだけで、Central へは何も送らない)。復号は別の isolate、
///   同時に 2 つまで、結果は URL ごとに覚える(読めなかったことも)。
/// - 書く: SNS のプロフィール編集でヘッダーを保存するとき。真ん中で 3:1 に切って 1440×480 にし、上の縁に書いて JPEG
///   (色差を間引かない 4:4:4、品質 92)。

/// 画像のバイト列 → 手がかり(別の isolate で動く。読めなければ null)。
HeaderHint? decodeHeaderHintBytes(Uint8List bytes) {
  final im = _decode(bytes);
  if (im == null || im.width < 288 || im.height < 48) return null;
  // 3:1 に近いものだけ(書くときに 3:1 に揃える。SNS は縦横の比を保って縮める)。
  final ratio = im.width / im.height;
  if (ratio < 2.6 || ratio > 3.4) return null;
  return headerHintDecode(im.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba), im.width, im.height);
}

img.Image? _decode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null; // 壊れた / 知らない形式
  }
}

/// [headerHintWriteImage] に渡すもの。
class HeaderHintWriteJob {
  const HeaderHintWriteJob({required this.source, required this.handle, required this.accountKey});
  final Uint8List source;
  final String handle;

  /// 書く SNS アカウント(`kind:instance:handle`)。
  final String accountKey;
}

/// ヘッダーの画像 → 3:1 に切って手がかりを書いた JPEG(読めない画像 / 書けないハンドル → null)。
Uint8List? headerHintWriteImage(HeaderHintWriteJob job) {
  final im = _decode(job.source);
  if (im == null || !headerHintCanEmbed(job.handle)) return null;
  final sized = _fit3x1(im);
  final d = Uint8List.fromList(sized.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba));
  headerHintEncode(d, job.handle, job.accountKey);
  final out = img.Image.fromBytes(width: headerHintWidth, height: headerHintHeight, bytes: d.buffer, numChannels: 4);
  return Uint8List.fromList(img.encodeJpg(out, quality: 92));
}

/// ヘッダーの画像 → 上の縁の手がかりを消したもの(帯のすぐ下を折り返して塗る。大きさは変えない)。読めなければ null。
Uint8List? headerHintEraseImage(Uint8List bytes) {
  final im = _decode(bytes);
  if (im == null || im.height < 48) return null;
  final out = im.convert(numChannels: 4);
  // 帯 = 高さの 1/48。縮めたときの滲みも含めて少し多めに。
  final band = (out.height / 48).ceil() + 1;
  for (var y = 0; y < band; y++) {
    final from = math.min(2 * band - 1 - y, out.height - 1);
    for (var x = 0; x < out.width; x++) {
      out.setPixel(x, y, out.getPixel(x, from));
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 92));
}

/// 真ん中で 3:1 に切って 1440×480 に。
img.Image _fit3x1(img.Image im) {
  var w = im.width, h = im.height;
  if (w > h * 3) {
    w = h * 3;
  } else {
    h = (w / 3).round();
  }
  final cropped = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
  return img.copyResize(cropped, width: headerHintWidth, height: headerHintHeight, interpolation: img.Interpolation.cubic);
}

const _cacheSize = 128;
const _maxConcurrent = 2;

/// URL ごとの結果と、取り / 復号の順番待ち。
class HeaderHintCache {
  HeaderHintCache(this._fetcher);
  final Future<Uint8List?> Function(Uri) _fetcher;
  final _done = <String, HeaderHint?>{};
  final _pending = <String, Future<HeaderHint?>>{};
  final _queue = Queue<Completer<void>>();
  var _running = 0;

  Future<HeaderHint?> read(String url) {
    if (_done.containsKey(url)) {
      final v = _done.remove(url);
      _done[url] = v;
      return SynchronousFuture(v);
    }
    return _pending[url] ??= _run(url);
  }

  /// 覚えている結果を捨てる(自分のヘッダーを替えたとき)。
  void forget(String url) => _done.remove(url);

  Future<HeaderHint?> _run(String url) async {
    if (_running >= _maxConcurrent) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _running++;
    HeaderHint? hint;
    try {
      final uri = Uri.tryParse(url);
      final bytes = uri == null ? null : await _fetcher(uri);
      if (bytes != null) hint = kIsWeb ? decodeHeaderHintBytes(bytes) : await compute(decodeHeaderHintBytes, bytes);
    } catch (e) {
      debugPrint('header hint: $url unreadable: $e');
    } finally {
      _running--;
      if (_queue.isNotEmpty) _queue.removeFirst().complete();
    }
    _pending.remove(url);
    _done[url] = hint;
    while (_done.length > _cacheSize) {
      _done.remove(_done.keys.first);
    }
    return hint;
  }
}

final headerHintCacheProvider = Provider<HeaderHintCache>((ref) => HeaderHintCache(ref.watch(iconThemeFetcherProvider)));

/// ヘッダー [url] に入っている手がかり(無い / 読めない → null)。
final headerHintProvider = FutureProvider.family<HeaderHint?, String>((ref, url) => ref.watch(headerHintCacheProvider).read(url));
