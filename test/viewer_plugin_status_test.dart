import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/users/profile_image_viewer.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 全画面表示プラグインの状態 (D-246): 黙って失敗しない。トグルに 検出あり / 検出なし / 失敗(理由) を出し、
/// 失敗したものはオフ → オンで渡し直せる。プロフィール画像の全画面にも同じトグル(全画面アクションバー)。
void main() {
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  final acc = fakeSession().account;
  final post = Post(id: 'i1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: '画像つき', media: [MediaItem(id: 'i', type: MediaType.image, url: Uri.parse('https://example.test/i.jpg'))]);

  Future<ProviderContainer> pump(WidgetTester tester, Map<String, FakeSlotRuntime Function()> fakes, Future<Uint8List?> Function(Uri) fetch) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': acc.key})});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]))),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        viewerImageFetcherProvider.overrideWithValue(fetch),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    for (final name in fakes.keys) {
      await c.read(slotPluginsProvider.notifier).register('fake:$name', bytes: Uint8List.fromList(name.codeUnits));
    }
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> settleAsync(WidgetTester tester) async {
    // 画像の復号は本物の非同期。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> manifest(String id) => {'id': id, 'name': id, 'version': '0.1.0', 'kind': 'mediaViewer', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget']};
  String tip(WidgetTester tester, String id) => tester.widget<RasqIconButton>(find.byKey(ValueKey('viewer.plugin.$id'))).tooltip ?? '';

  testWidgets('検出あり / 検出なし / プラグインのエラー がトグルに出る', (tester) async {
    final c = await pump(tester, {
      'hit': () => FakeSlotRuntime(manifest: manifest('t.hit'), handler: (_, fn, args) => fn == 'viewer.open' ? {'root': {'t': 'Text', 'k': 'x', 'p': {'text': '枠'}}} : null),
      'miss': () => FakeSlotRuntime(manifest: manifest('t.miss'), handler: (_, fn, args) => fn == 'viewer.open' ? <String, Object?>{} : null),
      'boom': () => FakeSlotRuntime(manifest: manifest('t.boom'), handler: (_, fn, args) => fn == 'viewer.open' ? throw StateError('wasm unreachable') : null),
    }, (_) async => png);
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    await settleAsync(tester);
    expect(tip(tester, 't.hit'), contains('検出あり'));
    expect(tip(tester, 't.miss'), contains('検出なし'));
    expect(tip(tester, 't.boom'), allOf(contains('失敗'), contains('wasm unreachable')));
    expect(find.descendant(of: find.byKey(const ValueKey('viewer.plugin.t.boom')), matching: find.byIcon(Icons.error_outline)), findsOneWidget);
    expect(find.text('枠'), findsOneWidget);
  });

  testWidgets('画像を取れなかったら失敗と出し、オフ → オンで渡し直す', (tester) async {
    var online = false;
    late FakeSlotRuntime rt;
    final c = await pump(tester, {
      'qr': () => rt = FakeSlotRuntime(manifest: manifest('t.qr'), handler: (_, fn, args) => fn == 'viewer.open' ? {'root': {'t': 'Text', 'k': 'x', 'p': {'text': '枠'}}} : null),
    }, (_) async => online ? png : null);
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    await settleAsync(tester);
    expect(tip(tester, 't.qr'), contains('画像を取得できませんでした'));
    expect(rt.calls.where((x) => x.$1 == 'viewer.open'), isEmpty);
    // 以前はここで二度と渡さなかった。オフ → オンでやり直せる。
    online = true;
    await tester.tap(find.byKey(const ValueKey('viewer.plugin.t.qr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viewer.plugin.t.qr')));
    await tester.pumpAndSettle();
    await settleAsync(tester);
    expect(rt.calls.where((x) => x.$1 == 'viewer.open').length, 1);
    expect(tip(tester, 't.qr'), contains('検出あり'));
    expect(find.text('枠'), findsOneWidget);
  });

  testWidgets('ボタンの宣言 (契約 v0.9): actions[].slot = viewer.overlay の label / icon を使い、投稿のボタンにはしない', (tester) async {
    final declared = {...manifest('t.decl'), 'name': '長いプラグイン名', 'actions': [{'id': 'toggle', 'slot': 'viewer.overlay', 'label': 'QR コード検出', 'icon': 'qr_code_scanner', 'tags': ['QR']}]};
    final c = await pump(tester, {
      'decl': () => FakeSlotRuntime(manifest: declared, handler: (_, fn, args) => fn == 'viewer.open' ? <String, Object?>{} : null),
      'plain': () => FakeSlotRuntime(manifest: manifest('t.plain'), handler: (_, fn, args) => fn == 'viewer.open' ? <String, Object?>{} : null),
    }, (_) async => png);
    expect(c.read(pluginActionsProvider), isEmpty);
    final a = c.read(viewerPluginActionsProvider).firstWhere((x) => x.plugin.id == 't.decl');
    expect((a.id, a.decl.label, a.decl.icon), ('slot:t.decl:viewer.overlay', 'QR コード検出', 'qr_code_scanner'));
    expect(a.decl.tags, ['全画面表示', 'QR']);
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    await settleAsync(tester);
    expect(tip(tester, 't.decl'), startsWith('QR コード検出'));
    expect(find.descendant(of: find.byKey(const ValueKey('viewer.plugin.t.decl')), matching: find.byIcon(Icons.qr_code_scanner)), findsOneWidget);
    // 宣言の無いものは従来どおり(名前 + パズルのアイコン)
    expect(tip(tester, 't.plain'), startsWith('t.plain'));
    expect(find.descendant(of: find.byKey(const ValueKey('viewer.plugin.t.plain')), matching: find.byIcon(Icons.extension)), findsOneWidget);
  });

  testWidgets('プロフィール画像の全画面にも全画面アクションバー(プラグインのトグル)', (tester) async {
    late FakeSlotRuntime rt;
    await pump(tester, {
      'qr': () => rt = FakeSlotRuntime(manifest: manifest('t.qr'), handler: (_, fn, args) => fn == 'viewer.open' ? {'root': {'t': 'Text', 'k': 'x', 'p': {'text': '枠'}}} : null),
    }, (_) async => png);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => ProfileImageViewerScreen(url: Uri.parse('https://example.test/avatar.png'), title: 'アイコン')));
    await tester.pumpAndSettle();
    await settleAsync(tester);
    final toggle = find.descendant(of: find.byType(ProfileImageViewerScreen), matching: find.byKey(const ValueKey('viewer.plugin.t.qr')));
    expect(toggle, findsOneWidget);
    expect(tip(tester, 't.qr'), contains('検出あり'));
    expect(find.descendant(of: find.byType(ProfileImageViewerScreen), matching: find.byType(RrlRenderer)), findsOneWidget);
    // オフにすると重ねが消え、オンで戻る(渡し直しはしない)。
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ProfileImageViewerScreen), matching: find.byType(RrlRenderer)), findsNothing);
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ProfileImageViewerScreen), matching: find.byType(RrlRenderer)), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'viewer.open').length, 1);
  });
}
