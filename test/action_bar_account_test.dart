import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-200: アクションバーの構成はアカウントごと。別サービスから流れてきた投稿は、そのアカウントの
/// ボタン群(SNS の宣言)と構成で出す。旧来の共通キーは初回に引き継ぐ。
void main() {
  const misskeyAcc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const bskyAcc = AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.bsky.social');
  Post post(String id, AccountId acc, String body) => Post(id: id, account: acc, author: UserSummary(id: 'u-$id', account: acc, displayName: '誰か'), createdAt: DateTime(2026, 9, 1), body: body);

  testWidgets('別アカウントの投稿のバーは、そのアカウントの構成(並び順)とアクションで出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bsky = AccountSession(account: bskyAcc, pluginId: 'test.bsky', token: 't', createdAt: DateTime(2026, 9, 1), displayName: 'アリス');
    // Bluesky アカウントの構成: リノートを先頭に(非表示は廃止 D-208)。共通キーには何も無い。
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': fakeSession().account.key}),
      '${ActionBarConfigStore.storageKey}.${bskyAcc.key}': jsonEncode(const ActionBarConfig(order: ['renote', 'reply']).toJson()),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: (_) => [post('m1', misskeyAcc, 'みすきー')]))
      ..register(FakeSnsPlugin(posts: (_) => [post('b1', bskyAcc, 'ぶるすか')], kind: SnsKind.bluesky, id: 'test.bsky'));
    late ProviderContainer c;
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: Consumer(builder: (context, ref, _) {
        c = ProviderScope.containerOf(context);
        final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
        return MaterialApp(
          home: Scaffold(
            body: ListView(children: [
              PostRow(post: post('m1', misskeyAcc, 'みすきー'), actions: actions, onAction: (_, {args = const {}}) async {}),
              PostRow(post: post('b1', bskyAcc, 'ぶるすか'), actions: actions, onAction: (_, {args = const {}}) async {}),
            ]),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // 構成の復元(実 I/O 無し)
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(bskyAcc.key)).order, ['renote', 'reply']);
    expect(c.read(actionBarConfigProvider(misskeyAcc.key)).order, isEmpty);
    // Misskey の投稿は返信が先、Bluesky の投稿はリノートが先(そのアカウントの構成)。
    final rows = find.byType(PostRow);
    double x(Finder row, String tip) => tester.getCenter(find.descendant(of: row, matching: find.byTooltip(tip))).dx;
    expect(x(rows.first, '返信'), lessThan(x(rows.first, 'リノート')));
    expect(x(rows.last, 'リノート'), lessThan(x(rows.last, '返信')));
  });

  test('旧来の共通キーは初回の復元で引き継ぐ', () async {
    final storage = MemorySessionStorage({ActionBarConfigStore.storageKey: jsonEncode(const ActionBarConfig(hidden: {'renote'}).toJson())});
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    c.read(actionBarConfigProvider(misskeyAcc.key));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(actionBarConfigProvider(misskeyAcc.key)).hidden, contains('renote'));
    // 保存は自分のキーへ。
    c.read(actionBarConfigProvider(misskeyAcc.key).notifier).set(const ActionBarConfig(hidden: {'reply'}));
    expect(await storage.read('${ActionBarConfigStore.storageKey}.${misskeyAcc.key}'), isNotNull);
    expect((jsonDecode((await storage.read(ActionBarConfigStore.storageKey))!) as Map)['hidden'], ['renote']); // 共通キーはそのまま
  });
}
