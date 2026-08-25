import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
final now = DateTime(2026, 8, 25, 12);

Post post(String id, String author, String body, {Duration age = Duration.zero}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: now.subtract(age),
      body: body,
    );

void main() {
  const engine = RelationalEngine(settings: RelationalSettings(threshold: 60, staleMinutes: 10));

  test('features: ハッシュタグ・メンション・カタカナ/英数・CJK連続語', () {
    final f = RelationalEngine.features(post('x', 'a', '#打上会 のストラトローンチ Stratolaunch @douglas 国際信州大学'));
    expect(f, containsAll(['打上会', 'ストラトローンチ', 'stratolaunch', 'douglas', '国際信州大学']));
  });

  test('ruleBasedSimilarity は 0.5 床の擬似 cos', () {
    final a = post('a', 'u1', '#ロケット 発射');
    final b = post('b', 'u2', '#ロケット すごい');
    final c = post('c', 'u3', 'まったく別の話题です');
    expect(RelationalEngine.ruleBasedSimilarity(a, b), greaterThan(0.6));
    expect(RelationalEngine.ruleBasedSimilarity(a, c), lessThan(0.6));
    expect(RelationalEngine.ruleBasedSimilarity(a, c), greaterThanOrEqualTo(0.5));
  });

  test('build: 同じ話題のフォロイー投稿が束ねられ、単発は出ない', () {
    final clusters = engine.build(followeePosts: [
      post('1', 'douglas', '#打上会 ストラトローンチ発射!', age: const Duration(minutes: 3)),
      post('2', 'tivard', 'ストラトローンチ 打ち上げ成功 #打上会', age: const Duration(minutes: 1)),
      post('3', 'lonely', '今日のお昼はカレーうどん', age: const Duration(minutes: 2)),
    ], now: now);
    expect(clusters, hasLength(1));
    expect(clusters.single.posts, hasLength(2));
    expect(clusters.single.members.map((u) => u.displayName), containsAll(['douglas', 'tivard']));
    expect(clusters.single.lastActivityAt, now.subtract(const Duration(minutes: 1)));
  });

  test('build: LTL 候補がしきい値以上ならクラスタに合流する', () {
    final clusters = engine.build(
      followeePosts: [
        post('1', 'douglas', '#打上会 ストラトローンチ発射!', age: const Duration(minutes: 3)),
        post('2', 'tivard', 'ストラトローンチ成功 #打上会', age: const Duration(minutes: 2)),
      ],
      candidatePosts: [
        post('9', 'stranger', 'ストラトローンチ #打上会 見てた!', age: const Duration(minutes: 1)),
        post('8', 'other', '無関係な夕飯の写真', age: const Duration(minutes: 1)),
      ],
      now: now,
    );
    expect(clusters.single.posts.map((p) => p.id), containsAll(['1', '2', '9']));
    expect(clusters.single.posts.map((p) => p.id), isNot(contains('8')));
  });

  test('しきい値 100 ではほぼ束ねない(スライダー上限)', () {
    const strict = RelationalEngine(settings: RelationalSettings(threshold: 100));
    final clusters = strict.build(followeePosts: [
      post('1', 'a', '#x ロケット'),
      post('2', 'b', '#x ロケット パーティー'), // 特徴が 1 語でも違えば cos 1.0 に届かない
    ], now: now);
    expect(clusters, isEmpty);
  });

  test('浮上ルール: staleMinutes 超は沈み、markAction で浮上する', () {
    final old = [
      post('1', 'a', '#topic ネタ', age: const Duration(minutes: 30)),
      post('2', 'b', '#topic ネタ返し', age: const Duration(minutes: 25)),
    ];
    expect(engine.build(followeePosts: old, now: now), isEmpty);

    // markAction(自分の関連投稿へのアクション)で浮上が更新されれば残る。
    const lenient = RelationalEngine(settings: RelationalSettings(threshold: 60, staleMinutes: 60));
    final clusters = lenient.build(followeePosts: old, now: now);
    engine.markAction(clusters, postKey: old.first.key, at: now.subtract(const Duration(minutes: 1)));
    expect(engine.pruneStale(clusters, now: now), hasLength(1));
  });

  test('除外ルール: しきい値から離れた投稿を4連続した著者は外れる', () {
    final clusters = engine.build(followeePosts: [
      post('1', 'douglas', '#打上会 ストラトローンチ', age: const Duration(minutes: 5)),
      post('2', 'tivard', 'ストラトローンチ #打上会', age: const Duration(minutes: 4)),
      post('3', 'noisy', '#打上会 ストラトローンチ 見た', age: const Duration(minutes: 3)),
    ], now: now);
    expect(clusters.single.members, hasLength(3));

    final pruned = engine.dropOffTopicMembers(clusters, recentByAuthor: {
      'misskey:misskey.io:noisy': [
        post('n1', 'noisy', '夕飯なう'),
        post('n2', 'noisy', 'ねむい'),
        post('n3', 'noisy', 'テレビみてる'),
        post('n4', 'noisy', 'おやすみ'),
      ],
    });
    expect(pruned.single.members.map((u) => u.displayName), isNot(contains('noisy')));
    expect(pruned.single.members, hasLength(2));
  });
}
