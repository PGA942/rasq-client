import 'dart:io';
import 'dart:typed_data';

import 'media_fetch.dart';

/// 画像用の通信(NetworkImage と同じく 1 つを使い回す)。
final HttpClient _client = HttpClient()..autoUncompress = true;

Future<Uint8List> fetchMedia(Uri url, bool Function(Uri url) allowHop, {required int maxRedirects, required int maxBytes}) async {
  var current = url;
  if (!allowHop(current)) throw RasqMediaBlocked(current, 'not allowed');
  for (var hop = 0;; hop++) {
    final request = await _client.getUrl(current);
    // 転送先を確かめずに送らない。
    request.followRedirects = false;
    final response = await request.close();
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) throw HttpException('redirect without location', uri: current);
      if (hop >= maxRedirects) throw RasqMediaBlocked(current, 'too many redirects');
      final next = current.resolve(location);
      // 各ホップで方針を確かめ直す(宣言の外 / loopback / LAN などへは送らない)。
      if (!allowHop(next)) throw RasqMediaBlocked(next, 'redirect not allowed');
      current = next;
      continue;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: current);
    }
    if (response.contentLength > maxBytes) {
      await response.drain<void>();
      throw RasqMediaBlocked(current, 'too large');
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in response) {
      out.add(chunk);
      if (out.length > maxBytes) throw RasqMediaBlocked(current, 'too large');
    }
    return out.takeBytes();
  }
}
