import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/profile/rasq_post_tile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// RASQ の投稿のタイル (D-274 → D-276): リブロード済みでも、ボタンは「リブロード」のまま(押してもタイルは開かない)。
void main() {
  testWidgets('リブロード済みのボタンを押しても、取り消しにもタイルのタップにもならない', (tester) async {
    var opened = 0;
    const post = RasqAccountPost(id: 'p1', body: '本文', author: RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'), rebroaded: true, rebroadCount: 1);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry())],
      child: MaterialApp(home: Scaffold(body: RasqPostTileView(post: post, onChanged: () {}, onOpen: () => opened++))),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('リブロード'));
    await tester.pump();
    expect(opened, 0);
    expect(find.textContaining('ログインするとリブロードできます'), findsOneWidget);
    expect(find.byTooltip('リブロードを取り消す'), findsNothing);
    await tester.tap(find.text('本文'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('注釈つきは畳む / 投票 / いいねのみ (D-275)', (tester) async {
    const post = RasqAccountPost(
      id: 'p2',
      body: '中身の本文',
      cw: 'ネタバレ注意',
      reactionAcceptance: 'likeOnly',
      author: RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'),
      poll: RasqPoll(choices: [(text: 'はい', votes: 2, voted: false), (text: 'いいえ', votes: 1, voted: false)]),
      queues: [RasqQueueCount(packId: null, stickerId: 'like', url: null, like: true, count: 3)],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry())],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RasqPostTileView(post: post, onChanged: () {})))),
    ));
    await tester.pump();
    // 注釈だけ見えて、中身は「もっと見る」まで出ない。
    expect(find.text('ネタバレ注意'), findsOneWidget);
    expect(find.text('中身の本文'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rasqPost.cw.toggle')));
    await tester.pump();
    expect(find.text('中身の本文'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPost.p2.poll')), findsOneWidget);
    expect(find.text('はい'), findsOneWidget);
    // いいねのみ: ボタンは ❤(いいね)、付いているいいねは ❤ のチップ。
    expect(find.byTooltip('いいね'), findsOneWidget);
    expect(find.byTooltip('キュー'), findsNothing);
    expect(find.text('❤'), findsWidgets);
  });

  testWidgets('引用 / 動画・音声 (D-276)', (tester) async {
    final post = RasqAccountPost(
      id: 'p3',
      body: '引用します',
      isQuote: true,
      author: const RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'),
      quote: RasqAccountPost(id: 'p0', body: '元の投稿です', author: const RasqPostAuthor(id: 'b', handle: 'hanako', displayName: 'ハナコ'), images: [RasqPostImage(id: 'v0', url: Uri.parse('https://central.test/v0'), type: 'video')]),
      images: [
        RasqPostImage(id: 'v1', url: Uri.parse('https://central.test/v1'), type: 'video'),
        RasqPostImage(id: 'a1', url: Uri.parse('https://central.test/a1'), type: 'audio', sensitive: true),
      ],
    );
    // SNS の投稿と同じ部品に渡す形: 動画は動画、音声はファイル。RASQ の投稿だと見分けられる。
    final asPost = post.toPost(central: Uri.parse('https://central.test'));
    expect([for (final m in asPost.media) m.type], [MediaType.video, MediaType.file]);
    expect(asPost.media[1].sensitive, isTrue);
    expect(isRasqPost(asPost), isTrue);
    expect('${asPost.url}', 'https://central.test/p/p3');
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry())],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Column(children: [
        RasqPostTileView(post: post, onChanged: () {}),
        // 元が消えた / 見られない引用。
        RasqPostTileView(post: const RasqAccountPost(id: 'p4', body: '消えた引用', isQuote: true, author: RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ')), onChanged: () {}),
      ])))),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('rasqPost.p3.quote')), findsOneWidget);
    expect(find.text('元の投稿です'), findsOneWidget);
    expect(find.text('ハナコ'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPost.p4.quoteGone')), findsOneWidget);
  });

  testWidgets('アクションバーは編集できる構成から組む (D-279)。既定の並びは 返信 / リブロード / キュー', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const post = RasqAccountPost(id: 'p5', body: '本文', author: RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry()), centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test'))],
      child: MaterialApp(home: Scaffold(body: RasqPostTileView(post: post, onChanged: () {}))),
    ));
    await tester.pump();
    // 既定の並び: 返信 / リブロード / キュー。
    final bar = tester.widget<RasqActionBar>(find.byType(RasqActionBar));
    expect([for (final i in bar.items) i.id], ['reply', 'rebroad', 'queue']);
  });
}
