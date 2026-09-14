import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/action_bar_edit_sheet.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_client/features/media/image_saver.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/post/share_fow.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
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
    final saved = <String>[];
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
        imageSaverProvider.overrideWithValue((item) async {
          saved.add(item.id);
          return '/tmp/${item.id}.jpg';
        }),
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
    // 投稿のメニューに準拠 (D-213): 詳細の代わりに「画像を保存」、共有 / お気に入り なども並ぶ。
    expect(find.text('詳細'), findsNothing);
    expect(find.text('画像を保存'), findsOneWidget);
    expect(find.text('リンクをコピー'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    // 画像を保存 → 差し替えた保存先が呼ばれ、スナックバー。
    await tester.tap(find.text('画像を保存'));
    await tester.pumpAndSettle();
    expect(saved, [post.media.first.id]);
    expect(find.textContaining('画像を保存しました'), findsOneWidget);
    // 「…」→ 共有 → 「内容をコピー」の代わりに「画像を保存」。
    await tester.tap(find.descendant(of: find.byType(MediaViewerScreen), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('共有'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post.share.saveImage')), findsOneWidget);
    expect(find.byKey(const ValueKey('post.share.copyContent')), findsNothing);
    c.read(overlayManagerProvider).close(postShareFowId);
    await tester.pumpAndSettle();
    // 下付き FOW(折りたたみ = 画面の 30% 未満)のぶんメディアの高さが詰まる (D-207)。
    final panel = tester.getRect(find.byKey(viewerPanelKey));
    expect(tester.getRect(find.byType(PageView)).bottom, lessThanOrEqualTo(panel.top + 1));
  });

  testWidgets('全画面表示プラグインは全画面アクションバーのボタン (D-214): ヘッダーの右端に並ぶ、編集画面の全画面バーで削除 / 検索(QR コード検出など)で戻せる、投稿バーの検索には出ない', (tester) async {
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
            manifest: {'id': 't.qr', 'name': 'QR コード検出', 'version': '0.1.0', 'kind': 'action', 'description': '枠を出すテスト', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget']},
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
    final toggleId = pluginActionId('t.qr', viewerToggleActionId);
    expect(isViewerToggleActionId(toggleId), isTrue);
    expect(viewerTogglePluginId(toggleId), 't.qr');
    expect(c.read(pluginActionsForProvider(ActionBarConfigStore.viewerKey(acc.key))).map((p) => p.id), [toggleId]);
    expect(c.read(pluginActionsForProvider(acc.key)), isEmpty); // 投稿バーには出ない
    // ビューワー: トグルはアクションバーの一員として SNS のボタンの後ろ、「…」は右端。
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    final menu = find.descendant(of: find.byType(MediaViewerScreen), matching: find.byTooltip('メニュー'));
    final width = tester.getSize(find.byType(RasqApp)).width;
    expect(tester.getRect(menu).right, closeTo(width - RasqSpacing.sm, 3)); // 右端(丸の内側のボタン)
    final toggle = find.byKey(const ValueKey('viewer.plugin.t.qr'));
    expect(toggle, findsOneWidget);
    expect(tester.getRect(toggle).right, lessThan(tester.getRect(menu).left));
    expect(tester.getRect(find.byKey(const ValueKey('viewer.action.reply'))).right, lessThan(tester.getRect(toggle).left)); // SNS のボタンの後ろ
    expect(tester.getRect(find.byTooltip('戻る')).left, closeTo(RasqSpacing.sm, 3));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(c.read(viewerOverlayPluginsProvider), isEmpty); // OFF
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    // 編集画面(投稿の … → アクションバーを編集)の全画面バーにトグルのタイル → (…) → 削除。
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションバーを編集'));
    await tester.pumpAndSettle();
    final tileMenu = find.byKey(ValueKey('actionbar.tile.menu.$toggleId.viewer'));
    await tester.ensureVisible(tileMenu);
    await tester.pumpAndSettle();
    await tester.tap(tileMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('actionbar.tile.$toggleId.viewer')), findsNothing);
    expect(c.read(slotActionSettingsProvider(acc.key)).isEnabled(toggleId), isFalse);
    // 投稿バーの (+) の検索には出ない。全画面バーの (+) には出る → 選ぶと戻る。
    await tester.tap(find.byKey(const ValueKey('actionbar.plugins.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('actionbar.plugin.$toggleId')), findsNothing);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.plugins.open.viewer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.plugins.open.viewer')));
    await tester.pumpAndSettle();
    expect(find.text('QR コード検出'), findsOneWidget);
    expect(find.textContaining('全画面表示プラグイン(ON / OFF のボタン)'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('actionbar.plugin.$toggleId')));
    await tester.pumpAndSettle();
    expect(c.read(slotActionSettingsProvider(acc.key)).isEnabled(toggleId), isTrue);
    expect(find.byKey(ValueKey('actionbar.tile.$toggleId.viewer')), findsOneWidget);
    c.read(overlayManagerProvider).close(actionBarEditFowId);
    await tester.pumpAndSettle();
    // ビューワーに戻る(OFF のまま = 白い枠線アイコン)。
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('viewer.plugin.t.qr')), matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
  });

}
