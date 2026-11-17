import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/feature_flags.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/settings/settings_sections.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_codec.dart';
import 'package:rasq_client/features/theme/icon_theme/rasq_theme_spec.dart';
import 'package:rasq_client/features/theme/tag_themes/community_tag_screen.dart';
import 'package:rasq_client/features/theme/tag_themes/tag_themes.dart';
import 'package:rasq_client/l10n/gen/app_localizations_ja.dart';
import 'package:rasq_client/features/theme/theme_display.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// ハッシュタグのテーマ: 共通の形と一覧 (D-582)・コミュハッシュタグ (D-583)・RASQ Atmos (D-584)。
/// テーマを付けたページ (D-587: 着せ替えと同じ層の ThemedSurface)。
Finder themedBy(RasqThemeSource source) => find.byWidgetPredicate((w) => w is ThemedSurface && w.spec?.source == source);

void main() {
  const basic = IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 68], text: [255, 255, 255], accent: [0, 204, 255], particle: 3);
  Map<String, Object?> theme({List<Map<String, Object?>> triggers = const [], Map<String, Object?>? scope}) => {
        ...RasqThemeSpec(basic: basic, frames: const [RasqThemeFrameRef(svgId: 'star')]).toJson(),
        'triggers': triggers,
        'scope': ?scope,
      };
  Map<String, Object?> atmosJson({String tag = 'RasqFes', bool thread = true, String? until}) => {
        'id': 'at_1',
        'kind': 'atmos',
        'tag': tag,
        'thread': thread,
        'until': ?until,
        'theme': theme(triggers: [
          {'kind': 'hashtagBadge', 'hashtag': tag, 'svg': 'star'},
          {'kind': 'actionAnimation', 'action': 'reply', 'svg': 'sparkle', 'motion': 'burst'},
        ]),
      };
  Map<String, Object?> communityJson({String tag = 'RasqArt'}) => {'id': 'ct_1', 'kind': 'community', 'tag': tag, 'theme': theme()};

  group('共通の形と一覧 (D-582)', () {
    test('1 件: タグは小文字・# なし、source / scope はアプリが決める、コミュハッシュタグはきっかけを持たない', () {
      final a = TagThemeEntry.fromJson({...atmosJson(tag: '#RasqFes'), 'theme': theme(scope: {'kind': 'profile'}, triggers: [
        {'kind': 'hashtagBadge', 'hashtag': 'ほかのタグ', 'svg': 'ring'},
        {'kind': 'hashtagBadge', 'hashtag': 'rasqfes', 'svg': 'star'},
        {'kind': 'actionAnimation', 'action': 'Reaction', 'svg': 'sparkle', 'motion': 'wiggle'},
      ])})!;
      expect(a.tag, 'rasqfes');
      expect(a.spec.source, RasqThemeSource.atmos);
      expect(a.spec.scope, const RasqThemeScope.hashtag('rasqfes'));
      expect(a.spec.triggers.map((t) => t.svgId), ['star', 'sparkle'], reason: 'ほかのタグの SVG アイコンは捨てる');
      expect(a.spec.triggers.last.motion, RasqThemeMotion.pop, reason: '知らない動きは pop');
      expect(a.thread, isTrue);
      final c = TagThemeEntry.fromJson({...communityJson(), 'thread': true, 'theme': theme(triggers: [{'kind': 'hashtagBadge', 'hashtag': 'rasqart', 'svg': 'star'}])})!;
      expect(c.spec.source, RasqThemeSource.communityTag);
      expect(c.spec.triggers, isEmpty);
      expect(c.thread, isFalse, reason: 'スレッドのテーマは Atmos だけ');
    });

    test('読めないものは使わない: 知らない種類・タグの形・id の形・テーマ', () {
      expect(TagThemeEntry.fromJson({...atmosJson(), 'kind': 'banner'}), isNull);
      expect(TagThemeEntry.fromJson(atmosJson(tag: 'two words')), isNull);
      expect(TagThemeEntry.fromJson(atmosJson(tag: 'a/b')), isNull);
      expect(TagThemeEntry.fromJson({...atmosJson(), 'id': '../x'}), isNull);
      expect(TagThemeEntry.fromJson({...atmosJson(), 'theme': {'v': 9}}), isNull);
    });

    test('アクションは ID でも種類でも当たる(大文字小文字は見ない)', () {
      final a = TagThemeEntry.fromJson({...atmosJson(), 'theme': theme(triggers: [{'kind': 'actionAnimation', 'action': 'reaction', 'svg': 'sparkle'}])})!;
      expect(a.animationFor(const ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'r')), isNotNull);
      expect(a.animationFor(const ActionDescriptor(id: 'like', genreTag: 'Reaction', label: 'l')), isNotNull);
      expect(a.animationFor(const ActionDescriptor(id: 'reply', genreTag: 'Reply', label: 'p')), isNull);
    });

    test('きっかけの動きは JSON で往復する', () {
      const t = RasqThemeTrigger.actionAnimation(actionId: 'renote', svgId: 'ring', motion: RasqThemeMotion.spin);
      expect(RasqThemeTrigger.fromJson(t.toJson()), t);
      expect(const RasqThemeTrigger.actionAnimation(actionId: 'renote', svgId: 'ring').toJson().containsKey('motion'), isFalse);
    });

    test('一覧: 同じ種類・同じタグは先のものだけ、期限の過ぎたものは使わない、取り直しの間隔は 15 分〜1 日', () {
      final cat = TagThemeCatalog.fromJson({
        'entries': [
          atmosJson(),
          {...atmosJson(tag: 'RASQFES'), 'id': 'at_dup'},
          {...atmosJson(tag: 'old', until: '2020-01-01T00:00:00Z'), 'id': 'at_old'},
          communityJson(),
          'garbage',
        ],
        'refreshSeconds': 5,
      });
      expect(cat.entries.map((e) => e.id), ['at_1', 'at_old', 'ct_1']);
      expect(cat.refresh, const Duration(minutes: 15));
      expect(cat.find(TagThemeKind.atmos, '#RASQFES')?.id, 'at_1');
      expect(cat.find(TagThemeKind.atmos, 'old'), isNull);
      expect(cat.find(TagThemeKind.community, 'rasqart')?.id, 'ct_1');
      expect(cat.find(TagThemeKind.atmos, 'rasqart'), isNull, reason: '種類が違えば当たらない');
      expect(cat.atmosFor(['none', 'rasqfes'])?.id, 'at_1');
    });

    test('投稿のハッシュタグは表示と同じ MFM の読み方で拾う(コードの中は拾わない)', () {
      Post p(String body) => Post(id: 'x', account: fakeSession().account, author: UserSummary(id: 'u', account: fakeSession().account, displayName: 'a'), createdAt: DateTime(2026), body: body);
      expect(postHashtags(p('今日は #RasqFes と #絵描き と #rasqfes')), ['rasqfes', '絵描き']);
      expect(postHashtags(p('`#notatag` だけ')), isEmpty);
      expect(postHashtags(p('タグなし')), isEmpty);
    });

    test('機能フラグ: 既定はすべて無効、名前で立てる', () {
      expect(ProviderContainer().read(featureFlagsProvider), const RasqFeatureFlags());
      expect(RasqFeatureFlags.parse('atmos, unknown'), const RasqFeatureFlags(atmos: true));
      expect(RasqFeatureFlags.parse('communityTagThemes,atmos').anyTagThemes, isTrue);
    });

    test('無効なら一覧を取りに行かない / 有効ならトークンを付けず via=app だけで取る(タグも送らない)', () async {
      final requests = <http.Request>[];
      final mock = MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode({'entries': [atmosJson()], 'refreshSeconds': 3600}), 200, headers: {'content-type': 'application/json'});
      });
      OrgateClient client(Ref ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => 'secret-token');
      final off = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage()), orgateClientProvider.overrideWith(client)]);
      addTearDown(off.dispose);
      expect((await off.read(tagThemeCatalogProvider.future)).entries, isEmpty);
      expect(requests, isEmpty);

      final on = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        orgateClientProvider.overrideWith(client),
        featureFlagsProvider.overrideWithValue(const RasqFeatureFlags(atmos: true)),
      ]);
      addTearDown(on.dispose);
      final cat = await on.read(tagThemeCatalogProvider.future);
      expect(cat.entries.single.tag, 'rasqfes');
      expect(cat.refresh, const Duration(hours: 1));
      expect(requests.single.url.toString(), 'https://central.test/api/v1/tag-themes?via=app');
      expect(requests.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
    });
  });

  group('設定の入口 (D-583)', () {
    test('無効なら設定の行も出さない', () {
      final l = AppLocalizationsJa();
      bool has(RasqFeatureFlags f) => settingsSectionsOf(l, flags: f)['appearance']!.rows.any((r) => r.route == Routes.settingsCommunityTags);
      expect(has(const RasqFeatureFlags()), isFalse);
      expect(has(const RasqFeatureFlags(atmos: true)), isFalse);
      expect(has(const RasqFeatureFlags(communityTagThemes: true)), isTrue);
    });
  });

  // ── 画面 ──

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, visibility: 'public', author: UserSummary(id: 'u-$id', account: acc, displayName: '誰か'), createdAt: DateTime(2026, 11, 1), body: body);

  group('RASQ Atmos (D-584)', () {
    Future<void> pumpRow(WidgetTester tester, {required bool on}) async {
      final catalog = TagThemeCatalog.fromJson({'entries': [atmosJson()]});
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('a1', 'お祭り #RasqFes')]));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(registry),
          featureFlagsProvider.overrideWithValue(RasqFeatureFlags(atmos: on)),
          tagThemeCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: Consumer(builder: (context, ref, _) {
          final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
          return MaterialApp(
            locale: const Locale('ja'),
            home: Scaffold(body: ListView(children: [PostRow(post: post('a1', 'お祭り #RasqFes'), actions: actions, onAction: (_, {args = const {}}) async {})])),
          );
        }),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('タグの付いた投稿に SVG のアイコン、アクションのボタンで SVG のアニメーション(押した操作はそのまま)', (tester) async {
      await pumpRow(tester, on: true);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // 同梱の SVG を読む
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('atmos.badge.rasqfes')), findsOneWidget);
      await tester.tap(find.byTooltip('返信'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('atmos.burst.sparkle')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('atmos.burst.sparkle')), findsNothing, reason: '1 回で消える');
    });

    testWidgets('無効なら、同じ一覧があってもアイコンもアニメーションも出さない', (tester) async {
      await pumpRow(tester, on: false);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('atmos.badge.rasqfes')), findsNothing);
      await tester.tap(find.byTooltip('返信'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('atmos.burst.sparkle')), findsNothing);
    });

    testWidgets('「動きを減らす」ではアニメーションを再生しない', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpRow(tester, on: true);
      await tester.tap(find.byTooltip('返信'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('atmos.burst.sparkle')), findsNothing);
    });
  });

  group('スレッド / タグのページ (D-583 / D-584)', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester, RasqFeatureFlags flags) async {
      // テーマの背景は動き続けるので、止めた 1 枚にする(pumpAndSettle のため)。
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'お祭り #RasqFes #RasqArt'), post('p2', 'ふつうの投稿')]));
      final catalog = TagThemeCatalog.fromJson({'entries': [atmosJson(), communityJson()]});
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        featureFlagsProvider.overrideWithValue(flags),
        tagThemeCatalogProvider.overrideWith((ref) async => catalog),
      ], child: const RasqApp()));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    testWidgets('Atmos: タグの付いた投稿のスレッドだけにテーマ(広告と分かる帯つき)', (tester) async {
      final c = await pumpApp(tester, const RasqFeatureFlags(atmos: true));
      c.read(routerProvider).push('/post/p1');
      await tester.pumpAndSettle();
      expect(themedBy(RasqThemeSource.atmos), findsOneWidget);
      expect(find.byKey(const ValueKey('tagTheme.banner.atmos.rasqfes')), findsOneWidget);
      expect(find.text('プロモーション · このスレッドだけのテーマ'), findsOneWidget);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/post/p2');
      await tester.pumpAndSettle();
      expect(themedBy(RasqThemeSource.atmos), findsNothing, reason: 'ほかのスレッドには付けない');
    });

    testWidgets('コミュハッシュタグ: そのタグのページにテーマ。無効なら付けない', (tester) async {
      final c = await pumpApp(tester, const RasqFeatureFlags(communityTagThemes: true));
      c.read(routerProvider).push('/trend/RasqArt');
      await tester.pumpAndSettle();
      expect(themedBy(RasqThemeSource.communityTag), findsOneWidget);
      expect(find.byKey(const ValueKey('tagTheme.banner.community.rasqart')), findsOneWidget);
      c.read(routerProvider).push('/post/p1');
      await tester.pumpAndSettle();
      expect(themedBy(RasqThemeSource.atmos), findsNothing, reason: 'Atmos は別のフラグ');
    });

    testWidgets('どちらも無効なら、タグのページにもスレッドにも何も付けない', (tester) async {
      final c = await pumpApp(tester, const RasqFeatureFlags());
      c.read(routerProvider).push('/trend/RasqArt');
      await tester.pumpAndSettle();
      expect(themedBy(RasqThemeSource.communityTag), findsNothing);
    });
  });

  group('コミュハッシュタグの申請 (D-583)', () {
    Map<String, Object?> status({bool subscribed = true, List<Map<String, Object?>> apps = const []}) => {
          'subscription': {'active': subscribed, 'plan': 'RASQ Plus'},
          'limit': 1,
          'applications': apps,
        };

    Future<(ProviderContainer, List<http.Request>)> pumpScreen(WidgetTester tester, Map<String, Object?> Function() mine, {List<Post> promos = const []}) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final mock = MockClient((r) async {
        requests.add(r);
        final path = r.url.path;
        if (r.method == 'GET' && path == '/api/v1/me/community-tags') return http.Response(jsonEncode(mine()), 200, headers: {'content-type': 'application/json'});
        if (r.method == 'POST' && path == '/api/v1/me/community-tags') {
          return http.Response(jsonEncode({'application': {'id': 'ct_new', 'tag': 'rasqart', 'state': 'pending'}}), 201, headers: {'content-type': 'application/json'});
        }
        if (r.method == 'DELETE') return http.Response('', 204);
        if (path == '/api/v1/tag-themes') return http.Response(jsonEncode({'entries': []}), 200, headers: {'content-type': 'application/json'});
        return http.Response('{}', 404);
      });
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        featureFlagsProvider.overrideWithValue(const RasqFeatureFlags(communityTagThemes: true)),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => 'tok')),
        communityTagPromoFinderProvider.overrideWithValue((tag) async => [for (final p in promos) if (postHashtags(p).contains(tag)) p]),
      ], child: const RasqApp()));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push(Routes.settingsCommunityTags);
      await tester.pumpAndSettle();
      return (c, requests);
    }

    testWidgets('設定 → アプリの外観 に行が出る(フラグが立っているとき)', (tester) async {
      final (c, _) = await pumpScreen(tester, status);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/settings/section/appearance');
      await tester.pumpAndSettle();
      expect(find.text('コミュニティのハッシュタグ'), findsOneWidget);
    });

    testWidgets('サブスクに入っていなければ申請できない(理由を出す)', (tester) async {
      await pumpScreen(tester, () => status(subscribed: false));
      expect(find.text('加入していません'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('communityTag.apply'))).onPressed, isNull);
      expect(find.text('申請するにはサブスクへの加入が必要です'), findsOneWidget);
    });

    testWidgets('状態の表示: 配信中 / 断られた理由、取り下げは確かめてから', (tester) async {
      final (_, requests) = await pumpScreen(tester, () => status(apps: [
            {'id': 'ct_a', 'tag': 'rasqart', 'state': 'approved', 'theme': theme()},
            {'id': 'ct_b', 'tag': 'oldtag', 'state': 'rejected', 'reason': 'tag_taken'},
          ]));
      expect(find.text('#rasqart'), findsWidgets);
      expect(tester.widget<Text>(find.byKey(const ValueKey('communityTag.app.ct_a.state'))).data, '配信中');
      expect(tester.widget<Text>(find.byKey(const ValueKey('communityTag.app.ct_b.state'))).data, '承認されませんでした · このタグはほかのコミュニティが使っています');
      // 上限 1 つを使っているので、新しい申請はできない。
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('communityTag.apply'))).onPressed, isNull);
      expect(find.byKey(const ValueKey('communityTag.app.ct_b.withdraw')), findsNothing, reason: '断られたものは取り下げられない');
      await tester.tap(find.byKey(const ValueKey('communityTag.app.ct_a.withdraw')));
      await tester.pumpAndSettle();
      expect(find.text('#rasqart の申請を取り下げますか?'), findsOneWidget);
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.tap(find.byKey(const ValueKey('communityTag.app.ct_a.withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取り下げる').last);
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'DELETE').single.url.path, '/api/v1/me/community-tags/ct_a');
    });

    testWidgets('申請: タグ → テーマ → 自分の宣伝の投稿 → 送る(テーマの形・投稿の場所を送る)', (tester) async {
      final promo = post('p9', '新しいコミュニティ #RasqArt に来てね');
      final (_, requests) = await pumpScreen(tester, status, promos: [promo]);
      await tester.tap(find.byKey(const ValueKey('communityTag.apply')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('communityTag.submit'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('communityTag.tag')), 'two words');
      await tester.pump();
      expect(find.text('空白や記号を含まない 64 字までのタグにしてください'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('communityTag.tag')), '#RasqArt');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('communityTag.preset.sakura')));
      await tester.pump();
      expect(find.byKey(const ValueKey('tagTheme.banner.community.rasqart')), findsOneWidget, reason: 'プレビュー');
      await tester.ensureVisible(find.byKey(const ValueKey('communityTag.findPromo')));
      await tester.tap(find.byKey(const ValueKey('communityTag.findPromo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('communityTag.promo.p9')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('communityTag.submit')));
      await tester.pumpAndSettle();
      final sent = requests.where((r) => r.method == 'POST').single;
      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect(body['tag'], 'rasqart');
      final spec = RasqThemeSpec.fromJson(body['theme'])!;
      expect(spec.source, RasqThemeSource.communityTag);
      expect(spec.scope, const RasqThemeScope.hashtag('rasqart'));
      expect(spec.frames.single.svgId, 'sakura');
      expect(body['promo'], {'sns': 'misskey', 'instance': 'example.test', 'postId': 'p9'});
      expect(find.byKey(const ValueKey('communityTag.screen')), findsOneWidget, reason: '状態の画面へ戻る');
      expect(requests.where((r) => r.method == 'GET' && r.url.path == '/api/v1/me/community-tags').length, 2, reason: '戻ったら読み直す');
    });

    testWidgets('宣伝の投稿が無ければ、そう出して送らせない', (tester) async {
      await pumpScreen(tester, status);
      await tester.tap(find.byKey(const ValueKey('communityTag.apply')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('communityTag.tag')), 'RasqArt');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('communityTag.findPromo')));
      await tester.tap(find.byKey(const ValueKey('communityTag.findPromo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('communityTag.noPromo')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('communityTag.submit'))).onPressed, isNull);
    });
  });
}
