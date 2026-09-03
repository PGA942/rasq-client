import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/relational/relational_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// M5f / D-086: アカウントバンドル供給 — 関連TL の入力に、現在アカウントの
/// HTL だけでなく他のログイン済みアカウントの HTL も混ざる。
void main() {
  testWidgets('bundleFolloweePostsProvider が全アカウントの HTL を重複除外で混ぜる', (tester) async {
    const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
    AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
      }),
    });
    // アカウント毎に author が異なる投稿を返す(viewer 引数から生成)。
    Post postOf(AccountId v) => Post(
        id: 'p-${v.handle}',
        account: v,
        author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle),
        createdAt: DateTime(2026, 8, 31, 10),
        body: '${v.handle} の投稿');
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final bundle = await container.read(bundleFolloweePostsProvider.future);
    expect({for (final p in bundle) p.author.id}, {'u-tester', 'u-second'}); // 両アカウント分
  });
}
