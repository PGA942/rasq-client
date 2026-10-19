import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/media/image_scale.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// D-511: 全画面表示 / 加工のプラグインへ渡す画像の大きさ(解像度)。
/// - 大きさを見るためだけに原寸で復号しない(縮める大きさで 1 回だけ)。長辺は必ず上限以内。
/// - Exif の向きのある JPEG は、向きを当てた(見たままの)縦横で渡す。ヘッダーの幅・高さは当てる前なので食い違っていた。
/// - `filter.apply` の width / height は、渡す画像そのものの画素数。
void main() {
  /// 生の画素が [w]x[h] で、Exif の向きが [orientation] の JPEG。
  Uint8List jpeg(int w, int h, {int? orientation}) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(30, 120, 200));
    if (orientation != null) im.exif.imageIfd.orientation = orientation;
    return Uint8List.fromList(img.encodeJpg(im, quality: 70));
  }

  Uint8List png(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

  Future<(int, int)> decodedSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = (await codec.getNextFrame()).image;
    final size = (frame.width, frame.height);
    frame.dispose();
    codec.dispose();
    return size;
  }

  group('ヘッダー(復号しない)', () {
    test('Exif の向きを読む。無い / PNG は null', () {
      expect(jpegExifOrientation(jpeg(40, 20, orientation: 6)), 6);
      expect(jpegExifOrientation(jpeg(40, 20, orientation: 3)), 3);
      expect(jpegExifOrientation(jpeg(40, 20)), isNull);
      expect(jpegExifOrientation(png(40, 20)), isNull);
      expect(jpegExifOrientation(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x02])), isNull, reason: '壊れた Exif でも落ちない');
    });

    test('向きを当てた縦横: 5〜8 は入れ替える。生のヘッダーは当てる前のまま', () {
      final rotated = jpeg(400, 200, orientation: 6);
      expect(imageSizeFromHeader(rotated), (400, 200));
      expect(orientedImageSizeFromHeader(rotated), (200, 400));
      expect(orientedImageSizeFromHeader(jpeg(400, 200, orientation: 3)), (400, 200));
      expect(orientedImageSizeFromHeader(png(400, 200)), (400, 200));
    });

    test('fitDimensions: 長辺を上限に、縦横比を保つ。収まっていれば null', () {
      expect(fitDimensions(1000, 500, 1024), isNull);
      expect(fitDimensions(8000, 2000, 1024), (1024, 256));
      expect(fitDimensions(3024, 4032, 1024), (768, 1024));
      expect(fitDimensions(40000, 10, 1024), (1024, 1), reason: '細長くても 0 にしない');
    });
  });

  group('復号(縮める大きさで 1 回だけ)', () {
    test('大きな画像は長辺 1024 以内の PNG になる(縦横比を保つ)', () async {
      final (bytes, w, h) = await ViewerPluginOverlays.downscalePng(png(5000, 1250), viewerPluginMaxSide);
      expect((w, h), (1024, 256));
      expect(await decodedSize(bytes), (1024, 256), reason: '言っている画素数と中身が同じ');
    });

    test('縦長の大きな写真も長辺(高さ)を 1024 に', () async {
      final (_, w, h) = await ViewerPluginOverlays.downscalePng(png(1500, 6000), viewerPluginMaxSide);
      expect((w, h), (256, 1024));
    });

    test('Exif で 90° 回る JPEG: 見たままの縦横で、長辺 1024 以内', () async {
      // 生は 1600x800、向き 6 = 見た目は 800x1600。縮める先は見たままの縦横から決める(生の縦横で決めると高さが 1024 を超える)。
      final (bytes, w, h) = await ViewerPluginOverlays.downscalePng(jpeg(1600, 800, orientation: 6), viewerPluginMaxSide);
      expect((w, h), (512, 1024));
      expect(await decodedSize(bytes), (512, 1024));
    });

    test('fitWithin(normalize): 上限以内でも向きを焼いた PNG にする', () async {
      final fitted = await fitWithin(jpeg(400, 200, orientation: 6), 2048, mimeType: 'image/jpeg', normalize: true);
      expect(fitted.mimeType, 'image/png');
      expect((fitted.width, fitted.height), (200, 400));
      expect(await decodedSize(fitted.bytes), (200, 400));
      expect(jpegExifOrientation(fitted.bytes), isNull, reason: '向きは画素に焼いた');
    });
  });

  group('プラグインへの受け渡し', () {
    final acc = fakeSession().account;
    late Map<String, FakeSlotRuntime Function()> fakes;
    setUp(() => fakes = {});

    Future<ProviderContainer> pump(WidgetTester tester, {Future<Uint8List?> Function(Uri)? fetch, List<Post> posts = const []}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': acc.key})});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
          slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
          if (fetch != null) viewerImageFetcherProvider.overrideWithValue(fetch),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    Future<void> settleAsync(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    testWidgets('全画面表示: 大きな / 回る写真も、渡す width / height = 渡す PNG の画素数 = 長辺 1024 以内・見たままの向き', (tester) async {
      late FakeSlotRuntime rt;
      fakes['v'] = () => rt = FakeSlotRuntime(
            manifest: {'id': 't.v', 'name': 'v', 'version': '0.1.0', 'kind': 'mediaViewer', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget']},
            handler: (_, fn, args) => fn == 'viewer.open' ? <String, Object?>{} : null,
          );
      final photos = {'big': png(6000, 1500), 'rot': jpeg(1600, 800, orientation: 6)};
      final post = Post(
        id: 'p', account: acc, author: UserSummary(id: 'u', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 10, 20), body: '写真',
        media: [for (final k in photos.keys) MediaItem(id: k, type: MediaType.image, url: Uri.parse('https://example.test/$k'))],
      );
      final c = await pump(tester, fetch: (u) async => photos[u.pathSegments.last]);
      await c.read(slotPluginsProvider.notifier).register('fake:v', bytes: Uint8List.fromList('v'.codeUnits));
      await tester.pumpAndSettle();
      c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
      await tester.pumpAndSettle();
      await settleAsync(tester);
      await tester.drag(find.descendant(of: find.byType(MediaViewerScreen), matching: find.byType(PageView)), const Offset(-250, 0));
      await tester.pumpAndSettle();
      await settleAsync(tester);
      final opens = [for (final x in rt.calls) if (x.$1 == 'viewer.open') x.$2];
      expect(opens.length, 2);
      final expected = [(1024, 256), (512, 1024)];
      for (var i = 0; i < 2; i++) {
        final a = opens[i];
        expect((a['width'], a['height']), expected[i]);
        final actual = (await tester.runAsync(() => decodedSize(base64Decode(a['bytesB64']! as String))))!;
        expect(actual, expected[i], reason: '言っている画素数と渡した PNG の中身が同じ');
      }
    });

    testWidgets('加工 (media.edit): Exif で回る JPEG は向きを焼いた PNG + 見たままの縦横で渡す', (tester) async {
      late FakeSlotRuntime rt;
      fakes['e'] = () => rt = FakeSlotRuntime(
            manifest: {'id': 't.e', 'name': 'e', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
            handler: (_, fn, args) => fn == 'media.edit' ? <String, Object?>{} : null,
          );
      final c = await pump(tester);
      final notifier = c.read(slotPluginsProvider.notifier);
      await notifier.register('fake:e', bytes: Uint8List.fromList('e'.codeUnits));
      await tester.pumpAndSettle();
      final plugin = c.read(slotPluginsProvider).firstWhere((p) => p.id == 't.e');
      await tester.runAsync(() => notifier.mediaEdit(plugin, index: 0, name: 'a.jpg', mimeType: 'image/jpeg', bytes: jpeg(400, 200, orientation: 6), onReplace: (_, _, _) {}));
      final a = rt.calls.lastWhere((x) => x.$1 == 'media.edit').$2;
      expect(a['mimeType'], 'image/png');
      expect((a['width'], a['height']), (200, 400));
      expect((await tester.runAsync(() => decodedSize(base64Decode(a['bytesB64']! as String))))!, (200, 400));

      // 向きの無い小さな JPEG は今までどおりそのまま(再エンコードしない)。
      final plain = jpeg(400, 200);
      await tester.runAsync(() => notifier.mediaEdit(plugin, index: 0, name: 'b.jpg', mimeType: 'image/jpeg', bytes: plain, onReplace: (_, _, _) {}));
      final b = rt.calls.lastWhere((x) => x.$1 == 'media.edit').$2;
      expect((b['mimeType'], b['width'], b['height'], b['bytesB64']), ('image/jpeg', 400, 200, base64Encode(plain)));
    });

    testWidgets('filter.apply: width / height は渡す画像そのものの画素数(呼び出し側の古い値ではない)', (tester) async {
      late FakeSlotRuntime rt;
      fakes['f'] = () => rt = FakeSlotRuntime(
            manifest: {'id': 't.f', 'name': 'f', 'version': '0.1.0', 'kind': 'action', 'slots': ['composer.media'], 'permissions': ['fow.widget']},
            handler: (_, fn, args) => fn == 'filter.apply' ? {'bytesB64': args['bytesB64'], 'mimeType': 'image/png'} : null,
          );
      final c = await pump(tester);
      final notifier = c.read(slotPluginsProvider.notifier);
      await notifier.register('fake:f', bytes: Uint8List.fromList('f'.codeUnits));
      await tester.pumpAndSettle();
      final plugin = c.read(slotPluginsProvider).firstWhere((p) => p.id == 't.f');
      // 掛けたときの元画像は 4032x3024 でも、焼き込んだ 1 枚(切り抜き / 書き出しの倍率)は 1008x756。
      await tester.runAsync(() => notifier.filterApply(plugin, actionId: 'x', seed: 1, width: 4032, height: 3024, bytes: png(1008, 756)));
      final a = rt.calls.lastWhere((x) => x.$1 == 'filter.apply').$2;
      expect((a['width'], a['height']), (1008, 756));
      // 読めない形式は渡された値のまま。
      await tester.runAsync(() => notifier.filterApply(plugin, actionId: 'x', seed: 1, width: 10, height: 20, bytes: Uint8List.fromList([1, 2, 3])));
      final b = rt.calls.lastWhere((x) => x.$1 == 'filter.apply').$2;
      expect((b['width'], b['height']), (10, 20));
    });
  });
}
