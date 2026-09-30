import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/ads/export_ad.dart';
import 'package:rasq_client/features/home/home_header.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart' show MediaEditResult;
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/swing/swing_composer.dart';
import 'package:rasq_client/features/swing/swing_models.dart';
import 'package:rasq_client/features/swing/swing_providers.dart';
import 'package:rasq_client/features/swing/swing_viewer.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// Swing (D-377 / Central S-056)。
void main() {
  final now = DateTime.now().toUtc();
  Map<String, Object?> swing(String id, String author, {String kind = 'text', String text = 'やっほー', Map<String, Object?>? media, Map<String, Object?>? plugin, Duration age = const Duration(minutes: 30)}) => {
        'id': id,
        'author': {'accountId': author, 'handle': author, 'displayName': '$author さん'},
        'kind': kind,
        'text': text,
        'media': media,
        'plugin': plugin,
        'createdAt': now.subtract(age).toIso8601String(),
        'expiresAt': now.add(const Duration(hours: 5)).toIso8601String(),
        'seen': false,
      };

  group('モデル', () {
    test('読み取り・並び(作った人ごと、人の中は古い順)・広告を挟む', () {
      final a1 = Swing.tryParse(swing('a1', 'alice', age: const Duration(minutes: 50)))!;
      final a2 = Swing.tryParse(swing('a2', 'alice', age: const Duration(minutes: 5)))!;
      final b1 = Swing.tryParse(swing('b1', 'bob', age: const Duration(minutes: 20)))!;
      expect(a1.author.displayName, 'alice さん');
      expect(a1.authorAccountId, 'alice');
      expect(Swing.tryParse({'id': 'x', 'kind': 'story', 'author': {}}), isNull);
      // alice のいちばん新しいもの(5 分前)が bob(20 分前)より新しい → alice が先、alice の中は古い順。
      expect([for (final s in orderForViewer([b1, a2, a1])) s.id], ['a1', 'a2', 'b1']);
      final six = [for (var i = 0; i < 6; i++) Swing.tryParse(swing('s$i', 'u$i'))!];
      expect([for (final x in interleaveAds(six, ads: true)) x.ad ? 'ad' : x.swing!.id], ['s0', 's1', 's2', 's3', 's4', 'ad', 's5']);
      expect(interleaveAds(six.take(5).toList(), ads: true).any((x) => x.ad), isFalse, reason: '最後には付けない');
      expect(interleaveAds(six, ads: false).any((x) => x.ad), isFalse);
      expect(swingMediaMimeFor('a.PNG'), 'image/png');
      expect(swingMediaMimeFor('a.mov'), 'video/quicktime');
      expect(swingMediaMimeFor('a.mp3'), isNull);
      expect(swingRemainingLabel(const Duration(hours: 3, minutes: 5)), 'あと 3 時間');
      expect(swingRemainingLabel(const Duration(minutes: 7)), 'あと 7 分');
    });
  });

  testWidgets('背景とテキストの無地の背景は、縦長の PNG', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final png = (await tester.runAsync(() => c.read(swingBackgroundProvider)()))!;
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final img = (await tester.runAsync(() => decodeImageFromList(png)))!;
    expect(img.height > img.width, isTrue);
  });

  /// Central のまね。[feed] を返し、見終えた / 作ったものを控える。
  (MockClient, List<String> seen, List<Map<String, Object?>> created, List<String> uploads) central(List<Map<String, Object?>> feed) {
    final seen = <String>[];
    final created = <Map<String, Object?>>[];
    final uploads = <String>[];
    http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final route = '${req.method} $path';
      if (route == 'GET /me') return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
      // D-379: 見終えたものも期限までは返す(all=true)。
      if (route == 'GET /swings/feed') return json([for (final s in feed) {...s, 'seen': seen.contains(s['id'])}]);
      if (route == 'GET /me/swings') return json(const []);
      if (route == 'GET /me/rasq-collections') {
        return json([
          {'id': 'rl1', 'kind': 'list', 'name': '友だち', 'owner': {'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'}, 'visibility': 'private', 'itemCount': 1},
        ]);
      }
      if (route == 'POST /swings/media') {
        uploads.add(req.headers['content-type'] ?? '');
        return json({'id': 'm1', 'url': 'https://central.test/api/v1/swings/media/m1?exp=1&sig=x', 'contentType': req.headers['content-type'], 'sizeBytes': req.bodyBytes.length}, 201);
      }
      if (route == 'POST /swings') {
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        created.add(body);
        return json({...swing('new', 'acc-1', kind: body['kind'] as String, text: '${body['text'] ?? ''}'), 'audience': body['audience'], 'viewCount': 0}, 201);
      }
      final m = RegExp(r'^POST /swings/([^/]+)/seen$').firstMatch(route);
      if (m != null) {
        seen.add(m.group(1)!);
        return http.Response('', 204);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    return (mock, seen, created, uploads);
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester, MockClient mock, {List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SwingFeed.interval = null;
    addTearDown(() => SwingFeed.interval = const Duration(seconds: 60));
    // 時間では進ませない(時間で進むテストだけ入れる)。
    SwingViewerScreen.displayDuration = null;
    addTearDown(() => SwingViewerScreen.displayDuration = const Duration(seconds: 6));
    final store = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(store),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ...extra,
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.runAsync(() => c.read(swingFeedProvider.future));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('ヘッダー: Swing は 1 人だけ、青いリング → ビューワー。左右のスワイプで次へ(見終えたものは Central へ)、閉じると最後のも。見終えた人は白いリング', (tester) async {
    final (mock, seen, _, _) = central([
      swing('a1', 'alice', text: 'アリスの 1 つめ', age: const Duration(minutes: 40)),
      swing('a2', 'alice', text: 'アリスの 2 つめ', age: const Duration(minutes: 10)),
      swing('b1', 'bob', text: 'ボブの', age: const Duration(minutes: 20)),
    ]);
    final c = await pumpApp(tester, mock);
    expect(find.byKey(const ValueKey('swing.create')), findsNothing, reason: '作るのは ＋ の FOW から');
    expect(find.byKey(const ValueKey('swing.bundle.alice')), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.bundle.bob')), findsNothing, reason: '1 人だけ');
    expect(find.descendant(of: find.byKey(const ValueKey('swing.bundle.alice')), matching: find.byKey(const ValueKey('swing.ring.unseen'))), findsOneWidget, reason: '見ていない = 青');

    await tester.tap(find.byKey(const ValueKey('swing.bundle.alice')));
    await tester.pumpAndSettle();
    expect(find.byType(SwingViewerScreen), findsOneWidget);
    expect(find.text('アリスの 1 つめ'), findsOneWidget);
    expect(find.textContaining('あと 4 時間'), findsOneWidget);

    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('アリスの 2 つめ'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen, ['a1']);

    await tester.tap(find.byKey(const ValueKey('swing.close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen, ['a1', 'a2']);
    expect(find.byType(SwingViewerScreen), findsNothing);
    // 見終えたものはヘッダーから消える(アリスはもう無い)。
    expect(find.byKey(const ValueKey('swing.bundle.alice')), findsNothing);
    expect(find.byKey(const ValueKey('swing.bundle.bob')), findsOneWidget, reason: '見ていない人が先');
    expect(c.read(swingFeedProvider).value!.where((s) => s.seen).map((s) => s.id), unorderedEquals(['a1', 'a2']), reason: '見終えたものも期限までは残る');
    // bob も見終える → 見ていない人がいなくなると、いちばん新しい人(alice)が白いリングで出る。
    await tester.tap(find.byKey(const ValueKey('swing.bundle.bob')));
    await tester.pumpAndSettle();
    expect(find.text('ボブの'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swing.close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(find.descendant(of: find.byKey(const ValueKey('swing.bundle.alice')), matching: find.byKey(const ValueKey('swing.ring.seen'))), findsOneWidget, reason: '見終えた = 白');
    // 白いリングからもう一度見られる。
    await tester.tap(find.byKey(const ValueKey('swing.bundle.alice')));
    await tester.pumpAndSettle();
    expect(find.text('アリスの 1 つめ'), findsOneWidget);
  });

  testWidgets('広告: 広告を出せる端末では Swing 5 個ごとに 1 枚(見終えの記録は無し)', (tester) async {
    final (mock, seen, _, _) = central([for (var i = 0; i < 6; i++) swing('s$i', 'u$i', text: 'Swing $i', age: Duration(minutes: 60 - i))]);
    final c = await pumpApp(tester, mock, extra: [
      exportAdNetworkProvider.overrideWithValue(ExportAdNetwork.admob),
      exportAdAllowedProvider.overrideWithValue(true),
      exportAdSdkProvider.overrideWithValue(_FakeAdSdk()),
    ]);
    c.read(routerProvider).push(Routes.swing());
    await tester.pumpAndSettle();
    expect(find.text('Swing 5'), findsOneWidget, reason: 'いちばん新しい人から');
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('fake.ad')), findsOneWidget);
    expect(find.text('広告'), findsOneWidget);
    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Swing 0'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen, ['s5', 's4', 's3', 's2', 's1'], reason: '広告のページは記録しない');
  });

  testWidgets('プラグインの Swing: 全画面の間はスワイプで移れない → 「全画面から縮小」でぼかして止め(paused)、移れる / page.end で次へ', (tester) async {
    final (mock, seen, _, _) = central([
      swing('p1', 'alice', kind: 'plugin', text: '', plugin: {'id': 'sample.swing-game', 'version': '1.0.0', 'data': {'level': 3}}, age: const Duration(minutes: 30)),
      swing('p2', 'alice', kind: 'plugin', text: '', plugin: {'id': 'sample.swing-game', 'version': '1.0.0', 'data': {'level': 4}}, age: const Duration(minutes: 20)),
      swing('t1', 'alice', text: 'さいご', age: const Duration(minutes: 10)),
    ]);
    final events = <String>[];
    final opened = <Map<String, Object?>>[];
    FakeSlotRuntime game() => FakeSlotRuntime(
          manifest: const {
            'id': 'sample.swing-game',
            'name': 'ゲーム',
            'version': '1.0.0',
            'kind': 'view',
            'slots': ['page'],
            'permissions': ['render'],
            'page': {'title': 'ゲーム', 'mode': 'solo', 'surfaces': ['swing']},
          },
          handler: (rt, fn, args) {
            switch (fn) {
              case 'page.open':
                opened.add(args);
                final level = ((args['context'] as Map)['data'] as Map)['level'];
                return {
                  'root': {
                    't': 'Column',
                    'k': 'root',
                    'c': [
                      {'t': 'Text', 'k': 'lv', 'p': {'text': 'レベル $level'}},
                      {'t': 'Button', 'k': 'done', 'p': {'label': 'おわる'}, 'on': {'tap': 'done'}},
                    ],
                  },
                };
              case 'done':
                rt.hostFn('page.end', {'token': args['token']});
                return {};
              case 'page.event':
                events.add('${args['type']}');
                return {};
              case 'page.close':
                events.add('close');
                return {};
            }
            return {};
          },
        );
    final c = await pumpApp(tester, mock, extra: [slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({'store:sample.swing-game@1.0.0': game}))]);
    await tester.runAsync(() => c.read(slotPluginsProvider.notifier).register('store:sample.swing-game@1.0.0', bytes: Uint8List.fromList(utf8.encode('game')), persist: false));
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.swing('alice'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('レベル 3'), findsOneWidget);
    expect(opened.single['surface'], 'swing');
    expect((opened.single['context'] as Map)['swingId'], 'p1');
    expect(((opened.single['context'] as Map)['author'] as Map)['accountId'], 'alice');

    // 全画面の間はスワイプで移れない。
    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('レベル 3'), findsOneWidget);
    expect(seen, isEmpty);

    // 縮小 → ぼかして止める → スワイプで次へ。
    await tester.tap(find.byKey(const ValueKey('swing.plugin.shrink')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.plugin.shrunk')), findsOneWidget);
    expect(events, contains('paused'));
    // 押すと全画面に戻る → もう一度縮小。
    await tester.tap(find.byKey(const ValueKey('swing.plugin.shrunk')));
    await tester.pumpAndSettle();
    expect(events, contains('resumed'));
    expect(find.byKey(const ValueKey('swing.plugin.shrink')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swing.plugin.shrink')));
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('レベル 4'), findsOneWidget);
    expect(events, contains('close'), reason: '離れたページは閉じる');
    // 2 つめも全画面の間は移れない。
    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('レベル 4'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen, ['p1']);

    // プラグインが page.end → 見終えて次へ。
    await tester.tap(find.text('おわる'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('さいご'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen, ['p1', 'p2']);
  });

  testWidgets('プラグインが入っていなければストアへ案内し、スワイプで移れる', (tester) async {
    final (mock, _, _, _) = central([
      swing('p1', 'alice', kind: 'plugin', text: '', plugin: {'id': 'sample.not-installed'}, age: const Duration(minutes: 30)),
      swing('t1', 'alice', text: 'つぎ', age: const Duration(minutes: 10)),
    ]);
    final c = await pumpApp(tester, mock);
    c.read(routerProvider).push(Routes.swing());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.plugin.needsInstall')), findsOneWidget);
    await tester.fling(find.byKey(const ValueKey('swing.viewer.pages')), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('つぎ'), findsOneWidget);
  });

  testWidgets('時間で次へ (D-379): テキスト / 画像は決まった時間で進む。中央のタップで一時停止 / 再開、左端 / 右端のタップで前 / 次', (tester) async {
    final (mock, seen, _, _) = central([
      swing('t1', 'alice', text: 'いち', age: const Duration(minutes: 30)),
      swing('t2', 'alice', text: 'に', age: const Duration(minutes: 20)),
      swing('t3', 'alice', text: 'さん', age: const Duration(minutes: 10)),
    ]);
    final c = await pumpApp(tester, mock);
    SwingViewerScreen.displayDuration = const Duration(seconds: 3);
    c.read(routerProvider).push(Routes.swing('alice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('いち'), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.progress')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('に'), findsOneWidget, reason: '3 秒で次へ');
    // 中央をタップ → 止まる(時間がたっても進まない)→ もう一度で再開。
    final size = tester.getSize(find.byKey(const ValueKey('swing.viewer.pages')));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('swing.paused')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('に'), findsOneWidget);
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('swing.paused')), findsNothing);
    // 左端 = 前、右端 = 次。
    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('いち'), findsOneWidget);
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('さん'), findsOneWidget);
    SwingViewerScreen.displayDuration = null;
    await tester.tap(find.byKey(const ValueKey('swing.close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(seen.toSet(), {'t1', 't2', 't3'});
  });

  testWidgets('未審査のプラグイン (D-379): 同意してから、入れ物を制限モード(通信なし、GPU は可)で動かす。子プラグインの入れ物は断る', (tester) async {
    final (mock, _, _, _) = central([
      swing('u1', 'alice', kind: 'plugin', text: '', plugin: {'id': 'my.game', 'version': '0.1.0', 'packageUrl': 'https://central.test/api/v1/swings/media/pk1?exp=1&sig=x', 'unreviewed': true}),
    ]);
    final wasm = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
    final loaded = <({String source, Set<String> permissions, bool gpu, Set<String> hosts})>[];
    FakeSlotRuntime game() => FakeSlotRuntime(
          manifest: const {
            'id': 'my.game',
            'name': 'ゲーム',
            'version': '0.1.0',
            'kind': 'view',
            'slots': ['page'],
            'permissions': ['render', 'network', 'gpu_ml'],
            'network': {'hosts': ['example.com']},
            'page': {'title': 'ゲーム', 'mode': 'solo', 'surfaces': ['swing']},
          },
          handler: (rt, fn, args) => fn == 'page.open' ? {'root': {'t': 'Text', 'k': 'hi', 'p': {'text': '未審査のゲーム'}}} : {},
        );
    final c = await pumpApp(tester, mock, extra: [
      swingPackageFetcherProvider.overrideWithValue((url) async => wasm),
      slotRuntimeLoaderProvider.overrideWithValue((Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        loaded.add((source: source, permissions: permissions, gpu: gpuCompute, hosts: fetchHosts));
        return game();
      }),
    ]);
    c.read(routerProvider).push(Routes.swing());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('swing.plugin.consent')), findsOneWidget);
    expect(loaded, isEmpty, reason: '同意するまで動かさない');
    await tester.tap(find.byKey(const ValueKey('swing.plugin.run')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('未審査のゲーム'), findsOneWidget);
    final run = loaded.last;
    expect(run.source, 'swing:u1');
    expect(run.permissions.contains('network'), isFalse, reason: '通信は閉じる');
    expect(run.hosts, isEmpty);
    expect(run.gpu, isTrue, reason: 'GPU は使える');

    // 入れ物の決まり: 素の wasm は 1 つ、wasm でも rasqpkg でもないものは断る。
    expect(() => checkSwingPackage(wasm, decompress: (b, {int maxOutput = 0}) => b), returnsNormally);
    expect(() => checkSwingPackage(Uint8List.fromList([1, 2, 3]), decompress: (b, {int maxOutput = 0}) => b), throwsStateError);
  });

  testWidgets('作る (D-380): ＋ → Swing → 画像 = 選んだ絵をそのまま編集画面へ → 送る画面(届け先と時間)。背景とテキスト = 無地の背景を編集画面へ。届け先が無ければ出せない', (tester) async {
    final (mock, _, created, uploads) = central(const []);
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    final edited = Uint8List.fromList([...png, 0]);
    final opened = <String>[];
    await pumpApp(tester, mock, extra: [
      swingMediaPickerProvider.overrideWithValue(({required bool video}) async => XFile.fromData(png, name: 'photo.png', path: 'photo.png', mimeType: 'image/png')),
      swingBackgroundProvider.overrideWithValue(() async => png),
      swingEditorProvider.overrideWithValue((context, {required bytes, required name, required mime}) async {
        opened.add('$name ${bytes.length}');
        return MediaEditResult(bytes: edited, mimeType: 'image/png', name: 'edited.png');
      }),
    ]);
    // ＋ → 作るものを選ぶ FOW → Swing → 2 段目(画像 / 動画 / プラグイン / 背景とテキスト)。
    await tester.tap(find.byTooltip('作成'));
    await tester.pumpAndSettle();
    for (final k in ['post', 'rasq', 'astell', 'swing']) {
      expect(find.byKey(ValueKey('create.$k')), findsOneWidget, reason: k);
    }
    await tester.tap(find.byKey(const ValueKey('create.swing')));
    await tester.pumpAndSettle();
    for (final s in SwingStart.values) {
      expect(find.byKey(ValueKey('swing.start.${s.name}')), findsOneWidget, reason: s.name);
    }
    await tester.tap(find.byKey(const ValueKey('swing.start.image')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(opened, ['photo.png ${png.length}'], reason: '選んだ絵をそのまま編集画面へ');
    expect(find.byType(SwingComposerScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.text')), findsNothing, reason: '文字だけの Swing は無い');
    await tester.tap(find.byKey(const ValueKey('swing.audience.list.rl1')));
    await tester.tap(find.byKey(const ValueKey('swing.ttl.6')));
    await tester.pump();
    // フォロワーを外してリストも外すと出せない。
    await tester.tap(find.byKey(const ValueKey('swing.audience.followers')));
    await tester.tap(find.byKey(const ValueKey('swing.audience.list.rl1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('swing.audience.empty')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('swing.send'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('swing.audience.followers')));
    await tester.tap(find.byKey(const ValueKey('swing.audience.list.rl1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('swing.send')));
    await tester.tap(find.byKey(const ValueKey('swing.send')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(uploads, ['image/png']);
    expect(created.single, {'kind': 'image', 'mediaId': 'm1', 'audience': {'followers': true, 'lists': ['rl1']}, 'ttlHours': 6});
    expect(find.byType(SwingComposerScreen), findsNothing);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
    await tester.pumpAndSettle();

    // 背景とテキスト: 無地の背景を編集画面へ(文字は編集画面で書く)→ 画像の Swing。
    await tester.tap(find.byTooltip('作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.swing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swing.start.background')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(opened.last, 'swing.png ${png.length}');
    await tester.ensureVisible(find.byKey(const ValueKey('swing.send')));
    await tester.tap(find.byKey(const ValueKey('swing.send')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(created.last['kind'], 'image');
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
    await tester.pumpAndSettle();

    // プラグイン: 送る画面で選ぶ。
    await tester.tap(find.byTooltip('作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.swing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swing.start.plugin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.plugin.file')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('swing.send'))).onPressed, isNull, reason: 'プラグインを選ぶまで出せない');
  });

  testWidgets('ヘッダーをしまう(↑)→ バーとタブ行が消え、アイコンと ↓ だけ浮かぶ。新着の Swing は 1 分だけ → ↓ で戻る', (tester) async {
    var clock = DateTime.now();
    HeaderArrivals.now = () => clock;
    addTearDown(() => HeaderArrivals.now = DateTime.now);
    final feed = [swing('old', 'bob', text: '前から', age: const Duration(minutes: 30))];
    final (mock, _, _, _) = central(feed);
    final c = await pumpApp(tester, mock);
    expect(find.byKey(const ValueKey('home.header.collapse')), findsOneWidget);
    expect(find.byTooltip('タイムライン設定'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home.header.collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.header.floating')), findsOneWidget);
    expect(find.byTooltip('タイムライン設定'), findsNothing, reason: 'タブ行もしまう');
    expect(find.byKey(const ValueKey('home.header.arrivals')), findsNothing, reason: '前からあったものは新着ではない');

    // 新しい Swing が届く → 1 分だけ浮かべる。
    feed.add(swing('new', 'carol', text: '届いた', age: const Duration(seconds: 5)));
    // (タイマーを偽の時間で進めたいので、runAsync の外で読み直す。MockClient は本物の I/O をしない。)
    unawaited(c.read(swingFeedProvider.notifier).refresh());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const ValueKey('home.header.arrival.swing:carol')), findsOneWidget);
    clock = clock.add(HeaderArrivals.window + const Duration(seconds: 1));
    await tester.pump(HeaderArrivals.window + const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('home.header.arrival.swing:carol')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home.header.expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.header.floating')), findsNothing);
    expect(find.byKey(const ValueKey('home.header.collapse')), findsOneWidget);
    expect(find.byTooltip('タイムライン設定'), findsOneWidget);
  });
}

class _FakeAdSdk implements ExportAdSdk {
  @override
  Widget buildAd({required ExportAdNetwork network, required ExportAdConfig config, required double width, required VoidCallback onLoaded, required VoidCallback onFailed}) {
    Future.microtask(onLoaded);
    return SizedBox(key: const ValueKey('fake.ad'), width: width, height: 250, child: const ColoredBox(color: Colors.grey));
  }
}
