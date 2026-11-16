import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 加工画面でプラグインのボタンを選んで編集している間も × が効く (D-567、ユーザー報告 2026-11-16)。
///
/// 実機のプラグインは専用 isolate で呼びを 1 つずつ処理するので、編集(`media.action`)の最中に送った `media.cancel` は
/// 前の呼びが終わるまで返らない。以前の × はその返事を待ってから閉じていたので、重い編集の間は押しても何も起きなかった。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=');

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('編集の返事を待っている間でも、パネルの × ですぐ閉じる(media.cancel は後ろで送る)。プラグインの FOW も閉じる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // 実機の isolate と同じく、呼びは 1 つずつ: 編集が終わるまで cancel も返らない。
    final busy = Completer<void>();
    late FakeSlotRuntime rt;
    final fakes = <String, FakeSlotRuntime Function()>{
      'm': () => rt = FakeSlotRuntime(
            manifest: {
              'id': 't.m', 'name': '重い加工', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
              'actions': [{'id': 'heavy', 'slot': 'composer.media', 'label': '重い', 'icon': 'auto_awesome'}],
            },
            handler: (self, fn, args) async {
              switch (fn) {
                case 'media.edit':
                  return {'genres': [{'id': 'g', 'actions': [{'id': 'heavy', 'label': '重い'}]}]};
                case 'media.action':
                  // 編集のパラメーターの FOW を開いて、重い処理に入る(返らない)。
                  self.openFow('params', {'t': 'Text', 'k': 'p', 'p': {'text': 'パラメーター'}}, title: 'パラメーター');
                  await busy.future;
                  return {};
                case 'media.cancel':
                  await busy.future;
                  return {};
              }
              return null;
            },
          ),
    };
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 11, 16), body: 'x')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(slotPluginsProvider.notifier).register('fake:m', bytes: Uint8List.fromList('m'.codeUnits));
    await settle(tester);
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.png', mimeType: 'image/png'));
    await settle(tester);
    final button = find.byKey(proMediaEditorBarKey('slot:t.m:heavy'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'media.action'), hasLength(1), reason: '宣言 id の編集がすぐ始まり、返事待ち');
    final manager = c.read(overlayManagerProvider);
    expect(manager.entries.where((e) => e.id.startsWith('fow.slot.t.m.')), isNotEmpty, reason: 'プラグインの FOW が開いている');

    // 編集の返事を待っている間に ×。
    await tester.tap(find.descendant(of: find.byType(MediaPluginPanel), matching: find.byTooltip('キャンセル')));
    await settle(tester);
    expect(find.byType(MediaPluginPanel), findsNothing, reason: '返事を待たずに閉じる');
    expect(find.byType(ProImageEditor), findsOneWidget, reason: '加工画面に戻る');
    expect(rt.calls.where((x) => x.$1 == 'media.cancel'), hasLength(1), reason: 'cancel は送っている');
    expect(manager.entries.where((e) => e.id.startsWith('fow.slot.t.m.')), isEmpty, reason: 'プラグインの FOW もすぐ閉じる');

    // あとからプラグインが返事をしても、何も壊れない。
    busy.complete();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MediaPluginPanel), findsNothing);
  });
}
