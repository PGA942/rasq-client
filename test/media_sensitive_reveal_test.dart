import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/media/media_reveal.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/settings/safety.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-510: センシティブ / 注釈(CW)のメディアは 1 枚ずつ。タイルで 1 枚開いて全画面へ行き、スワイプした先の
/// ほかのセンシティブな 1 枚は押すまでクッション。1 枚を開いてもほかは開かない。
void main() {
  final acc = fakeSession().account;
  MediaItem img(String id, {bool sensitive = false}) => MediaItem(id: id, type: MediaType.image, url: Uri.parse('https://example.test/$id.jpg'), sensitive: sensitive);
  Post postOf(List<MediaItem> media, {String? cw, String id = 's1'}) =>
      Post(id: id, account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 10, 20), body: '画像つき', contentWarning: cw, media: media);

  Finder cushion(String id) => find.byKey(ValueKey('viewer.cushion.$id'));
  Finder tileCushion(String id) => find.byKey(ValueKey('media.cushion.$id'));

  Future<ProviderContainer> pumpApp(WidgetTester tester, List<Post> posts, {SafetySettings? safety}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': acc.key})});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
        if (safety != null) safetySettingsProvider.overrideWithValue(safety),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openViewer(WidgetTester tester, ProviderContainer c, Post post, int index) async {
    c.read(routerProvider).push(Routes.viewer, extra: (post: post, index: index));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
  }

  Future<void> swipe(WidgetTester tester, {bool next = true}) async {
    final pages = find.descendant(of: find.byType(MediaViewerScreen), matching: find.byType(PageView));
    expect(pages, findsOneWidget);
    // 1 ページぶん(画面の幅 360 の半分超)だけ引く。強く払うと 2 枚ぶん進む。
    await tester.drag(pages, Offset(next ? -250 : 250, 0));
    await tester.pumpAndSettle();
  }

  group('SafetySettings.applyTo (D-510)', () {
    final items = [img('a', sensitive: true), img('b'), img('c', sensitive: true)];

    test('ぼかし(既定): 印のあるものだけ。CW 付きなら全部を 1 枚ずつ', () {
      const s = SafetySettings();
      expect([for (final m in s.applyTo(items).$1) m.sensitive], [true, false, true]);
      expect([for (final m in s.applyTo(items, cw: true).$1) m.sensitive], [true, true, true]);
    });

    test('「注釈を自動で開く」なら CW ではクッションを足さない / 表示するなら全部外す', () {
      expect([for (final m in const SafetySettings(openCw: true).applyTo(items, cw: true).$1) m.sensitive], [true, false, true]);
      expect([for (final m in const SafetySettings(sensitiveMedia: 'show').applyTo(items, cw: true).$1) m.sensitive], [false, false, false]);
    });

    test('セーフモード: 印のあるものは取り除き、CW の残りはクッション。index は元の位置', () {
      final (kept, map) = const SafetySettings(sensitiveMedia: 'hide').applyTo(items, cw: true);
      expect([for (final m in kept) m.id], ['b']);
      expect(kept.single.sensitive, isTrue);
      expect(map, [1]);
    });

    test('applyToPost は投稿の CW を見る', () {
      expect([for (final m in const SafetySettings().applyToPost(postOf(items, cw: '注意')).$1) m.sensitive], [true, true, true]);
      expect([for (final m in const SafetySettings().applyToPost(postOf(items)).$1) m.sensitive], [true, false, true]);
    });
  });

  testWidgets('RasqMediaGrid: 1 枚を開いてもほかのクッションは残る(ホストが持つ形でも)', (tester) async {
    final revealed = <String>{};
    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 400,
            child: RasqMediaGrid(items: [img('a', sensitive: true), img('b', sensitive: true), img('c')], revealed: revealed, onReveal: (id) => setState(() => revealed.add(id))),
          ),
        ),
      ),
    ));
    expect(tileCushion('a'), findsOneWidget);
    expect(tileCushion('b'), findsOneWidget);
    expect(tileCushion('c'), findsNothing);
    await tester.tap(tileCushion('a'));
    await tester.pump();
    expect(revealed, {'a'});
    expect(tileCushion('a'), findsNothing);
    expect(tileCushion('b'), findsOneWidget, reason: '開いたのは a だけ');
  });

  testWidgets('タイルで 1 枚開いて全画面へ → 開いた 1 枚はそのまま、スワイプした先のセンシティブは押すまでクッション', (tester) async {
    final post = postOf([img('a', sensitive: true), img('b', sensitive: true), img('c'), img('d', sensitive: true)]);
    final c = await pumpApp(tester, [post]);
    expect(find.byType(PostRow), findsWidgets);
    expect(tileCushion('a'), findsOneWidget);
    expect(tileCushion('b'), findsOneWidget);

    // タイルで a だけ開く → a を押して全画面へ。
    await tester.tap(tileCushion('a'));
    await tester.pumpAndSettle();
    expect(tileCushion('a'), findsNothing);
    expect(tileCushion('b'), findsOneWidget);
    expect(c.read(mediaRevealProvider)[post.key], {'a'});
    await tester.tap(find.descendant(of: find.byType(RasqMediaGrid), matching: find.byType(Image)).first);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(cushion('a'), findsNothing, reason: 'タイルで開いた 1 枚は開いたまま');

    // b へスワイプ → クッション(以前はそのまま見えていた)。
    await swipe(tester);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(cushion('b'), findsOneWidget);
    expect(find.text('センシティブな可能性のあるメディアです'), findsOneWidget);
    // 押すと b だけ開く。
    await tester.tap(cushion('b'));
    await tester.pumpAndSettle();
    expect(cushion('b'), findsNothing);
    expect(c.read(mediaRevealProvider)[post.key], {'a', 'b'});

    // c はもともと見える。d はまだクッション(b を開いても開かない)。
    await swipe(tester);
    expect(cushion('c'), findsNothing);
    await swipe(tester);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(cushion('d'), findsOneWidget);

    // 戻ってもタイルの b は開いたまま(全画面と共有)、d はクッションのまま。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsNothing);
    expect(tileCushion('b'), findsNothing);
  });

  testWidgets('Mastodon の投稿単位の sensitive(各メディアに配られる)も 1 枚ずつ。全画面で開いた 1 枚以外はクッション', (tester) async {
    // mastodon-wasm は status.sensitive を各タイルへ配る(全部 sensitive)。
    final post = postOf([img('m1', sensitive: true), img('m2', sensitive: true), img('m3', sensitive: true)], id: 'mast');
    final c = await pumpApp(tester, const []);
    await openViewer(tester, c, post, 1);
    expect(cushion('m2'), findsOneWidget, reason: 'タイルで開いていなければ全画面でもクッション');
    await tester.tap(find.text('表示する'));
    await tester.pumpAndSettle();
    expect(cushion('m2'), findsNothing);
    await swipe(tester, next: false);
    expect(cushion('m1'), findsOneWidget);
    await swipe(tester);
    await swipe(tester);
    expect(cushion('m3'), findsOneWidget);
  });

  testWidgets('注釈(CW)付きの投稿: 印の無いメディアも全画面で 1 枚ずつクッション', (tester) async {
    final post = postOf([img('x'), img('y')], cw: 'ネタバレ', id: 'cw1');
    final c = await pumpApp(tester, const []);
    c.read(mediaRevealProvider.notifier).reveal(post, 'x'); // タイルで x を開いた
    await openViewer(tester, c, post, 0);
    expect(cushion('x'), findsNothing);
    await swipe(tester);
    expect(cushion('y'), findsOneWidget);
  });

  testWidgets('セーフモード / 見守り中: タイルから取り除いたメディアは、全画面でも外せないクッション', (tester) async {
    final post = postOf([img('ok'), img('ng', sensitive: true)], id: 'safe');
    final c = await pumpApp(tester, const [], safety: const SafetySettings(sensitiveMedia: 'hide'));
    await openViewer(tester, c, post, 0);
    expect(cushion('ok'), findsNothing);
    await swipe(tester);
    expect(cushion('ng'), findsOneWidget);
    expect(find.text('表示しない設定のメディアです'), findsOneWidget);
    expect(find.text('表示する'), findsNothing);
    await tester.tap(cushion('ng'));
    await tester.pumpAndSettle();
    expect(cushion('ng'), findsOneWidget, reason: '押しても開かない');
  });

  testWidgets('「表示する」設定なら全画面でもクッションは出ない', (tester) async {
    final post = postOf([img('p', sensitive: true), img('q', sensitive: true)], cw: '注意', id: 'show');
    final c = await pumpApp(tester, const [], safety: const SafetySettings(sensitiveMedia: 'show'));
    await openViewer(tester, c, post, 0);
    expect(cushion('p'), findsNothing);
    await swipe(tester);
    expect(cushion('q'), findsNothing);
  });
}
