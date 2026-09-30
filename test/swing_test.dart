import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import 'package:rasq_client/features/vc/astell_fows.dart' show astellCreateFowId;
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart' show composerFowId;
import 'package:rasq_client/features/home/create_fow.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart' show MediaEditResult;
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart' show ProEditorExtraAction, ProEditorHandle;
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/swing/swing_composer.dart';
import 'package:rasq_client/features/swing/swing_models.dart';
import 'package:rasq_client/features/swing/swing_providers.dart';
import 'package:rasq_client/features/swing/swing_viewer.dart';
import 'package:rasq_client/features/swing/wagara.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart' show RasqActionCircle;
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// Swing (D-377 / Central S-056)。
/// いまの割り当て(テスト用: WidgetRef なしで読む)。
({String tap, List<String> slots}) fabAssignmentOf(ProviderContainer c, String scope) {
  final m = c.read(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
  final raw = m['${scope}Slots'];
  return (tap: '${m['${scope}Tap'] ?? 'post'}', slots: raw is List ? [for (final x in raw) '$x'] : const ['swing', 'astell', 'rasq']);
}

Future<void> setFabSlotsOf(ProviderContainer c, String scope, List<String> slots) => c.read(settingsAreaProvider(fabSettingsArea).notifier).set('${scope}Slots', slots);

void main() {
  test('＋ の枠 (D-385): 置いた数で並びが変わる(内側 3 + 外側 4)、スライドの距離で輪を選ぶ、保存は詰めて 7 つまで', () {
    Offset p(int n, int i) => fabSlotPositions(n)[i];
    expect(fabSlotPositions(1).length, 1);
    expect(p(1, 0).dx, closeTo(0, 0.01), reason: '1 つなら上');
    expect(p(2, 1).dy, closeTo(0, 0.01), reason: '2 つ目は左');
    expect(fabSlotPositions(3).every((o) => (o.distance - fabInnerRadius).abs() < 0.01), isTrue);
    expect(fabSlotPositions(4)[3].distance, closeTo(fabOuterRadius, 0.01), reason: '4 つ目から外側');
    expect(fabSlotPositions(7).length, 7);
    expect(fabSlotPositions(9).length, 7);
    // 外側が 4 つなら上から 90 / 60 / 30 / 0°。
    expect(p(7, 3).dx, closeTo(0, 0.01));
    expect(p(7, 6).dy, closeTo(0, 0.01));
    expect(fabSlotFor(const Offset(0, -80), 3), 0);
    expect(fabSlotFor(const Offset(-80, 0), 3), 1);
    expect(fabSlotFor(const Offset(-60, -60), 3), 2);
    expect(fabSlotFor(const Offset(-20, -20), 3), isNull, reason: '動かし足りない');
    expect(fabSlotFor(const Offset(80, 0), 3), isNull, reason: '右へ');
    expect(fabSlotFor(const Offset(0, -170), 3), 0, reason: '外側が無ければ遠くても内側');
    expect(fabSlotFor(const Offset(0, -170), 7), 3);
    expect(fabSlotFor(const Offset(-170, 0), 7), 6);
    expect(fabSlotFor(const Offset(-80, -140), 7), 4, reason: '60°');
    expect(fabSlotFor(const Offset(0, -80), 7), 0, reason: '近ければ内側');
    expect(normalizeFabSlots(['none', 'astell', 'post', 'astell', 'none']), ['astell', 'post'], reason: 'D-383 の保存(空き付き)も読める');
    expect(normalizeFabSlots([for (var i = 0; i < 9; i++) 'a$i']).length, fabMaxSlots);
  });

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

  testWidgets('Swing の背景 (D-386): 和柄 2 つの縦長の PNG', (tester) async {
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

  /// [fakeSwingEditor] = Swing の編集画面を開いたままにする(＋ から Swing を開くテストで、本物の編集画面を出さない)。
  Future<ProviderContainer> pumpApp(WidgetTester tester, MockClient mock, {List<Override> extra = const [], bool fakeSwingEditor = true}) async {
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
        if (fakeSwingEditor) ...[
          swingBackgroundProvider.overrideWithValue(() async => Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47])),
          swingEditorProvider.overrideWithValue((context, {required bytes, required name, required mime, actions = const []}) => Completer<MediaEditResult?>().future),
        ],
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

  testWidgets('作る (D-386): ＋ を上へスワイプ → すぐ和柄の背景で編集画面(バーの先頭に「プラグイン」「背景を変える」)→ 送る画面(届け先と時間)。閉じたら戻る。プラグインは送る画面で選ぶ', (tester) async {
    final (mock, _, created, uploads) = central(const []);
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    final edited = Uint8List.fromList([...png, 0]);
    final opened = <String>[];
    var bars = <List<String>>[];
    var cancel = false;
    final c = await pumpApp(tester, mock, fakeSwingEditor: false, extra: [
      swingBackgroundProvider.overrideWithValue(() async => png),
      swingEditorProvider.overrideWithValue((context, {required bytes, required name, required mime, actions = const []}) async {
        opened.add('$name ${bytes.length}');
        bars = [...bars, [for (final a in actions) '${a.id}:${a.label}']];
        return cancel ? null : MediaEditResult(bytes: edited, mimeType: 'image/png', name: 'edited.png');
      }),
    ]);
    // ＋ を上へスワイプ (D-381) → 始め方の一覧は無く、すぐ背景つきの編集画面。
    await tester.drag(find.byKey(const ValueKey('fab.home.gesture')), const Offset(0, -160));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.start.image')), findsNothing);
    expect(opened, ['swing.png ${png.length}'], reason: '和柄の背景をそのまま編集画面へ');
    expect(bars.single, ['swing.plugin:プラグイン', 'swing.background:背景を変える'], reason: 'バーの先頭に自動で足す');
    expect(find.byType(SwingComposerScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.preview')), findsOneWidget);
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

    // 編集画面を閉じたら、何も出さずに戻る。
    cancel = true;
    await tester.drag(find.byKey(const ValueKey('fab.home.gesture')), const Offset(0, -160));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(opened.length, 2);
    expect(find.byType(SwingComposerScreen), findsNothing);
    expect(created.length, 1);

    // プラグイン(編集画面の「プラグイン」から): 送る画面で選ぶ。
    c.read(routerProvider).push(Routes.swingNew, extra: const SwingDraft.plugin());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.plugin.file')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('swing.send'))).onPressed, isNull, reason: 'プラグインを選ぶまで出せない');
  });

  testWidgets('背景を変える (D-387): 押すと別の和柄(画像のまま差し替え)、長押しで画像 / 動画を選ぶ(動画は編集画面を開き直す、動画から和柄も開き直す)', (tester) async {
    final (mock, _, created, _) = central(const []);
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    final opened = <String>[];
    var backgrounds = 0;
    late BuildContext editorContext;
    Completer<MediaEditResult?>? current;
    await pumpApp(tester, mock, fakeSwingEditor: false, extra: [
      swingBackgroundProvider.overrideWithValue(() async {
        backgrounds++;
        return png;
      }),
      swingMediaPickerProvider.overrideWithValue(({required bool video}) async => video ? XFile.fromData(video_(), name: 'clip.mp4', path: 'clip.mp4', mimeType: 'video/mp4') : XFile.fromData(png, name: 'photo.png', path: 'photo.png', mimeType: 'image/png')),
      swingEditorProvider.overrideWithValue((context, {required bytes, required name, required mime, actions = const []}) {
        opened.add('$name $mime');
        editorContext = context;
        _actions = actions;
        return (current = Completer<MediaEditResult?>()).future;
      }),
    ]);
    ProEditorExtraAction act(String id) => _actions.firstWhere((a) => a.id == id);
    await tester.drag(find.byKey(const ValueKey('fab.home.gesture')), const Offset(0, -160));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(opened, ['swing.png image/png']);
    // 押す: 画像のまま、別の和柄に差し替え(開き直さない)。
    final h = _FakeHandle(editorContext, video: false, onClose: () => current!.complete(null));
    await tester.runAsync(() async => act(swingBackgroundActionId).onTap(h));
    expect(h.backgrounds.length, 1);
    expect(backgrounds, 2);
    expect(opened.length, 1);
    // 長押し → 画像: 差し替え。
    act(swingBackgroundActionId).onLongPress!(h);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(swingPickImageKey));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backgrounds.length, 2);
    expect(h.closed, isFalse);
    // 長押し → 動画: 動画で開き直す。
    act(swingBackgroundActionId).onLongPress!(h);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(swingPickVideoKey));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.closed, isTrue);
    expect(opened, ['swing.png image/png', 'clip.mp4 video/mp4']);
    // 動画のときに押す: 和柄で開き直す。
    final hv = _FakeHandle(editorContext, video: true, onClose: () => current!.complete(null));
    await tester.runAsync(() async => act(swingBackgroundActionId).onTap(hv));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(hv.backgrounds, isEmpty);
    expect(opened.last, 'swing.png image/png');
    // 仕上げ → 送る画面。
    current!.complete(MediaEditResult(bytes: png, mimeType: 'image/png', name: 'edited.png'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.preview')), findsOneWidget);
    expect(created, isEmpty);
  });

  test('和柄 (D-386): 19 種すべて描け、2 つは別の柄、乱数の種が同じなら同じ', () async {
    expect(Wagara.values.length, 19);
    expect(swingWagara.map((w) => w.label), ['七宝', '檜垣', '石畳', '立涌', '亀甲', '鱗', '菱', '松皮菱', '分銅繋ぎ'], reason: 'D-387 で背景に使う柄');
    expect(complementOf(const Color(0xFFFF0000)), const Color(0xFF00FFFF));
    // 配色: 明るい側は彩度 20% まで、2 枚目は類似色(±20〜40°)で濃淡が逆。
    for (var i = 0; i < 50; i++) {
      final (a, b) = pickWagaraColors(math.Random(i));
      HSVColor hsv(Color c) => HSVColor.fromColor(c);
      Color lighter(WagaraColors x) => hsv(x.ground).value > hsv(x.pattern).value ? x.ground : x.pattern;
      for (final x in [a, b]) {
        expect(hsv(lighter(x)).saturation, lessThanOrEqualTo(swingPaleMaxSaturation + 0.01));
        final d = (hsv(x.ground).hue - hsv(x.pattern).hue).abs();
        expect((d - 180).abs(), lessThan(6), reason: '補色(淡い色は 8 bit で色相が少しずれる)');
      }
      expect(lighter(a) == a.ground, lighter(b) != b.ground, reason: '濃淡が逆');
      final strongA = lighter(a) == a.ground ? a.pattern : a.ground;
      final strongB = lighter(b) == b.ground ? b.pattern : b.ground;
      final dh = ((hsv(strongA).hue - hsv(strongB).hue).abs() + 360) % 360;
      expect(math.min(dh, 360 - dh), inInclusiveRange(19, 41), reason: '類似色');
    }
    expect(Wagara.values.map((w) => w.label), isNot(contains('千鳥')));
    for (var i = 0; i < 40; i++) {
      final spec = SwingBackgroundSpec.random(math.Random(i));
      expect(spec.first, isNot(spec.second));
    }
    expect(SwingBackgroundSpec.random(math.Random(3)).label, SwingBackgroundSpec.random(math.Random(3)).label);
    for (final w in Wagara.values) {
      for (final mask in [false, true]) {
        final rec = ui.PictureRecorder();
        paintWagara(Canvas(rec), const Size(200, 300), w, color: const Color(0xFF123456), ground: const Color(0xFFFFFFFF), unit: 50, mask: mask);
        rec.endRecording().dispose();
      }
    }
  });

  test('Swing の検索 (D-386): 名前 / @ハンドル / 文字 / 種類。語は全部を満たすもの、作った人ごと', () {
    final feed = [
      Swing.tryParse(swing('a1', 'alice', text: '花火を見に来た'))!,
      Swing.tryParse(swing('a2', 'alice', text: 'かき氷', age: const Duration(minutes: 5)))!,
      Swing.tryParse(swing('b1', 'bob', text: '花火大会'))!,
    ];
    expect(searchSwingAuthors(feed, '花火').map((e) => e.first.authorAccountId), unorderedEquals(['alice', 'bob']));
    expect(searchSwingAuthors(feed, '花火 @bob').single.first.id, 'b1', reason: '語を重ねる');
    expect(searchSwingAuthors(feed, 'alice').single.total, 2);
    expect(searchSwingAuthors(feed, 'テキスト').length, 2, reason: '種類');
    expect(searchSwingAuthors(feed, 'ない言葉'), isEmpty);
  });

  testWidgets('AsTell の検索に Swing (D-386): 角丸バナー(アイコン + 名前)が先、押すとその人のビューワー。節のチップ「Swing」で Swing だけ', (tester) async {
    final (mock, _, _, _) = central([swing('s1', 'alice', text: '花火を見に来た'), swing('s2', 'bob', text: 'ランチ')]);
    final c = await pumpApp(tester, mock);
    c.read(routerProvider).go(Routes.vc);
    await tester.pumpAndSettle();
    final box = find.byKey(const ValueKey('astell.search'));
    await tester.enterText(find.descendant(of: box, matching: find.byType(TextField)), '花火');
    await tester.pumpAndSettle();
    final banner = find.byKey(const ValueKey('swing.banner.alice'));
    expect(banner, findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text('alice さん')), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.byKey(const ValueKey('swing.ring.unseen'))), findsOneWidget);
    expect(find.byKey(const ValueKey('swing.banner.bob')), findsNothing);
    // 節: Swing だけ(語なし)→ 2 人。
    await tester.enterText(find.descendant(of: box, matching: find.byType(TextField)), '');
    await tester.tap(find.descendant(of: box, matching: find.text('Swing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.banner.bob')), findsOneWidget);
    expect(find.byKey(const ValueKey('astell.search.rooms')), findsNothing, reason: 'Swing だけ');
    await tester.tap(find.byKey(const ValueKey('swing.banner.bob')));
    await tester.pumpAndSettle();
    expect(find.byType(SwingViewerScreen), findsOneWidget);
  });

  testWidgets('＋ (D-383): タップ = 投稿。スライドの向き(上 / 左 / 左上)で始める。素早く払っても長押しにならない。長押し / ホバーで暗くして丸ボタンを展開、歯車で並べ替え(ドラッグで入れる / 外す)。トレンドはハッシュタグ、AsTell の ＋', (tester) async {
    final (mock, _, _, _) = central(const []);
    final c = await pumpApp(tester, mock);
    final fab = find.byKey(const ValueKey('fab.home.gesture'));
    // タップ = 投稿(コンポーザー)。
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(composerFowId), isTrue);
    c.read(overlayManagerProvider).close(composerFowId);
    await tester.pumpAndSettle();
    // スライドを始めると 3 つの丸ボタンが出る(向かっている方が強く)。少しだけで離すと何もしない。
    var g = await tester.startGesture(tester.getCenter(fab));
    await g.moveBy(const Offset(0, -20));
    await g.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('fab.home.action.$i')), findsOneWidget, reason: '$i');
    }
    expect(find.byKey(const ValueKey('fab.home.action.3')), findsNothing, reason: '3 つなら外側の輪は無い');
    expect(find.descendant(of: find.byKey(const ValueKey('fab.home.action.0')), matching: find.text('Swing')), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(SwingComposerScreen), findsNothing, reason: '十分動かさなければ何もしない');
    expect(c.read(overlayManagerProvider).contains(composerFowId), isFalse, reason: '動かしたあとの離すは押したことにしない');
    // 左へ = AsTell を作る(既定)。
    g = await tester.startGesture(tester.getCenter(fab));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(tester.widget<RasqActionCircle>(find.byKey(const ValueKey('fab.home.action.1'))).selected, isTrue);
    await g.up();
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(astellCreateFowId), isTrue, reason: '左 = AsTell');
    c.read(overlayManagerProvider).close(astellCreateFowId);
    await tester.pumpAndSettle();
    // 左上へ = RASQ に投稿(既定)。
    g = await tester.startGesture(tester.getCenter(fab));
    await g.moveBy(const Offset(-15, -15));
    await g.moveBy(const Offset(-60, -60));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget, reason: '左上 = RASQ に投稿');
    c.read(overlayManagerProvider).close(composerFowId);
    await tester.pumpAndSettle();
    // 素早く上へ払う → 長押しにならず、Swing の作成ページへ。
    await tester.fling(fab, const Offset(0, -160), 3000);
    // 作成ページは開くとすぐ編集画面を待つ(読み込みの表示が回り続けるので settle しない)。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('fab.home.settings')), findsNothing, reason: '展開(長押し)にならない');
    expect(find.byType(SwingComposerScreen), findsOneWidget);
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    // 長押し = 暗くして展開、＋ は歯車に。背景を押すと閉じる。
    await tester.longPress(fab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab.home.scrim')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('fab.home.settings')), matching: find.byIcon(Icons.settings)), findsOneWidget);
    expect(c.read(overlayManagerProvider).contains(composerFowId), isFalse, reason: '長押しのあとの離すは押したことにしない');
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab.home.settings')), findsNothing);
    // 長押し → 丸ボタンを押す。
    await tester.longPress(fab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fab.home.action.1')));
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(astellCreateFowId), isTrue);
    c.read(overlayManagerProvider).close(astellCreateFowId);
    await tester.pumpAndSettle();
    // ホバー(マウス)でも展開、離れると閉じる。
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(fab));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab.home.action.0')), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab.home.settings')), findsNothing);
    await mouse.removePointer();
    // 歯車 → 並べ替えの FOW: 下の列から枠へ入れる / 枠から列へ外す。
    await tester.longPress(fab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fab.home.settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab.editor.close')), findsOneWidget);
    expect(find.byKey(const ValueKey('fab.editor.palette.post')), findsOneWidget);
    expect(find.byKey(ValueKey('fab.editor.palette.post:${fakeSession().account.key}')), findsOneWidget, reason: 'アカウントごとの投稿');
    Future<void> dragTo(Finder from, Finder to) async {
      final gg = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 50));
      await gg.moveBy(const Offset(0, -10));
      await tester.pump();
      await gg.moveTo(tester.getCenter(to));
      await tester.pump();
      await gg.up();
      await tester.pumpAndSettle();
    }

    await dragTo(find.byKey(const ValueKey('fab.editor.palette.post')), find.byKey(const ValueKey('fab.editor.slot.2')));
    expect(fabAssignmentOf(c, 'home').slots, ['swing', 'astell', 'post']);
    // 空き枠(4 つ目 = 外側の輪)へ足す。
    await dragTo(find.byKey(const ValueKey('fab.editor.palette.rasq')), find.byKey(const ValueKey('fab.editor.slot.add')));
    expect(fabAssignmentOf(c, 'home').slots, ['swing', 'astell', 'post', 'rasq']);
    expect(find.byKey(const ValueKey('fab.editor.slot.3')), findsOneWidget);
    // 枠どうしで入れ替える。
    await dragTo(find.byKey(const ValueKey('fab.editor.slot.3')), find.byKey(const ValueKey('fab.editor.slot.0')));
    expect(fabAssignmentOf(c, 'home').slots, ['rasq', 'astell', 'post', 'swing']);
    // 列へ戻すと外れて詰まる。
    await dragTo(find.byKey(const ValueKey('fab.editor.slot.0')), find.byKey(const ValueKey('fab.editor.palette')));
    expect(fabAssignmentOf(c, 'home').slots, ['astell', 'post', 'swing']);
    await tester.tap(find.byKey(const ValueKey('fab.editor.close')));
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(fabEditorFowId), isFalse);
    // 5 つ置く → 外側の輪に 2 つ。遠くまで動かすと外側、近くなら内側。
    await setFabSlotsOf(c, 'home', ['swing', 'astell', 'rasq', 'post', 'post:${fakeSession().account.key}']);
    await tester.pumpAndSettle();
    g = await tester.startGesture(tester.getCenter(fab));
    await g.moveBy(const Offset(-20, -5));
    await g.moveBy(const Offset(-140, -52));
    await tester.pump();
    expect(find.byKey(const ValueKey('fab.home.action.4')), findsOneWidget);
    expect(tester.widget<RasqActionCircle>(find.byKey(const ValueKey('fab.home.action.4'))).selected, isTrue, reason: '外側の左寄り');
    await g.up();
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(composerFowId), isTrue, reason: 'アカウントの投稿');
    c.read(overlayManagerProvider).close(composerFowId);
    await tester.pumpAndSettle();
    // 設定で タップ = RASQ に投稿 に。
    await c.read(settingsAreaProvider(fabSettingsArea).notifier).set('homeTap', 'rasq');
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget, reason: 'RASQ に投稿で開く');
    c.read(overlayManagerProvider).close(composerFowId);
    await tester.pumpAndSettle();

    // トレンドの ＋: 投稿はハッシュタグ入り。
    c.read(routerProvider).push('/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fab.trend.gesture')));
    await tester.pumpAndSettle();
    expect(find.textContaining('#打上会'), findsWidgets);
    c.read(overlayManagerProvider).close(composerFowId);
    await tester.pumpAndSettle();
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();

    // AsTell の ＋: タップ = AsTell を作る、長押しで Swing / RASQ / 投稿。
    c.read(routerProvider).go(Routes.vc);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fab.astell.gesture')));
    await tester.pumpAndSettle();
    expect(c.read(overlayManagerProvider).contains(astellCreateFowId), isTrue);
    c.read(overlayManagerProvider).close(astellCreateFowId);
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('fab.astell.gesture')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('fab.astell.action.0')), matching: find.text('Swing')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fab.astell.action.0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SwingComposerScreen), findsOneWidget);
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

List<ProEditorExtraAction> _actions = const [];
Uint8List video_() => Uint8List.fromList([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70]);

class _FakeHandle implements ProEditorHandle {
  _FakeHandle(this.context, {required this.video, required this.onClose});
  @override
  final BuildContext context;
  final bool video;
  final void Function() onClose;
  final backgrounds = <Uint8List>[];
  bool closed = false;
  @override
  bool get isVideo => video;
  @override
  Future<void> setBackground(Uint8List bytes) async => backgrounds.add(bytes);
  @override
  void close() {
    closed = true;
    onClose();
  }
}
