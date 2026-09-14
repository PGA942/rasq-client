import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';

/// フォールアップ先 = OpenAI 互換の推論サーバー (D-216): 質問と近かったリファレンスを添えて渡す。
void main() {
  test('未設定なら従来の失敗メッセージ', () async {
    await expectLater(const RaiFallUp().chat('こんにちは'), throwsA(isA<RaiLlmException>().having((e) => e.message, 'message', contains('未接続'))));
  });

  test('chat/completions へ system(+ リファレンス)と user を POST し、content を返す(<think> は落とす)', () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response.bytes(utf8.encode(jsonEncode({'choices': [{'message': {'role': 'assistant', 'content': '<think>考え中</think>投稿は右下の「投稿」からです。'}}]})), 200, headers: {'content-type': 'application/json'});
    });
    final f = RaiFallUp(baseUrl: 'http://127.0.0.1:8000/v1/', model: 'qwen3', token: 'abc', client: client);
    final reply = await f.chat('投稿したい', system: 'あなたは RAi です。', context: ['- 投稿する: ホームの「投稿」 → 本文を入力 → 送信']);
    expect(reply, '投稿は右下の「投稿」からです。');
    expect(seen!.url.toString(), 'http://127.0.0.1:8000/v1/chat/completions');
    expect(seen!.headers['authorization'], 'Bearer abc');
    final body = jsonDecode(seen!.body) as Map;
    expect(body['model'], 'qwen3');
    expect(body['stream'], false);
    expect((body['chat_template_kwargs'] as Map)['enable_thinking'], false);
    final messages = (body['messages'] as List).cast<Map>();
    expect(messages.length, 2);
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('あなたは RAi です。'));
    expect(messages.first['content'], contains('参考(操作リファレンス'));
    expect(messages.first['content'], contains('投稿する: ホームの「投稿」'));
    expect(messages.last, {'role': 'user', 'content': '投稿したい'});
  });

  test('HTTP エラー / 空の返事 / 届かない は RaiLlmException', () async {
    final bad = RaiFallUp(baseUrl: 'http://x/v1', client: MockClient((_) async => http.Response('nope', 500)));
    await expectLater(bad.chat('a'), throwsA(isA<RaiLlmException>().having((e) => e.message, 'message', contains('HTTP 500'))));
    final empty = RaiFallUp(baseUrl: 'http://x/v1', client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode({'choices': [{'message': {'content': '<think>…</think>'}}]})), 200)));
    await expectLater(empty.chat('a'), throwsA(isA<RaiLlmException>().having((e) => e.message, 'message', contains('返事がありません'))));
    final down = RaiFallUp(baseUrl: 'http://x/v1', client: MockClient((_) async => throw Exception('connection refused')));
    await expectLater(down.chat('a'), throwsA(isA<RaiLlmException>().having((e) => e.message, 'message', contains('届きません'))));
  });
}
