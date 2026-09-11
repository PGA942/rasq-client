// 描画確認ハーネス (D-169): メディアエディター / インラインのプラグイン FOW を PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/plugin_preview_test.dart --update-goldens
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
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/post/share_fow.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

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

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', '今日は打ち上げ')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))],
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
            if (fn == 'media.edit') {
              self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png'});
              return {'genres': [
                {'id': 'tone', 'label': '色調', 'icon': 'tune', 'actions': [{'id': 'gamma', 'label': 'ガンマ', 'icon': 'brightness_6'}, {'id': 'hue', 'label': '色相', 'icon': 'palette'}, {'id': 'reset', 'label': 'リセット', 'icon': 'restart_alt'}]},
                {'id': 'transform', 'label': '変形', 'icon': 'rotate_right', 'actions': [{'id': 'rotl', 'label': '左回転', 'icon': 'rotate_left'}, {'id': 'rotr', 'label': '右回転', 'icon': 'rotate_right'}]},
                {'id': 'crop', 'label': 'クロップ', 'icon': 'crop', 'actions': [{'id': 'none', 'label': 'なし', 'icon': 'crop_free'}, {'id': 'center', 'label': '中央 1:1', 'icon': 'crop_square'}]},
              ]};
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
    await tester.tap(find.byKey(const ValueKey('media.action.gamma')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_param_fow.png'));
    await tester.tap(find.byKey(const ValueKey('media.editor.pick')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('media_editor_pick.png'));
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
}
