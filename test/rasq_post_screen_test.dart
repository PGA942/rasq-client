import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/post/thread_section_bar.dart';
import 'package:rasq_client/features/profile/rasq_post_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ の投稿の詳細 (D-292): SNS の投稿の詳細と同じ作り(返信欄の帯 / 並び順 / 常駐の返信コンポーザー)。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  testWidgets('返信欄の帯で並び替え、常駐の返信コンポーザーから RASQ として返信する', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const hanako = {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'};
    Map<String, Object?> reply(String id, String body, int likes) => {
          'id': id, 'author': hanako, 'body': body, 'isReply': true, 'replyTo': 'p1', 'createdAt': '2026-09-20T00:00:0${id.substring(1)}Z',
          'queues': [if (likes > 0) {'packId': null, 'stickerId': 'like', 'like': true, 'count': likes, 'mine': false}],
        };
    final sent = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'GET' && path == '/posts/p1') {
        return json({'post': {'id': 'p1', 'author': hanako, 'body': 'もとの投稿', 'createdAt': '2026-09-20T00:00:00Z'}, 'replies': [reply('r1', 'ひとつめ', 0), reply('r2', 'ふたつめ', 5)]});
      }
      if (req.method == 'POST' && path == '/me/posts') {
        sent.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        return json({'id': 'r9', 'author': {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'}, 'body': 'x', 'isReply': true}, 201);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.rasqPost('p1'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqPostScreen), findsOneWidget);
    expect(find.byType(ThreadSectionBar), findsOneWidget);
    expect(find.text('返信 2'), findsOneWidget);

    // 既定は届いた順。帯の ∨ → 「リアクション数」で、キューの多い返信が上に来る。
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('ひとつめ') < y('ふたつめ'), isTrue);
    await tester.tap(find.byKey(const ValueKey('thread.section.bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リアクション数').last);
    await tester.pumpAndSettle();
    expect(y('ふたつめ') < y('ひとつめ'), isTrue);

    // 常駐の返信コンポーザー: 投稿先は RASQ に固定。相手へのメンションが入り、返信として送られる。
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '@hanako なるほど');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '返信'));
    await tester.pumpAndSettle();
    expect(sent.single, {'body': '@hanako なるほど', 'replyTo': 'p1'});
  });
}
