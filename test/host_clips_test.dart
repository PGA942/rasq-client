import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/clips/host_clips.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

const misskey = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
const bluesky = AccountId(kind: SnsKind.bluesky, instance: 'bsky.app', handle: 'yamada.bsky');

Post post(String id, AccountId account, String body) => Post(
      id: id,
      account: account,
      author: UserSummary(id: 'author-$id', account: account, displayName: '作者$id', avatarUrl: Uri.parse('https://example.invalid/a.png')),
      createdAt: DateTime(2026, 8, 27, 12),
      body: body,
      media: [MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://example.invalid/m.png'), sensitive: true)],
    );

void main() {
  test('ホスト横断クリップ: SNS を跨いで追加・重複排除・削除・永続化 (D-032)', () async {
    final storage = MemorySessionStorage();
    final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);
    final store = container.read(hostClipsProvider.notifier);
    await container.read(hostClipsProvider.future);

    final clip = await store.createClip('旅行の候補', description: '京都の宿・食・移動');
    await store.addPost(clip.id, post('1', misskey, '京都の宿'));
    await store.addPost(clip.id, post('2', bluesky, 'kyoto hotels'));
    await store.addPost(clip.id, post('1', misskey, '京都の宿')); // 重複は入らない

    var current = container.read(hostClipsProvider).value!.single;
    expect(current.entries, hasLength(2));
    expect(current.info.isHost, isTrue);
    expect(current.info.id, startsWith(hostClipIdPrefix));
    expect(current.info.notesCount, 2);

    await store.removePost(clip.id, post('2', bluesky, '').key);
    current = container.read(hostClipsProvider).value!.single;
    expect(current.entries, hasLength(1));

    // 永続化: 別コンテナ(=再起動)から同じストレージで復元できる。
    final container2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(container2.dispose);
    final restored = await container2.read(hostClipsProvider.future);
    expect(restored.single.name, '旅行の候補');
    expect(restored.single.description, '京都の宿・食・移動');
    expect(restored.single.info.description, '京都の宿・食・移動');
    expect(restored.single.entries.single.postKey, post('1', misskey, '').key);

    // KV は D-035 のキー規約。
    expect(await storage.read(hostClipsStorageKey), isNotNull);
  });

  test('スナップショット往復: 元投稿が無くても表示に必要な情報が残る', () {
    final original = post('9', bluesky, '消えるかもしれない投稿');
    final restored = postFromSnapshot((jsonDecode(jsonEncode(postSnapshot(original))) as Map).cast<String, Object?>());
    expect(restored.key, original.key);
    expect(restored.body, '消えるかもしれない投稿');
    expect(restored.author.displayName, '作者9');
    expect(restored.author.avatarUrl, isNotNull);
    expect(restored.createdAt, original.createdAt);
    expect(restored.media.single.url.toString(), 'https://example.invalid/m.png');
    expect(restored.media.single.sensitive, isTrue);
  });
}
