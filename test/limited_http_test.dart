import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/limited_http.dart';
import 'package:rasq_client/features/dev/review_import.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/relational/post_embeddings.dart';

/// HTTP 応答は上限まで少しずつ読み、超えたらその場でやめる(全部貯めてから大きさを見ない、セキュリティ確認 2026-10-09 の [18])。
void main() {
  const chunk = 64 * 1024;

  /// 終わらない応答: 送った塊の数を数え、読むのをやめたか(cancel)も見る。[contentLength] は嘘でも無くてもよい。
  ({MockClient client, int Function() sent, bool Function() cancelled}) endless({int? contentLength, int status = 200}) {
    var sent = 0;
    var cancelled = false;
    Stream<List<int>> body() async* {
      try {
        while (true) {
          sent++;
          yield Uint8List(chunk);
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        cancelled = true;
      }
    }

    final client = MockClient.streaming((req, _) async => http.StreamedResponse(body(), status, contentLength: contentLength));
    return (client: client, sent: () => sent, cancelled: () => cancelled);
  }

  group('getLimited', () {
    final url = Uri.parse('https://big.test/x');

    for (final length in [null, 10]) {
      test('Content-Length が ${length ?? '無い'} の巨大な応答: 上限を超えたところで読むのをやめる', () async {
        final e = endless(contentLength: length);
        await expectLater(getLimited(url, maxBytes: 4 * chunk, timeout: const Duration(seconds: 10), client: e.client), throwsA(isA<ResponseTooLargeException>()));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(e.cancelled(), isTrue);
        expect(e.sent(), lessThanOrEqualTo(6), reason: '上限(4 塊)を超えた先は受け取らない');
      });
    }

    test('Content-Length が上限を超えていれば、本文を読む前に断る', () async {
      final e = endless(contentLength: 1 << 40);
      await expectLater(getLimited(url, maxBytes: 4 * chunk, timeout: const Duration(seconds: 10), client: e.client), throwsA(isA<ResponseTooLargeException>()));
      expect(e.sent(), lessThanOrEqualTo(1));
    });

    test('上限ちょうどは届く。200 以外は本文を読まずに状態だけ', () async {
      final ok = MockClient((req) async => http.Response.bytes(Uint8List(4 * chunk), 200, headers: {'content-type': 'image/png'}));
      final r = await getLimited(url, maxBytes: 4 * chunk, timeout: const Duration(seconds: 10), client: ok);
      expect((r.statusCode, r.bodyBytes.length, r.headers['content-type']), (200, 4 * chunk, 'image/png'));
      final e = endless(status: 404);
      final gone = await getLimited(url, maxBytes: 4 * chunk, timeout: const Duration(seconds: 10), client: e.client);
      expect((gone.statusCode, gone.bodyBytes.length), (404, 0));
    });

    test('遅い応答は全体の期限で切る', () async {
      final slow = MockClient.streaming((req, _) async => http.StreamedResponse(Stream<List<int>>.periodic(const Duration(milliseconds: 50), (_) => [1]), 200));
      await expectLater(getLimited(url, maxBytes: 1 << 20, timeout: const Duration(milliseconds: 200), client: slow), throwsA(anything));
    });
  });

  test('審査ファイルの読込: 上限を超える配布物は読み切らずに断り、ファイルも作らない / ふつうの大きさは入る', () async {
    final dir = Directory.systemTemp.createTempSync('review-import-limit');
    addTearDown(() => dir.deleteSync(recursive: true));
    final e = endless();
    await expectLater(downloadReviewImport('https://judge.test/review-dl/big', client: e.client, dir: () async => dir), throwsA(isA<ReviewImportException>().having((x) => x.toString(), 'message', contains('$reviewImportMaxBytes bytes を超えています'))));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(e.cancelled(), isTrue);
    expect(e.sent() * chunk, lessThanOrEqualTo(reviewImportMaxBytes + 2 * chunk));
    expect(dir.listSync(), isEmpty);
    final small = MockClient((req) async => http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200, headers: {'content-disposition': 'attachment; filename="a-0.1.0.rasqpkg"'}));
    final path = await downloadReviewImport('https://judge.test/review-dl/ok', client: small, dir: () async => dir);
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });

  test('投稿画像の埋め込み / ビューアの重ね表示の画像: 上限を超える応答は途中でやめて null、ふつうの画像は届く', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final post = c.read(postImageFetcherProvider);
    final viewer = c.read(viewerImageFetcherProvider);
    for (final (fetch, cap) in [(post, postImageMaxBytes), (viewer, viewerImageMaxBytes)]) {
      for (final length in [null, 100]) {
        final e = endless(contentLength: length);
        final got = await http.runWithClient(() => fetch(Uri.parse('https://img.test/big.png')), () => e.client);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(got, isNull);
        expect(e.cancelled(), isTrue);
        expect(e.sent() * chunk, lessThanOrEqualTo(cap + 2 * chunk));
      }
      final ok = MockClient((req) async => http.Response.bytes(Uint8List(1000), 200));
      expect((await http.runWithClient(() => fetch(Uri.parse('https://img.test/ok.png')), () => ok))?.length, 1000);
    }
  });
}
