import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/backend/onboarding_discover_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart' show RasqPostAuthor;
import 'package:rasq_client/features/onboarding/discover_history.dart';
import 'package:rasq_client/features/onboarding/history_discover_screen.dart';
import 'package:rasq_client/features/onboarding/qr_discover_screen.dart';
import 'package:rasq_client/features/onboarding/sns_discover_screen.dart' show discoverImagePickerProvider;
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:zxing2/qrcode.dart';

// 友だちの QR から探す / 検索履歴を統合して探す (D-553)。

final _central = Uri.parse('https://central.test');

/// [text] の QR を描いた PNG(1 マス 6 画素、周りに余白)。
Uint8List _qrPng(String text) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  const scale = 6, quiet = 4;
  final size = (matrix.width + quiet * 2) * scale;
  final image = img.Image(width: size, height: size)..clear(img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) == 1) img.fillRect(image, x1: (x + quiet) * scale, y1: (y + quiet) * scale, x2: (x + quiet + 1) * scale - 1, y2: (y + quiet + 1) * scale - 1, color: img.ColorRgb8(0, 0, 0));
    }
  }
  return img.encodePng(image);
}

void main() {
  group('友だちの QR', () {
    test('QR の中身は Central の /@handle。読むのは、その Central の /@handle と rasq://account/ だけ', () {
      expect(centralAccountUrl(Uri.parse('https://central.test/api/v1'), 'hana'), 'https://central.test/@hana');
      expect(centralAccountUrl(Uri.parse('http://localhost:8080/api/v1'), 'hana'), 'http://localhost:8080/@hana');
      expect(rasqHandleOfQr('https://central.test/@hana', _central), 'hana');
      expect(rasqHandleOfQr(' https://CENTRAL.test/@Hana_1/ ', _central), 'Hana_1');
      expect(rasqHandleOfQr('rasq://account/hana', _central), 'hana');
      expect(rasqHandleOfQr('rasq://account/@hana', null), 'hana');
      // ほかのサイトの /@name は RASQ ではない。ページの下の階層(共有のコードなど)も人ではない。
      expect(rasqHandleOfQr('https://misskey.io/@hana', _central), isNull);
      expect(rasqHandleOfQr('https://central.test/@hana/abc', _central), isNull);
      expect(rasqHandleOfQr('https://central.test/hana', _central), isNull);
      expect(rasqHandleOfQr('rasq://astell/abc', _central), isNull);
      expect(rasqHandleOfQr('rasq://account/ha na', _central), isNull);
      expect(rasqHandleOfQr('こんにちは', _central), isNull);
    });

    test('画像の中の QR を端末で読む。QR の無い画像 / 画像でないものは null', () {
      expect(decodeQrText(_qrPng('https://central.test/@hana')), 'https://central.test/@hana');
      expect(decodeQrText(img.encodePng(img.Image(width: 64, height: 64)..clear(img.ColorRgb8(200, 200, 200)))), isNull);
      expect(decodeQrText(Uint8List.fromList([1, 2, 3])), isNull);
    });

    Future<void> pump(WidgetTester tester, {required String? qrText, required Set<String> accounts}) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async {
        final handle = req.url.pathSegments.last;
        if (req.url.path.contains('/accounts/') && accounts.contains(handle)) {
          return http.Response.bytes(utf8.encode(jsonEncode({'id': 'id-$handle', 'handle': handle, 'displayName': 'はな', 'bio': 'ねこが好き'})), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response.bytes(utf8.encode(jsonEncode({'error': {'code': '404', 'message': 'no'}})), 404, headers: {'content-type': 'application/json'});
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          centralBaseUrlProvider.overrideWithValue(_central),
          orgateBaseUrlProvider.overrideWithValue(_central),
          centralClientProvider.overrideWithValue(OrgateClient(baseUrl: _central, httpClient: client)),
          orgateClientProvider.overrideWithValue(OrgateClient(baseUrl: _central, httpClient: client)),
          discoverImagePickerProvider.overrideWithValue(({required bool camera, required int limit}) async => [Uint8List.fromList([0])]),
          qrDecoderProvider.overrideWithValue((bytes) async => qrText),
        ],
        child: const MaterialApp(home: DiscoverQrScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('画像から読む → RASQ アカウントの QR なら、その人が出る。ログインしていなければ自分の QR は出さない', (tester) async {
      await pump(tester, qrText: 'https://central.test/@hana', accounts: {'hana'});
      expect(find.byKey(const ValueKey('discover.qr.mine.none')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.qr.image')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.account.hana')), findsOneWidget);
      expect(find.text('ねこが好き'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.qr.error')), findsNothing);
    });

    testWidgets('QR が無い / RASQ の QR でない / その人がいない は、それぞれそう出す', (tester) async {
      await pump(tester, qrText: null, accounts: {});
      await tester.tap(find.byKey(const ValueKey('discover.qr.image')));
      await tester.pumpAndSettle();
      expect(find.textContaining('QR が見つかりませんでした'), findsOneWidget);

      await pump(tester, qrText: 'https://example.com/', accounts: {});
      await tester.tap(find.byKey(const ValueKey('discover.qr.image')));
      await tester.pumpAndSettle();
      expect(find.text('RASQ アカウントの QR ではありません'), findsOneWidget);

      await pump(tester, qrText: 'rasq://account/ghost', accounts: {});
      await tester.tap(find.byKey(const ValueKey('discover.qr.image')));
      await tester.pumpAndSettle();
      expect(find.text('@ghost は見つかりませんでした'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.account.ghost')), findsNothing);
    });
  });

  group('検索履歴', () {
    test('探した言葉を新しい順に控える。同じ言葉は 1 つ、長い文は控えない。消せる。端末に残る', () async {
      final storage = MemorySessionStorage({});
      final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
      addTearDown(c.dispose);
      final h = c.read(discoverHistoryProvider.notifier);
      await h.record(['猫', 'イラスト'], DiscoverHistorySource.content);
      await h.record([' Neko  写真 ', '猫', 'あ' * 41, ''], DiscoverHistorySource.people);
      expect(c.read(discoverHistoryProvider).map((e) => e.term), ['Neko 写真', '猫', 'イラスト']);
      expect(c.read(discoverHistoryProvider)[1].source, DiscoverHistorySource.people, reason: '同じ言葉は新しい方に置き換わる');
      await h.remove('猫');
      expect(c.read(discoverHistoryProvider).map((e) => e.term), ['Neko 写真', 'イラスト']);
      // 別の起動でも読める。
      final c2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
      addTearDown(c2.dispose);
      await c2.read(discoverHistoryProvider.notifier).ready;
      expect(c2.read(discoverHistoryProvider).map((e) => e.term), ['Neko 写真', 'イラスト']);
      await c2.read(discoverHistoryProvider.notifier).clear();
      expect(c2.read(discoverHistoryProvider), isEmpty);
    });

    test('まとめて探す: ユーザーは言葉ごと(同じ人は 1 度)、リストは言葉をつなげて 1 回。片方が失敗しても出す', () async {
      final asked = <String>[];
      String? listQuery;
      final r = await runHistoryDiscover(
        terms: [for (var i = 0; i < 10; i++) 't$i'],
        searchAccounts: (t) async {
          asked.add(t);
          if (t == 't1') throw StateError('x');
          return [RasqPostAuthor(id: 'a', handle: 'hana', displayName: 'はな')];
        },
        searchLists: (q) async {
          listQuery = q;
          return const [ListHit(id: 'l1', name: 'ねこ好き')];
        },
      );
      expect(asked.length, historyDiscoverMaxTerms, reason: '言葉は 8 個まで');
      expect(listQuery, 't0 t1 t2 t3 t4 t5 t6 t7');
      expect(r.accounts.single.handle, 'hana');
      expect(r.lists.single.id, 'l1');
      expect((await runHistoryDiscover(terms: const [], searchAccounts: (_) async => const [], searchLists: (_) async => const [])).isEmpty, isTrue);
    });

    testWidgets('履歴の画面: 新しい言葉が選ばれていて、選び直して探すと RASQ の人とリストが出る。空ならそう出す', (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      final client = MockClient((req) async {
        http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
        calls.add('${req.url.path.replaceFirst('/api/v1', '')}?${req.url.query}');
        if (req.url.path.endsWith('/accounts/search')) {
          return json([
            {'id': 'a1', 'handle': 'hana', 'displayName': 'はな'},
          ]);
        }
        if (req.url.path.endsWith('/onboarding/discover/lists')) {
          return json({
            'lists': [
              {'id': 'l1', 'name': 'ねこ好き', 'memberCount': 3},
            ],
          });
        }
        return json(<String, Object?>{});
      });
      final storage = MemorySessionStorage({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          centralBaseUrlProvider.overrideWithValue(_central),
          orgateBaseUrlProvider.overrideWithValue(_central),
          centralClientProvider.overrideWithValue(OrgateClient(baseUrl: _central, httpClient: client)),
          orgateClientProvider.overrideWithValue(OrgateClient(baseUrl: _central, httpClient: client)),
        ],
        child: const MaterialApp(home: DiscoverHistoryScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.history.empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.history.search')), findsNothing);

      final c = ProviderScope.containerOf(tester.element(find.byType(DiscoverHistoryScreen)));
      await tester.runAsync(() => c.read(discoverHistoryProvider.notifier).record(['猫', 'イラスト'], DiscoverHistorySource.content));
      await tester.pumpAndSettle();
      expect(find.text('選んだ 2 個の言葉で探す'), findsOneWidget);
      // 1 つ外して探す。
      await tester.tap(find.text('イラスト'));
      await tester.pumpAndSettle();
      expect(find.text('選んだ 1 個の言葉で探す'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.history.search')));
      await tester.pumpAndSettle();
      expect(calls.where((p) => p.startsWith('/accounts/search')).length, 1);
      expect(Uri.splitQueryString(calls.firstWhere((p) => p.startsWith('/onboarding/discover/lists')).split('?').last)['q'], '猫');
      expect(find.byKey(const ValueKey('discover.account.hana')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.l1')), findsOneWidget);
      // すべて消す。
      await tester.tap(find.byKey(const ValueKey('discover.history.clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.history.empty')), findsOneWidget);
    });
  });
}
