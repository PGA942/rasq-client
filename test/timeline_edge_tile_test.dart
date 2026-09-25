import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// TL の上下の更新タイル (D-298): 引っ張れない PC / Web でも更新できる。上のタイルからの更新は、見ている位置を動かさない。
/// 電話のアプリでは既定で出さない(設定で出せる。D-316)。
void main() {
  testWidgets('上の更新タイルを押すと、新しい投稿が「上」に足される(見ていた投稿の位置は変わらない)。上へスクロールすると出てくる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    Post make(AccountId viewer, String id, String body) => Post(id: id, account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: body);
    final plugin = FakeSnsPlugin(localEmojis: const {}, posts: (viewer) => [make(viewer, 'old', 'もとの投稿')]);
    await tester.pumpWidget(ProviderScope(
      // パソコン / Web 版(既定でタイルを出す)。
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)), mobileAppProvider.overrideWithValue(false)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    // 上のタイルは、先頭の投稿のすぐ上(最初は画面の外)。組み立てられただけでは、更新しない。
    expect(find.byKey(const ValueKey('tl.edge.top'), skipOffstage: false), findsOneWidget);
    final fetchesAtStart = plugin.opened.fold<int>(0, (n, s) => n + s.timelineFetches);
    for (final session in plugin.opened) {
      session.prepend(make(session.account, 'new', 'あとから来た投稿'));
    }
    // 上へ少しスクロールしてタイルが見えると、自分で更新する。
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(plugin.opened.fold<int>(0, (n, s) => n + s.timelineFetches) > fetchesAtStart, isTrue);
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(c.read(timelineProvider(TimelineKind.home)).value?.posts.map((p) => p.id).toList() ?? c.read(timelineProvider(TimelineKind.social)).value?.posts.map((p) => p.id).toList(), containsAll(['new', 'old']));
    // 見ていた投稿は、同じ場所のまま(新しい投稿は、その上に足される)。
    final before = tester.getTopLeft(find.text('もとの投稿').first).dy;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('もとの投稿').first).dy, before);
    // さらに上へスクロールすると、新しい投稿が出てくる。
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('あとから来た投稿'), findsWidgets);
  });

  group('電話のアプリ (D-316)', () {
    Post make(AccountId viewer, String id, String body) => Post(id: id, account: viewer, author: MockData.douglas, createdAt: DateTime.now(), body: body);

    Future<({ProviderContainer c, FakeSnsPlugin plugin})> pump(WidgetTester tester, {required bool mobile, bool? setting}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        if (setting != null) '$timelineDisplayArea.v1': jsonEncode({'edgeTiles': setting}),
      });
      final plugin = FakeSnsPlugin(localEmojis: const {}, posts: (viewer) => [make(viewer, 'old', 'もとの投稿')]);
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)), mobileAppProvider.overrideWithValue(mobile)],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return (c: ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin: plugin);
    }

    int fetches(FakeSnsPlugin p) => p.opened.fold<int>(0, (n, s) => n + s.timelineFetches);

    testWidgets('既定では上下の「投稿を読み込む」を出さない。下に引っ張って更新はできる', (tester) async {
      final t = await pump(tester, mobile: true);
      expect(t.c.read(timelineEdgeTilesProvider), isFalse);
      expect(find.byKey(const ValueKey('tl.edge.top'), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('tl.edge.bottom'), skipOffstage: false), findsNothing);
      expect(find.text('もとの投稿'), findsWidgets);
      final before = fetches(t.plugin);
      await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(fetches(t.plugin), greaterThan(before));
    });

    testWidgets('設定で出すと、電話のアプリでも出る', (tester) async {
      await pump(tester, mobile: true, setting: true);
      expect(find.byKey(const ValueKey('tl.edge.top'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('パソコン / Web 版は既定で出す。設定で消せる', (tester) async {
      await pump(tester, mobile: false);
      expect(find.byKey(const ValueKey('tl.edge.top'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('パソコン / Web 版で、設定で消したら出さない', (tester) async {
      await pump(tester, mobile: false, setting: false);
      expect(find.byKey(const ValueKey('tl.edge.top'), skipOffstage: false), findsNothing);
    });

    testWidgets('設定の画面(アプリの外観 → タイムラインの表示): 電話の既定は「切」、入れると保存されて TL に出る', (tester) async {
      final t = await pump(tester, mobile: true);
      t.c.read(routerProvider).push('/settings/dsl/$timelineDisplayArea');
      await tester.pumpAndSettle();
      expect(find.text('TL の上下に「投稿を読み込む」を出す'), findsOneWidget);
      final sw = find.descendant(of: find.byType(RasqSwitchListTile), matching: find.byType(Switch));
      expect(tester.widget<Switch>(sw).value, isFalse);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(t.c.read(settingsAreaProvider(timelineDisplayArea)).value?['edgeTiles'], isTrue);
      expect(t.c.read(timelineEdgeTilesProvider), isTrue);
    });
  });
}
