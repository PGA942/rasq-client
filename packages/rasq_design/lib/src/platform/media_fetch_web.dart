import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'media_fetch.dart';

/// Web 版: ブラウザはリダイレクトの転送先をページに見せずに追う(`<img>` も XHR も)。転送先を確かめてから送ることが
/// できないので、`redirect: 'manual'` で**追わずに**断る(net.fetch の Web 版と同じ、D-407)。同じ接続先の中の転送も追えない。
/// 資格情報は送らない。本文は少しずつ読み、[maxBytes] を超えたら通信を切る。
Future<Uint8List> fetchMedia(Uri url, bool Function(Uri url) allowHop, {required int maxRedirects, required int maxBytes}) async {
  if (!allowHop(url)) throw RasqMediaBlocked(url, 'not allowed');
  final abort = web.AbortController();
  final web.Response res;
  try {
    res = await web.window.fetch(url.toString().toJS, web.RequestInit(redirect: 'manual', credentials: 'omit', signal: abort.signal)).toDart;
  } catch (e) {
    throw StateError('fetch failed (network / CORS): $e');
  }
  if (res.type == 'opaqueredirect' || (res.status >= 300 && res.status < 400)) {
    abort.abort();
    throw RasqMediaBlocked(url, 'redirect is not followed on web');
  }
  if (res.status != 200) {
    abort.abort();
    throw StateError('HTTP ${res.status}');
  }
  final len = int.tryParse(res.headers.get('content-length') ?? '');
  final coding = (res.headers.get('content-encoding') ?? 'identity').trim().toLowerCase();
  if (len != null && coding == 'identity' && len > maxBytes) {
    abort.abort();
    throw RasqMediaBlocked(url, 'too large');
  }
  final body = res.body;
  if (body == null) return Uint8List(0);
  final reader = body.getReader() as web.ReadableStreamDefaultReader;
  final out = BytesBuilder(copy: false);
  for (;;) {
    final r = await reader.read().toDart;
    if (r.done) break;
    final chunk = (r.value as JSUint8Array?)?.toDart;
    if (chunk == null) continue;
    out.add(chunk);
    if (out.length > maxBytes) {
      reader.cancel().toDart.ignore();
      abort.abort();
      throw RasqMediaBlocked(url, 'too large');
    }
  }
  return out.takeBytes();
}
