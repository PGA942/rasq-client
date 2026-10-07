@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:stream_channel/stream_channel.dart';

/// ブラウザで動かす確認 (D-453): `flutter test --platform chrome test/web`(packages/plugin_runtime で)。
///
/// Codex セキュリティ検査の指摘 `resource-exhaustion.web-fetch-response-buffer`: Web 版の `net.fetch` は応答を
/// `res.arrayBuffer()` で丸ごと Worker のメモリに載せていた。いまは端末版 (rasq_wasm_runtime_core の
/// MAX_FETCH_BODY_BYTES) と同じ 32 MiB で読むのをやめて通信を切り、ゲストへは端末版と同じ B03 を返す。
/// 相手は spawnHybridUri で立てたローカルの HTTP サーバー (fetch_limit_server.dart)。送れたバイト数をサーバーで数え、
/// 上限を超えた応答を最後まで受け取っていない(= Worker のメモリに載せていない)ことも確かめる。

const _limit = 32 * 1024 * 1024;

/// ホスト関数の要求 JSON を `call` の args にそのまま受け取り、`host_fn` に渡して答えを返すだけのゲスト。
/// alloc はバンプ式(足りなければ memory.grow)、dealloc は何もしない。
/// (wat: `(func (export "call") (param i32 i32 i32 i32 i32 i32) (result i64) (call $host (local.get 2) (local.get 3)))` …)
final _relayModule = Uint8List.fromList([
  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x1f, 0x05, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7e, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f, 0x7f, 0x00, 0x60, 0x00, 0x01, 0x7e, 0x60, 0x06, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7e, 0x02, 0x10, 0x01, 0x04, 0x72, 0x61, 0x73, 0x71, 0x07, 0x68, 0x6f, 0x73, 0x74, 0x5f, 0x66, 0x6e, 0x00, 0x00, 0x03, 0x06, 0x05, 0x01, 0x02, 0x03, 0x03, 0x04, 0x05, 0x03, 0x01, 0x00, 0x01, 0x06, 0x07, 0x01, 0x7f, 0x01, 0x41, 0x80, 0x08, 0x0b, 0x07, 0x36, 0x06, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00, 0x05, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x00, 0x01, 0x07, 0x64, 0x65, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x00, 0x02, 0x08, 0x73, 0x6e, 0x61, 0x70, 0x73, 0x68, 0x6f, 0x74, 0x00, 0x03, 0x05, 0x70, 0x61, 0x74, 0x63, 0x68, 0x00, 0x04, 0x04, 0x63, 0x61, 0x6c, 0x6c, 0x00, 0x05, 0x0a, 0x45, 0x05, 0x2d, 0x01, 0x02, 0x7f, 0x23, 0x00, 0x21, 0x01, 0x23, 0x00, 0x20, 0x00, 0x6a, 0x24, 0x00, 0x23, 0x00, 0x41, 0xff, 0xff, 0x03, 0x6a, 0x41, 0x10, 0x76, 0x3f, 0x00, 0x6b, 0x21, 0x02, 0x20, 0x02, 0x41, 0x00, 0x4a, 0x04, 0x40, 0x20, 0x02, 0x40, 0x00, 0x1a, 0x0b, 0x20, 0x01, 0x0b, 0x02, 0x00, 0x0b, 0x04, 0x00, 0x42, 0x00, 0x0b, 0x04, 0x00, 0x42, 0x00, 0x0b, 0x08, 0x00, 0x20, 0x02, 0x20, 0x03, 0x10, 0x00, 0x0b,
]);

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
    worker = await WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: _relayModule, permissions: const {'network'}, fetchHosts: const {'127.0.0.1'}));
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
