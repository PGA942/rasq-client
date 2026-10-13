import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show ProImageEditor;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/plugins/svg_paint_editor.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/column_takeover.dart';
import 'package:rasq_client/shell/extra_column.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLite;

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// D-472: 加工画面は 1 つで、添付の種類(MIME / 拡張子)で道具と下段バーを変える。SVG は SVG の道具(落書きの面)+ SVG を受ける
/// プラグインのボタンだけのバー(構成 `editor:svg`)。落書きの編集画面は、幅の広い画面ではカラムの隣に**もう 1 カラム**足して開く。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 10, 13), body: body);
  late Map<String, FakeSlotRuntime Function()> fakes;

  Future<ProviderContainer> pump(WidgetTester tester, {Size size = const Size(1080, 2340), double dpr = 3}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]))),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  setUp(() => fakes = {});

  const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400"><path d="M10 10L100 100" fill="none" stroke="#000000" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  /// 紙の上をなぞる。
  Future<void> stroke(WidgetTester tester) async {
    final canvas = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    final g = await tester.startGesture(canvas.center);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(canvas.center + Offset(i * 5.0, i * 3.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
  }

  group('モード (拡張子 / MIME)', () {
    test('添付の種類 → モードと下段バーの構成', () {
      expect(mediaEditorModeOf(mimeType: 'image/png'), MediaEditorMode.image);
      expect(mediaEditorModeOf(mimeType: 'image/svg+xml'), MediaEditorMode.svg);
      expect(mediaEditorModeOf(mimeType: 'application/octet-stream', name: 'Paint.SVG'), MediaEditorMode.svg, reason: '拡張子でも');
      expect(mediaEditorModeOf(mimeType: 'video/mp4'), MediaEditorMode.video);
      expect(mediaEditorModeOf(mimeType: 'audio/mpeg'), MediaEditorMode.audio);
      expect(editorConfigKeyFor('image/svg+xml'), editorSvgConfigKey);
      expect(editorConfigKeyFor('image/jpeg'), editorImageConfigKey);
      expect(editorConfigKeyFor('audio/aac'), editorVideoConfigKey);
      expect(editorBuiltinActionsFor(editorSvgConfigKey), isEmpty, reason: 'SVG の道具は紙の面。ラスターの編集も Visualizer も出ない');
      expect(builtinActionsFor(editorSvgConfigKey), isEmpty);
      expect(ProMediaEditorArgs.svg(aspect: '1:1').mode, MediaEditorMode.svg);
      expect(ProMediaEditorArgs(bytes: Uint8List(0), name: 'a.svg', mimeType: 'image/svg+xml').isSvg, isTrue);
      expect(ProMediaEditorArgs(bytes: Uint8List(0), name: 'a.png', mimeType: 'image/png').isSvg, isFalse);
    });

    test('SVG のバーに出るのは accepts に image/svg+xml / .svg を書いたものだけ(image/* や */* では出ない)', () {
      SlotActionDecl decl(List<String> accepts, {String? output}) => SlotActionDecl(id: 'x', label: 'x', icon: 'x', tags: const [], slot: SlotIds.composerMedia, accepts: accepts, output: output);
      expect(svgEditorAccepts(decl(['image/svg+xml'])), isTrue);
      expect(svgEditorAccepts(decl(['.SVG'])), isTrue);
      expect(svgEditorAccepts(decl(['image/*'])), isFalse);
      expect(svgEditorAccepts(decl(['*/*'])), isFalse);
      expect(svgEditorAccepts(decl(const [])), isFalse, reason: '省略 = image/*');
      expect(svgEditorAccepts(decl(['image/svg+xml'], output: 'sticker')), isFalse);
      expect(svgEditorAccepts(decl(['image/svg+xml'], output: 'filter')), isFalse);
    });

    test('添付の SVG の viewBox → 落書きの紙の縦横比(1〜16 の整数)', () {
      expect(nearestPaintAspect(300, 400), '3:4');
      expect(nearestPaintAspect(1920, 1080), '16:9');
      expect(nearestPaintAspect(100, 100), '1:1');
      expect(nearestPaintAspect(1000, 10), '16:1');
      expect(nearestPaintAspect(0, 10), '3:4');
    });
  });

  testWidgets('添付の SVG は SVG モード: pro_image_editor は出ず、SVG を受けるプラグインが無ければバーも無い。完了で SVG の添付が返る', (tester) async {
    final c = await pump(tester);
    final result = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: Uint8List.fromList(utf8.encode(svg)), name: 'drawing.svg', mimeType: 'image/svg+xml'));
    await tester.pumpAndSettle();
    expect(find.byKey(proMediaEditorSvgKey), findsOneWidget);
    expect(find.byType(SvgPaintEditor), findsOneWidget);
    expect(find.byType(ProImageEditor), findsNothing);
    expect(find.byKey(proMediaEditorSvgBarKey), findsNothing);
    expect(find.text('drawing.svg'), findsOneWidget, reason: '見出しはファイル名');
    await stroke(tester);
    await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
    await tester.pumpAndSettle();
    final r = await result;
    expect(r, isNotNull);
    expect((r!.mimeType, r.name), ('image/svg+xml', 'drawing.svg'));
    final doc = SvgLite.parse(utf8.decode(r.bytes))!;
    expect(doc.viewBox.size, const Size(300, 400));
    expect(doc.shapes.length, 2, reason: '元の線 + なぞった線');
  });

  testWidgets('SVG を受けるプラグインのボタン: そのときの絵を SVG で media.edit に渡し、返った SVG(消毒)で紙を描き直す。ほかのボタンは出ない', (tester) async {
    late FakeSlotRuntime rt;
    const added = '<path d="M1 1L299 399" fill="none" stroke="#e53935" stroke-width="10"/>';
    fakes['s'] = () => rt = FakeSlotRuntime(
          manifest: {
            'id': 't.s', 'name': 'SVG 加工', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
            'actions': [
              {'id': 'frame', 'slot': 'composer.media', 'label': '枠', 'icon': 'crop_square', 'tags': ['Frame'], 'accepts': ['image/svg+xml']},
              {'id': 'raster', 'slot': 'composer.media', 'label': 'ラスター', 'tags': ['Filter'], 'accepts': ['image/*']},
              {'id': 'wave', 'slot': 'composer.media', 'label': '波形', 'tags': ['Audio'], 'accepts': ['audio/*', 'video/*']},
            ],
          },
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.edit':
                return {'genres': [{'id': 'add', 'actions': [{'id': 'frame', 'label': '枠'}]}]};
              case 'media.action' || 'media.cancel':
                return {};
              case 'media.commit':
                final input = utf8.decode(base64Decode(self.calls.where((x) => x.$1 == 'media.edit').last.$2['bytesB64'] as String));
                // 返す SVG にスクリプトを混ぜても、ホストが消毒する。
                return {'bytesB64': base64Encode(utf8.encode(input.replaceFirst('</svg>', '$added<script>alert(1)</script></svg>'))), 'mimeType': 'image/svg+xml', 'name': 'framed.svg'};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:s', bytes: Uint8List.fromList('s'.codeUnits));
    await tester.pumpAndSettle();
    expect(c.read(pluginActionsForProvider(editorSvgConfigKey)).map((a) => a.decl.id), ['frame']);
    late BuildContext ctx;
    await tester.runAsync(() async {});
    ctx = tester.element(find.byType(HomeScreen));
    final h = openSvgPaintEditor(ctx, aspect: '3:4', svg: svg, title: '落書き');
    await tester.pumpAndSettle();
    final bar = find.byKey(proMediaEditorSvgBarKey);
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byKey(proMediaEditorBarKey('slot:t.s:frame'))), findsOneWidget);
    for (final id in ['slot:t.s:raster', 'slot:t.s:wave', 'editor:cropRotate', 'editor:paint', editorVisualizerActionId]) {
      expect(find.byKey(proMediaEditorBarKey(id)), findsNothing, reason: id);
    }
    expect(find.byKey(proMediaEditorBarEditKey), findsOneWidget, reason: 'バーの編集は同じ仕組み');

    await stroke(tester);
    await tester.tap(find.byKey(proMediaEditorBarKey('slot:t.s:frame')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    expect(find.byType(SvgPaintEditor), findsOneWidget, reason: '「完了」で絵を受けても閉じない');
    final edit = rt.calls.where((x) => x.$1 == 'media.edit').single.$2;
    expect((edit['mimeType'], edit['name'], edit['width'], edit['height'], edit['actionId']), ('image/svg+xml', 'paint.svg', 300, 400, 'frame'));
    final sent = SvgLite.parse(utf8.decode(base64Decode(edit['bytesB64'] as String)))!;
    expect(sent.shapes.length, 2, reason: '元の線 + なぞった線');
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPluginPanel), findsNothing);
    expect(find.byType(SvgPaintEditor), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
    await tester.pumpAndSettle();
    final r = await h.result;
    expect(r, isNotNull);
    final out = SvgLite.parse(r!.svg)!;
    expect(out.shapes.length, 3, reason: 'プラグインが足した線も');
    expect(r.svg, isNot(contains('script')));
    expect(r.svg.toLowerCase(), contains('#e53935'));
  });

  group('もう 1 カラム (幅の広い画面)', () {
    testWidgets('ホームのカラムのページから: 第2カラムの右にもう 1 カラム足して開く(ほかのカラムは残る)。フォーカスは編集画面へ、キャンセルで閉じる', (tester) async {
      final c = await pump(tester, size: const Size(1600, 1000), dpr: 1);
      final homeBefore = tester.getRect(find.byType(HomeScreen));
      final h = openSvgPaintEditor(tester.element(find.byType(HomeScreen)), aspect: '3:4');
      await tester.pumpAndSettle();
      expect(c.read(extraColumnProvider)?.afterColumn, 0);
      expect(c.read(columnTakeoverProvider), isEmpty, reason: 'カラムを置き換えない');
      final extra = tester.getRect(find.byKey(const ValueKey('shell.extraColumn')));
      final home = tester.getRect(find.byType(HomeScreen));
      final third = tester.getRect(find.byType(ThirdColumnView));
      expect(home.width, lessThan(homeBefore.width), reason: '足したぶん縮む');
      expect(extra.left, closeTo(home.right, 1), reason: 'ホームのカラムのすぐ右');
      expect(third.left, greaterThanOrEqualTo(extra.right - 1), reason: '第3カラムはその右に残る');
      expect(find.byType(HomeScreen).hitTestable(), findsOneWidget, reason: 'ページは隠れない');
      final canvas = find.byKey(const ValueKey('svgpaint.canvas'));
      expect(canvas.hitTestable(), findsOneWidget, reason: '編集画面は見えて、押せる');
      expect(extra.contains(tester.getCenter(canvas)), isTrue);
      expect(c.read(extraColumnProvider)!.focus.hasFocus, isTrue, reason: 'フォーカスは編集画面へ');
      await tester.tap(find.byKey(const ValueKey('svgpaint.cancel')));
      await tester.pumpAndSettle();
      expect(await h.result, isNull);
      expect(c.read(extraColumnProvider), isNull);
      expect(find.byKey(const ValueKey('shell.extraColumn')), findsNothing);
      expect(tester.getRect(find.byType(HomeScreen)).width, closeTo(homeBefore.width, 1));
    });

    testWidgets('第3カラムのページ(右のカラムの Swing など)から: いちばん右にもう 1 カラム。描いて完了 → 結果、外から閉じる口でも閉じる', (tester) async {
      final c = await pump(tester, size: const Size(1600, 1000), dpr: 1);
      late BuildContext pane;
      openPageInPanes(
        tester.element(find.byType(HomeScreen)),
        id: 'test.page',
        title: 'ページ',
        location: '/home',
        builder: (ctx) {
          pane = ctx;
          return const Center(key: ValueKey('test.page'), child: Text('右のカラムのページ'));
        },
      );
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byKey(const ValueKey('test.page')));
      var h = openSvgPaintEditor(pane, aspect: '1:1');
      await tester.pumpAndSettle();
      expect(c.read(extraColumnProvider)?.afterColumn, 1);
      final extra = tester.getRect(find.byKey(const ValueKey('shell.extraColumn')));
      expect(extra.right, closeTo(1600, 1), reason: 'いちばん右');
      expect(tester.getRect(find.byKey(const ValueKey('test.page'))).right, closeTo(extra.left, 1), reason: 'ページのすぐ右(ページは縮んで残る)');
      expect(tester.getRect(find.byKey(const ValueKey('test.page'))).width, lessThan(page.width));
      expect(find.text('右のカラムのページ').hitTestable(), findsOneWidget);
      await stroke(tester);
      await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
      await tester.pumpAndSettle();
      final r = await h.result;
      expect(r?.svg, contains('<path'));
      expect(c.read(extraColumnProvider), isNull);

      h = openSvgPaintEditor(pane, aspect: '1:1');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shell.extraColumn')), findsOneWidget);
      h.close();
      await tester.pumpAndSettle();
      expect(await h.result, isNull);
      expect(find.byKey(const ValueKey('shell.extraColumn')), findsNothing);
    });

    testWidgets('D-468 の回帰: カラムの上に全画面のルートが被っていたら、カラムには出さず全画面のルートで開く(下に隠れない)', (tester) async {
      final c = await pump(tester, size: const Size(1600, 1000), dpr: 1);
      final home = tester.element(find.byType(HomeScreen));
      // 全画面のルート(設定)をカラムの上に重ねる。
      unawaited(c.read(routerProvider).push<Object?>(Routes.settings));
      await tester.pumpAndSettle();
      final h = openSvgPaintEditor(home, aspect: '3:4');
      await tester.pumpAndSettle();
      expect(c.read(extraColumnProvider), isNull, reason: 'カラムに出すと全画面のルートの下に隠れる');
      final canvas = find.byKey(const ValueKey('svgpaint.canvas'));
      expect(canvas.hitTestable(), findsOneWidget, reason: '編集画面はいちばん上');
      await tester.tap(find.byKey(const ValueKey('svgpaint.cancel')));
      await tester.pumpAndSettle();
      expect(await h.result, isNull);
    });

    testWidgets('開いたまま狭い画面になったら、全画面に重ねて出す(描きかけはそのまま)。戻すとまたカラム', (tester) async {
      final c = await pump(tester, size: const Size(1600, 1000), dpr: 1);
      final h = openSvgPaintEditor(tester.element(find.byType(HomeScreen)), aspect: '3:4');
      await tester.pumpAndSettle();
      await stroke(tester);
      tester.view.physicalSize = const Size(400, 860);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shell.extraColumn')), findsNothing);
      final canvas = find.byKey(const ValueKey('svgpaint.canvas'));
      expect(canvas.hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(1600, 1000);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shell.extraColumn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('svgpaint.done')));
      await tester.pumpAndSettle();
      final r = await h.result;
      expect(SvgLite.parse(r!.svg)!.shapes, hasLength(1), reason: '狭い画面へ移っても描きかけの線は残る');
      expect(c.read(extraColumnProvider), isNull);
    });
  });

  test('extraColumnWidth: 中身の 36%(320〜520)、半分まで', () {
    expect(extraColumnWidth(1528), closeTo(520, 0.01));
    expect(extraColumnWidth(1000), closeTo(360, 0.01));
    expect(extraColumnWidth(800), closeTo(320, 0.01));
    expect(extraColumnWidth(500), closeTo(250, 0.01));
  });
}
