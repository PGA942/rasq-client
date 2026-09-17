import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/learning_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/settings/learning_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 学習へのデータ提供 (D-243): 年齢の申告 → 要点を読んでチェック → 同意 → 撤回用のコード → 撤回。
/// サーバーは MockClient で Central の口(S-018)をまねる。
void main() {
  ({MockClient client, Map<String, Object?> state, List<String> calls}) fakeCentral({bool open = true, String? age}) {
    final state = <String, Object?>{'granted': false, 'age': age, 'guardian': false, 'code': null};
    final calls = <String>[];
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    Map<String, Object?> status() {
      final a = state['age'] as String?;
      final reason = a == null
          ? 'age-required'
          : a == '18+' || (a == '16-17' && state['guardian'] == true)
              ? null
              : a == '16-17'
                  ? 'guardian-required'
                  : 'under-16';
      return {
        'open': open,
        'granted': state['granted'],
        'since': state['granted'] == true ? '2026-09-17T03:00:00Z' : null,
        'version': state['granted'] == true ? rasqLearningVersion : null,
        'eligible': reason == null,
        'reason': reason,
        'ageBand': a,
        'posts': 0,
        'labels': 0,
        'models': <String>[],
        'hasWithdrawCode': state['code'] != null,
        'retentionYears': 5,
        'withdrawDays': 30,
      };
    }

    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'rasq_tester', 'displayName': 'テスター', 'createdAt': '2026-09-01T00:00:00Z'});
        case 'GET /me/learning':
          return json(status());
        case 'PUT /me/consents/age':
          state['age'] = (jsonDecode(req.body) as Map)['detail'];
          return json({'kind': 'age'});
        case 'PUT /me/consents/guardian':
          state['guardian'] = true;
          return json({'kind': 'guardian'});
        case 'POST /me/learning/grant':
          if (!open) return json({'error': {'code': '403', 'message': 'learning consent is not open yet'}}, 403);
          expect((jsonDecode(req.body) as Map)['version'], rasqLearningVersion);
          state['granted'] = true;
          state['code'] = 'code-abc-123';
          return json({'status': status(), 'withdrawCode': 'code-abc-123'});
        case 'POST /me/learning/withdraw':
          state['granted'] = false;
          state['code'] = null;
          return json(status());
        case 'POST /learning/withdraw':
          if ((jsonDecode(req.body) as Map)['code'] != state['code']) return json({'error': {'code': '404', 'message': 'no such withdrawal code'}}, 404);
          state['granted'] = false;
          state['code'] = null;
          return json({'withdrawn': true, 'withdrawDays': 30});
      }
      // バンドル同期など、この画面と関係ない口。
      return req.method == 'GET' ? json([]) : json(<String, Object?>{});
    });
    return (client: client, state: state, calls: calls);
  }

  Future<(ProviderContainer, MemorySessionStorage)> pump(WidgetTester tester, MockClient client, {bool account = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rootBundle.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      if (account) OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.settingsLearning);
    await tester.pumpAndSettle();
    expect(find.byType(LearningScreen), findsOneWidget);
    return (c, storage);
  }

  String statusOf(WidgetTester tester) => tester.widget<RasqValueListTile>(find.byKey(const ValueKey('learning.status'))).value;

  testWidgets('既定は「提供しない」。年齢の申告 → 要点にチェックを入れるまで同意できない → 同意 → 撤回用のコード → 撤回', (tester) async {
    final central = fakeCentral();
    final (_, storage) = await pump(tester, central.client);
    expect(statusOf(tester), '提供しない');
    // 登録の FOW より前に作ったアカウント: まず年齢の申告。16〜17 歳は保護者の同意も。
    expect(find.text('年齢の申告が必要です'), findsOneWidget);
    expect(find.byKey(const ValueKey('learning.grant')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('learning.declareAge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning.age.16-17')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申告する')); // 保護者の同意がまだ → 押せない
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c.startsWith('PUT /me/consents')), isEmpty);
    await tester.tap(find.byKey(const ValueKey('learning.guardian')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申告する'));
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c.startsWith('PUT /me/consents')), ['PUT /me/consents/age', 'PUT /me/consents/guardian']);
    // 同意: 確認のシート。チェックを入れるまで「同意して提供する」は押せない。
    await tester.tap(find.byKey(const ValueKey('learning.grant')));
    await tester.pumpAndSettle();
    expect(find.textContaining('DM、限定公開の投稿、AsTell の会話'), findsOneWidget);
    await tester.tap(find.text('同意して提供する'));
    await tester.pumpAndSettle();
    expect(central.calls, isNot(contains('POST /me/learning/grant')));
    await tester.ensureVisible(find.byKey(const ValueKey('learning.agree')));
    await tester.tap(find.byKey(const ValueKey('learning.agree')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して提供する'));
    await tester.pumpAndSettle();
    expect(central.calls, contains('POST /me/learning/grant'));
    expect(statusOf(tester), '提供する');
    // 撤回用のコードは画面に出て、端末にも控える(アカウントごと)。
    expect(find.text('code-abc-123'), findsOneWidget);
    expect(jsonDecode((await storage.read(learningCodeStorageKey))!), {'acc-1': 'code-abc-123'});
    // 撤回: 確認のあと。コードの控えも消える。
    await tester.ensureVisible(find.byKey(const ValueKey('learning.withdraw')));
    await tester.tap(find.byKey(const ValueKey('learning.withdraw')));
    await tester.pumpAndSettle();
    expect(find.textContaining('30 日以内を目標に消します'), findsOneWidget);
    await tester.tap(find.text('撤回する'));
    await tester.pumpAndSettle();
    expect(statusOf(tester), '提供しない');
    expect(find.text('code-abc-123'), findsNothing);
    expect(jsonDecode((await storage.read(learningCodeStorageKey))!), isEmpty);
  });

  testWidgets('受付が閉じている間は同意できない。16 歳未満は申告のやり直しも出さない', (tester) async {
    final closed = fakeCentral(open: false, age: '18+');
    await pump(tester, closed.client);
    expect(find.text('まだ始まっていません'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('learning.grant')));
    expect(button.onPressed, isNull);
    expect(find.text('受付はまだ始まっていません'), findsOneWidget);
  });

  testWidgets('13〜15 歳は提供できない / RASQ アカウントが無ければ作成の案内', (tester) async {
    final young = fakeCentral(age: '13-15');
    await pump(tester, young.client);
    expect(find.text('学習へのデータ提供は 16 歳以上でできます'), findsOneWidget);
    expect(find.byKey(const ValueKey('learning.declareAge')), findsNothing);
    expect(find.byKey(const ValueKey('learning.grant')), findsNothing);
  });

  testWidgets('RASQ アカウントが無ければ作成の案内。撤回用のコードでの撤回はアカウントなしでもできる', (tester) async {
    final central = fakeCentral();
    central.state['granted'] = true;
    central.state['code'] = 'lost-account-code';
    await pump(tester, central.client, account: false);
    expect(find.byKey(const ValueKey('learning.needAccount')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('learning.byCode')));
    await tester.tap(find.byKey(const ValueKey('learning.byCode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('learning.code.input')), 'lost-account-code');
    await tester.tap(find.text('撤回する'));
    await tester.pumpAndSettle();
    expect(central.calls, contains('POST /learning/withdraw'));
    expect(central.state['granted'], false);
  });
}
