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
  test('リアクション予測 (D-039/D-041): 複数リアクション済みは投稿内から指数選出、それ以外は履歴', () async {
    final storage = MemorySessionStorage();
    final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);
    final store = container.read(reactionHistoryProvider.notifier);
    await container.read(reactionHistoryProvider.future);

    // 合計 2 未満 + 履歴なし → null(アダプタの既定に任せる)。
    expect(store.predictFor(post(const {'👍': 1})), isNull);

    // 複数リアクション済み → 履歴が無くても**その投稿のリアクションの中**から。
    // 上位ほど指数関数的に出やすい(重み 2^-rank)— 多数の投稿で 1 位が最頻。
    final tally = <String, int>{};
    for (var i = 0; i < 300; i++) {
      final p = Post(
        id: 'p$i',
        account: account,
        author: const UserSummary(id: 'a', account: account, displayName: 'a'),
        createdAt: DateTime(2026, 8, 27),
        body: 'x',
        reactions: const {'👍': 10, '🎉': 5, '😇': 1},
      );
      final r = store.predictFor(p)!;
      expect(const ['👍', '🎉', '😇'], contains(r));
      tally[r] = (tally[r] ?? 0) + 1;
    }
    expect(tally['👍']!, greaterThan(tally['🎉'] ?? 0));
    expect(tally['🎉'] ?? 0, greaterThan(tally['😇'] ?? 0));
    // 同じ投稿なら結果は安定(決定的シード)。
    final fixed = post(const {'👍': 3, '🎉': 2});
    expect(store.predictFor(fixed), store.predictFor(fixed));

    await store.record('🎉');
    await store.record('🎉');
    await store.record('👍');

    // 合計 2 未満の投稿: 交差(👍 だけ付いている)→ 👍。
    expect(store.predictFor(post(const {'👍': 1})), '👍');
    // リアクションゼロ → 予測しない (D-281。自分の最頻に偏りすぎたため)。設定を入れると、自分の最頻 🎉。
    expect(store.predictFor(post(const {})), isNull);
    ReactionPrefs.predictWhenEmpty = true;
    addTearDown(() => ReactionPrefs.predictWhenEmpty = false);
    expect(store.predictFor(post(const {})), '🎉');

    // 永続化: 別コンテナで復元。
    final container2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container2.dispose);
    final restored = await container2.read(reactionHistoryProvider.future);
    expect(restored['🎉'], 2);
    expect(jsonDecode((await storage.read(reactionHistoryStorageKey))!), isA<Map>());
  });

  test('他サーバーの絵文字だけを見分ける (D-278)', () {
    expect(remoteReactionName(':blob@other.example:'), 'blob');
    // 自サーバー / Unicode / 壊れた形は、読み替えない。
    expect(remoteReactionName(':blob:'), isNull);
    expect(remoteReactionName(':blob@.:'), isNull);
    expect(remoteReactionName('👍'), isNull);
    expect(remoteReactionName(':@other.example:'), isNull);
    expect(remoteReactionName('::'), isNull);
  });
}
