import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-069: リプライ元投稿の省略タイル(ワイヤーフレーム p.5「1件の添付
/// リンク」の形)+ 返信TL/引用TL への振り分け。
void main() {
  final alice = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  final bob = UserSummary(id: 'bob', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ');

  Post parent(AccountId v) => Post(
      id: 'pp',
      account: v,
      author: alice,
      createdAt: DateTime(2026, 8, 30, 10),
      body: '大気圏離脱！',
      media: [MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://example.invalid/m.png'))]);
  Post reply(AccountId v) => Post(id: 'rr', account: v, author: bob, createdAt: DateTime(2026, 8, 30, 11), body: 'よかったやん！', replyTo: parent(v), replyToId: 'pp');
  Post quote(AccountId v) => Post(id: 'qq', account: v, author: bob, createdAt: DateTime(2026, 8, 30, 12), body: 'これすごい', quote: parent(v));

  Future<void> pump(WidgetTester tester) async {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [reply(v), quote(v), parent(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('TL のリプライ: リプライ元が省略タイル(名前 + 添付サマリー + 1行抜粋)で上に付き、タップで元スレッドへ', (tester) async {
    await pump(tester);

    // TL: 返信の上にリプライ元の省略タイル。
    expect(find.byType(RasqReplyParentTile), findsOneWidget);
    expect(find.text('1件の添付ファイル'), findsOneWidget);
    expect(find.text('よかったやん！'), findsOneWidget);

    // 省略タイルのタップ → リプライ元のスレッド展開へ。
    await tester.tap(find.byType(RasqReplyParentTile));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.text('大気圏離脱！'), findsWidgets);
  });

  testWidgets('リプライ欄(スレッド展開): 開いた返信の 1 つ前の投稿も省略タイルで表示される', (tester) async {
    await pump(tester);
    await tester.tap(find.text('よかったやん！'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    // ancestors が無い文脈でも replyTo から省略タイルが出る。
    expect(find.byType(RasqReplyParentTile), findsWidgets);
    expect(find.text('1件の添付ファイル'), findsWidgets);
  });

  testWidgets('ユーザーページ: 返信TL と 引用TL に振り分け(ノートには流れない)', (tester) async {
    await pump(tester);
    // ボブのユーザーページへ(返信タイルの作者名から)。
    await tester.tap(find.text('ボブ').first);
    await tester.pumpAndSettle();
    expect(find.text('返信'), findsWidgets); // タブ
    expect(find.text('引用'), findsOneWidget);

    // ノート: 返信も引用も流れない(ボブは他に投稿なし)。
    expect(find.text('よかったやん！'), findsNothing);
    expect(find.text('これすごい'), findsNothing);

    // 返信タブ → 返信のみ(リプライ元の省略タイル付き)。
    await tester.tap(find.text('返信').last);
    await tester.pumpAndSettle();
    expect(find.text('よかったやん！'), findsOneWidget);
    expect(find.text('これすごい'), findsNothing);
    expect(find.byType(RasqReplyParentTile), findsOneWidget);

    // 引用タブ → 引用のみ。
    await tester.tap(find.text('引用'));
    await tester.pumpAndSettle();
    expect(find.text('これすごい'), findsOneWidget);
    expect(find.text('よかったやん！'), findsNothing);
  });
}
