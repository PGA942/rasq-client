import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/profile/rasq_post_tile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// RASQ の投稿のタイル (D-274): リブロー済みでも、ボタンは「リブロー」のまま(押してもタイルは開かない)。
void main() {
  testWidgets('リブロー済みのボタンを押しても、取り消しにもタイルのタップにもならない', (tester) async {
    var opened = 0;
    const post = RasqAccountPost(id: 'p1', body: '本文', author: RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'), rebroaded: true, rebroadCount: 1);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry())],
      child: MaterialApp(home: Scaffold(body: RasqPostTileView(post: post, onChanged: () {}, onOpen: () => opened++))),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('リブロー'));
    await tester.pump();
    expect(opened, 0);
    expect(find.textContaining('リブロー済みです'), findsOneWidget);
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
}
