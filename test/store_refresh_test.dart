import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_home_screen.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/features/store/store_refresh.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fakes.dart';

/// ストアの非同期更新と「最近の投稿内容から選出」(D-358)。

const _newcomer = StorePluginCard(id: 'net.example.fresh', name: '天気タイムライン', summary: '天気の投稿だけを集めるタイムライン', version: '1.0.0', pluginType: StorePluginType.timeline);

/// 公開 → 次の読み込みから新しいプラグインが見える。
class _PublishingStore extends FakeStoreClient {
  bool published = false;
  int homeCalls = 0;

  @override
  Future<StoreHomeSections> home() async {
    homeCalls++;
    final h = await super.home();
    if (!published) return h;
    // トレンドの並びも変わる(既存の並びが入れ替わっても、画面の位置は保つ)。
    return (trending: [...h.trending.reversed], bookmarks: h.bookmarks, recent: [_newcomer, ...h.recent]);
  }

  @override
  Future<List<StorePluginCard>> search(String q, {Set<StoreFilter> filters = const {}}) async {
    final r = await super.search(q, filters: filters);
    return published && q.isEmpty ? [...r.reversed, _newcomer] : r;
  }
}

void main() {
  test('並んでいるものは位置を保ち、新しいものだけ先頭に(中身は新しい値に)', () {
    const a = StorePluginCard(id: 'a', name: 'A', rating: 1);
    const b = StorePluginCard(id: 'b', name: 'B');
    const c = StorePluginCard(id: 'c', name: 'C');
    final m = mergeFreshCards([a, b], [b, const StorePluginCard(id: 'a', name: 'A', rating: 5), c], {'a', 'b'});
    expect([for (final x in m.cards) x.id], ['c', 'a', 'b']);
    expect(m.added, {'c'});
    expect(m.cards[1].rating, 5);
    // 列から外れたものも消さない(読み直しで並びが揺れないように)。
    expect([for (final x in mergeFreshCards([a, b], [c], {'a', 'b'}).cards) x.id], ['c', 'a', 'b']);
  });

  test('最近の投稿に近いものを近い順に(遠いものは出さない)', () {
    const cards = [
      StorePluginCard(id: 'hashtag', name: 'ハッシュタグ候補', summary: '本文で # を打つと候補が出て、タップで挿入します。', pluginType: StorePluginType.composer),
      StorePluginCard(id: 'qr', name: 'QR コード検出', summary: '全画面表示の画像から QR コードを見つけて枠を出します。', pluginType: StorePluginType.viewer),
      StorePluginCard(id: 'weather', name: '天気タイムライン', summary: '天気の投稿だけを集めるタイムライン', pluginType: StorePluginType.timeline),
    ];
    final picked = pickByRecentPosts(cards, ['今日の天気は雨。天気の投稿を集めたい', '明日の天気も気になる']);
    expect(picked.first.id, 'weather');
    expect(picked.map((c) => c.id), isNot(contains('qr')));
    expect(pickByRecentPosts(cards, const []), isEmpty);
  });

  Future<ProviderContainer> pump(WidgetTester tester, _PublishingStore store, {List<String> posts = const []}) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        storeClientProvider.overrideWithValue(store),
        storeRecentPostTextsProvider.overrideWith((ref) async => posts),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  // 横の列は見えている分しか組まないので、列に渡した一覧を読む。
  List<String> rowIds(WidgetTester tester, String row) => [for (final c in tester.widget<StoreTileRow>(find.byKey(ValueKey('store.home.$row'))).cards) c.id];

  testWidgets('ホーム: スワイプで読み直すと、並びはそのまま・新しく公開されたものだけ先頭に「NEW」で足す', (tester) async {
    final store = _PublishingStore();
    final c = await pump(tester, store);
    c.read(routerProvider).push(Routes.store);
    await tester.pumpAndSettle();
    final before = rowIds(tester, 'trending');
    final recentBefore = rowIds(tester, 'recent');
    expect(recentBefore, isNot(contains(_newcomer.id)));

    store.published = true;
    await tester.fling(find.byKey(const ValueKey('store.home.trending')), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(store.homeCalls, 2);
    expect(rowIds(tester, 'trending'), before); // 並びが入れ替わっても位置は保つ
    expect(rowIds(tester, 'recent'), [_newcomer.id, ...recentBefore]);
    expect(find.descendant(of: find.byKey(ValueKey('store.slot.${_newcomer.id}')), matching: find.text('NEW')), findsOneWidget);
    expect(find.text('新しく公開されたプラグインを 1 件追加しました'), findsOneWidget);

    // もう一度: 新しいものは無い。
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.fling(find.byKey(const ValueKey('store.home.trending')), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('新しく公開されたプラグインはありません'), findsOneWidget);
  });

  testWidgets('検索: スワイプで新しいものを先頭に足す / 「最近の投稿内容から選出」で近いものだけ', (tester) async {
    final store = _PublishingStore();
    final c = await pump(tester, store, posts: ['#RASQ のハッシュタグ候補が出ると便利', 'ハッシュタグを打つのが面倒']);
    c.read(routerProvider).push(Routes.storeSearch());
    await tester.pumpAndSettle();
    final grid = find.byKey(const ValueKey('store.search.grid'));
    expect(grid, findsOneWidget);
    expect(find.byKey(ValueKey('store.slot.${_newcomer.id}')), findsNothing);

    store.published = true;
    await tester.fling(grid, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(ValueKey('store.slot.${_newcomer.id}')), matching: find.text('NEW')), findsOneWidget);

    // チップ(∨ で開く)。
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('store.search.box')), matching: find.byIcon(Icons.keyboard_arrow_down)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近の投稿内容から選出'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.search.recent.caption')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.slot.sample.composer-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.slot.sample.theme-starry')), findsNothing);
  });
}
