import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_models/rasq_models.dart';

/// SNS の投稿をアカウントページにまとめて出す / 固定投稿 (S-027)。
void main() {
  Map<String, Object?> wire(String id, String body) => {
        'id': id,
        'author': {'id': 'u1', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'displayName': 'タロ'},
        'createdAt': '2026-09-20T00:00:00Z',
        'body': body,
        'bodyFormat': 'mfm',
        'visibility': 'public',
        'url': 'https://mk.example/notes/$id',
      };
  RasqSnsPost sns(String id, String at) => RasqSnsPost(accountKey: 'misskey:mk.example:taro', kind: 'misskey', instance: 'mk.example', wire: wire(id, 'SNS $id'), createdAt: DateTime.parse(at));
  RasqAccountPost rasq(String id, String at, {String? rebroadedAt}) => RasqAccountPost(
        id: id,
        body: 'RASQ $id',
        createdAt: DateTime.parse(at),
        rebroadedAt: rebroadedAt == null ? null : DateTime.parse(rebroadedAt),
        rebroadedBy: rebroadedAt == null ? null : const RasqPostAuthor(id: 'a', handle: 'taro', displayName: 'タロ'),
      );

  test('並び: 固定(固定した順)→ 残りを新しい順に、RASQ と SNS を混ぜる。リブロードは、リブロードした時刻で', () {
    final list = RasqPostList(
      limit: 3,
      source: 'rasq',
      posts: [rasq('r1', '2026-09-10T00:00:00Z'), rasq('r2', '2026-09-01T00:00:00Z', rebroadedAt: '2026-09-19T00:00:00Z'), rasq('r3', '2026-09-05T00:00:00Z')],
      snsPosts: [sns('s1', '2026-09-18T00:00:00Z'), sns('s2', '2026-09-02T00:00:00Z')],
      pins: const [(source: 'sns', ref: 'misskey:mk.example:taro|s2'), (source: 'rasq', ref: 'r3'), (source: 'rasq', ref: 'gone')],
    );
    final order = [for (final e in orderAccountPosts(list)) '${e.pinned ? '*' : ''}${e.rasq?.id ?? e.sns?.postId}'];
    expect(order, ['*s2', '*r3', 'r2', 's1', 'r1']);
  });

  test('SNS の投稿: 見ている人が同じサーバーにアカウントを持っていれば、そのアカウントの投稿として読む(リアクションできる)', () {
    final p = sns('s1', '2026-09-18T00:00:00Z');
    const viewer = AccountId(kind: SnsKind.misskey, instance: 'mk.example', handle: 'hanako');
    expect(p.toPost(viewer: viewer).account, viewer);
    // 持っていなければ、投稿した SNS アカウント自身(読むだけ)。
    expect(p.toPost().account.key, 'misskey:mk.example:taro');
    expect(p.toPost().author.handle, 'taro');
    expect('${p.toPost().url}', 'https://mk.example/notes/s1');
    expect(p.pin, (source: 'sns', ref: 'misskey:mk.example:taro|s1'));
  });

  test('応答の snsPosts / pins / 預け入れの状態を読む', () {
    final st = RasqVaultStatus.fromJson({'accountKey': 'k', 'hasToken': true, 'postCount': 12, 'lastFetchAt': '2026-09-20T00:00:00Z', 'lastError': null});
    expect((st.hasToken, st.postCount, st.lastError), (true, 12, null));
    final s = RasqSnsPost.fromJson({'accountKey': 'misskey:mk.example:taro', 'kind': 'misskey', 'instance': 'mk.example', 'createdAt': '2026-09-20T00:00:00Z', 'post': wire('s9', 'x')});
    expect(s.postId, 's9');
  });
}
