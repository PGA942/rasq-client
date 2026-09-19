import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/post_image_fow.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/search/search_history.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 「ノート画像の追加」FOW (D-259): 投稿タイルそのものを画像にして添付にする。タブ + 絞り込み + 最近の検索。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const author = UserSummary(id: 'u1', account: acc, displayName: 'タロ・ヤマダ');
  Post post(String id, String body, {String? visibility, String? cw}) => Post(id: id, account: acc, author: author, createdAt: DateTime(2026, 9, 19), body: body, visibility: visibility, contentWarning: cw);

  test('公開範囲と絞り込み', () {
    for (final v in ['followers', 'specified', 'direct', 'private', 'limited']) {
      expect(isPickablePost(post('x', 'b', visibility: v)), isFalse, reason: v);
    }
    for (final v in <String?>['public', 'home', 'unlisted', null]) {
      expect(isPickablePost(post('x', 'b', visibility: v)), isTrue, reason: '$v');
    }
    final p = post('p', 'Happy birthday to me');
    expect(postMatchesFilter(p, ''), isTrue);
    expect(postMatchesFilter(p, 'BIRTHDAY happy'), isTrue); // 全部の言葉を含む、大文字小文字は見ない
    expect(postMatchesFilter(p, 'birthday cake'), isFalse);
    expect(postMatchesFilter(p, 'ヤマダ'), isTrue); // 作者の名前でも
  });

  test('最近の検索: 新しい順、同じ言葉は 1 つ、掛けていた絞り込みも残る、再起動後も読める', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({});
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    final h = c.read(searchHistoryProvider.notifier);
    await h.record('ロケットハンター同好会', chips: ['発射', '周回軌道']);
    await h.record('ペペロンチーズ');
    await h.record('ロケットハンター同好会', chips: ['発射']);
    await h.record('   ');
    expect(c.read(searchHistoryProvider).map((e) => '${e.query}:${e.chips.join(',')}'), ['ロケットハンター同好会:発射', 'ペペロンチーズ:']);
    final c2 = make();
    c2.read(searchHistoryProvider);
    await c2.read(searchHistoryProvider.notifier).ready;
    expect(c2.read(searchHistoryProvider).map((e) => e.query), ['ロケットハンター同好会', 'ペペロンチーズ']);
    final now = DateTime(2026, 9, 19, 18);
    expect(searchHistoryAgo(now.subtract(const Duration(hours: 1)), now: now), '1 時間前');
    expect(searchHistoryAgo(now.subtract(const Duration(days: 1)), now: now), '1 日前');
  });

  testWidgets('コンポーザー → FOW: タブ、限定公開は出ない、絞り込み、最近の検索 → 検索結果 → 絞り込み、決定で投稿タイルが PNG の添付になる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final posts = [
      post('p1', 'Happy birthday to me', visibility: 'public'),
      post('p2', 'フォロワー限定のひみつ', visibility: 'followers'),
      post('p3', '今日の天気 晴れ', visibility: 'home'),
      post('p4', 'ロケットの発射を見てきた', visibility: 'public', cw: 'ネタバレ'),
    ];
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      SearchHistory.storageKey: jsonEncode([SearchHistoryEntry(query: 'ロケット', at: DateTime.now().subtract(const Duration(hours: 1)), chips: const ['発射']).toJson()]),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts)))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('画像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿を画像にする'));
    await tester.pumpAndSettle();

    // ヘッダーとタブ。決定は選ぶまで押せない。
    expect(find.text('ノート画像の追加'), findsOneWidget);
    for (final id in ['tl:home', 'tl:social', 'mine', 'reacted', 'favorites', 'astell', 'searches']) {
      expect(find.byKey(ValueKey('postImage.tab.$id'), skipOffstage: false), findsOneWidget, reason: id);
    }
    expect(tester.widget<TextButton>(find.byKey(postImageConfirmKey)).onPressed, isNull);
    // 一覧 = タイムラインと同じ投稿タイル。限定公開は出ない(件数を出す)。
    expect(find.descendant(of: find.byKey(const ValueKey('postImage.post.p1')), matching: find.byType(PostRow)), findsOneWidget);
    expect(find.byKey(const ValueKey('postImage.post.p2')), findsNothing);
    expect(find.byKey(const ValueKey('postImage.excluded')), findsOneWidget);
    // 絞り込み(いま出ている一覧を言葉で絞る)。
    await tester.enterText(find.byKey(postImageFilterKey), '天気');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postImage.post.p3')), findsOneWidget);
    expect(find.byKey(const ValueKey('postImage.post.p1')), findsNothing);
    await tester.enterText(find.byKey(postImageFilterKey), '');
    await tester.pumpAndSettle();

    // 最近の検索 → 履歴のタイル → 押すと検索結果、ほかのタブと同じく上の欄で絞り込める。
    await tester.ensureVisible(find.byKey(const ValueKey('postImage.tab.searches'), skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('postImage.tab.searches')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postImage.history.ロケット')), findsOneWidget);
    expect(find.text('発射'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('postImage.history.ロケット')));
    await tester.pumpAndSettle();
    expect(find.text('「ロケット」の検索結果'), findsOneWidget);
    expect(find.byKey(const ValueKey('postImage.post.p4')), findsOneWidget);
    expect(find.byKey(const ValueKey('postImage.post.p1')), findsNothing);
    await tester.enterText(find.byKey(postImageFilterKey), 'みつからない言葉');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postImage.post.p4')), findsNothing);
    await tester.enterText(find.byKey(postImageFilterKey), '');
    await tester.pumpAndSettle();

    // 選ぶ → 決定 → 投稿タイルの PNG が添付に(注釈つきの投稿なのでセンシティブ)。
    await tester.tap(find.byKey(const ValueKey('postImage.post.p4')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.byKey(postImageConfirmKey)).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(postImageConfirmKey));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('ノート画像の追加'), findsNothing);
    expect(find.byTooltip('センシティブ解除'), findsOneWidget);
    expect(find.byKey(const ValueKey('postImage.asVideo')), findsNothing);
  });

  testWidgets('投稿タイルの画像化: 不透明な PNG、タイルの大きさ × 倍率', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: key, child: const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox(width: 120, height: 40, child: Text('投稿')))))));
    final bytes = (await tester.runAsync(() => capturePostTile(key, pixelRatio: 2)))!;
    final image = (await tester.runAsync(() async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image))!;
    expect((image.width, image.height), (240, 80));
    final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    expect(data.getUint8(3), 255); // 左上の画素は不透明
  });
}
