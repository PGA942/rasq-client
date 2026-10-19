import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'package:rasq_client/features/trend/tendency_controls.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/features/users/user_tab_view.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart' show FowFooter;
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-514: ユーザーページの選んでいるタブをもう一度押すと、タブにつながった並べ替え・絞り込みのパネル
/// (検索 / 指向性・刺激性 / 表示 / 並べ替え)。一覧が下へ進んでいれば、まずいちばん上へ。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const alice = UserSummary(id: 'u-alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  const bob = UserSummary(id: 'u-bob', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ');
  Post post(String id, String body, {int day = 1, Map<String, int> reactions = const {}, UserSummary? repostedBy, Post? quote}) =>
      Post(id: id, account: acc, author: alice, createdAt: DateTime(2026, 10, day), body: body, reactions: reactions, repostedBy: repostedBy, quote: quote);

  final curry = post('a1', '今日の晩ごはんはカレー', day: 4, reactions: {'👍': 1});
  final angry = post('a2', 'ふざけるな、許せない。むかつく', day: 3, reactions: {'👍': 5});
  final renote = post('a3', 'リノートされた投稿', day: 2, repostedBy: bob);
  final rocket = post('a4', 'ロケットの打ち上げを見た', day: 1, reactions: {'👍': 2});
  final quote = post('a5', '', quote: post('q', '引用元'));

  group('applyUserTabView (純関数)', () {
    final posts = [curry, angry, renote, rocket, quote];
    List<String> ids(List<Post> ps) => [for (final p in ps) p.id];

    test('既定は SNS の並びのまま全部', () {
      expect(ids(applyUserTabView(posts, UserTabView.defaults)), ['a1', 'a2', 'a3', 'a4', 'a5']);
      expect(UserTabView.defaults.isDefault, isTrue);
    });

    test('並べ替え: 古い順 / リアクション数(同じなら元の順)/ 傾向に合う順', () {
      expect(ids(applyUserTabView(posts, const UserTabView(sort: UserTabSort.oldest))), ['a5', 'a4', 'a3', 'a2', 'a1']);
      expect(ids(applyUserTabView(posts, const UserTabView(sort: UserTabSort.reactions))), ['a2', 'a4', 'a1', 'a3', 'a5']);
      // 好きなジャンル「ロケット」に近いものが上。
      final base = const TendencyProfile(genres: ['ロケット'], stimulus: {});
      expect(applyUserTabView(posts, const UserTabView(sort: UserTabSort.tendency), base: base).first.id, 'a4');
    });

    test('表示: リノート / 引用ノートを隠す', () {
      expect(ids(applyUserTabView(posts, const UserTabView(renotes: false))), ['a1', 'a2', 'a4', 'a5']);
      expect(ids(applyUserTabView(posts, const UserTabView(quotes: false))), ['a1', 'a2', 'a3', 'a4']);
    });

    test('検索: 空白で区切った語を全部含む(引用の本文も見る)', () {
      expect(ids(applyUserTabView(posts, UserTabView.defaults, query: 'カレー')), ['a1']);
      expect(ids(applyUserTabView(posts, UserTabView.defaults, query: '引用元')), ['a5']);
      expect(ids(applyUserTabView(posts, UserTabView.defaults, query: 'ロケット 見た')), ['a4']);
      expect(applyUserTabView(posts, UserTabView.defaults, query: 'ロケット カレー'), isEmpty);
    });

    test('刺激性: 上限を超えたぶんの合計が TL と同じ境目以上なら隠す (D-518) / 指向性: 好きなジャンルから外れたものを隠す', () {
      // トレンドと同じ基準: 少し超えただけでは隠さない(D-514 では 1 つでも超えたら隠していた)。
      expect(tendencyScorer.stimulusPenaltyOf(angry, const TendencyProfile(stimulus: {'anger': 0.3})), allOf(greaterThan(0), lessThan(tendencyStimulusHideAt)));
      expect(ids(applyUserTabView(posts, const UserTabView(stimulus: {'anger': 0.3}))), ['a1', 'a2', 'a3', 'a4', 'a5']);
      expect(ids(applyUserTabView(posts, const UserTabView(stimulus: {'anger': 0.0}))), ['a1', 'a3', 'a4', 'a5']);
      const base = TendencyProfile(genres: ['ロケット'], stimulus: {});
      expect(ids(applyUserTabView(posts, const UserTabView(directionality: 0), base: base)), ['a4']);
      // 好きなジャンルが無ければ指向性では落とさない。
      expect(applyUserTabView(posts, const UserTabView(directionality: 0), base: const TendencyProfile(stimulus: {})), hasLength(5));
    });

    test('保存の形: 既定の欄は書かない / 往復で同じ', () {
      expect(UserTabView.defaults.toJson(), isEmpty);
      const v = UserTabView(sort: UserTabSort.reactions, renotes: false, digest: true, directionality: 0.3, stimulus: {'anger': 0.4, 'joy': 1.0});
      expect(UserTabView.fromJson(jsonDecode(jsonEncode(v.toJson()))), v);
      expect(v.toJson()['stimulus'], {'anger': 0.4});
    });
  });

  group('ユーザーページ', () {
    late MemorySessionStorage storage;
    Future<ProviderContainer> pump(WidgetTester tester, {List<Post>? posts}) async {
      // 縦に長め(ヘッダーの下に 4 件とも並ぶように)。
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final all = posts ?? [curry, angry, renote, rocket];
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => all));
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push('/user/${alice.id}', extra: alice);
      await tester.pumpAndSettle();
      expect(find.byType(UserPageScreen), findsOneWidget);
      return c;
    }

    final panel = find.byKey(const ValueKey('user.tabView.panel'));
    Finder tab(String label) => find.descendant(of: find.byType(TabBar), matching: find.text(label));
    List<String> shownBodies(WidgetTester tester) => [for (final r in tester.widgetList<PostRow>(find.byType(PostRow))) r.post.body];

    testWidgets('選んでいるタブを押すとパネル、別のタブを押すと切り替えるだけ。首 / 閉じるで閉じる', (tester) async {
      await pump(tester);
      await tester.tap(tab('返信'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing, reason: '選んでいないタブは切り替えるだけ');
      expect(find.text('投稿はありません'), findsOneWidget);

      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(find.text('ノートの表示'), findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.search')), findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.radar')), findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.sort.reactions')), findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.digest')), findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.pinned')), findsNothing, reason: 'ピン留めの無い人');
      expect(find.text('4 件中 4 件'), findsOneWidget);
      // D-517: 下は FOW の標準のフッター(件数 + リセット / 閉じる)。
      final footer = find.descendant(of: panel, matching: find.byType(FowFooter));
      expect(footer, findsOneWidget);
      for (final k in ['user.tabView.count', 'user.tabView.reset', 'user.tabView.close']) {
        expect(find.descendant(of: footer, matching: find.byKey(ValueKey(k))), findsOneWidget, reason: k);
      }
      // D-518: 見た目は「このタイムラインから探す」と同じ並び(太い下線の節)、指向性 / 刺激性はトレンドと同じ部品。
      expect(find.descendant(of: panel, matching: find.byType(RasqSectionHeader)), findsNWidgets(3));
      expect(find.descendant(of: panel, matching: find.byType(TendencyControls)), findsOneWidget);
      // スマホの幅では縦に積む(レーダーは指向性の下)。
      expect(find.byKey(const ValueKey('user.tabView.tendency.stacked')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('user.tabView.tendency.stimulus'))).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('user.tabView.tendency.directivity'))).dy - 1));

      await tester.tap(find.byKey(const ValueKey('rasqOverlay.tether.hit')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing, reason: '首(元のタブ)のタップで閉じる');

      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user.tabView.close')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('広い画面ではパネルを広げ、指向性 / 刺激性を横に並べる (D-518)', (tester) async {
      await pump(tester);
      tester.view.physicalSize = const Size(1800, 2400);
      tester.view.devicePixelRatio = 2;
      await tester.pumpAndSettle();
      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(find.byKey(const ValueKey('user.tabView.tendency.columns')), findsOneWidget);
      final dir = tester.getRect(find.byKey(const ValueKey('user.tabView.tendency.directivity')));
      final stim = tester.getRect(find.byKey(const ValueKey('user.tabView.tendency.stimulus')));
      expect(stim.top, dir.top);
      expect(stim.left, greaterThanOrEqualTo(dir.right - 1));
    });

    testWidgets('並べ替え・表示・検索がすぐ一覧に効き、タブの種類ごとに保存される。リセットで元へ', (tester) async {
      final c = await pump(tester);
      expect(shownBodies(tester), [curry.body, angry.body, renote.body, rocket.body]);
      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('user.tabView.sort.reactions')));
      await tester.pumpAndSettle();
      expect(shownBodies(tester), [angry.body, rocket.body, curry.body, renote.body]);

      await tester.tap(find.byKey(const ValueKey('user.tabView.renotes')));
      await tester.pumpAndSettle();
      expect(shownBodies(tester), [angry.body, rocket.body, curry.body]);
      expect(find.text('4 件中 3 件'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('user.tabView.search')), 'カレー');
      await tester.pumpAndSettle();
      expect(shownBodies(tester), [curry.body]);

      await tester.tap(find.byKey(const ValueKey('user.tabView.digest')));
      await tester.pumpAndSettle();
      expect(find.byType(PostRow), findsNothing);
      expect(find.byKey(ValueKey('user.digest.${curry.id}')), findsOneWidget);

      // 保存(KV userPageTabs.v1 のキー posts)。検索の語は保存しない。
      final saved = jsonDecode((await storage.read('userPageTabs.v1'))!) as Map;
      expect(saved['posts'], {'sort': 'reactions', 'renotes': false, 'digest': true});
      expect(jsonEncode(saved), isNot(contains('カレー')));

      await tester.tap(find.byKey(const ValueKey('user.tabView.close')));
      await tester.pumpAndSettle();
      // 変えているタブの印(名前の右肩の点)。
      expect(find.descendant(of: find.byType(TabBar), matching: find.byKey(const ValueKey('tab.dot'))), findsOneWidget);

      // 開き直す(別の人のページでも同じ = タブの種類ごと)。読み直しても効いている。
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.invalidate(settingsAreaProvider('userPageTabs'));
      c.read(routerProvider).push('/user/${alice.id}', extra: alice);
      await tester.pumpAndSettle();
      expect(find.byType(PostRow), findsNothing, reason: 'ダイジェストのまま');
      final digestIds = [for (final w in tester.widgetList<InlinePostFrame>(find.byType(InlinePostFrame))) w.post.id];
      expect(digestIds, [angry.id, rocket.id, curry.id], reason: 'リアクション数の順、リノートなし(検索の語は消えている)');

      // リセット。
      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user.tabView.reset')));
      await tester.pumpAndSettle();
      expect(shownBodies(tester), [curry.body, angry.body, renote.body, rocket.body]);
      final after = jsonDecode((await storage.read('userPageTabs.v1'))!) as Map;
      expect(after['posts'], isNull);
    });

    testWidgets('指向性 / 刺激性の欄に指を置いている間は、タブの横のスワイプと戻るジェスチャーを止める。レーダーで刺激性を絞る', (tester) async {
      await pump(tester);
      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      TabBarView view() => tester.widget<TabBarView>(find.byType(TabBarView));
      PopScope pop() => tester.widget<PopScope>(find.ancestor(of: find.byType(RasqCollapsibleTabScaffold), matching: find.byWidgetPredicate((w) => w is PopScope)).first);
      expect(view().physics, isNull);
      expect(pop().canPop, isTrue);

      final radar = find.byKey(const ValueKey('user.tabView.radar'));
      await tester.ensureVisible(radar);
      await tester.pumpAndSettle();
      final center = tester.getCenter(radar);
      // 怒り(真上から時計回りに 7 番目 = 真左)の軸を、中心まで(トレンドと同じ基準なので、ほぼ 0 まで絞ると隠れる)。
      final g = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump();
      expect(view().physics, isA<NeverScrollableScrollPhysics>(), reason: '触れている間はタブの横のスワイプを止める');
      expect(pop().canPop, isFalse, reason: '戻るジェスチャーも止める');
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(view().physics, isNull);
      expect(pop().canPop, isTrue);
      final saved = jsonDecode((await storage.read('userPageTabs.v1'))!) as Map;
      final cap = ((saved['posts'] as Map)['stimulus'] as Map)['anger'] as num;
      expect(cap, lessThan(0.15));
      expect(shownBodies(tester), isNot(contains(angry.body)), reason: '怒りの強い投稿を隠す');

      // スライダー(指向性)も同じ欄。
      final slider = find.descendant(of: find.byKey(const ValueKey('user.tabView.tendency.slider')), matching: find.byType(Slider));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final g2 = await tester.startGesture(tester.getCenter(slider));
      await tester.pump();
      expect(view().physics, isA<NeverScrollableScrollPhysics>());
      await g2.up();
      await tester.pumpAndSettle();
      expect(view().physics, isNull);
    });

    testWidgets('一覧が下へ進んでいれば、選んでいるタブのタップはまずいちばん上へ(パネルは開かない)', (tester) async {
      await pump(tester, posts: [for (var i = 0; i < 30; i++) post('m$i', '投稿 $i', day: 1)]);
      await tester.drag(find.byType(PostRow).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      final nested = tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
      expect(nested.innerController.offset, greaterThan(0));

      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(nested.innerController.offset, 0);

      await tester.tap(tab('ノート'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget, reason: 'いちばん上ならパネル');
    });
  });
}
