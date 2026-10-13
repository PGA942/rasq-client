import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_models.dart';
import 'package:rasq_client/features/custom/custom_page.dart' show CustomPageArgs;
import 'package:rasq_client/features/home/home_screen.dart' show HomeScreen;
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart' show storeClientProvider;
import 'package:rasq_client/features/swing/swing_providers.dart';
import 'package:rasq_client/features/swing/swing_viewer.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/column_layout.dart' show swingInColumnProvider;
import 'package:rasq_client/shell/column_takeover.dart' show columnTakeoverProvider;
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fakes.dart';

/// D-468: 「みんなで落書き」(sample.paint、実物の wasm)を Swing で配ったとき、Swing のビューワーから自分のマスを押すと
/// SVG の編集画面(`media.editor.open`)が開き、完了で共有変数(`swing:<swingId>` のセッション)に書けること。
/// 作った人(入れている)と見る人(入れていない = 同意のうえ一時的に動かす)の両方、狭い画面と広い画面で。

/// スロットのプラグインを、テストの isolate の同期コントローラで動かす(tool/preview/homescenes_test.dart と同じ)。
class _InProcessSlotRuntime implements SlotRuntime {
  _InProcessSlotRuntime(this.controller);
  final WasmPluginController controller;
  @override
  WasmPluginViewModel get view => controller;
  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) async => controller.invoke(fn, args);
  @override
  set onAppFn(AppFnRelay? relay) => controller.env.onAppFn = relay == null ? null : (fn, args) => scheduleMicrotask(() => relay(fn, args));
  @override
  Stream<Map<String, Object?>> get fetchShapes => controller.fetchShapes;
  @override
  void dispose() => controller.dispose();
}

Future<SlotRuntime> _inProcessLoader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
  final env = RasqHostEnvironment(fowPermissions: fowPermissions, appFns: appFns, permissions: permissions, fetchHosts: fetchHosts, gpuCompute: gpuCompute);
  final c = WasmPluginController(wasmBytes: bytes, env: env, fuelPerCall: fuelPerCall)..load();
  if (c.lastError != null && c.document == null) {
    c.dispose();
    throw StateError(c.lastError!);
  }
  return _InProcessSlotRuntime(c);
}

/// 同梱の wasm(plugin-sample の custom-plugin-paint の dist と同じもの)。
Uint8List _paintWasm() => File('assets/plugins/custom_plugin_paint.wasm').readAsBytesSync();

/// 審査済みのストアの版を、セッション経由で取る(見る人が入れていないとき)。
class _Store extends FakeStoreClient {
  final downloads = <String>[];
  @override
  Future<StorePluginDetail?> plugin(String id) async => id == 'sample.paint'
      ? const StorePluginDetail(id: 'sample.paint', name: 'みんなで落書き', version: '0.1.0', pluginType: StorePluginType.custom, safety: SafetyBlock(permissions: [PermissionEntry('shared.session', 'みんなの落書き')]))
      : super.plugin(id);
  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) async {
    downloads.add('$pluginId/$sessionId');
    return _paintWasm();
  }
}

