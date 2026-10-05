import 'dart:convert';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart' show TimelineConfigScreen;
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/nodeprog/tl_sections_view.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/vc/astell_actions.dart' show AstellRoomTile;
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart' show astellHomeProvider;
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart' show RasqPluginTile;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-439 → D-442: セクション(「SNSタイムライン」の並びの中に置き、ノードを 3 つまで包む)と表示モード。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(int i, {String author = 'u1'}) => Post(
        id: 'p$i',
        account: acc,
        author: UserSummary(id: author, account: acc, displayName: '人$author'),
        createdAt: DateTime(2026, 10, 5, 12).subtract(Duration(minutes: i)),
        body: '投稿 $i',
      );
  AstellRoom room(String id, String title) => AstellRoom(id: id, ownerId: 'o', ownerHandle: 'o', ownerDisplayName: 'オーナー', title: title, createdAt: DateTime(2026, 10, 5));

  group('構成', () {
    test('JSON: セクションは子を 3 つまで。既定(通常 TL / 5 件)は書かない', () {
      const sec = TlSourceComponent(tl: sectionKind, label: '枠', children: [
        TlSourceComponent(tl: 'home', display: TlDisplayMode.relational, limit: 3),
        TlSourceComponent(tl: astellSectionKind),
        TlSourceComponent(tl: swingSectionKind),
        TlSourceComponent(tl: 'local'),
      ]);
      final back = TlSourceComponent.fromJson(jsonDecode(jsonEncode(sec.toJson())) as Map<String, Object?>);
      expect(back.children.map((c) => c.tl), ['home', astellSectionKind, swingSectionKind], reason: '3 つまで');
      expect(back.children.first.display, TlDisplayMode.relational);
      expect(back.children.first.limit, 3);
      expect(const TlSourceComponent().toJson().keys, isNot(containsAll(['limit', 'display', 'children'])));
    });

    test('D-439 の sections は、並びの先頭のセクションに写す', () {
      final cfg = TlConfig.fromJson({
        'sources': [{'tl': 'home'}],
        'sections': [{'id': 's1', 'title': 'おすすめ', 'tl': 'social', 'display': 'users', 'limit': 3}],
      });
      expect(cfg.sources.first.isSection, isTrue);
      expect(cfg.sources.first.label, 'おすすめ');
      expect((cfg.sources.first.children.single.tl, cfg.sources.first.children.single.display, cfg.sources.first.children.single.limit), ('social', TlDisplayMode.users, 3));
      expect(cfg.postSources.single.tl, 'home');
    });

    test('画面の並び: 並びの順。セクションの外の TL ノードは 1 本(最初の TL ノードの位置)。TL ノードが無ければ本体なし', () {
      const sec = TlSourceComponent(tl: sectionKind, label: 'A');
      const sw = TlSourceComponent(tl: swingSectionKind);
      final l = tlPageLayout(const TlConfig(sources: [sec, TlSourceComponent(tl: 'home'), sw, TlSourceComponent(tl: 'local')]));
      expect((l.before.single.label, l.main, l.after.single.tl), ('A', true, swingSectionKind));
      expect(tlPageLayout(const TlConfig(sources: [sec])).main, isFalse);
      expect(tlPageLayout(null).main, isTrue);
      final g = compileTlConfig(const TlConfig(sources: [sec, TlSourceComponent(tl: 'home'), sw]), scope: 'tl.home');
      expect([for (final n in g.nodes) if (n.type == 'tl.source') n.inputs.first.value], ['home'], reason: 'セクション / ブロックは本体のグラフに入れない');
    });

    test('トレンド TL の既定: 「フォロー中の反応」のセクション(AsTell / 会話 / 投稿)→ 本体はこのページの検索結果', () {
      final d = defaultTlConfig('trend');
      expect(d.sources.first.isSection, isTrue);
      expect(d.sources.first.label, 'フォロー中の反応');
      expect(d.sources.first.children.map((c) => (c.tl, c.display)), [(astellSectionKind, TlDisplayMode.timeline), (trendFollowingKind, TlDisplayMode.relational), (trendFollowingKind, TlDisplayMode.timeline)]);
      expect(d.postSources.single.tl, pageSearchKind);
    });
  });

  late List<Post> posts;
  late FakeSnsPlugin plugin;

  /// 開いたときに見えるタブ(テストの SNS はソーシャル)の構成を [cfg] にする。
  Future<ProviderContainer> pump(WidgetTester tester, TlConfig cfg, {String scope = 'tl.social', List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = fakeSession().account.key;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': key}),
    });
    posts = [for (var i = 0; i < 12; i++) post(i, author: i < 8 ? 'a' : 'b')];
    plugin = FakeSnsPlugin(posts: (_) => posts);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)), ...extra],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(settingsAreaProvider(nodeprogAreaFor(key, scope)).notifier).set('tlcfg', jsonEncode(cfg.toJson()));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('セクションの中のノードは入れた順に角丸の枠で。中の TL は新しい投稿を読み込まず、↻ で読み直す', (tester) async {
    final c = await pump(
      tester,
      const TlConfig(sources: [
        TlSourceComponent(tl: sectionKind, label: 'まとめ', children: [
          TlSourceComponent(tl: 'home', limit: 3),
          TlSourceComponent(tl: astellSectionKind, limit: 2),
        ]),
        TlSourceComponent(tl: 'social'),
      ]),
      extra: [astellHomeProvider.overrideWith((ref) async => AstellHome(trending: [room('r1', '花火'), room('r2', '月見'), room('r3', '紅葉')]))],
    );
    final first = find.byKey(const ValueKey('tl.section.まとめ.0'));
    final second = find.byKey(const ValueKey('tl.section.まとめ.1'));
    expect(find.descendant(of: first, matching: find.textContaining('投稿 ')), findsNWidgets(3), reason: '件数まで');
    expect(find.descendant(of: second, matching: find.byType(AstellRoomTile)), findsNWidgets(2));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy), reason: '入れた順');
    plugin.opened.last.prepend(post(99));
    await c.read(timelineProvider(TimelineKind.home).notifier).prependNewer();
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: find.text('投稿 99')), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('tl.section.まとめ')), matching: find.byTooltip('読み直す')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: find.text('投稿 99')), findsOneWidget);
  });

  testWidgets('表示モード: ユーザー(投稿の多い順)', (tester) async {
    await pump(tester, const TlConfig(sources: [TlSourceComponent(tl: 'social')], display: TlDisplayMode.users));
    expect(find.byKey(const ValueKey('tl.display.users')), findsOneWidget);
    expect(find.text('8 件の投稿'), findsOneWidget);
    expect(tester.getTopLeft(find.text('人a')).dy, lessThan(tester.getTopLeft(find.text('人b')).dy));
  });

  group('カスタマイズ画面 (D-442)', () {
    Future<ProviderContainer> open(WidgetTester tester, TlConfig cfg) async {
      final c = await pump(tester, cfg, scope: 'tl.home');
      c.read(routerProvider).push(Routes.tlConfig('tl.home'));
      await tester.pumpAndSettle();
      return c;
    }

    Future<TlConfig> saved(ProviderContainer c) async {
      final area = await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'tl.home')).future);
      return TlConfig.fromJson((jsonDecode(area['tlcfg']! as String) as Map).cast<String, Object?>());
    }

    /// 画面の縦のリストを送って [f] を出す(上にあっても下にあっても)。
    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      final list = find.descendant(of: find.byType(TimelineConfigScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first;
      await tester.drag(list, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(f, 200, scrollable: list);
    }

    testWidgets('パレットで長押し → 置く場所を選ぶ(セクションの中にも)', (tester) async {
      final c = await open(tester, const TlConfig(sources: [TlSourceComponent(tl: sectionKind, label: '枠'), TlSourceComponent(tl: 'home')]));
      await scrollTo(tester, find.text('タイムラインを追加'));
      await tester.tap(find.text('タイムラインを追加'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Swing'), 200, scrollable: find.byType(Scrollable).last);
      await tester.longPress(find.text('Swing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tlconfig.placing')), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('tlconfig.slot.0.0')));
      await tester.tap(find.byKey(const ValueKey('tlconfig.slot.0.0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tlconfig.placing')), findsNothing);
      final cfg = await saved(c);
      expect(cfg.sources.first.children.single.tl, swingSectionKind, reason: 'セクションの中へ置いた');
    });

    testWidgets('並べ替え: タイルをつかんでセクションの中へ動かす(3 つまで)/ セクションから出す', (tester) async {
      final c = await open(tester, const TlConfig(sources: [
        TlSourceComponent(tl: sectionKind, label: '枠', children: [TlSourceComponent(tl: astellSectionKind)]),
        TlSourceComponent(tl: 'home'),
        TlSourceComponent(tl: 'local'),
      ]));
      await scrollTo(tester, find.byKey(const ValueKey('tlconfig.sources.reorder')));
      await tester.tap(find.byKey(const ValueKey('tlconfig.sources.reorder')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tlconfig.reorder.hint')), findsOneWidget);
      // local(並びの 3 つ目)をセクションの 2 つ目へ。
      final from = find.byKey(const ValueKey('tlconfig.drag.top.2'));
      final to = find.byKey(const ValueKey('tlconfig.slot.0.1'));
      await scrollTo(tester, from);
      final g = await tester.startGesture(tester.getCenter(from));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      // つかんだタイルはそのままの見た目で指について動き、元の場所には薄い写しを残さない (D-443)。
      final feedback = find.byKey(const ValueKey('tlconfig.drag.feedback'));
      expect(feedback, findsOneWidget);
      expect(find.descendant(of: feedback, matching: find.byType(RasqPluginTile)), findsOneWidget);
      expect(find.descendant(of: from, matching: find.byType(RasqPluginTile)), findsNothing);
      await g.moveTo(tester.getCenter(to));
      await tester.pump();
      await g.moveTo(tester.getCenter(to) + const Offset(0, 1));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      var cfg = await saved(c);
      expect(cfg.sources.first.children.map((x) => x.tl), [astellSectionKind, 'local']);
      expect(cfg.sources.where((x) => !x.isSection).map((x) => x.tl), ['home']);
      // 並べ替えを終えて、… → セクションから出す。
        await scrollTo(tester, find.byKey(const ValueKey('tlconfig.sources.reorder')));
      await tester.tap(find.byKey(const ValueKey('tlconfig.sources.reorder')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('tlconfig.section.0.child.1.more')));
      await tester.tap(find.byKey(const ValueKey('tlconfig.section.0.child.1.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('セクションから出す'));
      await tester.pumpAndSettle();
      cfg = await saved(c);
      expect(cfg.sources.map((x) => x.tl), [sectionKind, 'local', 'home']);
    });
  });
}
