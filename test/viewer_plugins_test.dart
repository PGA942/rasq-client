import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 全画面表示プラグイン (D-207): 全画面の右上、「…」の右のアイコンで有効 / 無効を切り替える(保存される)。
void main() {
  testWidgets('右上のトグルで無効にすると画像を渡す相手から外れる、メディアは下付き FOW のぶん詰まる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final acc = fakeSession().account;
    final post = Post(
      id: 'i1',
      account: acc,
      author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
      createdAt: DateTime(2026, 9, 1),
      body: '画像つき',
      media: [MediaItem(id: 'i', type: MediaType.image, url: Uri.parse('https://example.test/i.jpg'))],
    );
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]));
    final fakes = <String, FakeSlotRuntime Function()>{
      'qr': () => FakeSlotRuntime(
            manifest: {'id': 't.qr', 'name': 'QR テスト', 'version': '0.1.0', 'kind': 'action', 'description': '枠を出すテスト', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget']},
            handler: (self, fn, args) => null,
          ),
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        viewerImageFetcherProvider.overrideWithValue((url) async => null),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(slotPluginsProvider.notifier).register('fake:qr', bytes: Uint8List.fromList('qr'.codeUnits));
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider).map((p) => p.id), ['t.qr']);
    // ビューワーの右上、「…」の右にプラグインのトグル (D-207)。ON = 塗りアイコン。
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('viewer.plugin.t.qr'));
    expect(toggle, findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.extension)), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider), isEmpty);
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
    // 保存される(設定エリア slots.viewer)。
    expect(c.read(settingsAreaProvider(viewerPluginsSettingsArea)).value?[viewerPluginEnabledKey('t.qr')], false);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider).length, 1);
    // 「…」に「全画面表示プラグイン」「オーバーレイに移動」は無い。
    await tester.tap(find.descendant(of: find.byType(MediaViewerScreen), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    expect(find.text('全画面表示プラグイン'), findsNothing);
    expect(find.text('オーバーレイに移動'), findsNothing);
    expect(find.text('リンクをコピー'), findsOneWidget);
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    // 下付き FOW(折りたたみ = 画面の 30% 未満)のぶんメディアの高さが詰まる (D-207)。
    final panel = tester.getRect(find.byKey(viewerPanelKey));
    expect(tester.getRect(find.byType(PageView)).bottom, lessThanOrEqualTo(panel.top + 1));
  });
}
