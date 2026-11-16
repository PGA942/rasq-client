import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/src/misskey_api.dart';
import 'package:test/test.dart';

/// セキュリティ確認 2026-11-11 の #13: Misskey の応答は上限 / 期限つきで読む(全部をメモリに貯めない)。
void main() {
  const chunk = 64 * 1024;

  /// 終わらない応答。送った塊の数と、読むのをやめたか(cancel)を見る。
  ({MockClient client, int Function() sent, bool Function() cancelled}) endless({int? contentLength}) {
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

    return (client: MockClient.streaming((req, _) async => http.StreamedResponse(body(), 200, contentLength: contentLength)), sent: () => sent, cancelled: () => cancelled);
  }

  Matcher tooLarge() => isA<SnsApiException>().having((e) => e.code.code, 'code', contains('04'));

  for (final length in [null, 10]) {
    test('meta(未ログイン)の Content-Length が ${length ?? '無い'} 巨大な応答: 上限で読むのをやめる', () async {
      final e = endless(contentLength: length);
      final api = MisskeyApi('big.example', client: e.client, maxResponseBytes: 4 * chunk);
      await expectLater(api.call('meta'), throwsA(tooLarge()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(e.cancelled(), isTrue);
      expect(e.sent(), lessThanOrEqualTo(6));
    });
  }

  test('Content-Length が上限を超えていれば読む前に断る', () async {
    final e = endless(contentLength: 1 << 40);
    final api = MisskeyApi('big.example', client: e.client, maxResponseBytes: 4 * chunk);
    await expectLater(api.call('meta'), throwsA(tooLarge()));
    expect(e.sent(), lessThanOrEqualTo(1));
  });

  test('頭が来ない / 本文が終わらない応答は期限で切る', () async {
    final hang = MockClient.streaming((req, _) => Completer<http.StreamedResponse>().future);
    await expectLater(MisskeyApi('slow.example', client: hang, timeout: const Duration(milliseconds: 100)).call('meta'), throwsA(isA<SnsApiException>()));
    final drip = MockClient.streaming((req, _) async => http.StreamedResponse(Stream<List<int>>.periodic(const Duration(milliseconds: 20), (_) => [32]), 200));
    await expectLater(MisskeyApi('slow.example', client: drip, bodyTimeout: const Duration(milliseconds: 200)).call('meta'), throwsA(isA<SnsApiException>()));
  });

  test('アップロードの応答も上限で切る', () async {
    final e = endless();
    final api = MisskeyApi('big.example', token: 't', client: e.client);
    await expectLater(api.upload('drive/files/create', bytes: Uint8List(4), filename: 'a.png', mimeType: 'image/png'), throwsA(tooLarge()));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(e.cancelled(), isTrue);
    expect(e.sent() * chunk, lessThanOrEqualTo(MisskeyApi.maxUploadResponseBytes + 2 * chunk));
  });

  test('ふつうの大きさはそのまま', () async {
    final ok = MockClient((req) async => http.Response('{"name":"ok"}', 200, headers: {'content-type': 'application/json'}));
    expect(await MisskeyApi('ok.example', client: ok).callMap('meta'), {'name': 'ok'});
  });
}
