import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-153: 指向性/刺激性のプロファイル — 採点と TL への適用。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  var n = 0;
  Post post(String body) => Post(id: 'p${n++}', account: acc, author: const UserSummary(id: 'u', account: acc, displayName: 'u'), createdAt: DateTime(2026, 9, 9), body: body);

  test('JSON の往復と既定値', () {
    final p = TendencyProfile.fromJson({'directionality': 0.2, 'stimulus': {'anger': 0.3}, 'genres': ['#ロケット', ' 宇宙 '], 'disliked': ['占い'], 'autoGenre': true});
    expect(p.enabled, isTrue);
    expect(p.genres, ['#ロケット', '宇宙']);
    expect(p.stimulusCap('anger'), 0.3);
    expect(p.stimulusCap('joy'), 1.0);
    expect(p.directionThreshold, closeTo(0.4, 1e-9));
    expect(TendencyProfile.fromJson(p.toJson()).disliked, ['占い']);
    expect(const TendencyProfile(stimulus: {}).active, isFalse); // 何も設定していなければ効かない
    // 刺激性の既定 (D-470): 新しいプロファイルは恐れ / 嫌悪 / 怒りを 45% までにするので効く。
    expect(const TendencyProfile().active, isTrue);
    expect(const TendencyProfile().stimulusCap('fear'), 0.45);
    expect(p.copyWith(snsDefault: true).active, isFalse);
    expect(TendencyProfile.tryParse('nope'), isNull);
  });

  test('刺激性: 語彙ルールで 8 感情', () {
    final e = emotionLexiconOf('死ね クズ、ほんとむかつく');
    expect(e['anger'], greaterThan(0.7));
    expect(e['disgust'], greaterThan(0.4));
    expect(e['joy'], 0);
    expect(emotionLexiconOf('打ち上げ成功おめでとう！楽しみ')['anticipation'], greaterThan(0));
    expect(emotionLexiconOf('こんにちは').values.every((v) => v == 0), isTrue);
  });

  test('指向性: ジャンル一致は 1、近い語は n-gram、遠い語は低い', () {
    const profile = TendencyProfile(genres: ['ロケット発射', '#宇宙']);
    expect(tendencyScorer.directionOf(post('今日はロケット発射を見に行く'), profile), 1.0);
    expect(tendencyScorer.directionOf(post('宇宙の話 #宇宙'), profile), 1.0);
    final near = tendencyScorer.directionOf(post('ロケットの整備中'), profile);
    final far = tendencyScorer.directionOf(post('今日の晩ごはんはカレー'), profile);
    expect(near, greaterThan(far));
    expect(tendencyScorer.directionOf(post('なんでも'), const TendencyProfile()), 1.0); // ジャンル無し = 制限なし
  });

  test('適用: 狭いと外れる投稿が落ち、嫌いなジャンルは消え、刺激性の超過は後ろ/除外', () {
    final rocket = post('ロケット発射おめでとう！');
    final curry = post('今日の晩ごはんはカレー');
    final angry = post('ロケット発射なんてクズだ、死ね、むかつく、ふざけるな');
    final fortune = post('今日の占い: ロケット発射の日は吉');
    final posts = [curry, angry, rocket, fortune];
    // 広い(1.0)ならジャンルで落とさない(並びは適合度順)。
    final wide = tendencyScorer.apply(posts, const TendencyProfile(genres: ['ロケット'], directionality: 1.0));
    expect(wide.last, curry); // ジャンルに合う 3 件(同点、元の順)が先、カレーは最後
    expect(wide.take(3), containsAll([rocket, angry, fortune]));
    // 狭い(0.0)ならカレーは落ちる。
    final narrow = tendencyScorer.apply(posts, const TendencyProfile(genres: ['ロケット'], directionality: 0.0));
    expect(narrow, isNot(contains(curry)));
    expect(narrow, contains(rocket));
    // 嫌いなジャンルは消える。
    final dis = tendencyScorer.apply(posts, const TendencyProfile(genres: ['ロケット'], directionality: 1.0, disliked: ['占い']));
    expect(dis, isNot(contains(fortune)));
    // 怒りの上限 0.2: 暴言の投稿は除外(超過 ≥ 0.75)か最後尾。
    final calm = tendencyScorer.apply(posts, const TendencyProfile(genres: ['ロケット'], directionality: 1.0, stimulus: {'anger': 0.2, 'disgust': 0.2}));
    expect(calm.first, rocket);
    expect(!calm.contains(angry) || calm.last == angry, isTrue);
    // 効かない設定は素通し(順序も維持)。
    expect(tendencyScorer.apply(posts, const TendencyProfile(stimulus: {})), posts);
    expect(applyTendencyProfile(posts, null), posts);
  });
}
