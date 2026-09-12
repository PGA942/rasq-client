// 描画確認ハーネス (D-169): メディアエディター / インラインのプラグイン FOW を PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/plugin_preview_test.dart --update-goldens
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui' show PictureRecorder, Canvas, ImageByteFormat;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_editor_screen.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/post/share_fow.dart';
import 'package:rasq_client/features/compose/drafts_fow.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fake_rai_llm.dart';
import '../../test/support/fake_slot_runtime.dart';
import '../../test/support/fakes.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);
  final fakes = <String, FakeSlotRuntime Function()>{};

  Future<ProviderContainer> pump(WidgetTester tester, {List<Post>? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts ?? [post('p1', '今日は打ち上げ')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)), raiLlmProvider.overrideWithValue(FakeRaiLlm(phase: RaiLlmPhase.ready)), deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 3000))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  // 実写風の代わりに 480×320 のグラデーション PNG(testWidgets の FakeAsync では toImage が進まないので setUpAll で)。
  late Uint8List png;
  setUpAll(() async {
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 320), Paint()..shader = const LinearGradient(colors: [Color(0xFFF09286), Color(0xFF02EFFD)]).createShader(const Rect.fromLTWH(0, 0, 480, 320)));
    canvas.drawCircle(const Offset(240, 160), 90, Paint()..color = const Color(0xFFF6E359));
    final img = await rec.endRecording().toImage(480, 320);
    png = (await img.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
  });

  testWidgets('media editor + inline hashtag fow', (tester) async {
    fakes['media'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.composer-media', 'name': 'メディア加工', 'version': '0.2.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            final catalog = {'genres': [
              {'id': 'tone', 'actions': [{'id': 'gamma', 'label': 'ガンマ', 'icon': 'brightness_6'}, {'id': 'hue', 'label': '色相', 'icon': 'palette'}, {'id': 'reset', 'label': 'リセット', 'icon': 'restart_alt'}]},
              {'id': 'process', 'actions': [{'id': 'gray', 'label': 'グレースケール', 'icon': 'filter_b_and_w'}, {'id': 'invert', 'label': 'ネガ反転', 'icon': 'invert_colors'}]},
              {'id': 'transform', 'actions': [{'id': 'rotl', 'label': '左回転', 'icon': 'rotate_left'}, {'id': 'rotr', 'label': '右回転', 'icon': 'rotate_right'}, {'id': 'crop_center', 'label': '中央 1:1', 'icon': 'crop_square'}, {'id': 'crop_top', 'label': '上 4:3', 'icon': 'crop_landscape'}]},
            ]};
            if (fn == 'media.catalog') return catalog;
            if (fn == 'media.edit') {
              self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png'});
              return catalog;
            }
            if (fn == 'media.action') {
              if (args['action'] == 'gamma') self.openFow('media-param', {'t': 'Column', 'k': 'root', 'c': [{'t': 'SliderListTile', 'k': 'gamma', 'p': {'title': 'ガンマ', 'value': 1.4, 'min': 0.3, 'max': 3.0, 'divisions': 27}, 'on': {'change': 'gammaChanged'}}, {'t': 'Button', 'k': 'close', 'p': {'label': '閉じる'}, 'on': {'tap': 'closeParam'}}]}, title: 'ガンマ');
              return {};
            }
            return {};
          },
        );
    fakes['text'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.composer-text', 'name': 'ハッシュタグ候補', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.text'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            if (fn == 'text.changed' && (args['trigger'] as String?)?.startsWith('#') == true) {
              self.openFow('hashtag-suggest', {'t': 'Column', 'k': 'root', 'c': [
                {'t': 'Text', 'k': 'hint', 'p': {'text': '${args['trigger']} の候補(最近使ったタグ + 辞書)'}},
                for (final t in ['打上会', '打ち上げ反省会', '打楽器']) {'t': 'ListTile', 'k': 't-$t', 'p': {'title': '#$t', 'subtitle': '辞書'}, 'on': {'tap': 'pick.$t'}},
              ]}, title: 'ハッシュタグ候補');
            }
            return {};
          },
        );
    final c = await pump(tester);
    final media = await c.read(slotPluginsProvider.notifier).register('fake:media', bytes: Uint8List.fromList('media'.codeUnits));
    await c.read(slotPluginsProvider.notifier).register('fake:text', bytes: Uint8List.fromList('text'.codeUnits));
    await tester.pumpAndSettle();
    // コンポーザーで # → インライン FOW(コンポーザーの子)。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '打ち上げ成功！ #打');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('composer_hashtag_inline_fow.png'));
    // メディアエディター。
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditor, extra: MediaEditorArgs(plugin: media!, bytes: png, name: 'photo.png', mimeType: 'image/png'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor.png'));
    // 横リストは中央から始まる (D-172) ので、左端のガンマまで戻す。
    final strip = find.descendant(of: find.byKey(mediaEditorStripKey), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('media.action.sample.composer-media.tone.gamma')), -60, scrollable: strip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media.action.sample.composer-media.tone.gamma')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_param_fow.png'));
    await tester.tap(find.byKey(const ValueKey('media.editor.pick')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_pick.png'));
    await tester.tap(find.text('ジャンル'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_genre.png'));
  });

  testWidgets('post share fow + inline plugin fow (D-170)', (tester) async {
    fakes['share'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.post-share', 'name': '共有テンプレート(サンプル)', 'version': '0.1.0', 'kind': 'action', 'description': '投稿をテンプレート(リンクのみ / 引用 / 作者に言及)で整えてコンポーザー・コピー・AsTell へ', 'slots': ['post.share'], 'permissions': ['fow.widget', 'storage.safe']},
          handler: (self, fn, args) {
            if (fn == 'post.share') {
              final link = '${args['link']}';
              self.openFow('share-template', {'t': 'Column', 'k': 'root', 'c': [
                {'t': 'Text', 'k': 'author', 'p': {'text': '作者: テスター', 'bold': true}},
                {'t': 'Text', 'k': 'body', 'p': {'text': '今日は打ち上げ'}},
                {'t': 'Text', 'k': 'sec', 'p': {'text': 'テンプレート'}},
                {'t': 'ListTile', 'k': 'tpl-link', 'p': {'title': '　 リンクのみ'}, 'on': {'tap': 'tpl.link'}},
                {'t': 'ListTile', 'k': 'tpl-quote', 'p': {'title': '✓ 引用(本文つき)'}, 'on': {'tap': 'tpl.quote'}},
                {'t': 'ListTile', 'k': 'tpl-mention', 'p': {'title': '　 作者に言及'}, 'on': {'tap': 'tpl.mention'}},
                {'t': 'Text', 'k': 'sec2', 'p': {'text': '文面'}},
                {'t': 'Text', 'k': 'result', 'p': {'text': '「今日は打ち上げ」\n$link'}},
                {'t': 'Row', 'k': 'row', 'c': [
                  {'t': 'Button', 'k': 'go', 'p': {'label': 'コンポーザーへ'}, 'on': {'tap': 'share.composer'}},
                  {'t': 'Button', 'k': 'copy', 'p': {'label': 'コピー'}, 'on': {'tap': 'share.copy'}},
                ]},
              ]}, title: '共有テンプレート');
            }
            return {};
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:share', bytes: Uint8List.fromList('share'.codeUnits));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('post_share_fow.png'));
    await tester.tap(find.byKey(const ValueKey('post.share.plugin.sample.post-share')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('post_share_plugin_inline_fow.png'));
    // 他のアカウントで共有 → コンポーザー(アカウントピル)。
    c.read(overlayManagerProvider).close(postShareFowId);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post.share.otherAccount')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('composer_account_pill.png'));
  });

  testWidgets('media editor overlay handles (D-172)', (tester) async {
    fakes['tf'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.media-transform', 'name': '変形ハンドル', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            final catalog = {'genres': [{'id': 'transform', 'actions': [{'id': 'rotate', 'label': '回転', 'icon': 'rotate_right'}, {'id': 'crop', 'label': 'クロップ', 'icon': 'crop'}, {'id': 'reset', 'label': 'リセット', 'icon': 'restart_alt'}]}]};
            if (fn == 'media.catalog') return catalog;
            if (fn == 'media.edit') {
              self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png', 'width': 480, 'height': 320});
              return catalog;
            }
            if (fn == 'media.action' && args['action'] == 'crop') {
              const l = 60.0, t = 40.0, r = 400.0, b = 280.0;
              Map<String, Object?> handle(String k, double x, double y) => {'t': 'Box', 'k': k, 'p': {'left': x - 12, 'top': y - 12, 'width': 24, 'height': 24, 'color': '#ffffff', 'borderColor': '#1e88e5', 'borderWidth': 2, 'radius': 12}, 'on': {'drag': 'crop.$k'}};
              self.hostFn('composer.media.overlay', {'token': args['token'], 'root': {'t': 'Stack', 'k': 'ov', 'p': {'width': 480, 'height': 320}, 'c': [
                {'t': 'Box', 'k': 'dim-t', 'p': {'left': 0, 'top': 0, 'width': 480, 'height': t, 'color': '#00000088'}},
                {'t': 'Box', 'k': 'dim-b', 'p': {'left': 0, 'top': b, 'width': 480, 'height': 320 - b, 'color': '#00000088'}},
                {'t': 'Box', 'k': 'dim-l', 'p': {'left': 0, 'top': t, 'width': l, 'height': b - t, 'color': '#00000088'}},
                {'t': 'Box', 'k': 'dim-r', 'p': {'left': r, 'top': t, 'width': 480 - r, 'height': b - t, 'color': '#00000088'}},
                {'t': 'Box', 'k': 'rect', 'p': {'left': l, 'top': t, 'width': r - l, 'height': b - t, 'color': '#00000000', 'borderColor': '#ffffff', 'borderWidth': 2}},
                handle('tl', l, t), handle('tr', r, t), handle('bl', l, b), handle('br', r, b),
              ]}});
            }
            return {};
          },
        );
    final c = await pump(tester);
    final tf = await c.read(slotPluginsProvider.notifier).register('fake:tf', bytes: Uint8List.fromList('tf'.codeUnits));
    await tester.pumpAndSettle();
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditor, extra: MediaEditorArgs(plugin: tf!, bytes: png, name: 'photo.png', mimeType: 'image/png'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media.action.sample.media-transform.transform.crop')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_crop_overlay.png'));
  });

  testWidgets('pro_image_editor with plugin bypass button (D-173)', (tester) async {
    fakes['m'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.composer-media', 'name': 'メディア加工', 'version': '0.3.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) => {'genres': []},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:m', bytes: Uint8List.fromList('m'.codeUnits));
    await tester.pumpAndSettle();
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'photo.png', mimeType: 'image/png'));
    // 画像の復号は本物の非同期なので runAsync で待つ。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.byKey(proMediaEditorPluginKey));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_pro.png'));
  });

  testWidgets('snap targets highlight (D-174)', (tester) async {
    fakes['snap'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.media-process', 'name': '加工', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            final catalog = {'genres': [{'id': 'process', 'actions': [{'id': 'sticker', 'label': 'スタンプ', 'icon': 'emoji_emotions'}, {'id': 'reset', 'label': 'リセット', 'icon': 'restart_alt'}]}]};
            if (fn == 'media.catalog') return catalog;
            if (fn == 'media.edit') {
              self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png', 'width': 480, 'height': 320});
              return catalog;
            }
            if (fn == 'media.action') {
              self.hostFn('composer.media.overlay', {'token': args['token'], 'root': {'t': 'Stack', 'k': 'ov', 'p': {'width': 480, 'height': 320}, 'c': [
                {'t': 'Box', 'k': 'face.0', 'p': {'left': 300, 'top': 60, 'width': 120, 'height': 120, 'label': '顔 1', 'color': '#00000000', 'borderColor': '#ffffffaa', 'borderWidth': 1}, 'on': {'tap': 'face.0'}},
                {'t': 'Box', 'k': 'obj.0', 'p': {'left': 60, 'top': 100, 'width': 100, 'height': 100, 'label': 'スタンプ 1', 'angle': 20, 'color': '#ffd60088', 'borderColor': '#ffffff', 'borderWidth': 2}, 'on': {'drag': 'obj.0.move'}},
              ]}});
            }
            return {};
          },
        );
    final c = await pump(tester);
    final p = await c.read(slotPluginsProvider.notifier).register('fake:snap', bytes: Uint8List.fromList('snap'.codeUnits));
    await tester.pumpAndSettle();
    c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditor, extra: MediaEditorArgs(plugin: p!, bytes: png, name: 'photo.png', mimeType: 'image/png'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media.action.sample.media-process.process.sticker')));
    await tester.pumpAndSettle();
    final ov = tester.getRect(find.byKey(mediaEditorOverlayKey));
    final scale = ov.width / 480;
    final at = ov.topLeft + Offset(360 * scale, 120 * scale);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_snap_menu.png'));
    await tester.tap(find.text('この上にドラッグ(合わせる先にする)'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_snap_target.png'));
  });

  testWidgets('plugin action bundle + edit sheet + drafts fow (D-176)', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {
            'id': 'sample.post-action', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'],
            'actions': [
              {'id': 'later', 'label': '後で読む', 'icon': 'bookmark', 'tags': ['Favorite', 'Bookmark', 'Star']},
              {'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']},
              {'id': 'quoteDraft', 'label': '引用の下書き', 'icon': 'format_quote', 'tags': ['Quote', 'Repost']},
            ],
          },
          handler: (self, fn, args) => {'result': {'done': true}},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('action_bundle_plugin.png'));
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションバーを編集'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('action_bar_edit_plugins.png'));
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    // 下書き FOW。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '明日の打ち上げの写真、あとで整理してから出す');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drafts.save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '週末の予定');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('drafts_fow.png'));
    await tester.tap(find.byKey(draftsSelectKey));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('drafts_fow_select.png'));
  });

  testWidgets('close popup choices + thread media all + profile image viewer (D-177)', (tester) async {
    // 画像 URL は全部グラデーション PNG を返す(debug 用のフック)。
    debugNetworkImageHttpClientProvider = () => _PngHttpClient(png);
    final author = UserSummary(id: 'u1', account: acc, displayName: 'テスター', avatarUrl: Uri.parse('https://example.test/avatar.png'));
    final withMedia = Post(
      id: 'p1',
      account: acc,
      author: author,
      createdAt: DateTime(2026, 8, 31),
      body: '打ち上げの写真、6 枚まとめて',
      media: [for (var i = 0; i < 6; i++) MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://example.test/$i.png'))],
    );
    await pump(tester, posts: [withMedia]);
    await tester.tap(find.text('打ち上げの写真、6 枚まとめて'));
    await tester.pumpAndSettle();
    // 画像の復号は本物の非同期(FakeAsync では進まない)。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(RasqApp), matchesGoldenFile('thread_media_all.png'));
    // 作者名 → プロフィール → アイコン → 全画面。
    await tester.tap(find.text('テスター').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqUserTileLarge), matching: find.byType(RasqAvatar)));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(RasqApp), matchesGoldenFile('profile_image_viewer.png'));
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    // 下書きを開いて直してからキャンセル → 上書き / 新規保存 / 変更を破棄 / キャンセル。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '明日の打ち上げの写真、あとで整理してから出す');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drafts.save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('明日の打ち上げの写真、あとで整理してから出す'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '明日の打ち上げの写真、整理できたので出す');
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('composer_close_overwrite.png'));
    debugNetworkImageHttpClientProvider = null; // テスト本体の中で戻す(不変条件の検査は tearDown より前)
  });

  testWidgets('RAi home + instruction pointing (D-179)', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // アイコン(asset)の復号
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('sidebar_rai.png'));
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('rai_home.png'));
    await tester.tap(find.byKey(const ValueKey('rai.models.open')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('rai_models_fow.png'));
    await tester.tap(find.text('閉じる').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('rai_bar_asking.png'));
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('rai_instruction.png'));
    await tester.tap(find.byKey(const ValueKey('rai.history')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('rai_history_fow.png'));
  });
}

/// プレビュー用: どの URL にも同じ PNG を 200 で返す HttpClient(`debugNetworkImageHttpClientProvider`)。
class _PngHttpClient implements HttpClient {
  _PngHttpClient(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PngRequest(bytes);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _PngRequest(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PngRequest implements HttpClientRequest {
  _PngRequest(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _PngResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PngResponse extends Stream<List<int>> implements HttpClientResponse {
  _PngResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
