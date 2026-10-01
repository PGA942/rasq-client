import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/payments_api.dart';
import 'package:rasq_client/features/store/http_store_client.dart';

/// 第 4 段階 (D-401 / ORGATE O-004): ポイント / 購入は ORGATE の口、掲載などは Central のまま。
/// 公開テスト(`ORGATE_PAID_FEATURES=off`)は `GET /payments/config` の `paidFeatures: false` と `403 paid_features_disabled`。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  const disabled = {'error': {'code': 'paid_features_disabled', 'message': 'ポイントと有料プラグインは公開テストでは使えません。'}};

  ({OrgateClient central, OrgateClient orgate, List<String> centralSeen, List<String> orgateSeen}) clients({bool paidOff = false}) {
    final centralSeen = <String>[];
    final orgateSeen = <String>[];
    final central = OrgateClient(
      baseUrl: Uri.parse('https://central.test'),
      httpClient: MockClient((req) async {
        centralSeen.add('${req.method} ${req.url.path}');
        if (req.url.path == '/api/v1/plugins/p.paid/manifest' && paidOff) return json(disabled, 403);
        return json({'error': {'code': 'not_found', 'message': 'no'}}, 404);
      }),
      tokenProvider: () => 'tok',
    );
    final orgate = OrgateClient(
      baseUrl: Uri.parse('https://orgate.test'),
      httpClient: MockClient((req) async {
        orgateSeen.add('${req.method} ${req.url.path} ${req.headers['authorization']}');
        if (paidOff) return json(disabled, 403);
        return switch ('${req.method} ${req.url.path}') {
          'GET /api/v1/me/points' => json({
              'balance': 500,
              'grants': [
                {'amount': 500, 'remaining': 500, 'source': 'stripe', 'createdAt': '2026-10-01T00:00:00Z', 'expiresAt': '2026-11-01T00:00:00Z', 'expired': false},
              ],
              'purchases': [],
            }),
          'POST /api/v1/plugins/p.paid/purchase' => json({'purchased': true, 'pointsSpent': 300, 'balance': 200}),
          _ => json({'error': {'code': 'not_found', 'message': 'no'}}, 404),
        };
      }),
      tokenProvider: () => 'tok',
    );
    return (central: central, orgate: orgate, centralSeen: centralSeen, orgateSeen: orgateSeen);
  }

  test('ポイントと購入は ORGATE へ(Bearer つき)、Central には行かない', () async {
    final c = clients();
    final store = HttpStoreClient(c.central, payments: c.orgate);
    final points = await store.points();
    expect(points.balance, 500);
    expect(points.nextExpiring?.remaining, 500);
    final r = await store.purchase('p.paid');
    expect((r.purchased, r.pointsSpent, r.balance), (true, 300, 200));
    expect(c.orgateSeen, ['GET /api/v1/me/points Bearer tok', 'POST /api/v1/plugins/p.paid/purchase Bearer tok']);
    expect(c.centralSeen, isEmpty);
    // 掲載は Central のまま。
    expect(await store.plugin('p.free'), isNull);
    expect(c.centralSeen, ['GET /api/v1/plugins/p.free']);
  });

  test('ORGATE につながない構成: ポイント / 購入ははっきりしたエラー', () async {
    final c = clients();
    final store = HttpStoreClient(c.central);
    await expectLater(store.points(), throwsA(isA<OrgateException>().having((e) => e.message, 'message', contains('ORGATE'))));
    await expectLater(store.purchase('p.paid'), throwsA(isA<OrgateException>().having((e) => e.message, 'message', contains('ORGATE'))));
    expect(c.centralSeen, isEmpty);
  });

  test('403 paid_features_disabled はアプリの文にそろえる(ポイント / 購入 / Central の構成)', () async {
    final c = clients(paidOff: true);
    final store = HttpStoreClient(c.central, payments: c.orgate);
    final matcher = isA<OrgateException>()
        .having((e) => e.serverCode, 'serverCode', paidFeaturesDisabledCode)
        .having((e) => e.message, 'message', paidFeaturesDisabledMessage)
        .having(isPaidFeaturesDisabled, 'isPaidFeaturesDisabled', isTrue);
    await expectLater(store.points(), throwsA(matcher));
    await expectLater(store.purchase('p.paid'), throwsA(matcher));
    await expectLater(store.manifest('p.paid'), throwsA(matcher));
    expect(paidFeaturesDisabledMessage, '公開テストでは有料プラグインは使えません');
  });

  test('PaymentsConfig: ワイヤーの形を読む', () {
    final cfg = PaymentsConfig.fromJson({
      'paidFeatures': false,
      'stripeMode': 'dummy',
      'points': {
        'available': false,
        'packs': [
          {'id': 'p500', 'points': 500, 'amountJpy': 500},
          {'id': 'p1000', 'points': 1000, 'amountJpy': 1000},
        ],
        'expiresAfterMonths': 1,
      },
      'reviewFee': {'enabled': true, 'amountJpy': 3000, 'taxIncluded': true, 'currency': 'jpy', 'provisional': true},
    });
    expect(cfg.paidFeatures, isFalse);
    expect(cfg.stripeMode, 'dummy');
    expect(cfg.pointsAvailable, isFalse);
    expect([for (final p in cfg.packs) (p.id, p.points, p.amountJpy)], [('p500', 500, 500), ('p1000', 1000, 1000)]);
    expect(cfg.pointsExpireAfterMonths, 1);
    expect((cfg.reviewFee.enabled, cfg.reviewFee.amountJpy, cfg.reviewFee.taxIncluded, cfg.reviewFee.provisional), (true, 3000, true, true));
  });

  test('paymentsConfigProvider: ORGATE の GET /payments/config(認証なし)。つながらない / 未設定は止まっている扱い', () async {
    String? auth = 'unset';
    final ok = ProviderContainer(overrides: [
      orgateClientProvider.overrideWithValue(OrgateClient(
        baseUrl: Uri.parse('https://orgate.test'),
        httpClient: MockClient((req) async {
          expect(req.url.path, '/api/v1/payments/config');
          auth = req.headers['authorization'];
          return json({'paidFeatures': true, 'stripeMode': 'live', 'points': {'available': true, 'packs': [], 'expiresAfterMonths': 1}, 'reviewFee': {'enabled': true, 'amountJpy': 3000}});
        }),
      )),
    ]);
    addTearDown(ok.dispose);
    expect((await ok.read(paymentsConfigProvider.future)).paidFeatures, isTrue);
    expect(ok.read(paidFeaturesProvider), isTrue);
    expect(auth, isNull);

    final down = ProviderContainer(overrides: [
      orgateClientProvider.overrideWithValue(OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: MockClient((req) async => http.Response('bad gateway', 502)))),
    ]);
    addTearDown(down.dispose);
    expect((await down.read(paymentsConfigProvider.future)).paidFeatures, isFalse);
    expect(down.read(paidFeaturesProvider), isFalse);

    final none = ProviderContainer(overrides: [orgateClientProvider.overrideWithValue(null)]);
    addTearDown(none.dispose);
    expect((await none.read(paymentsConfigProvider.future)).paidFeatures, isFalse);
  });
}
