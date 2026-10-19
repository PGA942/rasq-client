import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../settings/settings_dsl.dart';
import 'rai_llm.dart' show raiSettingsArea;
import '../../l10n/l10n.dart';

/// web 検索 (D-228): Brave Search API。RAi の関数 `web.search` から使う。
///
/// 2 つの口がある(鍵のプランで決まる):
/// - [RaiWebMode.answers] = **Answers API**(`/res/v1/chat/completions`、OpenAI 互換、モデル `brave-pro`)。検索して
///   根拠つきの短い答えを返す。ユーザーが取得した鍵のプラン(「Answers」)はこちらで、`web/search` は結果が空になる。
/// - [RaiWebMode.web] = 従来の web 検索(`/res/v1/web/search` → 題名 / URL / 説明の一覧)。
///
/// **第一期では無効**(ユーザー指定: 法人契約に切り替える可能性があるため)。有効化はビルド時の
/// `--dart-define=RASQ_WEB_SEARCH=true`、鍵は `--dart-define=RASQ_BRAVE_KEY=…` か設定エリア `rai` の `braveKey`、
/// 口は `--dart-define=RASQ_WEB_MODE=web|answers`(既定 answers)か設定 `braveMode`。無効 / 鍵なしのときは関数一覧にも出さず、
/// 呼ばれても「無効」と返す。
const raiWebSearchEnabled = bool.fromEnvironment('RASQ_WEB_SEARCH', defaultValue: false);
const raiBraveKeyDefine = String.fromEnvironment('RASQ_BRAVE_KEY');
const raiWebModeDefine = String.fromEnvironment('RASQ_WEB_MODE');

enum RaiWebMode { answers, web }

@immutable
class RaiWebHit {
  const RaiWebHit({required this.title, this.url, this.description = ''});
  final String title;
  final Uri? url;
  final String description;
}

class RaiWebSearch {
  const RaiWebSearch({this.token = '', this.enabled = raiWebSearchEnabled, this.client, this.mode = RaiWebMode.answers, this.baseUrl = 'https://api.search.brave.com/res/v1'});
  final String token;
  final bool enabled;
  final http.Client? client;
  final RaiWebMode mode;
  final String baseUrl;

  /// 使えるか = 有効化されていて鍵がある。
  bool get available => enabled && token.trim().isNotEmpty;

  void _check() {
    if (!enabled) throw RaiWebSearchException(appL10n.raiModelsWebDisabled);
    if (token.trim().isEmpty) throw RaiWebSearchException(appL10n.raiModelsWebNoKey);
  }

  /// 口に合わせて検索する: answers なら答え 1 件([RaiWebHit.description] に本文、URL は本文から拾えた最初のもの)、
  /// web なら上位 [count] 件。
  Future<List<RaiWebHit>> query(String q, {int count = 5}) async {
    if (mode == RaiWebMode.web) return search(q, count: count);
    final a = await answer(q);
    if (a.isEmpty) return const [];
    final url = RegExp(r'https?://[^\s)\]>]+').firstMatch(a)?.group(0);
    return [RaiWebHit(title: appL10n.raiModelsWebAnswerTitle, url: url == null ? null : Uri.tryParse(url), description: a)];
  }

  /// Answers API (D-228): `POST /chat/completions`(OpenAI 互換)。検索に基づく短い答え(日本語)を返す。
  Future<String> answer(String question, {String model = 'brave-pro'}) async {
    _check();
    final q = question.trim();
    if (q.isEmpty) return '';
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions'),
            headers: {'accept': 'application/json', 'content-type': 'application/json', 'x-subscription-token': token.trim()},
            body: jsonEncode({
              'model': model,
              'stream': false,
              // Answers API は messages を 1 件しか受けない(system 不可)ので、指示は質問に添える。
              'messages': [
                {'role': 'user', 'content': '$q\n\n(検索結果に基づいて日本語で簡潔に、200 文字以内で答えてください。根拠の URL があれば末尾に添えてください)'}, // l10n-ignore
              ],
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw RaiWebSearchException('HTTP ${res.statusCode}: ${_brief(utf8.decode(res.bodyBytes, allowMalformed: true))}');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final choices = body['choices'] as List? ?? const [];
      final content = choices.isEmpty ? '' : '${((choices.first as Map)['message'] as Map?)?['content'] ?? ''}';
      return content.trim();
    } on RaiWebSearchException {
      rethrow;
    } catch (e) {
      throw RaiWebSearchException(appL10n.raiModelsWebFailed('$e'));
    } finally {
      if (client == null) c.close();
    }
  }

  /// web 検索 (D-228): `GET /web/search` で上位 [count] 件(タイトル / URL / 説明)。失敗は [RaiWebSearchException]。
  Future<List<RaiWebHit>> search(String query, {int count = 5, String lang = 'ja', String country = 'JP'}) async {
    _check();
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/web/search').replace(queryParameters: {'q': q, 'count': '${count.clamp(1, 20)}', 'search_lang': lang, 'country': country});
    final c = client ?? http.Client();
    try {
      final res = await c.get(uri, headers: {'accept': 'application/json', 'accept-encoding': 'gzip', 'x-subscription-token': token.trim()}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw RaiWebSearchException('HTTP ${res.statusCode}: ${_brief(res.body)}');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final results = ((body['web'] as Map?)?['results'] as List?) ?? const [];
      return [
        for (final r in results)
          if (r is Map && r['url'] != null)
            RaiWebHit(title: _plain('${r['title'] ?? ''}'), url: Uri.parse('${r['url']}'), description: _plain('${r['description'] ?? ''}')),
      ];
    } on RaiWebSearchException {
      rethrow;
    } catch (e) {
      throw RaiWebSearchException(appL10n.raiModelsWebFailed('$e'));
    } finally {
      if (client == null) c.close();
    }
  }

  static String _brief(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;

  /// 説明に入る `<strong>` などを落とす。
  static String _plain(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#x27;', "'").trim();
}

class RaiWebSearchException implements Exception {
  const RaiWebSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 鍵 / 口は dart-define → 設定エリア `rai` の `braveKey` / `braveMode` の順。
final raiWebSearchProvider = Provider<RaiWebSearch>((ref) {
  final v = ref.watch(settingsAreaProvider(raiSettingsArea)).value ?? const <String, Object?>{};
  final key = raiBraveKeyDefine.isNotEmpty ? raiBraveKeyDefine : '${v['braveKey'] ?? ''}';
  final mode = (raiWebModeDefine.isNotEmpty ? raiWebModeDefine : '${v['braveMode'] ?? ''}') == 'web' ? RaiWebMode.web : RaiWebMode.answers;
  // チャイルドセーフ (D-307): 保護者が web 検索(`rai.web` / 検索の `web`)を許していなければ使えない。
  if (!ref.watch(childGateProvider.select((g) => g.raiWeb))) return RaiWebSearch(token: key, mode: mode, enabled: false);
  return RaiWebSearch(token: key, mode: mode);
});
