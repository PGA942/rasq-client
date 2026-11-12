import 'dart:async';
import 'dart:io' show File, IOSink;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../l10n/l10n.dart';

/// 応答本文を上限つきで読む GET(セキュリティ確認 2026-10-09 の [18])。
///
/// `http.get` は相手が送るだけ本文をメモリに貯めてから返すので、そのあとで大きさを見ても、貯める間のメモリは止まらない
/// (期限は時間を区切るだけで、速い巨大な応答は止めない)。ここでは本文を少しずつ読み、累計が [maxBytes] を 1 バイトでも
/// 超えたら、その場で読むのをやめて通信を切り(購読の cancel)、読んだぶんも手放して [ResponseTooLargeException] を投げる。
/// Content-Length が上限を超えていれば読む前に断る(嘘の / 無い Content-Length は読みながら数える方で止まる)。
/// 数えるのは届いた本文そのもの(端末版の http は圧縮を展開しながら渡すので、展開後の大きさ)。リダイレクトは http の
/// 既定どおり追い、最後の応答の本文を同じ上限で読む。Web 版プラグインの net.fetch の上限 (D-453) と同じ考え。
///
/// [timeout] は応答の頭と本文を読み終えるまでの全体。期限 / [cancelled] では要求そのものを取り消す(`AbortableRequest`。
/// `Future.timeout` のように待つのをやめるだけで通信が続く、ということがない。セキュリティ確認 2026-11-11 の #6 / #21)。
/// 200 以外も本文は読まずに [LimitedResponse.statusCode] だけ返す。
/// [client] を渡さなければ 1 回限りの [http.Client] を作って閉じる(テストは `http.runWithClient` で差し替えられる)。
Future<LimitedResponse> getLimited(Uri url, {required int maxBytes, required Duration timeout, http.Client? client, bool Function()? cancelled}) async {
  var builder = BytesBuilder(copy: false);
  final (status, headers) = await _streamLimited(
    url,
    maxBytes: maxBytes,
    timeout: timeout,
    client: client,
    cancelled: cancelled,
    onChunk: builder.add,
    onTooLarge: () => builder = BytesBuilder(copy: false), // 読んだぶんもすぐ手放す
  );
  return LimitedResponse(status, headers, builder.takeBytes());
}

/// [getLimited] と同じ上限 / 期限 / 取り消しで、本文を [file] へ順に書く(メモリに貯めない。#6 / #21)。
/// 200 でない / 上限を超えた / 期限切れ / 取り消し / 書けない、のどれでも途中のファイルを消して投げる。戻り = [file]。
Future<File> getLimitedToFile(Uri url, File file, {required int maxBytes, required Duration timeout, http.Client? client, bool Function()? cancelled}) async {
  IOSink? sink;
  try {
    sink = file.openWrite();
    final out = sink;
    final (status, _) = await _streamLimited(url, maxBytes: maxBytes, timeout: timeout, client: client, cancelled: cancelled, onChunk: out.add);
    if (status != 200) throw http.ClientException('HTTP $status', url);
    await out.flush();
    await out.close();
    sink = null;
    return file;
  } catch (_) {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    rethrow;
  }
}

/// 取り消された([cancelled] が true になった)。
class RequestCancelledException implements Exception {
  const RequestCancelledException(this.url);
  final Uri url;
  @override
  String toString() => 'cancelled: $url';
}

/// 期限 / 取り消しを見る間隔。
const _pollEvery = Duration(milliseconds: 200);

/// 本体: 要求を出し、200 なら本文を [onChunk] へ渡す。戻り = 状態と頭。
Future<(int, Map<String, String>)> _streamLimited(
  Uri url, {
  required int maxBytes,
  required Duration timeout,
  required void Function(List<int> chunk) onChunk,
  void Function()? onTooLarge,
  http.Client? client,
  bool Function()? cancelled,
}) async {
  final own = client == null;
  final c = client ?? http.Client();
  final abort = Completer<void>();
  final stop = Completer<Exception>(); // 期限 / 取り消しの理由
  StreamSubscription<List<int>>? sub;
  final deadline = DateTime.now().add(timeout);
  void halt(Exception why) {
    if (!stop.isCompleted) stop.complete(why);
    if (!abort.isCompleted) abort.complete();
    unawaited(sub?.cancel());
  }

  void check() {
    if (cancelled?.call() ?? false) return halt(RequestCancelledException(url));
    if (!DateTime.now().isBefore(deadline)) halt(TimeoutException('GET $url', timeout));
  }

  final ticker = Timer.periodic(_pollEvery, (_) => check());
  final end = Timer(timeout, check);
  check();
  try {
    if (stop.isCompleted) throw await stop.future;
    // 頭が来るまでの待ちにも、同じ期限を直接掛ける(上の ticker / end は本文の読み込みも含めて止める)。
    final send = c.send(http.AbortableRequest('GET', url, abortTrigger: abort.future)).timeout(timeout);
    final res = await Future.any<Object>([send, stop.future]);
    if (res is! http.StreamedResponse) {
      // 頭が来る前に止めた: あとから来た応答も読まずに捨てる。
      unawaited(send.then((r) => r.stream.listen(null).cancel(), onError: (_) {}));
      throw res as Exception;
    }
    if (res.statusCode != 200) {
      unawaited(res.stream.listen(null).cancel());
      return (res.statusCode, res.headers);
    }
    final declared = res.contentLength;
    if (declared != null && declared > maxBytes) {
      unawaited(res.stream.listen(null).cancel());
      throw ResponseTooLargeException(maxBytes, declared);
    }
    var got = 0;
    final done = Completer<void>();
    unawaited(stop.future.then((why) {
      if (!done.isCompleted) done.completeError(why);
    }));
    sub = res.stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        got += chunk.length;
        if (got > maxBytes) {
          onTooLarge?.call();
          unawaited(sub?.cancel());
          if (!abort.isCompleted) abort.complete();
          done.completeError(ResponseTooLargeException(maxBytes, got));
          return;
        }
        try {
          onChunk(chunk);
        } catch (e, st) {
          unawaited(sub?.cancel());
          done.completeError(e, st);
        }
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
    return (res.statusCode, res.headers);
  } on http.RequestAbortedException {
    // 止めたのはこちら: 理由(期限 / 取り消し)で投げる。
    if (stop.isCompleted) throw await stop.future;
    rethrow;
  } finally {
    ticker.cancel();
    end.cancel();
    await sub?.cancel();
    if (own) c.close();
  }
}

/// [getLimited] の答え。
class LimitedResponse {
  const LimitedResponse(this.statusCode, this.headers, this.bodyBytes);
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;
}

/// 応答本文が上限を超えた(読むのをやめた)。[seen] = 超えたと分かった時点の大きさ(Content-Length か、読んだ累計)。
class ResponseTooLargeException implements Exception {
  const ResponseTooLargeException(this.maxBytes, this.seen);
  final int maxBytes;
  final int seen;

  @override
  String toString() => appL10n.backendResponseTooLarge(maxBytes);
}
