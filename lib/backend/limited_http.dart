import 'dart:async';
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
/// [timeout] は応答の頭と本文を読み終えるまでの全体。200 以外も本文は読まずに [LimitedResponse.statusCode] だけ返す。
/// [client] を渡さなければ 1 回限りの [http.Client] を作って閉じる(テストは `http.runWithClient` で差し替えられる)。
Future<LimitedResponse> getLimited(Uri url, {required int maxBytes, required Duration timeout, http.Client? client}) async {
  final own = client == null;
  final c = client ?? http.Client();
  StreamSubscription<List<int>>? sub;
  try {
    final deadline = DateTime.now().add(timeout);
    final res = await c.send(http.Request('GET', url)).timeout(timeout);
    if (res.statusCode != 200) {
      unawaited(res.stream.listen(null).cancel());
      return LimitedResponse(res.statusCode, res.headers, Uint8List(0));
    }
    final declared = res.contentLength;
    if (declared != null && declared > maxBytes) {
      unawaited(res.stream.listen(null).cancel());
      throw ResponseTooLargeException(maxBytes, declared);
    }
    var builder = BytesBuilder(copy: false);
    final done = Completer<Uint8List>();
    sub = res.stream.listen(
      (chunk) {
        if (builder.length + chunk.length > maxBytes) {
          final seen = builder.length + chunk.length;
          builder = BytesBuilder(copy: false); // 読んだぶんもすぐ手放す
          unawaited(sub?.cancel());
          if (!done.isCompleted) done.completeError(ResponseTooLargeException(maxBytes, seen));
          return;
        }
        builder.add(chunk);
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete(builder.takeBytes());
      },
      cancelOnError: true,
    );
    final left = deadline.difference(DateTime.now());
    final body = await done.future.timeout(left.isNegative ? Duration.zero : left);
    return LimitedResponse(res.statusCode, res.headers, body);
  } finally {
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
