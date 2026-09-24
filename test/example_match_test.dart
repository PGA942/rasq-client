import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/trend/example_match.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-314: 例で決める — 例との近さ(純関数)、自分のトレンドの採点、子の端末の当てはめ(プラグイン / クリップ / リスト)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: UserSummary(id: 'u-$id', account: acc, displayName: '作者$id'), createdAt: DateTime(2026, 9, 24), body: body);

  const casino = ContentExample(kind: ExampleKind.text, text: 'オンラインカジノ スロット 一攫千金 ギャンブル');
  const quiz = ContentExample(kind: ExampleKind.plugin, ref: 'jp.example.quiz', text: '算数クイズ 毎日 1 問、解説つきで計算の練習');
  const horror = ContentExample(kind: ExampleKind.clip, ref: 'c-h', text: 'ホラー映画のまとめ 心霊 怖い話 呪い');

  group('近さ(類似度)', () {
    test('同じ話題の言い換えは近い(0.3 以上)、関係の薄い文は遠い', () {
      // 近い: 同じ語(カジノ / スロット)を含む別の言い方。
      expect(exampleSimilarity(casino.text, 'スロット攻略: オンラインカジノで勝つ方法を計算します'), greaterThanOrEqualTo(exampleNearThreshold));
      expect(exampleSimilarity(horror.text, '呪いのホラー映画を見た'), greaterThanOrEqualTo(exampleNearThreshold));
      expect(exampleSimilarity('ゲーム実況 配信 攻略', 'ゲームの攻略動画を配信します'), greaterThanOrEqualTo(exampleNearThreshold));
      expect(exampleSimilarity(quiz.text, '毎日の計算練習クイズ(算数)'), greaterThanOrEqualTo(exampleNearThreshold));
      // 同じハッシュタグは強いアンカー。
      expect(exampleSimilarity('#打上会 きょうの中継', 'ロケットの写真 #打上会'), greaterThanOrEqualTo(0.6));
      // 遠い: 話題が違う。
      expect(exampleSimilarity(casino.text, '今日の晩ごはんはカレー。スパイスを変えてみた'), lessThan(exampleNearThreshold));
      expect(exampleSimilarity(casino.text, quiz.text), lessThan(exampleNearThreshold));
      expect(exampleSimilarity(horror.text, '算数の宿題を終わらせた'), lessThan(exampleNearThreshold));
      expect(exampleSimilarity('ゲーム実況 配信 攻略', '宿題の答え合わせ'), lessThan(exampleNearThreshold));
      // ありふれた短い語 1 つ(「今日」)だけが同じ短い文どうしは、近いにしない(特徴語の重みと + 2)。
      expect(exampleSimilarity('今日は晴れ', '今日の晩ごはんはカレー'), lessThan(exampleNearThreshold));
      // スロットの名前(点つきの識別子)だけが同じプラグインは近くない。
      expect(exampleSimilarity('天気 明日の天気と気温を知らせます trend.suggest', 'トレンドサジェスト 関連タグを提案します trend.suggest'), lessThan(exampleNearThreshold));
      expect(exampleSimilarity('', casino.text), 0);
      // 決まった値(同じ入力は同じ結果)。
      expect(exampleSimilarity(casino.text, horror.text), exampleSimilarity(casino.text, horror.text));
    });

    test('ものの文が複数なら、いちばん近い文で測る / 許す例と止める例を別々に', () {
      const ex = ContentExamples(allow: [quiz], deny: [casino]);
      final s = exampleScoresOf(pluginExamplePieces(name: 'カジノ攻略', description: 'オンラインカジノのスロットで一攫千金', slots: ['tl']), ex);
      expect(s.nearDeny, isTrue);
      expect(s.nearAllow, isFalse);
      expect(s.leansDeny, isTrue);
      final q = exampleScoresOf(pluginExamplePieces(name: '計算ドリル', description: '算数の計算を毎日 1 問ずつ練習するクイズ'), ex);
      expect(q.nearAllow, isTrue);
      expect(q.nearDeny, isFalse);
      expect(exampleScoresOf(const ['なんでも'], ContentExamples.none), same(ExampleScores.zero));
    });

    test('束(クリップ / リスト): 近い投稿が 3 割以上か、名前 / 説明が近いときだけ', () {
      const ex = ContentExamples(deny: [horror]);
      final okPosts = ['今日は晴れ', '宿題おわった', '明日は遠足', 'お弁当はサンドイッチ', '算数のテスト'];
      // 5 件中 1 件だけホラー → 束ごとは寄せない(1/5 = 2 割)。
      expect(collectionScoresOf(meta: '日記', posts: [...okPosts.take(4), '呪いのホラー映画を見た'], examples: ex).nearDeny, isFalse);
      // 5 件中 2 件(4 割)→ 近い。
      expect(collectionScoresOf(meta: '日記', posts: [...okPosts.take(3), 'ホラー映画 心霊まとめを見た', '呪いのホラー映画を見た'], examples: ex).nearDeny, isTrue);
      // 名前 / 説明だけでも近ければ近い(中身が読めないとき)。
      expect(collectionScoresOf(meta: 'ホラー映画 心霊まとめ', posts: const [], examples: ex).nearDeny, isTrue);
      expect(collectionScoresOf(meta: '遠足の写真', posts: okPosts, examples: ex).nearDeny, isFalse);
    });
  });

  group('例の形', () {
    test('要約は空白をまとめて 300 文字で切る / 読めない例は飛ばす / 同じ鍵は片側だけ', () {
      expect(exampleTextOf([' 算数クイズ\n\n毎日  1 問 ', '']), '算数クイズ 毎日 1 問');
      expect(exampleTextOf(['あ' * 400]).runes.length, maxExampleChars);
      expect(exampleTextOf(['😀' * 400]).runes.length, maxExampleChars); // コードポイントで数える(Central と同じ)
      final ex = ContentExamples.fromJson({
        'allow': [quiz.toJson(), {'kind': 'video', 'text': 'x'}, {'kind': 'text', 'text': '  '}, casino.toJson()],
        'deny': [casino.toJson()],
      });
      expect(ex.allow, [quiz]); // 両側にあるものは止める側だけ(安全側)
      expect(ex.deny, [casino]);
      expect(ContentExamples.fromJson(ex.toJson()), ex);
      expect(casino.toJson().containsKey('ref'), isFalse);
      // 同じもと(鍵)を反対側に入れ直すと移る。
      final moved = ex.withExample(const ContentExample(kind: ExampleKind.plugin, ref: 'jp.example.quiz', text: '算数クイズ(新しい説明)'), allow: false);
      expect(moved.allow, isEmpty);
      expect(moved.deny.length, 2);
      // 上限を超えたら古いものから落とす。
      var many = ContentExamples.none;
      for (var i = 0; i < maxExamplesPerSide + 5; i++) {
        many = many.withExample(ContentExample(kind: ExampleKind.text, text: '例 $i'), allow: true);
      }
      expect(many.allow.length, maxExamplesPerSide);
      expect(many.allow.first.text, '例 5');
      expect(many.without(many.allow.first).allow.length, maxExamplesPerSide - 1);
    });
  });

  group('自分のトレンド (TendencyProfile.examples)', () {
    test('好きな例に近い投稿は残り、好きではない例に寄った投稿は落ちる(語 1 つではなく、もの全体で)', () {
      const profile = TendencyProfile(
        directionality: 0,
        examples: ContentExamples(
          allow: [ContentExample(kind: ExampleKind.post, text: 'ロケット打ち上げの中継 宇宙開発 人工衛星')],
          deny: [ContentExample(kind: ExampleKind.list, ref: 'l1', text: '芸能人の炎上 ゴシップ スキャンダル 週刊誌')],
        ),
      );
      expect(profile.active, isTrue);
      expect(profile.hasDirection, isTrue);
      final posts = [
        post('a', '人工衛星を載せたロケットの打ち上げ中継、成功！'),
        post('b', '週刊誌が芸能人のスキャンダルを報道して炎上'),
        post('c', '今日の晩ごはんはカレー'),
      ];
      const scorer = TendencyScorer();
      expect(scorer.isDisliked(posts[1], profile), isTrue);
      expect(scorer.isDisliked(posts[0], profile), isFalse);
      expect(scorer.directionOf(posts[0], profile), 1.0);
      expect(scorer.directionOf(posts[2], profile), lessThan(profile.directionThreshold));
      expect(scorer.apply(posts, profile).map((p) => p.id), ['a']);
      // 例が無ければ指向性では落とさない(いままでどおり)。
      expect(scorer.directionOf(posts[2], const TendencyProfile()), 1.0);
      // 保存の形。
      final back = TendencyProfile.fromJson(profile.toJson().cast<String, Object?>());
      expect(back.examples, profile.examples);
      expect(const TendencyProfile().toJson().containsKey('examples'), isFalse);
    });
  });

  group('子の端末 (allow.examples)', () {
    ChildGate gate({String install = 'any', List<String> ids = const [], ContentExamples? examples, bool plugins = true}) {
      final allow = {
        if (plugins) 'plugins': {'ids': ids, 'slots': <String, bool>{}, 'install': install},
        if (examples != null) 'examples': examples.toJson(),
      };
      final policy = ChildSafePolicy.fromJson({'schema': ChildSafePolicy.schemaV2, 'preset': 'custom', 'allow': allow});
      return ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: policy));
    }

    const ex = ContentExamples(allow: [quiz], deny: [casino]);
    final casinoPlugin = pluginExamplePieces(name: 'カジノ攻略', description: 'オンラインカジノのスロットで一攫千金', slots: ['tl']);
    final quizPlugin = pluginExamplePieces(name: '計算ドリル', description: '算数の計算を毎日 1 問ずつ練習するクイズ', slots: ['composer.text']);
    final otherPlugin = pluginExamplePieces(name: '天気', description: '明日の天気と気温を知らせます', slots: ['trend.suggest']);

    test('プラグイン: 止める例に近いものは any でも使えない / examples は許す例に近いものだけ / ids がいちばん強い', () {
      final any = gate(examples: ex);
      expect(any.pluginAllowed('x.casino', 'tl', text: casinoPlugin), isFalse);
      expect(any.pluginAllowed('x.weather', 'trend.suggest', text: otherPlugin), isTrue);
      expect(any.pluginAllowed('x.unknown', 'tl'), isTrue); // 中身が分からなければ例では止めない
      expect(any.installBlockReason('x.casino', text: casinoPlugin), contains('止めている例'));
      expect(any.installBlockReason('x.weather', text: otherPlugin), isNull);

      final byExamples = gate(install: 'examples', ids: ['x.casino'], examples: ex);
      expect(byExamples.pluginAllowed('x.quiz', 'composer.text', text: quizPlugin), isTrue);
      expect(byExamples.pluginAllowed('x.weather', 'trend.suggest', text: otherPlugin), isFalse);
      expect(byExamples.pluginAllowed('x.quiz', 'composer.text'), isFalse); // 中身が分からなければ許さない
      expect(byExamples.pluginAllowed('x.casino', 'tl', text: casinoPlugin), isTrue); // 名指しの ids は止める例より強い
      expect(byExamples.installBlockReason('x.quiz'), isNull); // 構成を取るまでは通す(取ったあとで決める)
      expect(byExamples.installBlockReason('x.quiz', text: quizPlugin), isNull);
      expect(byExamples.installBlockReason('x.weather', text: otherPlugin), contains('許す例'));
      // 許す例にも止める例にも近い → 止める例が勝つ。
      final both = gate(install: 'examples', examples: const ContentExamples(allow: [ContentExample(kind: ExampleKind.text, text: 'スロット オンラインカジノ 一攫千金')], deny: [casino]));
      expect(both.pluginAllowed('x.casino', 'tl', text: casinoPlugin), isFalse);

      // listed / none は例では広げない。allow.plugins が無くても、止める例は効く。
      expect(gate(install: 'listed', examples: ex).pluginAllowed('x.quiz', 'composer.text', text: quizPlugin), isFalse);
      expect(gate(plugins: false, examples: ex).pluginAllowed('x.casino', 'tl', text: casinoPlugin), isFalse);
      expect(gate(plugins: false, examples: ex).pluginAllowed('x.weather', 'tl', text: otherPlugin), isTrue);
      // 例が無ければ、いままでどおり。
      expect(gate().pluginAllowed('x.casino', 'tl', text: casinoPlugin), isTrue);
      expect(ChildGate.off.pluginAllowed('x.casino', 'tl', text: casinoPlugin), isTrue);
    });

    test('クリップ / リスト: 中身が止める例に近いものは出さない', () {
      final g = gate(examples: const ContentExamples(deny: [horror]));
      expect(g.hasDenyExamples, isTrue);
      expect(g.collectionHidden('夏の思い出', ['ホラー映画 心霊まとめを見た', '呪いのホラー映画を見た', '海に行った']), isTrue);
      expect(g.collectionHidden('夏の思い出', ['海に行った', 'スイカ割り', '花火大会']), isFalse);
      expect(g.collectionHidden('ホラー映画 心霊まとめ'), isTrue);
      // 許す例だけでは隠さない / 見守られていなければ何もしない。
      expect(gate(examples: const ContentExamples(allow: [horror])).collectionHidden('ホラー映画 心霊まとめ'), isFalse);
      expect(ChildGate.off.collectionHidden('ホラー映画 心霊まとめ'), isFalse);
    });

    test('方針の形: allow.examples と install: examples を読み書きする(無ければ出さない)', () {
      final p = ChildSafePolicy.fromJson({
        'schema': ChildSafePolicy.schemaV2,
        'allow': {
          'plugins': {'ids': <String>[], 'install': 'examples'},
          'examples': ex.toJson(),
        },
      });
      expect(p.allow!.plugins!.install, ChildSafeInstall.examples);
      expect(p.allow!.examples, ex);
      final j = p.toJson();
      expect(((j['allow'] as Map)['plugins'] as Map)['install'], 'examples');
      expect((j['allow'] as Map)['examples'], ex.toJson());
      final plain = ChildSafePolicy.fromJson({'schema': ChildSafePolicy.schemaV2, 'allow': {'plugins': {'install': 'any'}}});
      expect(plain.allow!.examples, isNull);
      expect((plain.toJson()['allow'] as Map).containsKey('examples'), isFalse);
      // 空にしたら欄ごと出さない(Central の「無い = 例では絞らない」)。
      expect((plain.copyWith(allow: plain.allow!.copyWith(examples: ContentExamples.none)).toJson()['allow'] as Map).containsKey('examples'), isFalse);
    });
  });
}
