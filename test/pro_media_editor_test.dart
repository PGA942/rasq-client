import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
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

  testWidgets('pro_image_editor が開き、プラグイン無しなら下段バーは内蔵の編集だけ、✕ で null', (tester) async {
    final c = await pump(tester);
    // コンポーザー FOW を開いたまま加工へ → FOW は退避(エディターの前に出ない)、閉じると戻る (D-174)。
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    final manager = c.read(overlayManagerProvider);
    final composer = manager.entries.where((e) => e.id == 'fow.composer').single;
    expect(manager.isFowSuspended(composer), isFalse);
    final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    expect(find.byType(ProImageEditor), findsOneWidget);
    expect(manager.isFowSuspended(composer), isTrue);
    expect(find.text('クロップ / 回転'), findsOneWidget); // 日本語化
    expect(find.text('ペイント'), findsOneWidget);
    expect(find.byKey(proMediaEditorBarKey('editor:cropRotate')), findsOneWidget);
    expect(find.byKey(proMediaEditorBarKey('editor:media'), skipOffstage: false), findsOneWidget); // 画像 / 動画のオブジェクト (D-262)
    expect(find.byKey(proMediaEditorBarEditKey), findsOneWidget);
    expect(find.byIcon(Icons.extension), findsNothing);
    // 「バーの編集」: 加工画面のバーだけの編集 FOW が(退避されずに)開く。内蔵の編集もタイルで並ぶ。
    await tester.ensureVisible(find.byKey(proMediaEditorBarEditKey));
    await settle(tester);
    await tester.tap(find.byKey(proMediaEditorBarEditKey));
    await settle(tester);
    expect(find.text('加工画面のバー(画像)'), findsOneWidget);
    expect(find.text('投稿アクションバー'), findsNothing);
    expect(find.byKey(const ValueKey('actionbar.tile.editor:cropRotate.editor.image')), findsOneWidget);
    expect(manager.isFowSuspended(manager.entries.where((e) => e.id == 'actionbar.edit').single), isFalse);
    manager.close('actionbar.edit');
    await settle(tester);
    await tester.tap(find.byIcon(Icons.clear).first);
    await settle(tester);
    expect(await future, isNull);
    expect(find.byType(ProImageEditor), findsNothing);
    expect(manager.isFowSuspended(composer), isFalse);
  });

  testWidgets('宣言の無いプラグインのボタン → 焼き込んだ画像で編集パネル → 適用 → 結果が pro_image_editor の背景になる', (tester) async {
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
    final button = find.byKey(proMediaEditorBarKey('slot:t.m:composer.media'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button); // 下段バーは横スクロール(右端)
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    // バイパス: プラグインのエディターが開き、media.edit には焼き込んだ画像(変更無しなら元のバイト)が渡る。
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    final edit = rt.calls.where((x) => x.$1 == 'media.edit').single.$2;
    expect((edit['bytesB64'] as String).startsWith('iVBORw0KGgo'), isTrue); // PNG で焼き込む(元と同じ画でも再エンコードされる)
    expect(edit['mimeType'], 'image/png');
    expect(edit['name'], 'a.png');
    expect(edit.containsKey('actionId'), isFalse); // 既定のボタンは宣言 id を渡さない
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await settle(tester);
    expect(rt.calls.where((x) => x.$1 == 'media.commit').length, 1);
    expect(find.byType(MediaPluginPanel), findsNothing);
    expect(find.byType(ProImageEditor), findsOneWidget);
    // 背景が差し替わり、レイヤー無し・履歴に 1 段(適用前へは戻れない = 焼き込み)。
    final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
    expect(state.stateManager.activeBackgroundImage?.byteArray, png);
    expect(state.activeLayers, isEmpty);
  });

  testWidgets('下段バーの宣言 (D-249、契約 v0.10): accepts で出し分け、タグが近い内蔵の編集へ束ねる、宣言 id の編集をすぐ始める', (tester) async {
    late FakeSlotRuntime rt;
    fakes['d'] = () => rt = FakeSlotRuntime(
          manifest: {
            'id': 't.d', 'name': '宣言つき', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
            'actions': [
              {'id': 'glaze', 'slot': 'composer.media', 'label': 'Glaze', 'icon': 'auto_awesome', 'tags': ['Filter']},
              {'id': 'wave', 'slot': 'composer.media', 'label': '波形', 'icon': 'graphic_eq', 'tags': ['Audio'], 'accepts': ['audio/*', 'video/*']},
              {'id': 'gifonly', 'slot': 'composer.media', 'label': 'GIF', 'tags': ['Gif'], 'accepts': ['.gif']},
            ],
          },
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.edit':
                return {'genres': [{'id': 'tone', 'actions': [{'id': 'glaze', 'label': 'Glaze'}]}]};
              case 'media.action' || 'media.cancel':
                return {};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:d', bytes: Uint8List.fromList('d'.codeUnits));
    await settle(tester);
    // 出し分け: 画像のバーには Glaze(accepts 無し = image/*)と GIF(拡張子は実際の添付で絞る)、動画のバーには 波形。
    expect(c.read(pluginActionsForProvider(editorImageConfigKey)).map((a) => a.decl.id), ['glaze', 'gifonly']);
    expect(c.read(pluginActionsForProvider(editorVideoConfigKey)).map((a) => a.decl.id), ['wave', 'gifonly']);
    // 投稿のアクションボタンには混ざらない。
    expect(c.read(pluginActionsProvider), isEmpty);

    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    // a.jpg なので GIF 専用は出ない。Glaze はタグ Filter → 内蔵の「フィルター」とのバンドル(auto:editor:filter)に入る。
    expect(find.byKey(proMediaEditorBarKey('slot:t.d:gifonly')), findsNothing);
    expect(find.byKey(proMediaEditorBarKey('slot:t.d:glaze')), findsNothing);
    expect(find.byKey(proMediaEditorBarKey('editor:filter')), findsNothing);
    final bundle = find.byKey(proMediaEditorBarKey('list:auto:editor:filter'));
    expect(bundle, findsOneWidget);
    await tester.ensureVisible(bundle);
    await settle(tester);
    await tester.tap(bundle);
    await settle(tester);
    await tester.tap(find.text('Glaze'));
    await settle(tester);
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'media.edit').single.$2['actionId'], 'glaze');
    // 宣言 id と同じ編集があるので、開いた直後に media.action。
    final act = rt.calls.where((x) => x.$1 == 'media.action').single.$2;
    expect((act['genre'], act['action']), ('tone', 'glaze'));
  });

  testWidgets('ステッカー (D-252): 一覧にアセットパックと「プラグインで作る」、output: sticker の結果は背景ではなくレイヤーになる', (tester) async {
    late FakeSlotRuntime rt;
    fakes['g'] = () => rt = FakeSlotRuntime(
          manifest: {
            'id': 't.g', 'name': 'ジェネレーター', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
            'actions': [{'id': 'qr', 'slot': 'composer.media', 'label': 'QR を作る', 'icon': 'qr_code_2', 'tags': ['Generator'], 'output': 'sticker'}],
          },
          handler: (self, fn, args) => switch (fn) {
            'media.edit' => {'genres': [{'id': 'add', 'actions': [{'id': 'make', 'label': '作る'}]}]},
            'media.action' || 'media.cancel' => {},
            'media.commit' => {'bytesB64': base64Encode(png), 'mimeType': 'image/png'},
            _ => null,
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:g', bytes: Uint8List.fromList('g'.codeUnits));
    await settle(tester);
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
    final background = state.stateManager.activeBackgroundImage;
    // ステッカー一覧: パックは未インストール、ジェネレーターが並ぶ。
    final button = find.byKey(proMediaEditorBarKey('editor:sticker'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    expect(find.text('プラグインで作る'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sticker.generate.slot:t.g:qr')));
    await settle(tester);
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await settle(tester);
    expect(rt.calls.where((x) => x.$1 == 'media.commit').length, 1);
    expect(find.byType(MediaPluginPanel), findsNothing);
    // 背景はそのまま、レイヤーが 1 枚増える。
    expect(state.activeLayers.length, 1);
    expect(state.activeLayers.single, isA<WidgetLayer>());
    expect(identical(state.stateManager.activeBackgroundImage, background), isTrue);
  });

  testWidgets('macOS / iOS (D-253): 変更ありで × → 確認は Cupertino のダイアログ。例外にならず「やめる」で閉じる', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final c = await pump(tester);
      final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
      await settle(tester);
      final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
      state.addLayer(WidgetLayer(widget: const SizedBox(width: 10, height: 10))); // 変更あり → 閉じるときに確認が出る
      await settle(tester);
      state.closeEditor();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('加工をやめますか？'), findsOneWidget);
      await tester.tap(find.text('やめる'));
      await settle(tester);
      expect(await future, isNull);
      expect(find.byType(ProImageEditor), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('「ノート」(D-260): 加工画面から「ノート画像の追加」→ 選んだ投稿タイルがオブジェクト(レイヤー)として置かれる', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
    final button = find.byKey(proMediaEditorBarKey('editor:post'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    // 加工画面は下の FOW を退避させるが、この FOW は出る。
    expect(find.text('ノート画像の追加'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('postImage.post.p1')));
    await settle(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('postImage.confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('ノート画像の追加'), findsNothing);
    expect(state.activeLayers.single, isA<WidgetLayer>());
    expect(state.activeLayers.single.meta?['rasqPost'], isNotNull);
    expect(state.activeLayers.single.interaction.enableMove, isTrue);
    // オブジェクトを押す → フッターから編集の FOW (D-266)。静止画は不透明度だけ。「削除」でレイヤーが消える。
    await tester.tap(find.byType(RawImage).first);
    await settle(tester);
    expect(find.byKey(const ValueKey('mediaObject.opacity')), findsOneWidget);
    expect(find.byKey(const ValueKey('mediaObject.loop')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mediaObject.remove')));
    await settle(tester);
    expect(state.activeLayers, isEmpty);
  });

  testWidgets('加工画面で「ノート」を置いて × →「やめる」: 退避中のコンポーザーは書きかけのまま戻る。Escape でも閉じない', (tester) async {
    final c = await pump(tester);
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '書きかけの投稿');
    await tester.pump();
    final manager = c.read(overlayManagerProvider);
    final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
    await settle(tester);
    final button = find.byKey(proMediaEditorBarKey('editor:post'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('postImage.post.p1')));
    await settle(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('postImage.confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(tester.state<ProImageEditorState>(find.byType(ProImageEditor)).activeLayers, hasLength(1));
    // Escape(戻る)は、隠れているコンポーザーを閉じない。
    manager.handleBack();
    await settle(tester);
    expect(manager.contains('fow.composer'), isTrue);
    await tester.tap(find.byIcon(Icons.clear).first);
    await settle(tester);
    await tester.tap(find.text('やめる'));
    await settle(tester);
    expect(await future, isNull);
    expect(find.byType(ProImageEditor), findsNothing);
    expect(find.text('書きかけの投稿'), findsOneWidget);
  });

  test('mediaAccepts: MIME の型 / 完全一致 / 拡張子、空は image/*', () {
    expect(mediaAccepts(const [], mimeType: 'image/png'), isTrue);
    expect(mediaAccepts(const [], mimeType: 'video/mp4'), isFalse);
    expect(mediaAccepts(const ['video/*', 'audio/*'], mimeType: 'audio/mpeg'), isTrue);
    expect(mediaAccepts(const ['video/mp4'], mimeType: 'video/quicktime'), isFalse);
    expect(mediaAccepts(const ['.GIF'], mimeType: 'image/gif', name: 'Anim.gif'), isTrue);
    expect(mediaAccepts(const ['.gif'], mimeType: 'image/png', name: 'a.png'), isFalse);
    expect(mediaAccepts(const ['*/*'], mimeType: 'application/pdf'), isTrue);
  });
}
