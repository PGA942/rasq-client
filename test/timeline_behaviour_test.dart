import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/learning_api.dart';
import 'package:rasq_client/features/home/home_header.dart' show homeHeaderArea;
import 'package:rasq_client/features/learning/contribution.dart';
import 'package:rasq_client/features/home/new_posts_pill.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart' show nodeprogAreaFor;
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/scroll_memory.dart';
import 'package:rasq_client/shell/scroll_to_top.dart';
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
  group('D-505 開いている画面のボタンをもう一度押すと、いちばん上へ', () {
    testWidgets('ホーム: 開いているタブの TL だけいちばん上へ。隠れたタブの位置は残す。別のページを開いていれば一番上の画面へ戻る', (tester) async {
      await pump(tester);
      await tester.drag(find.byKey(const ValueKey('tl.view.social')), const Offset(0, -1500));
      await tester.pumpAndSettle();
      final social = tlPosition(tester, 'tl.view.social').pixels;
      expect(social, greaterThan(1000));
      // 「フォロー中」のタブへ移って、そちらも下へ。
      await tester.tap(find.text('フォロー中').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('tl.view.home')), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tlPosition(tester, 'tl.view.home').pixels, greaterThan(500));
      // 下のナビのホーム(選んでいるので塗りのアイコン)をもう一度押す。
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      final home = tlPosition(tester, 'tl.view.home');
      expect(home.pixels, home.minScrollExtent, reason: 'いちばん上へ');
      expect(find.text('投稿 0'), findsOneWidget);
      // 隠れているソーシャルは動かさない(D-504 の位置のまま)。
      await tester.tap(find.text('おすすめ').first);
      await tester.pumpAndSettle();
      expect(tlPosition(tester, 'tl.view.social').pixels, social);
      // 投稿を開いた(タブの中のページ)ときは、もう一度押すと一番上の画面へ戻る(いちばん上へは送らない)。
      await tester.tap(find.textContaining('投稿 ').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tl.view.social')), findsNothing);
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tl.view.social')), findsOneWidget);
      expect(tlPosition(tester, 'tl.view.social').pixels, social, reason: '戻っただけ');
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(tlPosition(tester, 'tl.view.social').pixels, tlPosition(tester, 'tl.view.social').minScrollExtent);
    });

    testWidgets('scrollToTopIn: 縦の一覧だけ、TickerMode が切れた / Offstage の中は動かさない', (tester) async {
      final a = ScrollController(initialScrollOffset: 400);
      final b = ScrollController(initialScrollOffset: 400);
      final h = ScrollController(initialScrollOffset: 400);
      final o = ScrollController(initialScrollOffset: 400);
      final root = GlobalKey();
      Widget list(ScrollController c, {Axis axis = Axis.vertical}) => SizedBox(height: 100, width: 200, child: ListView.builder(scrollDirection: axis, controller: c, itemCount: 100, itemBuilder: (_, i) => SizedBox(height: 50, width: 50, child: Text('$i'))));
      await tester.pumpWidget(MaterialApp(
        home: Builder(key: root, builder: (context) => Column(children: [
          list(a),
          TickerMode(enabled: false, child: list(b)),
          list(h, axis: Axis.horizontal),
          Offstage(child: list(o)),
        ])),
      ));
      expect(scrollToTopIn(root.currentContext!), isTrue);
      await tester.pumpAndSettle();
      expect((a.offset, b.offset, h.offset, o.offset), (0.0, 400.0, 400.0, 400.0));
    });
  });
  group('D-506 新しい投稿の札', () {
    /// SNS に新しい投稿を足して、TL の自動更新(上に足す)を回す。
    Future<void> arrive(WidgetTester tester, ProviderContainer c, List<Post> fresh) async {
      for (final s in plugin.opened) {
        for (final p in fresh.reversed) {
          s.prepend(p);
        }
      }
      await c.read(timelineProvider(TimelineKind.social).notifier).prependNewer();
      await tester.pumpAndSettle();
    }

    final pill = find.byKey(const ValueKey('tl.newPosts.pill'));

    testWidgets('届くと「顔 新しい投稿」(3 人まで)、押すといちばん上へ送って消える', (tester) async {
      final c = await pump(tester);
      await arrive(tester, c, [post(-1, author: 'x'), post(-2, author: 'y'), post(-3, author: 'x'), post(-4, author: 'z'), post(-5, author: 'w')]);
      expect(pill, findsOneWidget);
      expect(find.descendant(of: pill, matching: find.text('新しい投稿')), findsOneWidget);
      for (final a in ['x', 'y', 'z']) {
        expect(find.byKey(ValueKey('tl.newPosts.face.misskey:example.test:$a')), findsOneWidget, reason: '新しい順に 3 人');
      }
      expect(find.byKey(const ValueKey('tl.newPosts.face.misskey:example.test:w')), findsNothing);
      expect(find.text('投稿 -1'), findsNothing, reason: '見ている位置は動かない(中心より上に足した)');
      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(pill, findsNothing);
      expect(find.text('投稿 -1'), findsOneWidget);
      final pos = tlPosition(tester, 'tl.view.social');
      expect(pos.pixels, pos.minScrollExtent);
    });

    testWidgets('しばらくたつと消える / 自分でいちばん上まで送っても消える', (tester) async {
      NewPostsPillController.duration = const Duration(seconds: 3);
      addTearDown(() => NewPostsPillController.duration = const Duration(seconds: 10));
      final c = await pump(tester);
      await arrive(tester, c, [post(-1, author: 'x')]);
      expect(pill, findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(pill, findsNothing);
      await arrive(tester, c, [post(-2, author: 'y')]);
      expect(pill, findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('tl.view.social')), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(pill, findsNothing);
    });

    testWidgets('ヘッダーをしまっている間 / 設定で切ると出さない', (tester) async {
      final c = await pump(tester);
      await c.read(settingsAreaProvider(homeHeaderArea).notifier).set('collapsed', true);
      await tester.pumpAndSettle();
      await arrive(tester, c, [post(-1, author: 'x')]);
      expect(pill, findsNothing);
      await c.read(settingsAreaProvider(homeHeaderArea).notifier).set('collapsed', false);
      await tester.pumpAndSettle();
      expect(pill, findsOneWidget, reason: 'ヘッダーを戻せば、まだ消えていない札は出る');
      await c.read(settingsAreaProvider(timelineDisplayArea).notifier).set('newPostsPill', false);
      await tester.pumpAndSettle();
      expect(pill, findsNothing);
      await arrive(tester, c, [post(-2, author: 'y')]);
      expect(pill, findsNothing);
    });
  });
  group('D-507 自分の投稿が TL に出る(表示モードごと)', () {
    /// ＋ のボタン(タップ = 投稿)から投稿する。
    Future<void> postViaFab(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const ValueKey('fab.home.gesture')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pumpAndSettle();
      await tester.tap(find.text('送信'));
      await tester.pumpAndSettle();
    }

    Future<void> setConfig(ProviderContainer c, String scope, TlConfig cfg, WidgetTester tester) async {
      await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, scope)).notifier).set('tlcfg', jsonEncode(cfg.toJson()));
      await tester.pumpAndSettle();
    }

    Finder shown(String text) => find.text(text).hitTestable();

    testWidgets('通常の表示(いちばん上を見ている): 開いているタブ(フォロー中以外)にも出て、見える位置まで送る', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('tl.view.social')), findsOneWidget);
      await postViaFab(tester, '自分の投稿 A');
      expect(shown('自分の投稿 A'), findsOneWidget, reason: '開いているおすすめ(social)の TL');
    });

    testWidgets('フォロー中のタブ: 上に足した投稿が見える位置まで送る', (tester) async {
      await pump(tester);
      await tester.tap(find.text('フォロー中').first);
      await tester.pumpAndSettle();
      await postViaFab(tester, '自分の投稿 B');
      expect(shown('自分の投稿 B'), findsOneWidget);
    });

    testWidgets('下のほうを読んでいるときは動かさず、「新しい投稿」の札で知らせる', (tester) async {
      await pump(tester);
      await tester.drag(find.byKey(const ValueKey('tl.view.social')), const Offset(0, -1500));
      await tester.pumpAndSettle();
      final at = tlPosition(tester, 'tl.view.social').pixels;
      await postViaFab(tester, '自分の投稿 C');
      expect(tlPosition(tester, 'tl.view.social').pixels, at);
      expect(find.byKey(const ValueKey('tl.newPosts.pill')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tl.newPosts.pill')));
      await tester.pumpAndSettle();
      expect(shown('自分の投稿 C'), findsOneWidget);
    });

    testWidgets('表示モード: ユーザー / 関連(会話)でも読み直す', (tester) async {
      final c = await pump(tester);
      await setConfig(c, 'tl.social', const TlConfig(sources: [TlSourceComponent(tl: 'social')], display: TlDisplayMode.users), tester);
      expect(find.text('テスター'), findsNothing);
      await postViaFab(tester, '自分の投稿 D');
      expect(find.text('テスター'), findsOneWidget, reason: 'ユーザーの並びに自分');
    });

    testWidgets('セクションだけの並び(本体の TL なし): セクションの中の TL も読み直す', (tester) async {
      final c = await pump(tester);
      await setConfig(
          c,
          'tl.social',
          const TlConfig(sources: [
            TlSourceComponent(tl: sectionKind, label: 'まとめ', children: [TlSourceComponent(tl: 'home', limit: 3)]),
          ]),
          tester);
      expect(find.text('投稿 0'), findsOneWidget);
      await postViaFab(tester, '自分の投稿 E');
      expect(find.text('自分の投稿 E'), findsOneWidget);
    });

    testWidgets('総合表示: 総合の TL に出る', (tester) async {
      final c = await pump(tester);
      await c.read(sessionsProvider.notifier).setBundleView(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tl.view.bundle')), findsOneWidget);
      await postViaFab(tester, '自分の投稿 F');
      expect(shown('自分の投稿 F'), findsOneWidget);
    });

    testWidgets('隠れているタブは、開いたときに読み直す', (tester) async {
      await pump(tester);
      await tester.tap(find.text('フォロー中').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('おすすめ').first);
      await tester.pumpAndSettle();
      await postViaFab(tester, '自分の投稿 G');
      await tester.tap(find.text('フォロー中').first);
      await tester.pumpAndSettle();
      expect(shown('自分の投稿 G'), findsOneWidget);
    });
  });
  group('D-508 見えていない TL は読まない', () {
    int fetches() => plugin.opened.fold(0, (n, s) => n + s.timelineFetches);
    int userFetches() => plugin.opened.fold(0, (n, s) => n + s.userPostsFetches);
    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets('隠れたタブの TL は、読み直しを頼まれても取りに行かず、開いたときに 1 回だけ取る', (tester) async {
      final c = await pump(tester);
      await openTab(tester, 'フォロー中');
      await openTab(tester, 'おすすめ');
      final before = fetches();
      // RAi の関数 / リストの変更などが「フォロー中」の読み直しを頼む(隠れている)。
      for (var i = 0; i < 3; i++) {
        c.invalidate(timelineProvider(TimelineKind.home));
        await tester.pumpAndSettle();
      }
      debugPrint('D-508 hidden TL fetches after 3 invalidations: ${fetches() - before}');
      expect(fetches() - before, 0, reason: '隠れている間は取りに行かない');
      await openTab(tester, 'フォロー中');
      expect(fetches() - before, 1, reason: '開いたときに 1 回');
      // 見えている TL は今までどおりすぐ読み直す。
      c.invalidate(timelineProvider(TimelineKind.home));
      await tester.pumpAndSettle();
      expect(fetches() - before, 2);
    });

    testWidgets('しばらく隠れていた TL は、開いたときに新しい投稿を上に足す', (tester) async {
      TimelineNotifier.staleAfter = Duration.zero;
      addTearDown(() => TimelineNotifier.staleAfter = const Duration(minutes: 2));
      await pump(tester);
      await openTab(tester, 'フォロー中');
      await openTab(tester, 'おすすめ');
      for (final s in plugin.opened) {
        s.prepend(post(-1, author: 'x'));
      }
      final before = fetches();
      await openTab(tester, 'フォロー中');
      expect(fetches() - before, 1);
      expect(find.byKey(const ValueKey('tl.newPosts.pill')), findsOneWidget, reason: '上に足した(D-506 の札)');
    });

    testWidgets('学習への貢献が入っていても、関連 TL を開いていなければ会話を組まない(ゲストの投稿を取りに行かない)', (tester) async {
      ContributionController.debounce = const Duration(days: 1);
      final c = await pump(tester, extra: [learningProvider.overrideWith(_GrantedLearning.new)]);
      await c.read(learningProvider.future);
      await tester.pumpAndSettle();
      expect(c.read(contributionProvider).active, isTrue);
      // リノートで運ばれてきた、フォローしていない人(関連 TL のゲスト D-046)の投稿が届き続ける。
      for (var i = 0; i < 3; i++) {
        for (final s in plugin.opened) {
          s.prepend(Post(
              id: 'rn$i',
              account: acc,
              author: UserSummary(id: 'guest$i', account: acc, displayName: 'ゲスト$i'),
              repostedBy: UserSummary(id: 'u1', account: acc, displayName: '人u1'),
              createdAt: DateTime(2026, 10, 20, 12, 1 + i),
              body: 'リノート $i'));
        }
        await c.read(timelineProvider(TimelineKind.home).notifier).prependNewer();
        await tester.pumpAndSettle();
      }
      debugPrint('D-508 guest userPosts fetches while 関連 is hidden: ${userFetches()}');
      expect(userFetches(), 0, reason: '関連 TL が見えていない');
      await openTab(tester, '関連');
      expect(userFetches(), greaterThan(0), reason: '開けば組む');
    });
  });
}

class _GrantedLearning extends LearningNotifier {
  @override
  Future<LearningStatus?> build() async => const LearningStatus(open: true, granted: true, eligible: true, scope: 'extended');
}
