import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/media/viewer_sequence.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 第1回 全画面表示: 投稿をまたいでスワイプ (D-549) / 上下に引っ張って閉じる (D-550) / 投稿アクションバー付き FOW (D-553)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  MediaItem image(String id) => MediaItem(id: id, type: MediaType.image, url: Uri.parse('https://example.test/$id.jpg'));
  Post post(String id, String body, List<MediaItem> media) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 11, 16), body: body, media: media);

  final p1 = post('p1', '一つ目', [image('a'), image('b')]);
  final p2 = post('p2', 'メディア無し', const []);
  final p3 = post('p3', '三つ目', [image('c')]);
  final p4 = post('p4', '四つ目', [image('d')]);

  Future<ProviderContainer> pump(WidgetTester tester, {List<Post>? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts ?? [p1, p2, p3]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  String? countText(WidgetTester tester) {
    final f = find.byKey(const ValueKey('viewer.count'));
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  /// 1 ページぶん(画面の幅 360 の半分より長く、幅より短く引く: 長すぎると 2 ページ進む)。
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.drag(find.byType(PageView), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  group('並び (D-549)', () {
    List<int> all(Post p) => [for (var i = 0; i < p.media.length; i++) i];

    test('開いた投稿の位置から、メディア付き投稿の添付を TL の順に並べる。メディアの無い投稿 / 重複は飛ばす', () {
      final slides = buildViewerSlides([p1, p2, p3, p1], p3, visibleMedia: all);
      expect([for (final s in slides) '${s.post.id}:${s.media}'], ['p1:0', 'p1:1', 'p3:0']);
    });

    test('開いた投稿が並びに無ければ、その投稿だけ', () {
      expect([for (final s in buildViewerSlides([p1], p3, visibleMedia: all)) '${s.post.id}:${s.media}'], ['p3:0']);
    });

    test('ほかの投稿はタイルに出ている添付だけ(取り除いたものは飛ばす)。開いた投稿はぜんぶ', () {
      final slides = buildViewerSlides([p1, p3], p3, visibleMedia: (p) => p.id == 'p1' ? [1] : const []);
      expect([for (final s in slides) '${s.post.id}:${s.media}'], ['p1:1', 'p3:0']);
    });

    test('続きは末尾にだけ足す(最後の投稿より後ろ、重複なし)', () {
      final slides = buildViewerSlides([p1, p3], p1, visibleMedia: all);
      expect([for (final s in appendViewerSlides(slides, [p1, p3, p4], visibleMedia: all)) s.post.id], ['p4']);
      expect(appendViewerSlides(slides, [p4, p1, p3], visibleMedia: all), isEmpty, reason: '上に積まれた新着は取り込まない');
    });
  });

  testWidgets('ホームの TL から開くと、添付の最後から次のメディア付き投稿へスワイプが続き、戻れる。FOW の投稿も替わる', (tester) async {
    await pump(tester);
    // TL の 1 つ目の投稿の 1 枚目のタイルから開く。
    final tiles = find.descendant(of: find.byType(RasqMediaGrid).first, matching: find.byType(GestureDetector));
    expect(tiles, findsWidgets);
    await tester.tap(tiles.first);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    // 1 枚目(または押した 1 枚)から、p1 の最後まで送る。
    while (countText(tester) == '1 / 2') {
      await swipe(tester, -300);
    }
    expect(countText(tester), '2 / 2');
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('一つ目')), findsOneWidget);
    // 最後の添付から、さらに左へ → メディアの無い p2 を飛ばして p3。
    await swipe(tester, -300);
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(countText(tester), isNull, reason: 'p3 は 1 枚だけ');
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('三つ目')), findsOneWidget);
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('一つ目')), findsNothing);
    // 読み込み済みの最後: それ以上は進まない(止まる)。
    await swipe(tester, -300);
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('三つ目')), findsOneWidget);
    // 逆方向: p1 の最後の添付へ戻る。
    await swipe(tester, 300);
    expect(countText(tester), '2 / 2');
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('一つ目')), findsOneWidget);
  });

  testWidgets('読み込み済みの端に近づいたら続きを読み込み、末尾に足す。上の端は止まる', (tester) async {
    final c = await pump(tester);
    final loaded = [p1, p3];
    var loads = 0;
    final sequence = ViewerSequence(
      posts: () => loaded,
      loadMore: () async {
        loads++;
        loaded.add(p4);
      },
      canLoadMore: () => loads == 0,
    );
    c.read(routerProvider).push(Routes.viewer, extra: MediaViewerArgs(post: p1, index: 0, sequence: sequence));
    await tester.pumpAndSettle();
    // 開いた時点で最後から 2 枚以内(3 枚の 1 枚目) → 読み込む。
    expect(loads, 1);
    await swipe(tester, 300); // 上の端(新しい側)は止まる
    expect(countText(tester), '1 / 2');
    for (var i = 0; i < 3; i++) {
      await swipe(tester, -300);
    }
    expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('四つ目')), findsOneWidget);
    expect(loads, 1, reason: 'もう続きは無い');
  });

  testWidgets('並びを渡さずに開くと、これまでどおりその投稿の添付だけ', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).push(Routes.viewer, extra: (post: p1, index: 1));
    await tester.pumpAndSettle();
    expect(countText(tester), '2 / 2');
    await swipe(tester, -300);
    expect(countText(tester), '2 / 2');
    expect(find.byType(MediaViewerScreen), findsOneWidget);
  });

  group('上下に引っ張って閉じる (D-550)', () {
    testWidgets('拡大していなければ、上へ引いても閉じる(短ければ戻る)', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).push(Routes.viewer, extra: (post: p3, index: 0));
      await tester.pumpAndSettle();
      final face = find.byKey(viewerMediaInsetKey);
      await tester.drag(face, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerScreen), findsOneWidget, reason: '短い = 戻る');
      await tester.drag(face, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerScreen), findsNothing);
    });

    testWidgets('拡大中はパンが先: 限界(上端)に達してから、さらに引いたぶんだけで閉じる', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).push(Routes.viewer, extra: (post: p3, index: 0));
      await tester.pumpAndSettle();
      final viewer = find.byType(InteractiveViewer);
      final ctrl = tester.widget<InteractiveViewer>(viewer).transformationController!;
      final h = tester.getSize(viewer).height;
      // 2 倍に拡大して、縦の真ん中を見ている。
      ctrl.value = Matrix4.identity()
        ..translateByDouble(0, -h / 2, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      await tester.pumpAndSettle();
      Future<void> pull(double total) async {
        final g = await tester.startGesture(tester.getCenter(viewer));
        const step = 20.0;
        for (var moved = 0.0; moved < total; moved += step) {
          await g.moveBy(const Offset(0, step));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
      }

      // 限界より手前の引っ張り = パンだけ(閉じない、拡大はそのまま)。
      await pull(h / 4);
      expect(find.byType(MediaViewerScreen), findsOneWidget);
      expect(ctrl.value.getMaxScaleOnAxis(), closeTo(2, 0.01));
      expect(ctrl.value.getTranslation().y, greaterThan(-h / 2));
      // 上端まで行ってから、さらに閉じる距離を超えて引く → 閉じる。
      await pull(h / 2 + viewerSwipeCloseDistance + 120);
      expect(find.byType(MediaViewerScreen), findsNothing);
    });

    testWidgets('拡大中、上端でも閉じる距離に足りなければ戻る(拡大はそのまま)', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).push(Routes.viewer, extra: (post: p3, index: 0));
      await tester.pumpAndSettle();
      final viewer = find.byType(InteractiveViewer);
      final ctrl = tester.widget<InteractiveViewer>(viewer).transformationController!;
      ctrl.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1); // 上端に付いている
      await tester.pumpAndSettle();
      final g = await tester.startGesture(tester.getCenter(viewer));
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerScreen), findsOneWidget);
      expect(ctrl.value.getMaxScaleOnAxis(), closeTo(2, 0.01));
    });
  });

  group('投稿アクションバー付き FOW (D-553)', () {
    test('全画面アクションバーの既定は、SNS の投稿まわりのアクションを外す(投稿のバーはそのまま)', () {
      final viewer = ActionBarConfigStore.defaultFor(ActionBarConfigStore.viewerKey(acc.key));
      for (final id in ['reply', 'renote', 'reaction', 'favorite', 'reblog', 'repost', 'quote', 'favourite', 'bookmark']) {
        expect(viewer.hidden, contains(id));
      }
      final actions = [for (final id in ['reply', 'renote', 'reaction']) ActionDescriptor(id: id, genreTag: 'X', label: id)];
      expect(viewer.apply(actions), isEmpty);
      expect(ActionBarConfigStore.defaultFor(acc.key).apply(actions).length, 3, reason: '投稿のバーは変わらない');
    });

    testWidgets('下側の FOW の上辺は投稿の実物のアクションバー(ヘッダーには投稿のボタンが無い)', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).push(Routes.viewer, extra: (post: p3, index: 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viewer.action.reply')), findsNothing);
      final bar = find.byKey(viewerPanelBarKey);
      expect(bar, findsOneWidget);
      // 実物のバー = タイムラインの投稿と同じ PostRow のバー(複製の行ではない)。
      expect(find.ancestor(of: bar, matching: find.byType(PostRow)), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.byType(RasqActionBar)), findsOneWidget);
      // FOW の中で一番上(投稿の本文より上)。
      expect(tester.getRect(bar).bottom, lessThanOrEqualTo(tester.getRect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.text('三つ目'))).top + 1));
      expect(find.descendant(of: find.byKey(viewerPanelKey), matching: find.byType(RasqActionBar)), findsOneWidget, reason: 'バーは 1 本だけ');
    });
  });
}
