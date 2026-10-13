// 描画確認用 (D-471): RASQ の機能の紹介(初回のツアー)の全ページ(スマホ / タブレット)と、「{SNS}でログイン」の「新規登録」。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/feature_tour_preview_test.dart --update-goldens
// → tool/preview/feature_tour_<phone|tablet>_<nn>_<ページ>.png、feature_tour_<phone|tablet>_tendency.png(「いま設定を見る」)、
//   feature_tour_login_<misskey|bluesky>.png
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/onboarding/feature_tour.dart';
import 'package:rasq_client/features/onboarding/feature_tour_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart' show MisskeyPlugin;

import '../../test/support/fakes.dart';

class _NoMarker implements FeatureTourInstallMarker {
  @override
  Future<bool?> checkAndMark(SessionStorage storage) async => false;
}

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display', 'FlutterTest']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    // アイコン: Flutter SDK の控えから Material Icons を読む(homeshots_test.dart と同じ)。
    const inSdk = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var icons = '${Platform.environment['FLUTTER_ROOT'] ?? ''}/$inSdk';
    for (var d = File(Platform.resolvedExecutable).parent; !File(icons).existsSync() && d.path != d.parent.path; d = d.parent) {
      icons = '${d.path}/$inSdk';
    }
    if (File(icons).existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File(icons).readAsBytesSync().buffer)));
      await loader.load();
    }
  });

  final pages = featureTourPages(ChildGate.off);

  /// 画像(RASQ のロゴなど)は読み込みが非同期なので、読み終えてから撮る。
  Future<void> shot(WidgetTester tester, String file) async {
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await expectLater(find.byType(RasqApp), matchesGoldenFile(file));
  }

  Future<ProviderContainer> pump(WidgetTester tester, Size size, double dpr, {bool tour = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      if (tour) SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      // 入れて最初のログインのあと(初めて = スキップなし)。
      featureTourDeviceKey: FeatureTourDevice(pending: tour).encode(),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()
          ..register(FakeSnsPlugin(posts: MockData.timeline))
          ..register(FakeSnsPlugin(id: MisskeyPlugin.pluginId, posts: (_) => const []))),
        featureTourInstallMarkerProvider.overrideWithValue(_NoMarker()),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  for (final (name, size, dpr) in [('phone', const Size(780, 1688), 2.0), ('tablet', const Size(1920, 1200), 1.5)]) {
    testWidgets('tour: $name', (tester) async {
      final c = await pump(tester, size, dpr);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      for (final (i, p) in pages.indexed) {
        await shot(tester, 'feature_tour_${name}_${(i + 1).toString().padLeft(2, '0')}_${p.id}.png');
        if (p.id == 'trend') {
          await tester.tap(find.byKey(const ValueKey('tour.openTendency')));
          await tester.pumpAndSettle();
          await shot(tester, 'feature_tour_${name}_tendency.png');
          c.read(overlayManagerProvider).close('trend.tendency');
          await tester.pumpAndSettle();
        }
        if (i < pages.length - 1) {
          await tester.tap(find.byKey(const ValueKey('tour.next')));
          await tester.pumpAndSettle();
        }
      }
    });
  }

  for (final (sns, route) in [('misskey', Routes.loginMisskey), ('bluesky', Routes.loginBluesky)]) {
    testWidgets('login: $sns', (tester) async {
      final c = await pump(tester, const Size(780, 1688), 2.0, tour: false);
      c.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      await shot(tester, 'feature_tour_login_$sns.png');
    });
  }
}
