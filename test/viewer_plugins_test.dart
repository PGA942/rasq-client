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
import 'package:rasq_client/features/media/viewer_plugins_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/store_home_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 全画面表示プラグインの編集 (D-205): 全画面の「…」→「全画面表示プラグイン」で一覧、有効 / 無効を切り替える。
void main() {
  testWidgets('「…」→ 全画面表示プラグイン → 無効にすると画像を渡す相手から外れる', (tester) async {
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
    // ビューワーの「…」→「全画面表示プラグイン」。
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(MediaViewerScreen), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全画面表示プラグイン'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerPluginsScreen), findsOneWidget);
    expect(find.text('QR テスト'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer.plugins.t.qr')));
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider), isEmpty);
    await tester.tap(find.byKey(const ValueKey('viewer.plugins.t.qr')));
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider).length, 1);
    await tester.tap(find.byKey(const ValueKey('viewer.plugins.store')));
    await tester.pumpAndSettle();
    expect(find.byType(StoreHomeScreen), findsOneWidget);
  });
}
