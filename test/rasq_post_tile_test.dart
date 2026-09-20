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
}
