import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/trend/trend_reports.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-402: トレンドの通報は Central の `POST /reports {trend}` へ送る(トークンの取り直しつきの Central の口)。
/// 送れなければ端末に控えて、次にトレンドの「…」を開いたときに送り直す。通報したトレンドは一覧から隠す。
void main() {
  test('通報の本文: ワードと、そのトレンドを出した SNS アカウント(Central がサーバーだけを取る)', () {
    expect(
      trendReportBody({'tag': '#月見', 'reason': 'spam', 'note': '宣伝', 'account': 'misskey:example.test:tester', 'sent': false, 'hidden': true}),
      {
        'trend': {'tag': '#月見', 'accountKey': 'misskey:example.test:tester'},
        'reason': 'spam',
        'note': '宣伝',
      },
    );
    expect(trendReportBody({'tag': 'x', 'reason': 'other'}), {'trend': {'tag': 'x'}, 'reason': 'other'});
  });

  late MemorySessionStorage storage;
  final posted = <Map<String, Object?>>[];
  var down = false;

  Future<ProviderContainer> pump(WidgetTester tester, {Map<String, String> extra = const {}}) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    posted.clear();
    down = false;
    storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      ...extra,
    });
    http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final route = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
      if (route == 'GET /me') return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
      if (route == 'POST /reports') {
        if (down) return json({'error': {'code': '503', 'message': 'down'}}, 503);
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        posted.add(body);
        return json({'id': 'rep-${posted.length}', 'reason': body['reason'], 'status': 'open', 'trend': body['trend']}, 201);
      }
      if (req.method == 'GET') return json(const []);
      return json(const {});
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const [], trends: const [TrendTag(tag: '打上会', usersCount: 10), TrendTag(tag: '#月見', usersCount: 5)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.runAsync(() => c.read(orgateAccountProvider.future));
    await tester.pumpAndSettle();
    return c;
  }

  Future<Map> saved() async => jsonDecode((await storage.read('$trendReportsArea.v1')) ?? '{}') as Map;

  Future<void> report(WidgetTester tester, String tag, {String reason = 'スパム'}) async {
    await tester.tap(find.byKey(ValueKey('trend.more.$tag')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('通報'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(reason).first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trend.report.send')));
    await tester.pumpAndSettle();
  }

  testWidgets('通報は Central へ届き、そのトレンドは一覧から消える', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('trend.tile.#月見')), findsWidgets);
    await report(tester, '#月見');
    expect(posted, [
      {
        'trend': {'tag': '#月見', 'accountKey': fakeSession().account.key},
        'reason': 'spam',
      },
    ]);
    expect(find.text('通報しました。RASQ の審査で確認します'), findsOneWidget);
    expect((await saved())['月見'], allOf(containsPair('sent', true), containsPair('reportId', 'rep-1'), containsPair('hidden', true)));
    expect(find.byKey(const ValueKey('trend.tile.#月見')), findsNothing);
    expect(find.byKey(const ValueKey('trend.tile.打上会')), findsWidgets);
  });

  testWidgets('送れなければ端末に控え、次に「…」を開いたときに送り直す(前の版の控えも送る)', (tester) async {
    // D-397 の版で端末に控えただけの通報(sent / hidden の印が無い)。
    await pump(tester, extra: {
      '$trendReportsArea.v1': jsonEncode({
        '花火': {'tag': '花火', 'reason': 'other', 'at': '2026-10-01T00:00:00Z'},
      }),
    });
    down = true;
    await report(tester, '打上会', reason: '嫌がらせ・暴言');
    expect(posted, isEmpty);
    expect(find.textContaining('送れなかったので、この端末に控えました'), findsOneWidget);
    expect((await saved())['打上会'], allOf(containsPair('sent', false), containsPair('reason', 'harassment')));
    expect(find.byKey(const ValueKey('trend.tile.打上会')), findsNothing);

    // 繋がるようになってから「…」を開くと、控えが送られる。
    down = false;
    await tester.tap(find.byKey(const ValueKey('trend.more.#月見')).first);
    await tester.pumpAndSettle();
    expect(posted.map((b) => (b['trend'] as Map)['tag']).toSet(), {'打上会', '花火'});
    final s = await saved();
    expect(s['打上会'], containsPair('sent', true));
    expect(s['花火'], containsPair('sent', true));
  });
}
