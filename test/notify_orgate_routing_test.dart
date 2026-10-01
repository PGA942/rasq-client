import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/notify_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/notify/central_inbox.dart';
import 'package:rasq_client/session/session_storage.dart';

/// 第 3 段階 (D-400 / Central S-064 / ORGATE O-003): 通知の口(受信箱・長いポーリング・通知トークン・プッシュ登録)は ORGATE。
/// Central と ORGATE を別の接続先にして、通知まわりが Central へ行かないことを確かめる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  /// 名前つきの偽のサーバー。呼ばれた口を [hits] に残す。
  MockClient server(String name, List<String> hits, Future<http.Response> Function(http.Request req, String path) answer) => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        hits.add('$name ${req.method} $path');
        return answer(req, path);
      });

  test('通知トークン / プッシュ登録の口は ORGATE(Central と別の接続先でも)', () {
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://orgate.test')),
    ]);
    addTearDown(c.dispose);
    expect(c.read(notifyApiProvider)!.client.baseUrl.host, 'orgate.test');
    expect(c.read(centralClientProvider)!.baseUrl.host, 'central.test');
  });

  test('アカウントの通知欄 (S-026) は ORGATE の受信箱を読む。投稿の一覧は Central のまま', () async {
    final hits = <String>[];
    final api = RasqAccountPageApi(
      OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: server('central', hits, (req, path) async => json({'posts': <Object>[], 'limit': 3, 'source': 'rasq', 'snsPosts': <Object>[], 'pins': <Object>[]}))),
      edge: OrgateClient(
        baseUrl: Uri.parse('https://orgate.test'),
        httpClient: server('orgate', hits, (req, path) async => json([
              {'id': 'n1', 'kind': 'post.mention', 'title': 'メンション', 'body': 'やあ', 'payload': {'postId': 'p1', 'actor': {'id': 'a2', 'handle': 'bob', 'displayName': 'ボブ'}}, 'createdAt': '2026-10-01T00:00:00Z'},
              {'id': 'n2', 'kind': 'sns_share.request', 'title': 'x', 'body': 'y', 'payload': <String, Object?>{}, 'createdAt': '2026-10-01T00:00:01Z'},
            ])),
      ),
    );
    final notices = await api.notifications();
    await api.posts('taro');
    expect(notices.map((n) => n.postId), ['p1']);
    expect(hits, ['orgate GET /me/notifications', 'central GET /accounts/taro/posts']);
  });

  test('受信箱の見回り (D-309) と長いポーリング (D-322) は ORGATE。Central の受信箱の口は呼ばない', () async {
    final hits = <String>[];
    var waits = 0;
    final notices = <Map<String, Object?>>[];
    final orgate = server('orgate', hits, (req, path) async {
      if (path == '/me') return json({'id': 'acc-a', 'handle': 'alice', 'kind': 'user', 'hasPassword': false, 'emailVerified': false});
      if (path == '/me/notifications') return json(notices.reversed.toList());
      if (path == '/me/notifications/wait') {
        waits++;
        // 1 回目の待ちの間に、Central で起きたこと(メンション)が ORGATE に届いた。
        if (waits == 1) {
          notices.add({'id': 'n1', 'kind': 'post.mention', 'title': 'メンション', 'body': 'やあ', 'payload': {'postId': 'p1'}, 'createdAt': '2026-10-01T00:00:05Z'});
          return json(notices.reversed.toList());
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return json(<Object>[]);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final central = server('central', hits, (req, path) async {
      if (path == '/me') return json({'id': 'acc-a', 'handle': 'alice', 'displayName': 'アリス', 'createdAt': '2026-09-01T00:00:00Z'});
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final got = <String>[];
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-a', 'tokens': {'acc-a': 'tok-a'}, 'currentAccountId': 'acc-a'}),
        // はじめての読みは印を付けるだけなので、前に見た印を置いておく。
        CentralInbox.storageKey: jsonEncode({'acc-a': {'at': '2026-10-01T00:00:00.000Z', 'ids': <String>[]}}),
      })),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://orgate.test')),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: orgate, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralInboxLiveProvider.overrideWithValue((enabled: true, retry: const Duration(milliseconds: 20))),
      centralNoticeHandlersProvider.overrideWithValue({
        'post.mention': (ref, list) async => got.addAll([for (final n in list) '${n.kind} ${n.payload['postId']}']),
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(centralInboxProvider, (_, _) {});
    for (var i = 0; i < 300 && got.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(got, ['post.mention p1']);
    final inbox = hits.where((h) => h.contains('/me/notifications')).toList();
    expect(inbox, isNotEmpty);
    expect(inbox.every((h) => h.startsWith('orgate ')), isTrue, reason: '$inbox');
    expect(inbox.any((h) => h.startsWith('orgate GET /me/notifications/wait')), isTrue);
    expect(hits.where((h) => h.startsWith('central ') && h.contains('notif')), isEmpty);
  });
}
