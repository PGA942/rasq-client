import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/media/video_player.dart';
import 'package:rasq_client/features/notifications/notification_prefs.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/legal_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_sections.dart';
import 'package:rasq_client/features/store/store_home_screen.dart';
import 'package:rasq_client/features/vc/astell_actions.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 設定全般 (D-238): すべての行に行き先がある、ホストの設定ページ(静的 RRL)は全部読める、
/// 設定値が実際に読まれる(プラグイン枠 / Tell タイル / 広告枠 / 通知 / 動画 / MFM)。
void main() {
  const actions = {settingsActionTrendGenres, settingsActionTrendTendency, settingsActionRelationalTuning, settingsActionAstellBar, 'notificationPrefs'};

  test('すべての行に行き先がある(「フォントやカラースキーム」は画面内のシート)、ホストの DSL ページは全部パースできる', () {
    final hostAreas = <String>{};
    for (final e in settingsSections.entries) {
      for (final r in e.value.rows) {
        if (e.key == 'appearance' && r.title == 'フォントやカラースキーム') continue;
        expect(r.route, isNotNull, reason: '${e.value.title} / ${r.title}');
        final route = r.route!;
        expect(route.startsWith('/') || actions.contains(route), isTrue, reason: route);
        if (route.startsWith('/settings/dsl/') && !route.startsWith('/settings/dsl/sns.')) hostAreas.add(route.substring('/settings/dsl/'.length));
      }
    }
    expect(hostAreas.length, greaterThan(15));
    for (final area in hostAreas) {
      final f = File('assets/settings/$area.rrl.json');
      expect(f.existsSync(), isTrue, reason: area);
      final spec = SettingsPageSpec.fromJson((jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>());
      expect(spec.area, area);
      expect(spec.isRemote, isFalse);
    }
  });

  final fakes = <String, FakeSlotRuntime Function()>{};
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rootBundle.clear();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('プラグインの構成 → カスタムトレンドの配信: オフにするとトレンドプラグインが呼ばれなくなる、ページ内のリンクでストアへ', (tester) async {
    fakes['trend'] = () => FakeSlotRuntime(
          manifest: {'id': 't.trend', 'name': 'トレンド候補', 'version': '0.1.0', 'kind': 'action', 'description': '候補', 'slots': ['trend.suggest'], 'permissions': <String>[]},
          handler: (self, fn, args) => null,
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:trend', bytes: Uint8List.fromList('trend'.codeUnits));
    await tester.pumpAndSettle();
    expect(c.read(slotPluginsForProvider(SlotIds.trendSuggest)).length, 1);
    c.read(routerProvider).push('/settings/section/plugins');
    await tester.pumpAndSettle();
    await tester.tap(find.text('カスタムトレンドの配信'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('トレンドプラグインの候補を表示'));
    await tester.pumpAndSettle();
    expect(c.read(slotPluginsForProvider(SlotIds.trendSuggest)), isEmpty);
    expect(c.read(slotPluginsProvider).length, 1); // 登録は残る
    await tester.tap(find.text('プラグインストア'));
    await tester.pumpAndSettle();
    expect(find.byType(StoreHomeScreen), findsOneWidget);
  });

  testWidgets('FOW を開く行: トレンドのジャンル / 指向性、リレーショナルの投稿クラスター', (tester) async {
    final c = await pump(tester);
    final manager = c.read(overlayManagerProvider);
    c.read(routerProvider).push('/settings/section/trend');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャンル'));
    await tester.pumpAndSettle();
    expect(manager.contains('trend.genres'), isTrue);
    manager.close('trend.genres');
    await tester.pumpAndSettle();
    await tester.tap(find.text('トレンドの指向性/刺激性'));
    await tester.pumpAndSettle();
    expect(manager.contains('trend.tendency'), isTrue);
    manager.close('trend.tendency');
    await tester.pumpAndSettle();
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    c.read(routerProvider).push('/settings/section/relational');
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿クラスター'));
    await tester.pumpAndSettle();
    expect(manager.contains('relational.tuning'), isTrue);
    manager.close('relational.tuning');
    await tester.pumpAndSettle();
  });

  testWidgets('ヘルプ、法的表示: バージョン / 文書 / プラグインの規約 / オープンソースライセンス', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).push('/settings/section/about');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ヘルプ、法的表示'), 200);
    await tester.tap(find.text('ヘルプ、法的表示'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text(rasqAppVersion), findsOneWidget);
    expect(find.byKey(const ValueKey('legal.plugin.test.fake')), findsOneWidget);
    await tester.tap(find.text('クッキーについて'));
    await tester.pumpAndSettle();
    expect(find.textContaining('クッキーを使いません'), findsOneWidget);
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('legal.licenses')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('legal.licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('設定値が読まれる: Tell タイル / 広告枠 / 通知プロファイルの保存 / 動画と MFM の既定', (tester) async {
    final c = await pump(tester);
    expect(find.byType(AstellHeaderStrip), findsOneWidget);
    await c.read(settingsAreaProvider('astell.tiles').notifier).set('headerStrip', false);
    await tester.pumpAndSettle();
    expect(find.byType(AstellHeaderStrip), findsNothing);
    await c.read(settingsAreaProvider('astell.tiles').notifier).set('headerStrip', true);
    await c.read(settingsAreaProvider('astell.tiles').notifier).set('headerMax', 2);
    await tester.pumpAndSettle();
    expect(tester.widget<AstellHeaderStrip>(find.byType(AstellHeaderStrip)).max, 2);
    // 広告枠(検索ホーム)。
    c.read(routerProvider).go(Routes.search);
    await tester.pumpAndSettle();
    expect(find.text('広告'), findsOneWidget);
    await c.read(settingsAreaProvider('resources').notifier).set('showAds', false);
    await tester.pumpAndSettle();
    expect(find.text('広告'), findsNothing);
    // 通知プロファイルは設定エリアに保存され、読み直しても残る。
    c.read(notificationPrefsProvider.notifier).setKind(NotificationKind.reaction, false);
    await tester.pumpAndSettle();
    expect((await c.read(sessionStorageProvider).read('notifications.prefs.v1'))!, contains('"kinds.reaction":false'));
    expect(c.read(notificationPrefsProvider).isOn(NotificationKind.reaction), isFalse);
    expect(c.read(notificationPrefsProvider).isOn(NotificationKind.follow), isTrue);
    // 動画 / MFM の既定はアプリの根から描画側へ流れる。
    await c.read(settingsAreaProvider('appearance.video').notifier).set('defaultSpeed', '1.5');
    await c.read(settingsAreaProvider('appearance.video').notifier).set('autoplay', false);
    await c.read(settingsAreaProvider('appearance.mfm').notifier).set('animations', false);
    await c.read(settingsAreaProvider('appearance.mfm').notifier).set('speed', 150);
    await tester.pumpAndSettle();
    expect(VideoPrefs.defaultSpeed, 1.5);
    expect(VideoPrefs.autoplay, isFalse);
    expect(RasqMfmTransform.motion.value, (enabled: false, speed: 1.5));
    // 後始末(静的な設定を既定に戻す)。
    VideoPrefs.defaultSpeed = 1.0;
    VideoPrefs.autoplay = true;
    RasqMfmTransform.motion.value = (enabled: true, speed: 1.0);
  });
}
