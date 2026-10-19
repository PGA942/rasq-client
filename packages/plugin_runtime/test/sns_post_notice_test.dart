import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 投稿の知らせ (契約 v0.25、D-500): `sns.createPost` / `sns.sendDm` の答えの `notice: {code, message}` を、
/// [WasmSnsSession] が [SentPost.notice] に渡す。無い(古いプラグイン)・形が違う・文が空なら null。
void main() {
  const account = AccountId(kind: SnsKind.mastodon, instance: 'mastodon.example', handle: 'me');
  final post = {
    'id': 's1', 'createdAt': '2026-10-20T00:00:00.000Z', 'body': '本文', 'bodyFormat': 'plain',
    'author': {'id': 'me', 'kind': 'mastodon', 'instance': 'mastodon.example', 'handle': 'me', 'displayName': 'me'},
  };

  WasmSnsSession sessionAnswering(Map<String, Object?> value, List<String> calls) => WasmSnsSession(
        account: account,
        invoke: (fn, args) async {
          calls.add(fn);
          return {'ok': true, 'value': value};
        },
      );

  test('createPostWithNotice: notice の code と message を渡す。createPost は投稿だけ', () async {
    final calls = <String>[];
    final s = sessionAnswering({'post': post, 'notice': {'code': 'quote.fallbackUrl', 'message': '引用元の URL を付けて投稿しました'}}, calls);
    final sent = await s.createPostWithNotice(const NewPost(text: '本文', quoteOfId: 'q1'));
    expect(sent.post.id, 's1');
    expect(sent.post.account, account);
    expect((sent.notice?.code, sent.notice?.message), ('quote.fallbackUrl', '引用元の URL を付けて投稿しました'));
    expect((await s.createPost(const NewPost(text: '本文'))).id, 's1');
    expect(calls, ['sns.createPost', 'sns.createPost']);
  });

  test('sendDmWithNotice も同じ', () async {
    final calls = <String>[];
    final s = sessionAnswering({'post': post, 'notice': {'code': 'x.y', 'message': 'お知らせ'}}, calls);
    final room = DmRoom(id: 'r', kind: DmRoomKind.direct, peer: const UserSummary(id: 'u2', account: account, displayName: 'u2'));
    final sent = await s.sendDmWithNotice(room, const NewPost(text: 'やあ'));
    expect(sent.notice?.message, 'お知らせ');
    expect((await s.sendDm(room, const NewPost(text: 'やあ'))).id, 's1');
    expect(calls, ['sns.sendDm', 'sns.sendDm']);
  });

  test('notice が無い(v0.24 以前のプラグイン)・形が違う・文が空なら null', () async {
    for (final value in <Map<String, Object?>>[
      {'post': post},
      {'post': post, 'notice': null},
      {'post': post, 'notice': '文字列'},
      {'post': post, 'notice': {'code': 'a.b'}},
      {'post': post, 'notice': {'code': 'a.b', 'message': '  '}},
    ]) {
      final sent = await sessionAnswering(value, []).createPostWithNotice(const NewPost(text: 'x'));
      expect(sent.notice, isNull, reason: '$value');
    }
    // code が無くても message は出す(ホストは知らない code でも文を出す)。
    final sent = await sessionAnswering({'post': post, 'notice': {'message': ' 知らせ '}}, []).createPostWithNotice(const NewPost(text: 'x'));
    expect((sent.notice?.code, sent.notice?.message), ('', '知らせ'));
  });

  test('SnsSessionBase の既定: createPost を呼んで知らせ無し', () async {
    final s = _Plain();
    final sent = await s.createPostWithNotice(const NewPost(text: 'x'));
    expect((sent.post.id, sent.notice), ('p', null));
  });
}

class _Plain extends SnsSessionBase {
  @override
  AccountId get account => const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'me');
  @override
  String get pluginId => 'plain';
  @override
  int get maxPostLength => 3000;
  @override
  Future<Post> createPost(NewPost draft) async =>
      Post(id: 'p', account: account, author: UserSummary(id: 'me', account: account, displayName: 'me'), createdAt: DateTime(2026), body: draft.text);
}
