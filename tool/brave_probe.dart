// Brave Search の疎通確認 (D-228): `BRAVE_KEY=… dart run tool/brave_probe.dart [--web] [質問]`。
// 鍵は環境変数からだけ読む(リポジトリには置かない)。Flutter に依存しない(dart run で動く)ので
// アプリ側の RaiWebSearch と同じリクエストをここで組む。既定は Answers API(chat/completions、鍵のプランが
// 「Answers」のとき)。`--web` で従来の web/search。
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final key = Platform.environment['BRAVE_KEY'] ?? '';
  if (key.isEmpty) {
    stderr.writeln('BRAVE_KEY が空です');
    exit(2);
  }
  final web = args.contains('--web');
  final words = [for (final a in args) if (a != '--web') a];
  final q = words.isEmpty ? 'SAKAMOTO DAYS のアニメは何期まで放送されていますか？' : words.join(' ');
  if (web) {
    final uri = Uri.parse('https://api.search.brave.com/res/v1/web/search').replace(queryParameters: {'q': q, 'count': '3', 'search_lang': 'ja', 'country': 'JP'});
    final res = await http.get(uri, headers: {'accept': 'application/json', 'x-subscription-token': key});
    stdout.writeln('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final results = ((body['web'] as Map?)?['results'] as List?) ?? const [];
    for (final r in results) {
      stdout.writeln('- ${r['title']} [${r['url']}]\n  ${'${r['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]+>'), '')}');
    }
    stdout.writeln('${results.length} 件(0 件なら鍵のプランが web 検索を含まない = Answers の口を使う)');
    return;
  }
  final res = await http.post(
    Uri.parse('https://api.search.brave.com/res/v1/chat/completions'),
    headers: {'accept': 'application/json', 'content-type': 'application/json', 'x-subscription-token': key},
    body: jsonEncode({
      'model': 'brave-pro',
      'stream': false,
      // messages は 1 件だけ(system は 422)。
      'messages': [
        {'role': 'user', 'content': '$q\n\n(検索結果に基づいて日本語で簡潔に、200 文字以内で答えてください。根拠の URL があれば末尾に添えてください)'},
      ],
    }),
  );
  stdout.writeln('HTTP ${res.statusCode}');
  final text = utf8.decode(res.bodyBytes);
  if (res.statusCode != 200) {
    stdout.writeln(text.length > 400 ? text.substring(0, 400) : text);
    exit(1);
  }
  final body = jsonDecode(text) as Map;
  final choices = body['choices'] as List? ?? const [];
  stdout.writeln(choices.isEmpty ? '(答えなし)' : ((choices.first as Map)['message'] as Map)['content']);
  stdout.writeln('usage: ${body['usage']}');
}
