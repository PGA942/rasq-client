import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/headers.dart';
import 'package:rasq_client/shell/nav.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-429: 幅の広い画面(左にナビゲーションのレール)では、ヘッダーの左のアカウントのアイコンはレールの下端へ。
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const [])))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('広い画面: ホーム / 検索(第 3 カラム)のヘッダーにアイコンは無く、レールの一番上のアイコンでサイドバーが開く', (tester) async {
    await pump(tester, const Size(1280, 800));
    final rail = find.byKey(const ValueKey('rail.avatar'));
    expect(rail, findsOneWidget);
    expect(find.byType(RasqHeaderAvatarButton), findsOneWidget, reason: 'レールの 1 つだけ(ホームと第 3 カラムの検索のヘッダーには出さない)');
    expect(tester.getCenter(rail).dx, lessThan(72));
    expect(tester.getCenter(rail).dy, lessThan(100), reason: '一番上(狭い画面のヘッダーの左上と同じあたり、D-435)');
    final tabs = [for (final t in RasqNavTab.values) tester.getCenter(find.byTooltip(t.label).first).dy];
    expect(tabs.first, greaterThan(tester.getCenter(rail).dy), reason: 'タブはアイコンの下');
    for (var i = 1; i < tabs.length; i++) {
      expect(tabs[i] - tabs[i - 1], greaterThanOrEqualTo(64), reason: 'タブの間を広く');
    }
    await tester.tap(rail);
    await tester.pumpAndSettle();
    expect(find.byType(RasqSidebar), findsOneWidget);
  });

  testWidgets('狭い画面: これまでどおりヘッダーの左のアイコン(レールは無い)', (tester) async {
    await pump(tester, const Size(400, 800));
    expect(find.byKey(const ValueKey('rail.avatar')), findsNothing);
    expect(find.byType(RasqHeaderAvatarButton), findsOneWidget);
    expect(tester.getCenter(find.byType(RasqHeaderAvatarButton)).dy, lessThan(100), reason: 'ヘッダーの左');
  });
}
