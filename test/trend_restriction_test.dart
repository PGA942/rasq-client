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
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/trend/trend_restrictions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-404 / Central S-068: EmoM の閾値(0〜100、既定 50)と、その公開(既定オフ)。運営が制限したトレンドは、
/// 点数 > この端末の閾値(オーバーフロー "all" は常に)なら検索のトレンドの一覧に並べない。
void main() {
  group('判定', () {
    test('ワードは Central と同じそろえ方', () {
      expect(normalizeTrendTag('  ＃ＴＥＳＴ　月見  '), 'test 月見');
      expect(normalizeTrendTag('#Foo   Bar'), 'foo bar');
      expect(normalizeTrendTag(' # '), '');
    });

    test('点数 > 閾値 で隠す。"all"(101%)は閾値に関係なく。サーバーを限る制限は、そのサーバーのトレンドだけ', () {
      const rs = [
        TrendRestriction(tag: '打上会', instance: 'example.test', score: 60),
        TrendRestriction(tag: '月見', score: 40),
        TrendRestriction(tag: '花火', score: null),
      ];
      expect(isTrendRestricted('#打上会', ['example.test'], rs, 50), isTrue);
      expect(isTrendRestricted('#打上会', ['example.test'], rs, 60), isFalse); // 等しければ出す
      expect(isTrendRestricted('打上会', ['other.example'], rs, 0), isFalse); // 別のサーバー
      expect(isTrendRestricted('打上会', ['other.example', 'Example.Test'], rs, 0), isTrue); // 出どころのどれか
      expect(isTrendRestricted('月見', const [], rs, 39), isTrue);
      expect(isTrendRestricted('月見', const [], rs, 40), isFalse);
      for (final t in [0, 50, 100]) {
        expect(isTrendRestricted('＃花火', ['any.example'], rs, t), isTrue, reason: 'overflow @ $t');
      }
      expect(isTrendRestricted('ほか', ['example.test'], rs, 0), isFalse);
    });

    test('Central の形を読む(解除・形の違うものは捨てる)', () {
      expect(TrendRestriction.fromJson({'tag': 'a', 'kind': 'misskey', 'instance': 'Example.Test', 'score': 51})?.toJson(), {'tag': 'a', 'instance': 'example.test', 'score': 51});
      expect(TrendRestriction.fromJson({'tag': 'a', 'instance': null, 'score': 'all'})?.all, isTrue);
      expect(TrendRestriction.fromJson({'tag': 'a', 'score': 10, 'lifted': true}), isNull);
      expect(TrendRestriction.fromJson({'tag': 'a', 'score': 'x'}), isNull);
      expect(emomThresholdOf(const {}), 50);
      expect(emomThresholdOf(const {'threshold': 120}), 100);
    });
  });

  late MemorySessionStorage storage;
  final calls = <String>[];
  var restrictions = <Map<String, Object?>>[];
  var down = false;

  Future<ProviderContainer> pump(WidgetTester tester, {Map<String, String> extra = const {}, bool offline = false}) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    calls.clear();
    down = offline;
    storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      ...extra,
    });
    http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final route = '${req.method} $path';
      if (route == 'GET /me') return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
      if (path == '/trend-restrictions') {
        calls.add('$route ${req.url.queryParameters['instance']}');
        if (down) return json({'error': {'code': '503', 'message': 'down'}}, 503);
        return json({'restrictions': restrictions, 'now': '2026-10-01T00:00:00Z'});
      }
      if (path == '/me/emom-threshold') {
        if (down) return json({'error': {'code': '503', 'message': 'down'}}, 503);
        calls.add(req.method == 'PUT' ? '$route ${req.body}' : route);
        if (req.method == 'DELETE') return http.Response('', 204);
        final v = (jsonDecode(req.body) as Map)['value'];
        return json({'disclosed': true, 'value': v, 'updatedAt': '2026-10-01T00:00:00Z'});
      }
      if (req.method == 'GET') return json(const []);
      return json(const {});
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: (_) => const [], trends: const [TrendTag(tag: '打上会', usersCount: 10), TrendTag(tag: '#月見', usersCount: 5), TrendTag(tag: '花火', usersCount: 3), TrendTag(tag: '紅葉', usersCount: 2)]));
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

  Future<Map> saved() async => jsonDecode((await storage.read('$emomArea.v1')) ?? '{}') as Map;
  bool shown(String tag) => find.byKey(ValueKey('trend.tile.$tag')).evaluate().isNotEmpty;

  testWidgets('制限されたトレンドは閾値と比べて一覧から消える(101% = 全員)。別のサーバーの制限は効かない', (tester) async {
    restrictions = [
      {'tag': '打上会', 'kind': 'misskey', 'instance': 'example.test', 'score': 60},
      {'tag': '月見', 'kind': null, 'instance': null, 'score': 40},
      {'tag': '花火', 'kind': null, 'instance': null, 'score': 'all'},
      {'tag': '紅葉', 'kind': 'misskey', 'instance': 'other.example', 'score': 'all'},
    ];
    // 閾値 50(既定): 60 > 50 で 打上会 は隠れ、40 の 月見 は出る。花火 はオーバーフロー。紅葉 は別のサーバーの制限。
    await pump(tester);
    expect(calls, contains('GET /trend-restrictions example.test'));
    expect([shown('打上会'), shown('#月見'), shown('花火'), shown('紅葉')], [false, true, false, true]);
    // 閾値を 100(いちばん広い)にしても、オーバーフローは隠れたまま。
    await storage.write('$emomArea.v1', jsonEncode({'threshold': 100}));
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.invalidate(settingsAreaProvider(emomArea));
    await tester.pumpAndSettle();
    expect([shown('打上会'), shown('#月見'), shown('花火'), shown('紅葉')], [true, true, false, true]);
    // 閾値 30: 40 > 30 で 月見 も隠れる。
    await storage.write('$emomArea.v1', jsonEncode({'threshold': 30}));
    c.invalidate(settingsAreaProvider(emomArea));
    await tester.pumpAndSettle();
    expect([shown('打上会'), shown('#月見'), shown('花火'), shown('紅葉')], [false, false, false, true]);
  });

  testWidgets('Central に繋がらなければ、前に読めた制限の控えで隠す', (tester) async {
    restrictions = const [];
    await pump(tester, offline: true, extra: {
      '$trendRestrictionsCacheArea.v1': jsonEncode({
        'items': [
          {'tag': '花火', 'instance': null, 'score': 'all'},
        ],
      }),
    });
    expect([shown('打上会'), shown('花火')], [true, false]);
  });

  testWidgets('設定: 閾値のスライダー(既定 50)と、公開(既定オフ)→ 値を送る / 変えたら送り直す / オフで消してもらう', (tester) async {
    restrictions = const [];
    final c = await pump(tester);
    c.read(routerProvider).push(Routes.settingsEmom);
    await tester.pumpAndSettle();
    expect(find.text('EmoM の閾値'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('emom.value'))).data, '50');
    expect(find.text('閾値を公開する(制限の目安に使う)'), findsOneWidget);
    expect(find.textContaining('あなたの値を個別に見ることはありません'), findsOneWidget);
    expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('emom.disclose')), matching: find.byType(Switch))).value, isFalse);
    expect(find.text('公開していません'), findsOneWidget);
    expect(calls.where((x) => x.contains('emom')), isEmpty);

    // 公開する → いまの値を送る。
    await tester.tap(find.byKey(const ValueKey('emom.disclose')));
    await tester.pumpAndSettle();
    expect(calls.last, 'PUT /me/emom-threshold {"value":50}');
    expect(await saved(), allOf(containsPair('disclose', true), containsPair('sent', 50)));
    expect(find.text('公開しています(値 50)'), findsOneWidget);

    // スライダーを右端へ(高い = 許容が広い)→ 送り直す。
    await tester.drag(find.byKey(const ValueKey('emom.slider')), const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('emom.value'))).data, '100');
    expect(calls.last, 'PUT /me/emom-threshold {"value":100}');
    expect(await saved(), allOf(containsPair('threshold', 100), containsPair('sent', 100)));
    expect(find.textContaining('広め'), findsOneWidget);

    // オフ → 送った値を消してもらう。
    await tester.tap(find.byKey(const ValueKey('emom.disclose')));
    await tester.pumpAndSettle();
    expect(calls.last, 'DELETE /me/emom-threshold');
    expect(await saved(), allOf(containsPair('disclose', false), containsPair('sent', null), containsPair('threshold', 100)));
  });

  testWidgets('まだ届いていない公開は、トレンドを読むときに送る', (tester) async {
    restrictions = const [];
    await pump(tester, extra: {
      '$emomArea.v1': jsonEncode({'threshold': 20, 'disclose': true}),
    });
    // 起動してトレンドを読んだとき(制限の読み込みのついで)に送る。
    expect(calls, contains('PUT /me/emom-threshold {"value":20}'));
    expect(await saved(), containsPair('sent', 20));
  });
}
