import 'package:rasq_models/rasq_models.dart';
import 'package:test/test.dart';

/// D-074: SNS 境界の Post ワイヤ (`rasq.post/1`) の往復。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'viewer.test', handle: 'me');
  final alice = UserSummary(
    id: 'alice',
    account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'),
    displayName: 'アリス',
    avatarUrl: Uri.parse('https://example.test/a.png'),
    bio: 'ロケットの話をします',
  );

  test('post: quote/replyTo/media/poll/reactions 込みで JSON 往復できる', () {
    final parent = Post(
      id: 'pp',
      account: viewer,
      author: alice,
      createdAt: DateTime.utc(2026, 8, 30, 10),
      body: '大気圏離脱！',
      media: [MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://f/1.png'), sensitive: true, width: 16, height: 9)],
    );
    final post = Post(
      id: 'rr',
      account: viewer,
      author: alice,
      createdAt: DateTime.utc(2026, 8, 30, 11),
      body: 'よかったやん！',
      bodyFormat: 'mfm',
      contentWarning: 'cw だよ',
      poll: Poll(options: const [PollOption(text: '犬派', votes: 2), PollOption(text: '猫派', votes: 3)], multiple: true, expiresAt: DateTime.utc(2026, 9), votedIndices: const {1}),
      quote: parent,
      replyTo: parent,
      replyToId: 'pp',
      repostedBy: alice,
      counts: const {'reply': 1, 'renote': 2, 'reaction': 5},
      visibility: 'home',
      localOnly: true,
      directToIds: const ['alice'],
      reactions: const {'👍': 3, ':blobcat:': 2},
      reactionEmojis: {':blobcat:': Uri.parse('https://example.test/blobcat.webp')},
      myReaction: '👍',
      url: Uri.parse('https://example.test/notes/rr'),
    );

    final wire = SnsWire.post(post);
    final back = SnsWire.postFrom(wire, account: viewer);

    expect(back.id, 'rr');
    expect(back.account, viewer); // キー付けは取り込み側が与える
    expect(back.author.displayName, 'アリス');
    expect(back.author.account.instance, 'example.test');
    expect(back.author.bio, 'ロケットの話をします');
    expect(back.body, 'よかったやん！');
    expect(back.bodyFormat, 'mfm');
    expect(back.contentWarning, 'cw だよ');
    expect(back.createdAt, post.createdAt);
    expect(back.poll!.options[1].text, '猫派');
    expect(back.poll!.multiple, isTrue);
    expect(back.poll!.votedIndices, {1});
    expect(back.quote!.id, 'pp');
    expect(back.quote!.media.single.sensitive, isTrue);
    expect(back.quote!.media.single.aspectRatio, closeTo(16 / 9, 0.001));
    expect(back.replyTo!.id, 'pp');
    expect(back.replyToId, 'pp');
    expect(back.repostedBy!.id, 'alice');
    expect(back.counts, post.counts);
    expect(back.visibility, 'home');
    expect(back.localOnly, isTrue);
    expect(back.directToIds, ['alice']);
    expect(back.reactions, post.reactions);
    expect(back.reactionEmojis[':blobcat:'].toString(), 'https://example.test/blobcat.webp');
    expect(back.myReaction, '👍');
    expect(back.url.toString(), 'https://example.test/notes/rr');
  });

  test('page: items + nextCursor の往復、欠けたフィールドは既定に縮退', () {
    final page = Page(items: [Post(id: 'p1', account: viewer, author: alice, createdAt: DateTime.utc(2026), body: 'hi')], nextCursor: 'p1');
    final back = SnsWire.pageFrom(SnsWire.page(page), account: viewer);
    expect(back.items.single.id, 'p1');
    expect(back.nextCursor, 'p1');
    expect(back.items.single.media, isEmpty);
    expect(back.items.single.reactions, isEmpty);

    // 最小ワイヤ(author の一部欠落)もクラッシュせず取り込める。
    final sparse = SnsWire.postFrom({'id': 'x', 'author': {'id': 'u', 'handle': 'u'}, 'createdAt': 'not-a-date', 'body': 'b'}, account: viewer);
    expect(sparse.author.displayName, 'u');
    expect(sparse.body, 'b');
  });
}
