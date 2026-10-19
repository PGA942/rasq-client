import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/scroll_memory.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// タイムラインと移動のふるまい (D-504〜D-508)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(int i, {String author = 'u1'}) => Post(
        id: 'p$i',
        account: acc,
        author: UserSummary(id: author, account: acc, displayName: '人$author'),
        createdAt: DateTime(2026, 10, 20, 12).subtract(Duration(minutes: i)),
        body: '投稿 $i',
      );

  late List<Post> posts;
  late FakeSnsPlugin plugin;

  Future<ProviderContainer> pump(WidgetTester tester, {List<Override> extra = const [], Size size = const Size(1080, 2340)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = fakeSession().account.key;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': key}),
    });
    posts = [for (var i = 0; i < 40; i++) post(i, author: 'u${i % 5}')];
    plugin = FakeSnsPlugin(posts: (_) => posts);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)), ...extra],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  /// [view] のキーの TL(ホームのタブの中身)の縦のスクロール。
  ScrollPosition tlPosition(WidgetTester tester, String view) {
    final s = find.descendant(of: find.byKey(ValueKey(view)), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first;
    return tester.state<ScrollableState>(s).position;
  }

  group('D-504 スクロール位置を覚える', () {
    testWidgets('RememberScroll: 作り直しても前の位置から。アカウントの id ごとに別', (tester) async {
      final memory = ScrollMemory();
      Widget list(bool on) => ProviderScope(
            overrides: [scrollMemoryProvider.overrideWithValue(memory)],
            child: MaterialApp(
              home: on
                  ? RememberScroll(
                      id: 'test.list',
                      builder: (_, c) => ListView.builder(key: const ValueKey('list'), controller: c, itemCount: 200, itemBuilder: (_, i) => SizedBox(height: 50, child: Text('行 $i'))),
                    )
                  : const SizedBox.shrink(),
            ),
          );
      await tester.pumpWidget(list(true));
      await tester.drag(find.byKey(const ValueKey('list')), const Offset(0, -1200));
      await tester.pumpAndSettle();
      final at = tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
      expect(at, greaterThan(1000));
      await tester.pumpWidget(list(false));
      await tester.pumpWidget(list(true));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, at, reason: '作り直しても同じ位置');
      expect(memory['null|test.list']?.offset, at, reason: 'ログインしていなければアカウントは null');
    });

    testWidgets('ホームの TL(開いたときに見えるソーシャル): 下へ行って、通知へ移って戻っても / 総合表示に入って出て作り直しても、前の位置', (tester) async {
      final c = await pump(tester);
      await tester.drag(find.byKey(const ValueKey('tl.view.social')), const Offset(0, -1500));
      await tester.pumpAndSettle();
      final at = tlPosition(tester, 'tl.view.social').pixels;
      expect(at, greaterThan(1000));
      expect(find.text('投稿 0'), findsNothing);
      // 下のナビで通知 → ホーム。
      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(tlPosition(tester, 'tl.view.social').pixels, at);
      // 総合表示の出入り: ホームの TL の画面はいったん捨てられ、作り直される。
      await c.read(sessionsProvider.notifier).setBundleView(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tl.view.social')), findsNothing);
      await c.read(sessionsProvider.notifier).setBundleView(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tl.view.social')), findsOneWidget);
      expect(tlPosition(tester, 'tl.view.social').pixels, at, reason: '作り直しても前の位置から');
      expect(find.text('投稿 0'), findsNothing);
    });
  });
}
