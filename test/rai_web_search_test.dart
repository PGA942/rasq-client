import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/features/rai/rai_web_search.dart';

/// web 検索 (D-228): Brave Search API。第一期では無効(ビルド時の RASQ_WEB_SEARCH で有効化)。
void main() {
  test('既定(第一期)は無効: available=false、呼ぶと「無効」', () async {
    const ws = RaiWebSearch(token: 'k');
    expect(raiWebSearchEnabled, isFalse);
    expect(ws.available, isFalse);
    await expectLater(ws.search('x'), throwsA(isA<RaiWebSearchException>().having((e) => e.message, 'message', contains('web 検索はまだ使えません'))));
    await expectLater(const RaiWebSearch(enabled: true).search('x'), throwsA(isA<RaiWebSearchException>().having((e) => e.message, 'message', contains('鍵が設定されていません'))));
  });

  test('Answers(既定の口): /res/v1/chat/completions に鍵ヘッダーで POST し、答えの本文と本文中の URL を 1 件にする', () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response.bytes(utf8.encode(jsonEncode({'model': 'brave-pro', 'choices': [{'index': 0, 'message': {'role': 'assistant', 'content': '**SAKAMOTO DAYS** は 2025 年に第 1 期(22 話)が放送されました。\n根拠: https://example.test/sd'}, 'finish_reason': 'stop'}]})), 200, headers: {'content-type': 'application/json'});
    });
    final ws = RaiWebSearch(token: 'secret', enabled: true, client: client);
    expect(ws.mode, RaiWebMode.answers);
    final hits = await ws.query('SAKAMOTO DAYS のアニメは何期まで？');
    expect(seen!.method, 'POST');
    expect(seen!.url.toString(), 'https://api.search.brave.com/res/v1/chat/completions');
    expect(seen!.headers['x-subscription-token'], 'secret');
    final body = jsonDecode(seen!.body) as Map;
    expect(body['model'], 'brave-pro');
    expect(body['stream'], false);
    expect((body['messages'] as List).length, 1); // Answers API は 1 件だけ(system 不可)
    expect(((body['messages'] as List).single as Map)['role'], 'user');
    expect(((body['messages'] as List).single as Map)['content'], startsWith('SAKAMOTO DAYS のアニメは何期まで？'));
    expect(hits.single.title, 'web の答え');
    expect(hits.single.description, contains('第 1 期(22 話)'));
    expect(hits.single.url.toString(), 'https://example.test/sd');
    expect(await ws.query(' '), isEmpty);
  });

  test('web(従来の口): /res/v1/web/search に q / count / 言語と鍵ヘッダーで GET し、web.results を題名 / URL / 説明にする(タグは落とす)', () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'web': {
            'results': [
              {'title': 'サカモトデイズ - Wikipedia', 'url': 'https://ja.wikipedia.org/wiki/SAKAMOTO_DAYS', 'description': '<strong>SAKAMOTO DAYS</strong>は鈴木祐斗による漫画 &amp; アニメ'},
              {'title': '公式', 'url': 'https://example.test/sakamoto'},
            ]
          }
        })),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ws = RaiWebSearch(token: 'secret', enabled: true, client: client, mode: RaiWebMode.web);
    expect(ws.available, isTrue);
    final hits = await ws.query('サカモトデイズ', count: 2);
    expect(seen!.url.host, 'api.search.brave.com');
    expect(seen!.url.path, '/res/v1/web/search');
    expect(seen!.url.queryParameters, {'q': 'サカモトデイズ', 'count': '2', 'search_lang': 'ja', 'country': 'JP'});
    expect(seen!.headers['x-subscription-token'], 'secret');
    expect(hits.length, 2);
    expect(hits.first.title, 'サカモトデイズ - Wikipedia');
    expect(hits.first.description, 'SAKAMOTO DAYSは鈴木祐斗による漫画 & アニメ');
    expect(hits.last.url.toString(), 'https://example.test/sakamoto');
    expect(hits.last.description, '');
  });

  test('HTTP エラーは RaiWebSearchException、空の検索語は空', () async {
    final ws = RaiWebSearch(token: 'k', enabled: true, client: MockClient((_) async => http.Response('{"message":"rate limited"}', 429)));
    await expectLater(ws.search('x'), throwsA(isA<RaiWebSearchException>().having((e) => e.message, 'message', contains('HTTP 429'))));
    await expectLater(ws.answer('x'), throwsA(isA<RaiWebSearchException>().having((e) => e.message, 'message', contains('HTTP 429'))));
    expect(await ws.search('  '), isEmpty);
  });
}
