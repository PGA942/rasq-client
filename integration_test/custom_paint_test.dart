import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_page.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/rasqpkg.dart' show storeSlotSource;
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show PluginRegistry;
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLiteView;

import '../test/support/fake_store_client.dart';
import '../test/support/fakes.dart';

/// みんなで落書き (D-465、契約 v0.22): **同梱の実物の wasm**(plugin-sample/custom-plugin-paint)を本物のランタイムで動かし、
/// 自分のマスを押す → メディア編集画面の SVG モードで指でなぞる → 完了 → 共有セッション(モックの Central)に期限つきで書かれ、
/// マスに SVG が描かれるまで。ユニットテストでは偽のランタイムしか使えない(ワーカー isolate と実際のなぞり・描画)ので、ここで通す。
/// `flutter test integration_test/custom_paint_test.dart -d macos`
Future<bool> waitFor(WidgetTester tester, Finder f, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('みんなで落書き: 自分のマス → SVG モードで描く → 完了 → 期限つきで共有され、マスに絵が出る / 消す', (tester) async {
    final custom = MockCustomSessionClient();
    final container = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(FakeStoreClient()),
      customSessionClientProvider.overrideWithValue(custom),
    ]);
    addTearDown(container.dispose);
    final bytes = (await rootBundle.load('assets/plugins/custom_plugin_paint.wasm')).buffer.asUint8List();
    final p = await container.read(slotPluginsProvider.notifier).register(storeSlotSource('sample.paint', '0.1.0'), bytes: bytes, persist: false);
    expect(p?.manifest.id, 'sample.paint');
    final s = await custom.create(pluginId: 'sample.paint', version: '0.1.0', scope: 'link');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: CustomPageScreen(args: CustomPageArgs(pluginId: 'sample.paint', sessionId: s.id))),
    ));
    expect(await waitFor(tester, find.text('✏️ タップして描く')), isTrue, reason: '自分の空のマス');
    await tester.tap(find.text('✏️ タップして描く'));
    expect(await waitFor(tester, find.byKey(const ValueKey('svgpaint.canvas'))), isTrue, reason: 'SVG モードの編集画面');

    // 赤で斜めになぞる。
    await tester.tap(find.byKey(const ValueKey('svgpaint.color.1')));
    final canvas = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    final g = await tester.startGesture(canvas.topLeft + const Offset(20, 20));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(canvas.topLeft + Offset(20 + i * canvas.width / 14, 20 + i * canvas.height / 14));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('svgpaint.done')));

    // 期限つきで Central(モック)に書かれ、マスに SVG が出る。
    expect(await waitFor(tester, find.byType(SvgLiteView)), isTrue, reason: 'マスに落書き');
    final v = custom.vars[s.id]!['@me.paint']!;
    final svg = '${(v.value as Map)['svg']}';
    expect(svg, contains('<path'));
    expect(svg.toLowerCase(), contains('#e53935'));
    expect(v.expiresAt, isNotNull);
    expect(find.textContaining('あと '), findsWidgets);

    // 「消す」→ value: null。
    await tester.tap(find.text('消す').first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(custom.vars[s.id]!.containsKey('@me.paint'), isFalse);
    expect(find.text('✏️ タップして描く'), findsOneWidget);
  });
}
