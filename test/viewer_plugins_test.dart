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
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 全画面表示プラグイン (D-207 → D-305): 全画面の右上、「…」の右のアイコンで ON / OFF を切り替える。
/// 契約 v0.14 (temp): 切り替えはその全画面限りで保存されず、次に開いたときは既定(宣言 / 設定)に戻る。
void main() {
  /// トグルの ON / OFF(ON でも画像を取れないと警告のアイコンになるので、アイコンではなく状態を見る)。
  bool toggleOn(WidgetTester tester, String id) => tester.widget<ViewerPluginToggle>(find.byWidgetPredicate((w) => w is ViewerPluginToggle && w.pluginId == id)).enabled;

  testWidgets('右上のトグルで無効にすると画像を渡す相手から外れる(この全画面限り)、メディアは下付き FOW のぶん詰まる', (tester) async {
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
        // 写真とファイルを選べる端末(iPad など)のつもり。
        mediaSaveDestinationsHereProvider.overrideWithValue(const [MediaSaveDestination.photos, MediaSaveDestination.files]),
        imageSaverProvider.overrideWithValue((item, dest) async {
          saved.add('${item.id}:${dest.name}');
          return '画像を保存しました(${dest.name})';
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
    // このテストは画像を取れない(fetcher が null)。黙らずにトグルへ出す (D-246): 警告の印 + 理由。
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.error_outline)), findsOneWidget);
    expect(tester.widget<RasqIconButton>(toggle).tooltip, contains('画像を取得できませんでした'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
    // 保存されない(契約 v0.14 temp): switch はオンのまま、slots.global の auto にも書かない。
    expect(c.read(viewerOverlayPluginsProvider).length, 1);
    expect(c.read(actionButtonPrefsProvider).autoOverride(pluginActionId('t.qr', viewerToggleActionId)), isNull);
    expect(c.read(settingsAreaProvider(actionButtonPrefsArea)).value?[ActionButtonPrefs.autoKey], isNull);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(toggleOn(tester, 't.qr'), isTrue);
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
    // 保存先 (D-334): 写真とファイルを選べる端末なら既定の「保存するたびに選ぶ」でシート → ファイル。
    expect(find.byKey(const ValueKey('media.save.files')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media.save.files')));
    await tester.pumpAndSettle();
    expect(saved, ['${post.media.first.id}:files']);
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
    // 下付き FOW のぶんメディアの高さが詰まる (D-207)。
    final panel = tester.getRect(find.byKey(viewerPanelKey));
    expect(tester.getRect(find.byType(PageView)).bottom, lessThanOrEqualTo(panel.top + 1));
    // ヘッダー付き FOW が出るとメディアはその下へ、消えると戻る (D-215: 空いているスペースへ移動)。
    final manager = c.read(overlayManagerProvider);
    manager.showFow<void>(id: 't.top', spec: FowSpec(title: '上', cancelText: '閉じる', attachTop: true, initialHeightFactor: 0.25), semanticsLabel: '上', builder: (_, _) => const SizedBox(height: 80));
    await tester.pumpAndSettle();
    final topRect = manager.entries.where((e) => e.id == 't.top').single.fow!.laidOut!;
    expect(tester.getRect(find.byType(PageView)).top, greaterThanOrEqualTo(topRect.bottom - 1));
    expect(tester.getRect(find.byType(PageView)).bottom, lessThanOrEqualTo(panel.top + 1)); // 下も詰まったまま
    manager.close('t.top');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PageView)).top, 0);
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
    expect(find.descendant(of: toggle, matching: find.byIcon(Icons.extension_outlined)), findsOneWidget); // OFF(この全画面限り)
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
    // ビューワーに戻る: 前の全画面での OFF は引き継がず、既定(オン = 塗りのアイコン)に戻る(契約 v0.14 temp)。
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    expect(toggleOn(tester, 't.qr'), isTrue);
  });

  testWidgets('temp (契約 v0.14 §2.4 / §2.11): slots.viewer の保存は slots.global.auto へ移行、初期状態は 設定 → 宣言 → 既定、長押しで「次からも自動でオン / オフ」、switch オフで出ない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final acc = fakeSession().account;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': acc.key}),
      // v0.13 までの保存: 「t.qr は OFF」。
      legacyViewerPluginsStorageKey: jsonEncode({'enabled.t.qr': false}),
    });
    final post = Post(id: 'i1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: '画像つき', media: [MediaItem(id: 'i', type: MediaType.image, url: Uri.parse('https://example.test/i.jpg'))]);
    Map<String, Object?> manifest(String id, {bool? auto}) => {
          'id': id, 'name': id, 'version': '0.1.0', 'kind': 'mediaViewer', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget'],
          if (auto != null) 'actions': [{'id': 'toggle', 'slot': 'viewer.overlay', 'label': id, 'icon': 'qr_code_scanner', 'tags': ['QR'], 'auto': auto}],
        };
    final fakes = <String, FakeSlotRuntime Function()>{
      'qr': () => FakeSlotRuntime(manifest: manifest('t.qr'), handler: (self, fn, args) => null),
      // 審査済み(ストアから)で auto: false を宣言 → 初期状態 OFF。
      'store:t.off': () => FakeSlotRuntime(manifest: manifest('t.off', auto: false), handler: (self, fn, args) => null),
      // サイドロードの auto: false は読まない → ホスト既定の ON。
      'side': () => FakeSlotRuntime(manifest: manifest('t.side', auto: false), handler: (self, fn, args) => null),
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]))),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        viewerImageFetcherProvider.overrideWithValue((url) async => null),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final slots = c.read(slotPluginsProvider.notifier);
    await slots.register('fake:qr', bytes: Uint8List.fromList('qr'.codeUnits));
    await slots.register('store:t.off', bytes: Uint8List.fromList('off'.codeUnits));
    await slots.register('fake:side', bytes: Uint8List.fromList('side'.codeUnits));
    await tester.pumpAndSettle();
    final qrId = pluginActionId('t.qr', viewerToggleActionId);
    // 移行: slots.viewer は捨てられ、slots.global の auto に写っている。
    expect(await storage.read(legacyViewerPluginsStorageKey), isNull);
    expect(c.read(actionButtonPrefsProvider).autoOverride(qrId), isFalse);
    final actions = {for (final a in c.read(viewerPluginActionsProvider)) a.plugin.id: a};
    expect(actions['t.off']!.plugin.isReviewed, isTrue);
    expect(actions['t.off']!.effectiveAuto(c.read(actionButtonPrefsProvider)), isFalse);
    expect(actions['t.side']!.plugin.isReviewed, isFalse);
    expect(actions['t.side']!.effectiveAuto(c.read(actionButtonPrefsProvider)), isTrue);
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    expect(toggleOn(tester, 't.qr'), isFalse); // 移行した OFF
    expect(toggleOn(tester, 't.side'), isTrue); // 既定 ON(サイドロードの宣言は読まない)
    expect(toggleOn(tester, 't.off'), isFalse); // 審査済みの宣言 auto: false
    // 宣言のアイコンは色で ON / OFF を出す: t.off は OFF(白 54%)。
    expect(tester.widget<RasqIconButton>(find.byKey(const ValueKey('viewer.plugin.t.off'))).color, Colors.white54);
    // 長押し → 「次からも自動でオン」: 今の全画面は変わらず、設定が書かれる。
    await tester.longPress(find.byKey(const ValueKey('viewer.plugin.t.qr')));
    await tester.pumpAndSettle();
    expect(find.text('次からも自動でオン'), findsOneWidget);
    expect(find.text('プラグインの既定に戻す'), findsOneWidget); // 上書きがあるので出る
    await tester.tap(find.text('次からも自動でオン'));
    await tester.pumpAndSettle();
    expect(c.read(actionButtonPrefsProvider).autoOverride(qrId), isTrue);
    expect(toggleOn(tester, 't.qr'), isFalse); // この全画面はそのまま
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
    await tester.pumpAndSettle();
    expect(toggleOn(tester, 't.qr'), isTrue); // 次の全画面から ON
    // switch オフ(端末全体): トグルが消え、画像も渡さない(temp は評価しない)。
    await setActionSwitch(c.read(settingsAreaProvider(actionButtonPrefsArea).notifier), c.read(actionButtonPrefsProvider), qrId, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer.plugin.t.qr')), findsNothing);
    expect(c.read(viewerOverlayPluginsProvider).map((p) => p.id), isNot(contains('t.qr')));
    expect(c.read(pluginActionsForProvider(ActionBarConfigStore.viewerKey(acc.key))).map((p) => p.id), isNot(contains(qrId))); // 検索の候補にも出ない
  });

}
