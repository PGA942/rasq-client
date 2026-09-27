import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/lists/lists_screens.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-195: Bluesky アカウントのリストページは「公開リスト」と「カスタムフィード」で欄を分け、
/// フィードはタップでその TL ページ(歯車で TL 設定、スコープ `tl.feed:<uri>`)。Misskey 側は従来どおり。
void main() {
  const feeds = [FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/cats', name: 'Cats', description: 'ねこのフィード', likeCount: 3, creator: 'cat.bsky.social')];
  final bsky = AccountSession(account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.bsky.social'), pluginId: 'test.bsky', token: 't', createdAt: DateTime(2026, 9, 1), displayName: 'アリス');

  Future<ProviderContainer> pump(WidgetTester tester, {required bool blueskyCurrent}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': blueskyCurrent ? bsky.account.key : fakeSession().account.key}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: MockData.timeline))
      ..register(FakeSnsPlugin(posts: MockData.timeline, kind: SnsKind.bluesky, id: 'test.bsky', feeds: feeds));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.lists);
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('Bluesky: 上部メニュー「リスト / カスタムフィード」、フィード → TL ページ → 歯車で tl.feed スコープ、インポートは検索 / URL', (tester) async {
    final c = await pump(tester, blueskyCurrent: true);
    expect(find.byType(ListsScreen), findsOneWidget);
    expect(find.text('Fediverse Banner'), findsOneWidget); // 「リスト」タブ(フェイクのリスト)
    expect(find.text('カスタムフィード'), findsOneWidget); // タブ
    await tester.tap(find.text('カスタムフィード'));
    await tester.pumpAndSettle();
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('@cat.bsky.social ・ ♥ 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lists.feed.at://did:plc:x/app.bsky.feed.generator/cats')));
    await tester.pumpAndSettle();
    expect(find.byType(FeedTimelineScreen), findsOneWidget);
    await tester.tap(find.byTooltip('フィードTL設定'));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    final cfg = defaultTlConfig('tl.feed:at://did:plc:x/app.bsky.feed.generator/cats');
    expect(cfg.sources.single.isFeed, isTrue);
    expect(cfg.sources.single.feedUri, 'at://did:plc:x/app.bsky.feed.generator/cats');
    expect(defaultTlConfig('tl.featured').sources.single.tl, 'featured'); // 宣言どおりの id も通る
    // インポート: 検索 / URL → リストタイル → タップでフィード TL。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ListsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('リストのインポート'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lists.import.search')), findsOneWidget);
    expect(find.text('検索語か URL を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('lists.import.search')), 'cat');
    await tester.pumpAndSettle();
    expect(find.text('フィードの検索結果'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lists.feed.at://did:plc:x/app.bsky.feed.generator/cats')));
    await tester.pumpAndSettle();
    expect(find.byType(FeedTimelineScreen), findsOneWidget);
    // フィードの保存 (D-227): 保存済みなら「保存を外す」、外すと「フィードを保存」。ヘッダーと行の両方に同じボタン。
    expect(find.byTooltip('保存を外す'), findsOneWidget);
    await tester.tap(find.byTooltip('保存を外す'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('フィードを保存'), findsOneWidget);
    expect(await (c.read(currentSnsSessionProvider) as FakeSnsSession).savedFeeds(), isEmpty);
    await tester.tap(find.byTooltip('フィードを保存'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('保存を外す'), findsOneWidget);
    // タイムラインに取り込む (D-227): ホームの TL カスタマイズの取り込み元に feed:<uri> が足される(画面を通らずに同じ保存先へ)。
    await tester.tap(find.byKey(const ValueKey('feed.import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('「Cats」をホームのタイムラインに取り込みました'), findsOneWidget);
    final area = await c.read(settingsAreaProvider('nodeprog.${bsky.account.key}.tl.home').future);
    final home = TlConfig.fromJson((jsonDecode(area['tlcfg'] as String) as Map).cast<String, Object?>());
    expect(home.sources.map((s) => s.tl), contains('feed:at://did:plc:x/app.bsky.feed.generator/cats'));
    expect(home.sources.last.account, '${bsky.account}');
    expect(area['graph'], contains('tl.feed'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 2 回目は足さない。
    await tester.tap(find.byKey(const ValueKey('feed.import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('もうホームのタイムラインに入っています'), findsOneWidget);
  });

  testWidgets('Misskey: タブ無し、カスタムフィードは出ない、インポートは従来', (tester) async {
    await pump(tester, blueskyCurrent: false);
    expect(find.text('カスタムフィード'), findsNothing);
    expect(find.text('Fediverse Banner'), findsOneWidget);
    expect(find.byTooltip('リストを作成'), findsOneWidget);
    await tester.tap(find.byTooltip('リストのインポート'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lists.import.search')), findsNothing);
    expect(find.text('ローカルからインポート'), findsOneWidget);
  });
}