void main() {
  final now = DateTime.now().toUtc();

  ({MockClient mock, List<String> seen}) central() {
    final seen = <String>[];
    http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final route = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
      if (route == 'GET /me') return json({'id': 'acc-1', 'handle': 'tester', 'displayName': 'テスター'});
      if (route == 'GET /swings/feed') {
        return json([
          {
            'id': 'sw1',
            'author': {'accountId': 'alice', 'handle': 'alice', 'displayName': 'アリス'},
            'kind': 'plugin',
            'text': '',
            'plugin': {'id': 'sample.paint', 'version': '0.1.0', 'sessionId': 'cs-swing'},
            'createdAt': now.subtract(const Duration(minutes: 5)).toIso8601String(),
            'expiresAt': now.add(const Duration(hours: 5)).toIso8601String(),
            'seen': seen.contains('sw1'),
          },
          {
            'id': 't1',
            'author': {'accountId': 'alice', 'handle': 'alice', 'displayName': 'アリス'},
            'kind': 'text',
            'text': 'つぎの Swing',
            'createdAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
            'expiresAt': now.add(const Duration(hours: 5)).toIso8601String(),
            'seen': false,
          },
        ]);
      }
      final m = RegExp(r'^POST /swings/([^/]+)/seen$').firstMatch(route);
      if (m != null) {
        seen.add(m.group(1)!);
        return http.Response('', 204);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    return (mock: mock, seen: seen);
  }

  /// Swing のセッション(作った人 = alice が持ち主、Central S-079 の `swing:<swingId>`)。
  MockCustomSessionClient swingSession() {
    final custom = MockCustomSessionClient(me: const CustomParticipant(accountId: 'acc-1', handle: 'tester', displayName: 'テスター'));
    custom.sessions['cs-swing'] = CustomSession(id: 'cs-swing', pluginId: 'sample.paint', version: '0.1.0', scope: 'swing:sw1', title: 'みんなで落書き', ownerAccountId: 'alice', ownerHandle: 'alice', createdAt: now);
    custom.vars['cs-swing'] = {};
    custom.others['cs-swing'] = const [CustomParticipant(accountId: 'alice', handle: 'alice', displayName: 'アリス')];
    return custom;
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester, {required MockClient mock, required MockCustomSessionClient custom, required StoreClient store, required Size size, double dpr = 3, bool swingInColumn = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    SwingFeed.interval = null;
    addTearDown(() => SwingFeed.interval = const Duration(seconds: 60));
    SwingViewerScreen.displayDuration = null;
    addTearDown(() => SwingViewerScreen.displayDuration = const Duration(seconds: 6));
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
        customSessionClientProvider.overrideWithValue(custom),
        storeClientProvider.overrideWithValue(store),
        slotRuntimeLoaderProvider.overrideWithValue(_inProcessLoader),
        if (swingInColumn) swingInColumnProvider.overrideWithValue(true),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.runAsync(() => c.read(swingFeedProvider.future));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> until(WidgetTester tester, Finder f, {int tries = 60}) async {
    for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f, findsWidgets);
  }

  /// 自分のマスを押す → 編集画面 → ひと筆 → 完了 → 共有変数に書く。
  Future<void> drawOnce(WidgetTester tester, MockCustomSessionClient custom, {bool swingShown = false, Key back = const ValueKey('swing.plugin.page')}) async {
    if (!swingShown) {
      await until(tester, find.text('✏️ タップして描く'));
      await tester.tap(find.text('✏️ タップして描く'));
    }
    await until(tester, find.byKey(const ValueKey('svgpaint.canvas')));
    final canvas = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    expect(canvas.width, greaterThan(0));
    final g = await tester.startGesture(canvas.center);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(canvas.center + Offset(i * 6.0, i * 4.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    final done = find.byKey(const ValueKey('svgpaint.done'));
    expect(done, findsOneWidget);
    expect(tester.getRect(done).overlaps(Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio), isTrue);
    await tester.tap(done);
    for (var i = 0; i < 40 && custom.vars['cs-swing']!['@acc-1.paint'] == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(custom.vars['cs-swing']!['@acc-1.paint'], isNotNull, reason: '完了で shared.set me.paint(Swing のセッション)');
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('svgpaint.canvas')), findsNothing, reason: '編集画面は閉じた');
    expect(find.byKey(back), findsOneWidget, reason: 'ページに戻った');
    expect(find.text('✏️ タップして描く'), findsNothing, reason: '自分のマスに絵');
  }

  for (final (label, size, dpr) in [('狭い画面', const Size(1080, 2340), 3.0), ('広い画面', const Size(2560, 1600), 2.0)]) {
    testWidgets('Swing の落書き ($label): 作った人(入れている)は自分のマスから編集画面を開いて描ける', (tester) async {
      final (:mock, seen: _) = central();
      final custom = swingSession();
      final c = await pumpApp(tester, mock: mock, custom: custom, store: _Store(), size: size, dpr: dpr);
      final plugin = await tester.runAsync(() => c.read(slotPluginsProvider.notifier).register('/plugins/sample.paint.wasm', bytes: _paintWasm(), persist: false));
      expect(plugin?.manifest.id, 'sample.paint', reason: c.read(slotPluginsNoticeProvider));
      c.read(routerProvider).push(Routes.swing('alice'));
      await pumpFor(tester, 400);
      await drawOnce(tester, custom);
    });

    testWidgets('Swing の落書き ($label): 見る人(入れていない)は「参加する」のあと自分のマスから編集画面を開いて描ける', (tester) async {
      final (:mock, seen: _) = central();
      final custom = swingSession();
      final store = _Store();
      final c = await pumpApp(tester, mock: mock, custom: custom, store: store, size: size, dpr: dpr);
      c.read(routerProvider).push(Routes.swing('alice'));
      await until(tester, find.byKey(const ValueKey('swing.plugin.join')));
      await tester.tap(find.byKey(const ValueKey('swing.plugin.join')));
      await until(tester, find.byKey(const ValueKey('swing.plugin.page')));
      expect(store.downloads, ['sample.paint/cs-swing']);
      await drawOnce(tester, custom);
    });
  }

  testWidgets('Swing の落書き (広い画面・第3カラムの Swing): 編集画面はホームのカラムに重ねて開く', (tester) async {
    final (:mock, seen: _) = central();
    final custom = swingSession();
    final c = await pumpApp(tester, mock: mock, custom: custom, store: _Store(), size: const Size(2560, 1600), dpr: 2, swingInColumn: true);
    final plugin = await tester.runAsync(() => c.read(slotPluginsProvider.notifier).register('/plugins/sample.paint.wasm', bytes: _paintWasm(), persist: false));
    expect(plugin?.manifest.id, 'sample.paint', reason: c.read(slotPluginsNoticeProvider));
    openSwingViewer(tester.element(find.byType(HomeScreen)), author: 'alice');
    await pumpFor(tester, 400);
    await until(tester, find.text('✏️ タップして描く'));
    await tester.tap(find.text('✏️ タップして描く'));
    await until(tester, find.byKey(const ValueKey('svgpaint.canvas')));
    expect(c.read(columnTakeoverProvider)[0]?.id, 'media.svg.editor', reason: '第3カラムの Swing の隣(ホームのカラム)');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swing.plugin.page')), findsOneWidget, reason: 'Swing は見えたまま');
    await drawOnce(tester, custom, swingShown: true);
  });

  testWidgets('作った人: 招待のページ(Swing のセッション)の上で自分の Swing を見て戻っても、ページから描ける', (tester) async {
    final (:mock, seen: _) = central();
    final custom = swingSession();
    final c = await pumpApp(tester, mock: mock, custom: custom, store: _Store(), size: const Size(1080, 2340));
    final plugin = await tester.runAsync(() => c.read(slotPluginsProvider.notifier).register('/plugins/sample.paint.wasm', bytes: _paintWasm(), persist: false));
    expect(plugin?.manifest.id, 'sample.paint', reason: c.read(slotPluginsNoticeProvider));
    // 招待したあとの「自分もそこに入り直す」ページ(custom_page.dart の invite)。
    c.read(routerProvider).push(Routes.customPage('sample.paint', const CustomPageArgs(pluginId: 'sample.paint', version: '0.1.0', sessionId: 'cs-swing').query));
    await until(tester, find.text('✏️ タップして描く'));
    // 上に Swing を開いて、同じプラグインのページ(Swing)を見る → 閉じて戻る。
    c.read(routerProvider).push(Routes.swing('alice'));
    await until(tester, find.byKey(const ValueKey('swing.plugin.page')));
    await pumpFor(tester, 300);
    await tester.tap(find.byKey(const ValueKey('swing.close')));
    await pumpFor(tester, 600);
    expect(find.byKey(const ValueKey('swing.plugin.page')), findsNothing);
    await drawOnce(tester, custom, back: const ValueKey('custom.page.body'));
  });
}
