import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

/// `wasm_web_fetch_limit_test.dart` の相手 (D-453): spawnHybridUri で VM 側に立てる、ローカルの HTTP サーバー。
///
/// - `/small`: 小さい本文。
/// - `/exact`: ちょうど上限 (32 MiB) の本文(Content-Length 付き)。
/// - `/huge-chunked`: Content-Length 無しで 256 MiB を流し続ける(相手が切ったら止める)。
/// - `/huge-length`: Content-Length 64 MiB を名乗り、本文を流す(相手が切ったら止める)。
///
/// 送れたバイト数を道 (path) ごとに数えておき、`'sent:<path>'` を受けたら、その応答を送り終えてから数を返す。
Future<void> hybridMain(StreamChannel<Object?> channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final sent = <String, int>{};
  final done = <String, Completer<void>>{};
  final chunk = Uint8List(64 * 1024)..fillRange(0, 64 * 1024, 0x61); // "aaaa…"(UTF-8 として読める)

  // HttpResponse の flush は相手が切っても失敗を返さないことがあるので、ソケットを切り離して自分で書く
  // (書けなかった = 相手が切った、を確実に数えるため)。Content-Length が無ければ、本文は接続を閉じて終わる形。
  Future<void> stream(HttpResponse res, String path, int total) async {
    final finished = done.putIfAbsent(path, Completer<void>.new);
    res.persistentConnection = false;
    res.headers.chunkedTransferEncoding = false;
    try {
      final socket = await res.detachSocket();
      try {
        while (sent[path]! < total) {
          final n = (total - sent[path]!).clamp(0, chunk.length);
          socket.add(n == chunk.length ? chunk : Uint8List.sublistView(chunk, 0, n));
          await socket.flush().timeout(const Duration(seconds: 10));
          sent[path] = sent[path]! + n;
        }
        await socket.close();
      } finally {
        socket.destroy();
      }
    } catch (_) {
      // 相手(ブラウザ)が切った。
    } finally {
      if (!finished.isCompleted) finished.complete();
    }
  }

  server.listen((req) async {
    final res = req.response;
    final path = req.uri.path;
    res.headers.set('access-control-allow-origin', '*');
    res.headers.set('access-control-expose-headers', '*');
    res.headers.contentType = ContentType.text;
    sent[path] = 0;
    switch (path) {
      case '/small':
        res.write('hello');
        await res.close();
        sent[path] = 5;
        done.putIfAbsent(path, Completer<void>.new).complete();
      case '/exact':
        res.contentLength = 32 * 1024 * 1024;
        await stream(res, path, 32 * 1024 * 1024);
      case '/huge-chunked':
        await stream(res, path, 256 * 1024 * 1024);
      case '/huge-length':
        res.contentLength = 64 * 1024 * 1024;
        await stream(res, path, 64 * 1024 * 1024);
      default:
        res.statusCode = 404;
        await res.close();
    }
  });

  channel.stream.listen((msg) async {
    final s = '$msg';
    if (s.startsWith('sent:')) {
      final path = s.substring(5);
      await done.putIfAbsent(path, Completer<void>.new).future.timeout(const Duration(seconds: 30), onTimeout: () {});
      channel.sink.add(sent[path] ?? -1);
    }
  });
  channel.sink.add(server.port);
}
