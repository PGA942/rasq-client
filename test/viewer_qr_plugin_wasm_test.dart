import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-519: 同梱の QR コード検出(sample.media-fullscreen、assets/plugins/media_fullscreen_plugin.wasm)を**本物の wasm** で、
/// ビューワーと同じ渡し方(長辺 1024 の PNG、Exif の向きを当てたもの、D-511)で動かす。
/// 以前はホストが全画面表示プラグインに「ビットマップを触らない」fuel 予算(5000 万)しか渡さず、`viewer.open` が毎回
/// `E02`(実行の予算切れ)で落ちて、全画面のトグルが「!」(失敗)になっていた。
void main() {
  const url = 'https://example.com/qr?from=rasq';
  final wasm = File('assets/plugins/media_fullscreen_plugin.wasm').readAsBytesSync();
  // ランタイムの 2 つの予算(画像処理 / それ以外)。
  final mediaBudget = fuelBudgetFor(permissions: const {}, slots: const {kComposerMediaSlot});
  final standardBudget = fuelBudgetFor(permissions: const {});

  /// [text] の QR を [im] の ([left], [top]) に 1 モジュール [module] 画素で描く。戻りは QR の一辺(画素)。
  int drawQr(img.Image im, {required int left, required int top, required int module, String text = url}) {
    final qr = QrImage(QrCode.fromData(data: text, errorCorrectLevel: QrErrorCorrectLevel.M));
    final n = qr.moduleCount;
    // 静止ゾーン(4 モジュール)ぶん白く。
    img.fillRect(im, x1: left - 4 * module, y1: top - 4 * module, x2: left + (n + 4) * module - 1, y2: top + (n + 4) * module - 1, color: img.ColorRgb8(255, 255, 255));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (qr.isDark(y, x)) img.fillRect(im, x1: left + x * module, y1: top + y * module, x2: left + (x + 1) * module - 1, y2: top + (y + 1) * module - 1, color: img.ColorRgb8(15, 15, 20));
      }
    }
    return n * module;
  }

  /// 写真らしい背景(なめらかな色の変化 + 細かい模様)。
  img.Image photo(int w, int h) {
    final im = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final t = ((x * 7 + y * 13) % 23) * 3;
        im.setPixelRgb(x, y, 90 + (x * 120 ~/ w) + t ~/ 2, 110 + (y * 100 ~/ h), 140 + t);
      }
    }
    return im;
  }

  /// ホストの読み込みと同じ手順: マニフェストを読み、宣言から fuel 予算を決めて起動する(slot_plugins.dart の 2 段目)。
  ({WasmPluginController c, int budget, List<(String, Map<String, Object?>)> fows}) load({int? budgetOverride}) {
    final probe = WasmPluginController(wasmBytes: wasm)..load();
    final m = (probe.invoke('plugin.manifest')['value'] as Map).cast<String, Object?>();
    probe.dispose();
    final permissions = (m['permissions'] as List).cast<String>().toSet();
    final slots = (m['slots'] as List).cast<String>().toSet();
    final budget = budgetOverride ?? fuelBudgetFor(permissions: permissions, slots: slots);
    final fows = <(String, Map<String, Object?>)>[];
    final env = RasqHostEnvironment(
      permissions: permissions,
      onFow: (fn, args) {
        fows.add((fn, args));
        return {'opened': true};
      },
      appFns: RasqHostFns.appFns,
      onAppFn: (_, _) {},
    );
    return (c: WasmPluginController(wasmBytes: wasm, env: env, fuelPerCall: budget)..load(), budget: budget, fows: fows);
  }

  /// ビューワーと同じ渡し方で `viewer.open` を呼ぶ。戻りは (結果, 渡した幅, 高さ)。
  Future<(Map<String, dynamic>, int, int)> open(WasmPluginController c, Uint8List src) async {
    final (bytes, w, h) = await ViewerPluginOverlays.downscalePng(src, viewerPluginMaxSide);
    expect(w <= viewerPluginMaxSide && h <= viewerPluginMaxSide, isTrue);
    final r = c.invoke('viewer.open', {'token': 'tok', 'url': 'https://example.test/a', 'mimeType': 'image/png', 'width': w, 'height': h, 'bytesB64': base64Encode(bytes)});
    return (r, w, h);
  }

  /// 結果の枠(1 つめ)。見つからなければテストを落とす。
  Map<String, dynamic> firstBox(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    final root = (r['value'] as Map)['root'] as Map?;
    expect(root, isNotNull, reason: 'QR が見つからなかった: $r');
    final box = ((root!['c'] as List).first as Map).cast<String, dynamic>();
    expect(box['t'], 'Box');
    expect((box['on'] as Map)['tap'], 'qr.0');
    return (box['p'] as Map).cast<String, dynamic>();
  }

  void expectNear(Map<String, dynamic> p, {required double left, required double top, required double size, double tol = 12}) {
    expect((p['left'] as num).toDouble(), closeTo(left, tol), reason: 'left: $p');
    expect((p['top'] as num).toDouble(), closeTo(top, tol), reason: 'top: $p');
    expect((p['width'] as num).toDouble(), closeTo(size, tol), reason: 'width: $p');
    expect((p['height'] as num).toDouble(), closeTo(size, tol), reason: 'height: $p');
  }

  group('本物の wasm(sample.media-fullscreen)', () {
    test('ホストが渡す fuel 予算は画像処理のほう(viewer.overlay は画像を受け取って復号する)', () {
      final l = load();
      expect(l.budget, mediaBudget);
      final m = (l.c.invoke('plugin.manifest')['value'] as Map);
      expect(m['id'], 'sample.media-fullscreen');
      expect(m['slots'], [SlotIds.viewerOverlay]);
      l.c.dispose();
    });

    test('原因の再現: ビットマップを触らない予算(5000 万)では viewer.open が E02(トグルの「!」)', () async {
      final im = photo(1024, 1024);
      drawQr(im, left: 300, top: 300, module: 8);
      final l = load(budgetOverride: standardBudget);
      final (r, _, _) = await open(l.c, Uint8List.fromList(img.encodePng(im)));
      expect(r['ok'], isFalse);
      expect((r['error'] as Map)['code'], 'E02');
      l.c.dispose();
    });

    test('長辺 1024 の PNG: QR を見つけて枠を重ね、タップで FOW に中身', () async {
      final im = photo(1024, 768);
      final size = drawQr(im, left: 600, top: 200, module: 6);
      final l = load();
      final (r, w, h) = await open(l.c, Uint8List.fromList(img.encodePng(im)));
      expect((w, h), (1024, 768));
      expectNear(firstBox(r), left: 600, top: 200, size: size.toDouble());
      final tap = l.c.invoke('qr.0', {'nodeId': 'qr-0', 'kind': 'tap'});
      expect(tap['ok'], isTrue, reason: '$tap');
      final fow = l.fows.where((f) => f.$1 == 'fow.open').single.$2;
      expect(jsonEncode(fow['root']), contains(url));
      l.c.dispose();
    });

    test('写真の大きさの JPEG(4032×3024): ホストが長辺 1024 に縮めて渡しても見つかり、枠は渡した画素系', () async {
      final im = photo(4032, 3024);
      final size = drawQr(im, left: 2600, top: 700, module: 16);
      final l = load();
      final (r, w, h) = await open(l.c, Uint8List.fromList(img.encodeJpg(im, quality: 88)));
      expect((w, h), (1024, 768));
      const k = 1024 / 4032;
      expectNear(firstBox(r), left: 2600 * k, top: 700 * k, size: size * k);
      l.c.dispose();
    });

    test('Exif の向き 6(90° 回転)の JPEG: 見たままの縦横で渡り、枠も見たままの位置', () async {
      // 生の画素は 1600×1200。向き 6 は表示で時計回りに 90°: 生の (x, y) → 見た目の (1200 - 1 - y, x)。
      final im = photo(1600, 1200);
      final size = drawQr(im, left: 300, top: 200, module: 8);
      im.exif.imageIfd.orientation = 6;
      final l = load();
      final (r, w, h) = await open(l.c, Uint8List.fromList(img.encodeJpg(im, quality: 90)));
      // 見たままは 1200×1600 → 長辺 1024 に縮めて 768×1024。
      expect((w, h), (768, 1024));
      const k = 1024 / 1600;
      expectNear(firstBox(r), left: (1200 - 200 - size) * k, top: 300 * k, size: size * k);
      l.c.dispose();
    });
  });

  group('全画面のトグル(本物の wasm を登録して、ビューワーから渡す)', () {
    final acc = fakeSession().account;
    final post = Post(id: 'q1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 10, 20), body: 'QR つき', media: [MediaItem(id: 'm', type: MediaType.image, url: Uri.parse('https://example.test/qr.png'))]);

    testWidgets('検出あり になり、「!」(失敗)にならない', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final im = photo(1024, 1024);
      drawQr(im, left: 320, top: 360, module: 8);
      final png = Uint8List.fromList(img.encodePng(im));
      final budgets = <int?>[];
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': acc.key})});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]))),
          // 本物の wasm を同期のコントローラで(ワーカーの isolate はテストの疑似非同期では進まない)。予算はホストが決めたものをそのまま。
          slotRuntimeLoaderProvider.overrideWithValue((bytes, {required source, required fowPermissions, required appFns, required permissions, required fuelPerCall, required fetchHosts, required gpuCompute}) async {
            budgets.add(fuelPerCall);
            final c = WasmPluginController(wasmBytes: bytes, fuelPerCall: fuelPerCall, env: RasqHostEnvironment(permissions: permissions, fowPermissions: fowPermissions, appFns: appFns, fetchHosts: fetchHosts))..load();
            return _SyncSlotRuntime(c);
          }),
          viewerImageFetcherProvider.overrideWithValue((_) async => png),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      await c.read(slotPluginsProvider.notifier).register('store:sample.media-fullscreen', bytes: wasm);
      await tester.pumpAndSettle();
      expect(budgets.last, mediaBudget, reason: '宣言(viewer.overlay)から決めた予算');

      c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: 0));
      await tester.pumpAndSettle();
      const key = ValueKey('viewer.plugin.sample.media-fullscreen');
      String tip() => tester.widget<RasqIconButton>(find.byKey(key)).tooltip ?? '';
      // 画像の復号は本物の非同期。プラグインが答えるまで待つ。
      for (var i = 0; i < 300 && tip().contains('画像を見ています'); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
      }
      expect(tip(), contains('検出あり'));
      expect(find.descendant(of: find.byKey(key), matching: find.byIcon(Icons.error_outline)), findsNothing);
    });
  });
}

class _SyncSlotRuntime implements SlotRuntime {
  _SyncSlotRuntime(this.c);
  final WasmPluginController c;
  @override
  WasmPluginViewModel get view => c;
  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) async => c.invoke(fn, args);
  @override
  set onAppFn(AppFnRelay? relay) => c.env.onAppFn = relay;
  @override
  Stream<Map<String, Object?>> get fetchShapes => c.fetchShapes;
  @override
  void dispose() => c.dispose();
}
