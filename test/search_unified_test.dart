import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/trend/trend_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 検索を RASQ アカウントでまとめる (D-388)。
void main() {
  final bsky = AccountSession(
    account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'tester.bsky.social'),
    pluginId: 'test.bsky',
    token: 't',
    createdAt: DateTime(2026, 9, 1),
    displayName: 'テスター(Bluesky)',
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: (v) => const [], trends: const [TrendTag(tag: '打上会', usersCount: 10), TrendTag(tag: '花火', usersCount: 5)]))
      ..register(FakeSnsPlugin(posts: (v) => const [], id: 'test.bsky', kind: SnsKind.bluesky, trends: const [TrendTag(tag: '#花火'), TrendTag(tag: '月見')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('トレンドは RASQ アカウントの中の SNS アカウント全部から集め、同じワードは 1 つに。行には波形の代わりに「サーバーのアイコン + サーバー名」', (tester) async {
    final c = await pump(tester);
    final t = await tester.runAsync(() => c.read(sourcedTrendsProvider.future));
    expect(t!.tags.map((x) => x.tag), ['打上会', '#花火', '月見'], reason: '1 位どうし → 2 位どうし、同じワードは先に出たほう');
    expect(t.sources[trendKey('花火')]!.map((a) => a.instance), ['bsky.social', 'example.test'], reason: '# と大文字小文字を無視して 1 つに');
    c.read(routerProvider).go(Routes.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search.account')), findsOneWidget);
    final moon = find.byKey(const ValueKey('trend.server.月見'));
    expect(find.descendant(of: moon, matching: find.text('bsky.social')), findsOneWidget, reason: 'サーバー情報が無ければホスト名');
    expect(find.descendant(of: find.byKey(const ValueKey('trend.server.#花火')), matching: find.text(' +1')), findsOneWidget, reason: 'ほかのサーバーでもトレンド');
    expect(find.descendant(of: find.byKey(const ValueKey('trend.server.打上会')), matching: find.text('example.test')), findsOneWidget);
  });
}
