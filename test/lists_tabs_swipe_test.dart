import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/pane_swipe_back.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// リストの画面のタブ(すべて / アカウントごと / RASQ)と作成先の FOW (D-349)、第3カラムのスワイプで戻る (D-350)。
void main() {
  final second = AccountSession(account: const AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'hanako'), pluginId: 'test.fake', token: 't2', createdAt: DateTime(2026, 9, 1), displayName: 'ハナコ');

  Future<(ProviderContainer, FakeSnsPlugin)> pumpApp(WidgetTester tester, {Size size = const Size(1080, 2340), double dpr = 3, List<Post> Function(AccountId)? posts}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), second.toJson()], 'current': fakeSession().account.key}),
    });
    final plugin = FakeSnsPlugin(posts: posts ?? MockData.timeline);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin);
  }

  testWidgets('リストの画面: 上にタブ(すべて / アカウントごと)。現在のアカウントのタブから。別のアカウントのリストは切り替えてから開く', (tester) async {
    final (c, _) = await pumpApp(tester);
    c.read(routerProvider).push(Routes.lists);
    await tester.pumpAndSettle();
    final tabs = find.byKey(const ValueKey('lists.tabs'));
    expect(find.descendant(of: tabs, matching: find.text('すべて')), findsOneWidget);
    // 同じ handle は無いので @handle だけ。
    expect(find.descendant(of: tabs, matching: find.text('@tester')), findsOneWidget);
    expect(find.descendant(of: tabs, matching: find.text('@hanako')), findsOneWidget);
    // 現在のアカウント(@tester)のタブ: 見出しはリスト / クリップ。
    expect(find.text('Fediverse Banner'), findsOneWidget);
    expect(find.text('公開クリップ'), findsOneWidget);
    expect(find.text('内緒のクリップ'), findsNothing); // 非公開は既定で出さない

    // すべて: アカウントごとの見出し。
    await tester.tap(find.descendant(of: tabs, matching: find.text('すべて')));
    await tester.pumpAndSettle();
    expect(find.text('@tester@example.test'), findsOneWidget);
    expect(find.text('@hanako@other.test'), findsOneWidget);

    // 別のアカウントのタブからリストを開く → そのアカウントに切り替わる。
    await tester.tap(find.descendant(of: tabs, matching: find.text('@hanako')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lists.list.l1')).last);
    await tester.pumpAndSettle();
    expect(c.read(currentAccountProvider)?.key, second.account.key);
    expect(find.textContaining('@hanako@other.test に切り替えました'), findsOneWidget);
  });

  testWidgets('リストを作成: + でアクションバンドルと同じ FOW(アカウントごと)→ 選んだアカウントで作る', (tester) async {
    final (c, plugin) = await pumpApp(tester);
    c.read(routerProvider).push(Routes.lists);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('リストを作成'));
    await tester.pumpAndSettle();
    expect(find.text('@tester@example.test のリスト'), findsOneWidget);
    expect(find.text('@hanako@other.test のリスト'), findsOneWidget);
    expect(find.text('RASQ リスト(SNS 横断)'), findsNothing); // RASQ アカウントが無ければ出さない
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.pick.${'misskey:other.test:hanako'}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '新しいリスト');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();
    final hanako = plugin.opened.lastWhere((s) => s.account.key == second.account.key);
    expect(hanako.createdLists, ['新しいリスト']);
    expect(plugin.opened.where((s) => s.account.key == fakeSession().account.key).expand((s) => s.createdLists), isEmpty);
  });

  group('PaneSwipeBack', () {
    Future<List<String>> pump(WidgetTester tester, Widget child) async {
      final backs = <String>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PaneSwipeBack(onBack: () => backs.add('back'), child: child))));
      return backs;
    }

    testWidgets('右スワイプで戻る。短い / 縦 / 左は戻らない', (tester) async {
      final backs = await pump(tester, ListView(children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('行 $i'))]));
      await tester.dragFrom(const Offset(100, 300), const Offset(40, 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(100, 300), const Offset(30, 200));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(400, 300), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(backs, isEmpty);
      await tester.dragFrom(const Offset(100, 300), const Offset(160, 10));
      await tester.pumpAndSettle();
      expect(backs, ['back']);
    });

    testWidgets('隠れた TL(左に前のタブがある TabBarView)の上では戻らない。先頭のタブなら戻る。スライダーの上は戻らない', (tester) async {
      var value = 0.2;
      final backs = await pump(
        tester,
        DefaultTabController(
          length: 2,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
            SizedBox(height: 60, child: StatefulBuilder(builder: (_, set) => Slider(value: value, onChanged: (v) => set(() => value = v)))),
            const Expanded(child: TabBarView(children: [Center(child: Text('TL A')), Center(child: Text('TL B'))])),
          ]),
        ),
      );
      // 先頭のタブ: 左に隠れた TL は無い → 戻る。
      await tester.dragFrom(tester.getCenter(find.text('TL A')), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(backs, ['back']);
      // 2 枚目: 右スワイプは前のタブへ(戻らない)。
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.flingFrom(tester.getCenter(find.text('TL B')), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(backs, ['back']);
      expect(find.text('TL A'), findsOneWidget);
      // スライダーを右へ動かしても戻らない。
      await tester.dragFrom(tester.getTopLeft(find.byType(Slider)) + const Offset(60, 30), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(backs, ['back']);
      expect(value, greaterThan(0.2));
    });
  });

  testWidgets('タブレット: 第3カラムの投稿を右スワイプで閉じる(< と同じ)', (tester) async {
    final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
    Post post(AccountId viewer) => Post(id: 'p1', account: viewer, author: author, createdAt: DateTime(2026, 9, 27, 10), body: 'スワイプで戻る確認');
    final (c, _) = await pumpApp(tester, size: const Size(2400, 1600), dpr: 2, posts: (v) => [post(v)]);
    await tester.tap(find.text('スワイプで戻る確認').first);
    await tester.pumpAndSettle();
    final inCol3 = find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(PostDetailScreen));
    expect(inCol3, findsOneWidget);
    await tester.dragFrom(tester.getCenter(inCol3), const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(inCol3, findsNothing);
    expect(c.read(thirdColumnProvider), isNull);
  });
}
