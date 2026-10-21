@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:stream_channel/stream_channel.dart';

import 'relay_module.dart';

/// ブラウザで動かす確認 (D-453): `flutter test --platform chrome test/web`(packages/plugin_runtime で)。
///
/// Codex セキュリティ検査の指摘 `resource-exhaustion.web-fetch-response-buffer`: Web 版の `net.fetch` は応答を
/// `res.arrayBuffer()` で丸ごと Worker のメモリに載せていた。いまは端末版 (rasq_wasm_runtime_core の
/// MAX_FETCH_BODY_BYTES) と同じ 32 MiB で読むのをやめて通信を切り、ゲストへは端末版と同じ B03 を返す。
/// 相手は spawnHybridUri で立てたローカルの HTTP サーバー (fetch_limit_server.dart)。送れたバイト数をサーバーで数え、
/// 上限を超えた応答を最後まで受け取っていない(= Worker のメモリに載せていない)ことも確かめる。

const _limit = 32 * 1024 * 1024;

void main() {
  late StreamChannel<Object?> channel;
  late StreamIterator<Object?> replies;
  late int port;
  late WasmPluginWorker worker;

  setUpAll(() async {
    channel = spawnHybridUri('fetch_limit_server.dart');
    replies = StreamIterator(channel.stream);
    expect(await replies.moveNext(), isTrue);
    port = replies.current! as int;
  });

  setUp(() async {
    worker = await WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: relayModule, permissions: const {'network'}, fetchHosts: const {'127.0.0.1'}));
  });
  tearDown(() => worker.dispose());

  Future<Map<String, Object?>> fetch(String path) async {
    final request = jsonEncode({'fn': 'net.fetch', 'callId': 'c1', 'args': {'url': 'http://127.0.0.1:$port$path'}});
    return (jsonDecode(await worker.call(fn: 'x', argsJson: request, callId: 'c1')) as Map).cast<String, Object?>();
  }

  /// サーバーがその道で送れたバイト数(応答を送り終える / 切られるのを待ってから)。
  Future<int> sentBytes(String path) async {
    channel.sink.add('sent:$path');
    expect(await replies.moveNext(), isTrue);
    return replies.current! as int;
  }

  test('小さい応答はそのまま届く', () async {
    final r = await fetch('/small');
    expect(r['ok'], isTrue, reason: '$r');
    expect((r['value']! as Map)['bodyText'], 'hello');
  });

  test('ちょうど上限 (32 MiB) の応答は届く', () async {
    final r = await fetch('/exact');
    expect(r['ok'], isTrue, reason: '${r['error']}');
    expect(((r['value']! as Map)['bodyText'] as String).length, _limit);
  });

  test('上限を超える応答 (Content-Length 無し) は、端末版と同じ B03 になり、残りは受け取らない', () async {
    final r = await fetch('/huge-chunked');
    expect(r['ok'], isFalse);
    expect(r['callId'], 'c1');
    expect(r['error'], {'code': 'B03', 'message': 'response body exceeds $_limit bytes'});
    // 256 MiB のうち、上限 + ブラウザ / OS の先読みぶんしか送れていない(直す前は 256 MiB を丸ごと受け取っていた)。
    expect(await sentBytes('/huge-chunked'), lessThan(2 * _limit));
  });

  test('Content-Length が上限を超える応答は、読む前に B03', () async {
    final r = await fetch('/huge-length');
    expect(r['ok'], isFalse);
    expect(r['error'], {'code': 'B03', 'message': 'response body exceeds $_limit bytes'});
    // 名乗った 64 MiB のうち、上限にも届かないうちに切っている(直す前は 64 MiB を受け取って ok で返していた)。
    expect(await sentBytes('/huge-length'), lessThan(_limit));
  });
}
