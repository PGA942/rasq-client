import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_editor_screen.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 添付の加工 (D-173): 基本は pro_image_editor、下段バーの「プラグイン」でメディアエディター (D-169) へ
/// バイパスし、適用結果が新しい背景になって戻る。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);
  // 2×1 の PNG(赤 / 青)。
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=');
  late Map<String, FakeSlotRuntime Function()> fakes;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  setUp(() => fakes = {});

  /// pro_image_editor は画像の復号が本物の非同期(FakeAsync では進まない)なので、runAsync で待ってから数フレーム進める。
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('pro_image_editor が開き、プラグイン無しなら下段バーに「プラグイン」は無い、✕ で null', (tester) async {
    final c = await pump(tester);
    final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    expect(find.byType(ProImageEditor), findsOneWidget);
    expect(find.text('クロップ / 回転'), findsOneWidget); // 日本語化
    expect(find.text('ペイント'), findsOneWidget);
    expect(find.byKey(proMediaEditorPluginKey), findsNothing);
    await tester.tap(find.byIcon(Icons.clear).first);
    await settle(tester);
    expect(await future, isNull);
    expect(find.byType(ProImageEditor), findsNothing);
  });

  testWidgets('「プラグイン」→ 焼き込んだ画像でメディアエディター → 適用 → 結果が pro_image_editor の背景になる', (tester) async {
    late FakeSlotRuntime rt;
    fakes['m'] = () => rt = FakeSlotRuntime(
          manifest: {'id': 't.m', 'name': 'テスト加工', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.catalog' || 'media.edit':
                return {'genres': [{'id': 'tone', 'actions': [{'id': 'x', 'label': 'X'}]}]};
              case 'media.action' || 'media.cancel':
                return {};
              case 'media.commit':
                return {'bytesB64': base64Encode(png), 'mimeType': 'image/png', 'name': 'edited.png'};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:m', bytes: Uint8List.fromList('m'.codeUnits));
    await settle(tester);
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    expect(find.byKey(proMediaEditorPluginKey), findsOneWidget);
    await tester.ensureVisible(find.byKey(proMediaEditorPluginKey)); // 下段バーは横スクロール(右端)
    await settle(tester);
    await tester.tap(find.byKey(proMediaEditorPluginKey));
    await settle(tester);
    // バイパス: プラグインのエディターが開き、media.edit には焼き込んだ画像(変更無しなら元のバイト)が渡る。
    expect(find.byType(MediaEditorScreen), findsOneWidget);
    final edit = rt.calls.where((x) => x.$1 == 'media.edit').single.$2;
    expect((edit['bytesB64'] as String).startsWith('iVBORw0KGgo'), isTrue); // PNG で焼き込む(元と同じ画でも再エンコードされる)
    expect(edit['mimeType'], 'image/png');
    expect(edit['name'], 'a.png');
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await settle(tester);
    expect(rt.calls.where((x) => x.$1 == 'media.commit').length, 1);
    expect(find.byType(MediaEditorScreen), findsNothing);
    expect(find.byType(ProImageEditor), findsOneWidget);
    // 背景が差し替わり、レイヤー無し・履歴に 1 段(適用前へは戻れない = 焼き込み)。
    final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
    expect(state.stateManager.activeBackgroundImage?.byteArray, png);
    expect(state.activeLayers, isEmpty);
  });
}
