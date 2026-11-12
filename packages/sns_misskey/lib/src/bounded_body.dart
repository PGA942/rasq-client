import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 応答本文が上限を超えた(読むのをやめて通信を切った。セキュリティ確認 2026-11-11 の #13)。
class MisskeyResponseTooLarge implements Exception {
  const MisskeyResponseTooLarge(this.maxBytes);
  final int maxBytes;
  @override
  String toString() => 'response exceeds $maxBytes bytes';
}

/// 要求を出し、応答の本文を上限つきで読む (#13)。
///
/// `http.Response.fromStream` / `Client.post` は相手が送るだけ本文をメモリに貯めるので、ここでは少しずつ読み、届いた本文
/// (端末版の http は圧縮を展開しながら渡すので、展開後)の累計が [maxBytes] を超えたら、その場で要求を取り消して
/// [MisskeyResponseTooLarge] を投げる。Content-Length は当てにしない(上限を超えると申告していれば、読む前に断る)。
/// [headerTimeout] = 応答の頭までの期限、[totalTimeout] = 本文を読み終えるまでの全体の期限。どちらも過ぎたら要求を取り消して
/// [TimeoutException] を投げる(`Future.timeout` のように待つのをやめるだけで通信が続く、ということがない)。
/// [build] は取り消しの合図([abort])を持つ要求(`AbortableRequest` / `AbortableMultipartRequest`)を作る。
Future<({int statusCode, Uint8List body})> sendBounded(
  http.Client client,
  http.BaseRequest Function(Future<void> abort) build, {
  required int maxBytes,
  required Duration headerTimeout,
  required Duration totalTimeout,
}) async {
  final abort = Completer<void>();
  final timedOut = Completer<TimeoutException>();
  void expire(String what, Duration d) {
    if (!timedOut.isCompleted) timedOut.complete(TimeoutException(what, d));
    if (!abort.isCompleted) abort.complete();
  }

  final total = Timer(totalTimeout, () => expire('response body', totalTimeout));
  final header = Timer(headerTimeout, () => expire('response headers', headerTimeout));
  StreamSubscription<List<int>>? sub;
  try {
    final send = client.send(build(abort.future));
    final first = await Future.any<Object>([send, timedOut.future]);
    if (first is TimeoutException) {
      unawaited(send.then((r) => r.stream.listen(null).cancel(), onError: (_) {}));
      throw first;
    }
    header.cancel();
    final res = first as http.StreamedResponse;
    final declared = res.contentLength;
    if (declared != null && declared > maxBytes) {
      if (!abort.isCompleted) abort.complete();
      unawaited(res.stream.listen(null).cancel());
      throw MisskeyResponseTooLarge(maxBytes);
    }
    var builder = BytesBuilder(copy: false);
    final done = Completer<void>();
    unawaited(timedOut.future.then((e) {
      if (!done.isCompleted) done.completeError(e);
    }));
    sub = res.stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        if (builder.length + chunk.length > maxBytes) {
          builder = BytesBuilder(copy: false); // 読んだぶんもすぐ手放す
          if (!abort.isCompleted) abort.complete();
          unawaited(sub?.cancel());
          done.completeError(MisskeyResponseTooLarge(maxBytes));
          return;
        }
        builder.add(chunk);
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    return (statusCode: res.statusCode, body: builder.takeBytes());
  } on http.RequestAbortedException {
    if (timedOut.isCompleted) throw await timedOut.future;
    rethrow;
  } finally {
    total.cancel();
    header.cancel();
    await sub?.cancel();
  }
}
