import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/home/reaction_history.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');

Post post(Map<String, int> reactions) => Post(
      id: 'p1',
      account: account,
      author: const UserSummary(id: 'a', account: account, displayName: 'a'),
      createdAt: DateTime(2026, 8, 27),
      body: 'hello',
      reactions: reactions,
    );

void main() {
  test('リアクション予測 (D-039): 投稿の既存リアクション × 自分の履歴 → 最頻 → null', () async {
    final storage = MemorySessionStorage();
    final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);
    final store = container.read(reactionHistoryProvider.notifier);
    await container.read(reactionHistoryProvider.future);

    // 履歴なし → null(アダプタの既定に任せる)。
    expect(store.predictFor(post(const {'👍': 3})), isNull);

    await store.record('🎉');
    await store.record('🎉');
    await store.record('👍');

    // 投稿に付いているものと自分の履歴の交差(🎉 は付いていない)→ 👍。
    expect(store.predictFor(post(const {'👍': 3, '😇': 1})), '👍');
    // 交差があれば自分の最頻 🎉。
    expect(store.predictFor(post(const {'🎉': 1, '👍': 2})), '🎉');
    // 交差ゼロ → 自分の最頻 🎉。
    expect(store.predictFor(post(const {':blobcat:': 5})), '🎉');

    // 永続化: 別コンテナで復元。
    final container2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container2.dispose);
    final restored = await container2.read(reactionHistoryProvider.future);
    expect(restored['🎉'], 2);
    expect(jsonDecode((await storage.read(reactionHistoryStorageKey))!), isA<Map>());
  });
}
