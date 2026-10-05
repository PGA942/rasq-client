import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/timeline_providers.dart' show isSelfFetch;
import 'package:rasq_client/features/nodeprog/node_executor.dart' show withPageQuery;
import 'package:rasq_client/features/nodeprog/node_tabs.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/features/trend/trend_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-431: トレンド TL / トレンドタイル / Today の 3 つの構成。それぞれの画面の歯車から TL のカスタマイズと同じ画面で編集し、
/// トレンドタイルでは重い(ML モデル / GPU)アルゴリズムを使えない。傾向 FOW の指向性/刺激性はアルゴリズムの一番最後に固定。
void main() {
  group('構成', () {
    test('Today / トレンドタイル / トレンド TL の既定の取得元は SNS ごとのノード (D-440)。タイルは自動更新なし。トレンド TL にトレンド枠の鎖はもう付かない', () {
      expect(defaultTlConfig(trendTodayScope).sources.single.tl, 'featured');
      expect(defaultTlConfig('trend').postSources.single.tl, pageSearchKind);
      expect(defaultTlConfig(trendTilesScope).sources.single.tl, trendTagsKind);
      expect([for (final s in defaultTlConfig(trendTilesScope, bundleAccounts: ['@a@m.example', '@b@bsky.social']).sources) (s.tl, s.account)], [(trendTagsKind, '@a@m.example'), (trendTagsKind, '@b@bsky.social')]);
      expect(defaultTlConfig(trendTilesScope).clock, '');
      final g = compileTlConfig(defaultTlConfig('trend'), scope: 'trend');
      expect({for (final n in g.nodes) n.type}, isNot(contains('trend.frame')), reason: 'タイルの並びは trend.tiles へ分けた');
    });

    test('ワードの無い検索の取得元は、このページのワード / タグで引く (D-440)。トレンド TL の基礎(タグの検索)と同じなら取り直さない', () {
      expect(withPageQuery('search:', '花火'), 'search:花火');
      expect(withPageQuery('acct:@a@m.example|search:', '花火'), 'acct:@a@m.example|search:花火');
      expect(withPageQuery('search:月見', '花火'), 'search:月見', reason: 'ワードを決めた検索はそのまま');
      expect(withPageQuery('search:', null), 'search:');
      expect(isSelfFetch('search:花火', 'tag:花火'), isTrue);
      expect(isSelfFetch('acct:@b@x|search:花火', 'tag:花火'), isFalse, reason: 'ほかのアカウントの検索は取りに行く');
      expect(isSelfFetch('featured', 'featured'), isTrue);
    });

    test('トレンドタイルで使えないのは重いもの(サジェスト / 絞り込み / TL プラグイン)だけ', () {
      expect(trendTilesUnavailableReason('suggest'), isNotNull);
      expect(trendTilesUnavailableReason('filter'), isNotNull);
      expect(trendTilesUnavailableReason('plugin:dict'), isNotNull);
      expect(trendTilesUnavailableReason('queryfilter'), isNull);
      expect(trendTilesUnavailableReason('chrono'), isNull);
    });

    test('トレンドタイルの構成をタグに掛ける: 検索絞り込み(含む / 除外、# と大文字小文字は無視)、重いものと空の語は飛ばす', () {
      const tags = ['#花火', '打上会', 'Hanabi', '月見'];
      List<String> run(List<TlAlgorithmComponent> a) => applyTrendTilesConfig(tags, TlConfig(algorithms: a), (t) => t);
      expect(run(const [TlAlgorithmComponent(type: 'queryfilter', query: '花火')]), ['#花火']);
      expect(run(const [TlAlgorithmComponent(type: 'queryfilter', query: '#花火', exclude: true)]), ['打上会', 'Hanabi', '月見']);
      expect(run(const [TlAlgorithmComponent(type: 'queryfilter', query: 'hanabi')]), ['Hanabi']);
      expect(run(const [TlAlgorithmComponent(type: 'queryfilter', query: '花火', enabled: false)]), tags);
      expect(run(const [TlAlgorithmComponent(type: 'queryfilter')]), tags, reason: '語が空なら何もしない');
      expect(run(const [TlAlgorithmComponent(type: 'suggest'), TlAlgorithmComponent(type: 'chrono')]), tags);
    });

    test('傾向をタグに掛ける: 好きではないジャンルは除き、残りは好きなジャンルに近い順(しきい値では落とさない)', () {
      const tags = ['打上会', '花火大会', '月見', '激辛'];
      expect(applyTendencyToTags(tags, (t) => t, const TendencyProfile()), tags, reason: '効く設定が無ければそのまま');
      final out = applyTendencyToTags(tags, (t) => t, const TendencyProfile(genres: ['花火'], disliked: ['激辛']));
      expect(out.first, '花火大会');
      expect(out, isNot(contains('激辛')));
      expect(out.toSet(), {'打上会', '花火大会', '月見'});
    });
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline, trends: const [TrendTag(tag: '打上会', usersCount: 10), TrendTag(tag: '花火', usersCount: 5), TrendTag(tag: '月見')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).go('/search');
    await tester.pumpAndSettle();
    return c;
  }

  Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);

  testWidgets('検索ホームの歯車 → トレンドタイルのカスタマイズ: 5 つのタブ、取得元は SNS アカウントごとのトレンド (D-440)、重いものは灰色で押せない、検索絞り込みで並びが変わる', (tester) async {
    final c = await pump(tester);
    expect(find.byKey(const ValueKey('trend.tile.月見')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trend.customize')));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    // タブ行(横に送る並び)に 5 つ。
    final tabsRow = find.descendant(of: find.byKey(const ValueKey('tlconfig.tabs')), matching: find.byType(Scrollable)).first;
    for (final t in ['トレンドタイル', 'トレンド TL', 'フォロー中', 'ユーザー', 'Today']) {
      final tab = find.descendant(of: find.byKey(const ValueKey('tlconfig.tabs')), matching: find.text(t));
      await tester.scrollUntilVisible(tab, 80, scrollable: tabsRow);
      expect(tab, findsOneWidget, reason: t);
    }
    await tester.drag(tabsRow, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(inScreen(find.byKey(const ValueKey('tlconfig.tiles.source'))), findsOneWidget);
    expect(inScreen(find.text('トレンドを取得')), findsOneWidget, reason: 'いまのアカウントのトレンド');
    expect(inScreen(find.text('取得元を追加')), findsOneWidget);
    expect(inScreen(find.text('タイムラインを追加')), findsNothing);
    expect(inScreen(find.text('自動更新')), findsNothing);

    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    final suggest = find.byKey(const ValueKey('tlconfig.palette.suggest'));
    expect(find.ancestor(of: suggest, matching: find.byType(Opacity)), findsWidgets, reason: '灰色');
    expect(find.descendant(of: suggest, matching: find.textContaining('ML モデルを使うので')), findsOneWidget);
    await tester.tap(suggest);
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsOneWidget, reason: '押しても足さない(パレットは開いたまま)');
    expect(find.byKey(const ValueKey('tlconfig.palette.tendency')), findsNothing, reason: '傾向は一番最後に固定で掛かるので足さない');
    await tester.tap(find.byKey(const ValueKey('tlconfig.palette.queryfilter')));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsNothing);

    // 検索絞り込みの語を入れた構成(画面の保存と同じ置き場)→ タイルの並びに効く。
    final key = fakeSession().account.key;
    final area = await c.read(settingsAreaProvider(nodeprogAreaFor(key, trendTilesScope)).future);
    final saved = TlConfig.fromJson((jsonDecode(area['tlcfg']! as String) as Map).cast<String, Object?>());
    expect(saved.algorithms.map((a) => a.type), contains('queryfilter'));
    final next = saved.copyWith(algorithms: [for (final a in saved.algorithms) a.isQueryFilter ? a.copyWith(query: '月見', exclude: true) : a]);
    await c.read(settingsAreaProvider(nodeprogAreaFor(key, trendTilesScope)).notifier).set('tlcfg', jsonEncode(next.toJson()));
    final tags = await c.read(trendFrameTagsProvider.future);
    expect([for (final t in tags) t.tag], ['打上会', '花火']);

    // 取得元 (D-440): 入っていないアカウントのトレンドだけにすると、タイルは空。いまのアカウントに戻すと出る。
    final tilesArea = c.read(settingsAreaProvider(nodeprogAreaFor(key, trendTilesScope)).notifier);
    await tilesArea.set('tlcfg', jsonEncode(const TlConfig(sources: [TlSourceComponent(tl: trendTagsKind, account: '@nobody@else.example')], clock: '').toJson()));
    expect(await c.read(trendFrameTagsProvider.future), isEmpty);
    await tilesArea.set('tlcfg', jsonEncode(TlConfig(sources: [TlSourceComponent(tl: trendTagsKind, account: '${fakeSession().account}')], clock: '').toJson()));
    expect([for (final t in await c.read(trendFrameTagsProvider.future)) t.tag], containsAll(['打上会', '花火', '月見']));
  });

  testWidgets('Today / トレンド TL の歯車はそれぞれのタブで開く。傾向を設定していれば、アルゴリズムの最後に緑の枠の固定の項目', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('today.customize')));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tlconfig.tendency.pinned')), findsNothing, reason: '傾向が何も効かない設定なら出さない');
    expect(inScreen(find.text('タイムラインを追加')), findsOneWidget, reason: 'Today は取得元を選べる');

    // 傾向 FOW で好きなジャンルを決めた → 一番最後に固定の項目。
    await c.read(settingsAreaProvider('storage.safe').notifier).set(TendencyProfile.slot, const TendencyProfile(genres: ['花火']).toJson());
    c.invalidate(tendencyProfileProvider);
    await tester.pumpAndSettle();
    final pinned = find.byKey(const ValueKey('tlconfig.tendency.pinned'));
    expect(pinned, findsOneWidget);
    expect(find.descendant(of: pinned, matching: find.text('好きなジャンル 1')), findsOneWidget);
    expect(find.descendant(of: pinned, matching: find.byKey(const ValueKey('tlconfig.tendency.info'))), findsOneWidget);
    final add = tester.getTopLeft(inScreen(find.text('アルゴリズムを追加'))).dy;
    expect(tester.getTopLeft(pinned).dy, lessThan(add));
    expect(tester.getTopLeft(pinned).dy, greaterThan(tester.getTopLeft(inScreen(find.text('時系列順'))).dy), reason: 'ほかのアルゴリズムより後');
    // タイルの並びにも、好きなジャンルに近い順で掛かる。
    expect([for (final t in await c.read(trendFrameTagsProvider.future)) t.tag].first, '花火');
  });
}
