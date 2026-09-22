import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_filter.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// カスタムフィルター (D-255、契約 v0.12): 描画リストの読み取り / 描画、ON / OFF、完了時の overlay = 焼き込み・pixels = filter.apply。
void main() {
  test('描画リストの読み取り: 形の違う op は捨てる、色 / 合成 / 上限、mode と matrix', () {
    final spec = parseMediaFilterSpec({
      'mode': 'pixels',
      'matrix': List.filled(20, 0.5),
      'ops': [
        {'op': 'rect', 'x': 0, 'y': 0, 'w': 1, 'h': 1, 'color': '#FF8800', 'opacity': 0.2, 'blend': 'overlay'},
        {'op': 'ring', 'x': 0.5, 'y': 0.5, 'r': 0.3, 'width': 0.02, 'color': '#80FFFFFF', 'blend': 'plus', 'blur': 9},
        {'op': 'star', 'x': 0, 'y': 0, 'color': '#FFFFFF'}, // 知らない op
        {'op': 'circle', 'x': 0.5, 'y': 0.5, 'r': 0.1, 'color': 'red'}, // 色が読めない
        'junk',
      ],
    })!;
    expect(spec.mode, MediaFilterMode.pixels);
    expect(spec.matrix, hasLength(20));
    expect(spec.ops.map((o) => (o.kind, o.blend)), [('rect', BlendMode.overlay), ('ring', BlendMode.plus)]);
    expect((spec.ops[0].color, spec.ops[0].opacity), (const Color(0xFFFF8800), 0.2));
    expect((spec.ops[1].color, spec.ops[1].blur), (const Color(0x80FFFFFF), 1.0)); // blur は 0..1 に丸める
    expect(parseMediaFilterSpec({'ops': []})!.mode, MediaFilterMode.overlay); // 既定はレイヤー重ね
    expect(parseMediaFilterSpec('nope'), isNull);
    final many = parseMediaFilterSpec({'ops': [for (var i = 0; i < mediaFilterMaxOps + 7; i++) {'op': 'circle', 'x': 0.5, 'y': 0.5, 'r': 0.01, 'color': '#FFFFFF'}]})!;
    expect((many.ops.length, many.dropped), (mediaFilterMaxOps, 7));
    expect(parseFilterColor('#12'), isNull);
  });

  test('パラメーターとオブジェクト (v0.13): 範囲に丸める、形の違うものは捨てる、オブジェクトは pixels にならない', () {
    final spec = parseMediaFilterSpec({
      'mode': 'pixels',
      'object': {'x': 0.5, 'y': 0.3, 'size': 0.7},
      'params': [
        {'id': 'count', 'label': '個数', 'min': 4, 'max': 80, 'step': 1, 'value': 500},
        {'id': 'strength', 'min': 0, 'max': 1, 'step': 0.05, 'value': 0.5},
        {'id': 'count', 'min': 0, 'max': 1}, // 同じ id
        {'id': 'bad', 'min': 3, 'max': 3}, // 幅が無い
        'junk',
      ],
      'ops': [{'op': 'ring', 'x': 0.5, 'y': 0.5, 'r': 0.4, 'width': 0.05, 'color': '#FFFFFF'}],
    })!;
    expect(spec.params.map((p) => (p.id, p.label, p.value, p.divisions)), [('count', '個数', 80.0, 76), ('strength', 'strength', 0.5, 20)]);
    expect((spec.params[0].format(12.4), spec.params[1].format(0.35)), ('12', '0.35'));
    expect((spec.object!.x, spec.object!.y, spec.object!.size), (0.5, 0.3, 0.7));
    expect(spec.mode, MediaFilterMode.overlay);
    expect(parseMediaFilterSpec({'ops': []})!.object, isNull);
  });

  testWidgets('描画: 座標は絵に対する 0..1(大きさが違っても同じ場所)、マトリックス状の配置', (tester) async {
    // 4×4 の格子の左上の 2 マスにだけ白い四角 + 中央に赤い丸。
    final spec = parseMediaFilterSpec({
      'ops': [
        for (var gy = 0; gy < 2; gy++) {'op': 'rect', 'x': 0.0, 'y': gy * 0.25, 'w': 0.25, 'h': 0.25, 'color': '#FFFFFF'},
        {'op': 'circle', 'x': 0.5, 'y': 0.5, 'r': 0.1, 'color': '#FF0000'},
      ],
    })!;
    await tester.runAsync(() async {
      for (final (w, h) in [(200, 100), (800, 400)]) {
        final img = await renderMediaFilter(spec, w, h, background: const Color(0xFF000000));
        final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        (int, int, int) px(double fx, double fy) {
          final o = ((fy * h).floor() * w + (fx * w).floor()) * 4;
          return (d.getUint8(o), d.getUint8(o + 1), d.getUint8(o + 2));
        }

        expect(px(0.1, 0.1), (255, 255, 255), reason: '$w×$h');
        expect(px(0.1, 0.4), (255, 255, 255));
        expect(px(0.1, 0.6), (0, 0, 0));
        expect(px(0.5, 0.5), (255, 0, 0));
        expect(px(0.9, 0.9), (0, 0, 0));
      }
    });
  });

  group('加工画面', () {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    // 2×1 の PNG(赤 / 青)。
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=');
    late Map<String, FakeSlotRuntime Function()> fakes;
    setUp(() => fakes = {});

    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 19), body: 'こんにちは')]));
      await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))], child: const RasqApp()));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('ON / OFF と完了: overlay はレイヤーとして焼き込まれ(プラグインは呼ばれない)、pixels は外してから filter.apply、失敗は伝える', (tester) async {
      late FakeSlotRuntime rt;
      final applied = Uint8List.fromList([...png]);
      fakes['f'] = () => rt = FakeSlotRuntime(
            manifest: {
              'id': 't.f', 'name': 'フィルター', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
              'actions': [
                {'id': 'halo', 'slot': 'composer.media', 'label': '光輪', 'icon': 'flare', 'tags': ['Halo'], 'output': 'filter'},
                {'id': 'glaze', 'slot': 'composer.media', 'label': 'Glaze', 'icon': 'auto_awesome', 'tags': ['Glaze'], 'output': 'filter'},
                {'id': 'broken', 'slot': 'composer.media', 'label': 'こわれ', 'tags': ['Broken'], 'output': 'filter'},
              ],
            },
            handler: (self, fn, args) {
              if (fn == 'filter.preview') {
                return {
                  'mode': args['actionId'] == 'halo' ? 'overlay' : 'pixels',
                  'ops': [{'op': 'ring', 'x': 0.5, 'y': 0.5, 'r': 0.3, 'width': 0.05, 'color': '#FFE9A8', 'blend': 'plus'}],
                };
              }
              if (fn == 'filter.apply') return args['actionId'] == 'broken' ? null : {'bytesB64': base64Encode(applied), 'mimeType': 'image/png'};
              return null;
            },
          );
      final c = await pump(tester);
      await c.read(slotPluginsProvider.notifier).register('fake:f', bytes: Uint8List.fromList('f'.codeUnits));
      await settle(tester);
      final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
      await settle(tester);
      final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
      Future<void> press(String id) async {
        final b = find.byKey(proMediaEditorBarKey('slot:t.f:$id'));
        await tester.ensureVisible(b);
        await settle(tester);
        await tester.tap(b);
        await settle(tester);
      }

      // ON: パネルは開かず、動かせないレイヤーが 1 枚。seed と絵の大きさが渡る。
      await press('halo');
      expect(find.byType(MediaPluginPanel), findsNothing);
      expect(state.activeLayers.length, 1);
      final layer = state.activeLayers.single;
      expect((layer.interaction.enableMove, layer.interaction.enableSelection), (false, false));
      final preview = rt.calls.where((x) => x.$1 == 'filter.preview').single.$2;
      expect((preview['actionId'], preview['width'], preview['height'], preview['seed'] is int), ('halo', 2, 1, true));
      // OFF → ON し直すと seed は変わる(別の掛け直し)。
      await press('halo');
      expect(state.activeLayers, isEmpty);
      await press('halo');
      await press('glaze');
      await press('broken');
      expect(state.activeLayers.length, 3);

      state.doneEditing();
      await settle(tester);
      await settle(tester);
      final result = (await future)!;
      // pixels の 2 つが押した順に apply(overlay の halo は呼ばれない)。失敗した「こわれ」は飛ばして伝える。
      final applies = [for (final x in rt.calls.where((x) => x.$1 == 'filter.apply')) x.$2];
      expect(applies.map((a) => a['actionId']), ['glaze', 'broken']);
      expect(applies.first['seed'], rt.calls.where((x) => x.$1 == 'filter.preview' && x.$2['actionId'] == 'glaze').single.$2['seed']);
      expect((applies.first['bytesB64'] as String).startsWith('iVBORw0KGgo'), isTrue); // 焼き込んだ PNG が渡る
      expect(applies[1]['bytesB64'], base64Encode(applied)); // 前のフィルターの結果が次の入力(直列)
      expect(result.bytes, applied);
      expect(find.textContaining('適用できなかったフィルター: こわれ'), findsOneWidget);
    });
    testWidgets('overlay の焼き込み: レイヤーは絵いっぱいに重なる(四隅と中央がフィルターの色、縦横比が違う op も絵の座標どおり)', (tester) async {
      fakes['o'] = () => FakeSlotRuntime(
            manifest: {
              'id': 't.o', 'name': '重ね', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
              'actions': [{'id': 'tint', 'slot': 'composer.media', 'label': '色', 'tags': ['Tint'], 'output': 'filter'}],
            },
            // 全面をマゼンタで塗り、左半分にだけ緑を重ねる。
            handler: (self, fn, args) => fn == 'filter.preview'
                ? {'mode': 'overlay', 'ops': [{'op': 'rect', 'x': 0, 'y': 0, 'w': 1, 'h': 1, 'color': '#FF00FF'}, {'op': 'rect', 'x': 0, 'y': 0, 'w': 0.5, 'h': 1, 'color': '#00FF00'}]}
                : null,
          );
      final c = await pump(tester);
      await c.read(slotPluginsProvider.notifier).register('fake:o', bytes: Uint8List.fromList('o'.codeUnits));
      await settle(tester);
      // 120×60 の灰色の絵。
      final source = (await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 120, 60), Paint()..color = const Color(0xFF808080));
        final img = await rec.endRecording().toImage(120, 60);
        return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      }))!;
      final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: source, name: 'g.png', mimeType: 'image/png'));
      await settle(tester);
      final b = find.byKey(proMediaEditorBarKey('slot:t.o:tint'));
      await tester.ensureVisible(b);
      await settle(tester);
      await tester.tap(b);
      await settle(tester);
      tester.state<ProImageEditorState>(find.byType(ProImageEditor)).doneEditing();
      await settle(tester);
      await settle(tester);
      final result = (await future)!;
      final d = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(result.bytes);
        final img = (await codec.getNextFrame()).image;
        return (img.width, img.height, (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!);
      }))!;
      final (w, h, data) = d;
      expect(w / h, closeTo(2, 0.05));
      (int, int, int) px(double fx, double fy) {
        final o = ((fy * h).floor().clamp(0, h - 1) * w + (fx * w).floor().clamp(0, w - 1)) * 4;
        return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
      }

      for (final (fx, fy) in [(0.03, 0.06), (0.03, 0.94), (0.25, 0.5), (0.45, 0.5)]) {
        expect(px(fx, fy), (0, 255, 0), reason: '左半分 ($fx, $fy)');
      }
      for (final (fx, fy) in [(0.55, 0.5), (0.97, 0.06), (0.97, 0.94), (0.75, 0.5)]) {
        expect(px(fx, fy), (255, 0, 255), reason: '右半分 ($fx, $fy)');
      }
    });
    testWidgets('パラメーターとオブジェクト (D-257): ON で調整の FOW、スライダーで filter.preview を呼び直して絵を差し替える(レイヤーは置いたまま)、オブジェクトは動かせる位置に置かれて焼き込まれる、外すのは FOW から', (tester) async {
      late FakeSlotRuntime rt;
      fakes['p'] = () => rt = FakeSlotRuntime(
            manifest: {
              'id': 't.p', 'name': '調整つき', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
              'actions': [{'id': 'halo', 'slot': 'composer.media', 'label': '光輪', 'tags': ['Halo'], 'output': 'filter'}],
            },
            handler: (self, fn, args) {
              if (fn != 'filter.preview') return null;
              final w = ((args['params'] as Map?)?['width'] as num?)?.toDouble() ?? 0.2;
              // 右上の 1/4(中心 0.75, 0.25、短辺の半分の正方形)に、正方形いっぱいの緑の四角。太さ w は op の数で表す。
              return {
                'mode': 'overlay',
                'object': {'x': 0.75, 'y': 0.25, 'size': 0.5},
                'params': [{'id': 'width', 'label': '太さ', 'min': 0.1, 'max': 1.0, 'step': 0.1, 'value': w}],
                'ops': [for (var i = 0; i < (w * 10).round(); i++) {'op': 'rect', 'x': 0, 'y': 0, 'w': 1, 'h': 1, 'color': '#00FF00'}],
              };
            },
          );
      final c = await pump(tester);
      await c.read(slotPluginsProvider.notifier).register('fake:p', bytes: Uint8List.fromList('p'.codeUnits));
      await settle(tester);
      // 100×100 の灰色の絵。
      final source = (await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = const Color(0xFF808080));
        return (await (await rec.endRecording().toImage(100, 100)).toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      }))!;
      final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: source, name: 'g.png', mimeType: 'image/png'));
      await settle(tester);
      final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
      final button = find.byKey(proMediaEditorBarKey('slot:t.p:halo'));
      await tester.ensureVisible(button);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      // ON: レイヤー 1 枚(動かせる)+ 調整の FOW。
      final layer = state.activeLayers.single;
      expect((layer.interaction.enableMove, layer.interaction.enableScale, layer.interaction.enableEdit), (true, true, false));
      expect(find.byKey(const ValueKey('filter.param.width')), findsOneWidget);
      expect(rt.calls.where((x) => x.$1 == 'filter.preview').length, 1);
      // スライダー → params 付きで呼び直し、同じ seed、レイヤーは同じもののまま。
      await tester.drag(find.descendant(of: find.byKey(const ValueKey('filter.param.width')), matching: find.byType(Slider)), const Offset(200, 0));
      await settle(tester);
      final calls = [for (final x in rt.calls.where((x) => x.$1 == 'filter.preview')) x.$2];
      expect(calls.length, greaterThan(1));
      expect((calls.last['params'] as Map)['width'], greaterThan(0.2));
      expect(calls.last['seed'], calls.first['seed']);
      expect(identical(state.activeLayers.single, layer), isTrue);
      // FOW を閉じて、もう一度押すと外れずに FOW が開き直る。
      c.read(overlayManagerProvider).close('media.pro.filter');
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      expect(state.activeLayers.length, 1);
      expect(find.byKey(const ValueKey('filter.remove')), findsOneWidget);
      c.read(overlayManagerProvider).close('media.pro.filter');
      await settle(tester);
      // 焼き込み: 右上の 1/4 だけ緑、ほかは灰色のまま。
      state.doneEditing();
      await settle(tester);
      await settle(tester);
      final result = (await future)!;
      final d = (await tester.runAsync(() async {
        final img = (await (await ui.instantiateImageCodec(result.bytes)).getNextFrame()).image;
        return (img.width, img.height, (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!);
      }))!;
      final (w, h, data) = d;
      (int, int, int) px(double fx, double fy) {
        final o = ((fy * h).floor() * w + (fx * w).floor()) * 4;
        return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
      }

      expect(px(0.75, 0.25), (0, 255, 0));
      expect(px(0.55, 0.05), (0, 255, 0));
      expect(px(0.95, 0.45), (0, 255, 0));
      expect(px(0.25, 0.25), (128, 128, 128));
      expect(px(0.75, 0.75), (128, 128, 128));
      expect(px(0.45, 0.25), (128, 128, 128));
    });

    testWidgets('FOW の「外す」でレイヤーごと外れる', (tester) async {
      fakes['r'] = () => FakeSlotRuntime(
            manifest: {
              'id': 't.r', 'name': '外す', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget'],
              'actions': [{'id': 'm', 'slot': 'composer.media', 'label': 'マトリックス', 'tags': ['Matrix'], 'output': 'filter'}],
            },
            handler: (self, fn, args) => fn == 'filter.preview'
                ? {'params': [{'id': 'n', 'label': '個数', 'min': 1, 'max': 9, 'step': 1, 'value': 3}], 'ops': [{'op': 'rect', 'x': 0, 'y': 0, 'w': 1, 'h': 1, 'color': '#FF00FF', 'opacity': 0.2}]}
                : null,
          );
      final c = await pump(tester);
      await c.read(slotPluginsProvider.notifier).register('fake:r', bytes: Uint8List.fromList('r'.codeUnits));
      await settle(tester);
      c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: png, name: 'a.jpg', mimeType: 'image/jpeg'));
      await settle(tester);
      final state = tester.state<ProImageEditorState>(find.byType(ProImageEditor));
      final button = find.byKey(proMediaEditorBarKey('slot:t.r:m'));
      await tester.ensureVisible(button);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      expect(state.activeLayers.length, 1);
      await tester.tap(find.byKey(const ValueKey('filter.remove')));
      await settle(tester);
      expect(state.activeLayers, isEmpty);
      expect(find.byKey(const ValueKey('filter.remove')), findsNothing);
    });
  });
}
