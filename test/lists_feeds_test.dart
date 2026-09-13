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
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-195: Bluesky アカウントのリストページは「公開リスト」と「カスタムフィード」で欄を分け、
/// フィードはタップでその TL ページ(歯車で TL 設定、スコープ tl.feed:<uri>)。Misskey 側は従来どおり。
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

  testWidgets('Bluesky: 公開リスト / カスタムフィードの欄、フィード → TL ページ → 歯車で tl.feed スコープ', (tester) async {
    await pump(tester, blueskyCurrent: true);
    expect(find.byType(ListsScreen), findsOneWidget);
    expect(find.text('公開リスト'), findsOneWidget);
    expect(find.text('Fediverse Banner'), findsOneWidget); // フェイクのリスト
    expect(find.text('カスタムフィード'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('@cat.bsky.social ・ ♥ 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lists.feed.at://did:plc:x/app.bsky.feed.generator/cats')));
    await tester.pumpAndSettle();
    expect(find.byType(FeedTimelineScreen), findsOneWidget);
    expect(find.text('Cats'), findsWidgets); // ヘッダー
    await tester.tap(find.byTooltip('フィードTL設定'));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    final cfg = defaultTlConfig('tl.feed:at://did:plc:x/app.bsky.feed.generator/cats');
    expect(cfg.sources.single.isFeed, isTrue);
    expect(cfg.sources.single.feedUri, 'at://did:plc:x/app.bsky.feed.generator/cats');
    expect(defaultTlConfig('tl.featured').sources.single.tl, 'featured'); // 宣言どおりの id も通る
  });

  testWidgets('Misskey: 欄は「リスト」のまま、カスタムフィードは出ない', (tester) async {
    await pump(tester, blueskyCurrent: false);
    expect(find.text('公開リスト'), findsNothing);
    expect(find.text('カスタムフィード'), findsNothing);
    expect(find.text('Fediverse Banner'), findsOneWidget);
  });
}
