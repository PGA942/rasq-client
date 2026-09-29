import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/compose/compose_target.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/features/compose/poll_editor.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// コンポーザーの RASQ 指定 (D-271): バンドルタイルの RASQ アカウントの行を長押し → RASQ アカウントとして投稿。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  testWidgets('長押しで RASQ 指定 → 送信は POST /me/posts(SNS には投稿しない)。SNS の行を選ぶと解除', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'POST' && path == '/me/posts') {
        sent.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        return json({'id': 'p1', 'body': 'x'}, 201);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final plugin = FakeSnsPlugin(posts: MockData.timeline);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.sns')), findsOneWidget);
    // ピル → バンドルタイル → RASQ アカウントの行を長押し。
    await tester.tap(find.byKey(const ValueKey('composer.pill.sns')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('composer.rasqRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'RASQ からこんにちは');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(sent.single, {'body': 'RASQ からこんにちは'});
    expect(find.text('RASQ に投稿しました'), findsOneWidget);
  });

  testWidgets('RASQ 指定でも、注釈と投票は SNS と同じに使える(投票は 6 個まで)。送るのは cw / poll つきの POST /me/posts', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'POST' && path == '/me/posts') {
        sent.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        return json({'id': 'p1', 'body': 'x'}, 201);
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
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer.pill.sns')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('composer.rasqRow')));
    await tester.pumpAndSettle();
    // 注釈 + 投票。
    await tester.tap(find.byTooltip('隠す(注釈)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '注釈..'), 'ネタバレ');
    await tester.tap(find.byTooltip('投票'));
    await tester.pumpAndSettle();
    final choices = find.descendant(of: find.byType(PollEditor), matching: find.byType(TextField));
    await tester.enterText(choices.at(0), 'はい');
    await tester.enterText(choices.at(1), 'いいえ');
    expect(tester.widget<PollEditor>(find.byType(PollEditor)).maxChoices, 6);
    await tester.enterText(find.byType(TextField).first.evaluate().isEmpty ? find.byType(TextField).first : find.widgetWithText(TextField, 'いいことがありますように！'), '本文');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(sent.single, {'body': '本文', 'cw': 'ネタバレ', 'poll': {'choices': ['はい', 'いいえ'], 'multiple': false}});
  });

  testWidgets('RASQ の投稿の引用 (D-276): 投稿先は RASQ に固定、送るのは quoteOf つきの POST /me/posts', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'POST' && path == '/me/posts') {
        sent.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        return json({'id': 'p1', 'body': 'x'}, 201);
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
    const source = RasqAccountPost(id: 'src-1', body: '引用される投稿', author: RasqPostAuthor(id: 'acc-2', handle: 'hanako', displayName: 'ハナコ'));
    showComposerWith(ComposeQuote(source.toPost()), manager: c.read(overlayManagerProvider), router: c.read(routerProvider));
    await tester.pumpAndSettle();
    // RASQ 指定を渡さなくても、RASQ の投稿の引用は RASQ に固定。元の投稿のプレビューが出る。
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget);
    expect(find.text('引用される投稿'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'これはいい');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(sent.single, {'body': 'これはいい', 'quoteOf': 'src-1'});
  });

  testWidgets('@ 補完 (D-285): RASQ 指定では Central のアカウント検索、SNS では searchUsers。候補を押すと、その場のメンションに置き換わる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'GET' && path == '/accounts/search') {
        asked.add(req.url.queryParameters['q'] ?? '');
        return json([{'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'}]);
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
    showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), rasqTarget: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'やあ @ha');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(asked, ['ha']);
    expect(find.byKey(const ValueKey('composer.mentions')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('composer.mention.@hanako')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'やあ @hanako ');
    expect(find.byKey(const ValueKey('composer.mentions')), findsNothing);
  });
}
