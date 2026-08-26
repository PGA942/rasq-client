import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_providers.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
final base = DateTime(2026, 8, 26, 12);

Post post(String id, String author, String body, {Duration at = Duration.zero}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: base.add(at),
      body: body,
    );

void main() {
  group('特徴抽出', () {
    test('タグ・メンション・固有名詞近似', () {
      final f = extractFeatures(post('x', 'a', '#打上会 のストラトローンチ Stratolaunch @douglas 国際信州大学'));
      expect(f, containsAll(['打上会', 'ストラトローンチ', 'stratolaunch', 'douglas', '国際信州大学']));
    });

    test('反応表現の検出(短文のみ)', () {
      expect(isReactivePost(post('1', 'a', 'それな')), isTrue);
      expect(isReactivePost(post('2', 'a', 'えっ、マジ')), isTrue);
      expect(isReactivePost(post('3', 'a', 'わかる……')), isTrue);
      expect(isReactivePost(post('4', 'a', '本日の登壇資料を公開しました。リンクはこちらです。ぜひご覧ください。それでは。')), isFalse);
      expect(isReactivePost(post('5', 'a', '天気は快晴です')), isFalse);
    });

    test('ルールベース類似度は 0.5〜1.0(共有語が多いほど高い)', () {
      final a = post('a', 'u1', 'ストラトローンチの機体が好き');
      final b = post('b', 'u2', 'ストラトローンチの機体、翼が長い');
      final c = post('c', 'u3', '今日のごはんはカレー');
      expect(ruleBasedSimilarity(a, b), greaterThan(ruleBasedSimilarity(a, c)));
      expect(ruleBasedSimilarity(a, c), greaterThanOrEqualTo(0.5));
    });
  });

  group('会話イベント (D-027)', () {
    test('空リプ会話が 1 イベントに束なる(反応表現+時間+発話交替)', () {
      final posts = [
        post('1', 'alice', '同人誌の原稿、落とした……'),
        post('2', 'bob', 'えっ、マジ', at: const Duration(seconds: 40)),
        post('3', 'alice', 'マジ……無理だった', at: const Duration(seconds: 90)),
        post('4', 'carol', '天気は快晴。散歩日和です', at: const Duration(seconds: 60)),
      ];
      final engine = ConversationEngine();
      final events = engine.build(followeePosts: posts, now: base.add(const Duration(minutes: 3)));
      expect(events, hasLength(1));
      final e = events.single;
      // 仮 ROOT(開始点)まで遡って束なっている。
      expect(e.root.id, '1');
      expect(e.posts.map((p) => p.id), ['1', '2', '3']);
      // carol の独り言は仮 ROOT のまま表示されない。
      expect(e.members.map((u) => u.displayName), ['alice', 'bob']);
    });

    test('話題語を共有する会話は内容類似で束なり、無関係は分かれる', () {
      final posts = [
        post('1', 'a', 'ストラトローンチの打ち上げ配信見てる'),
        post('2', 'b', 'ストラトローンチの配信、望遠の画角すごいな', at: const Duration(minutes: 1)),
        post('3', 'c', '猫カフェのラテアート可愛かった', at: const Duration(minutes: 2)),
        post('4', 'd', 'ラテアート目当てで猫カフェ行きたい', at: const Duration(minutes: 3)),
      ];
      final events = ConversationEngine().build(followeePosts: posts, now: base.add(const Duration(minutes: 4)));
      expect(events, hasLength(2));
      final byRoot = {for (final e in events) e.root.id: e.posts.map((p) => p.id).toList()};
      expect(byRoot['1'], ['1', '2']);
      expect(byRoot['3'], ['3', '4']);
    });

    test('ユーザー除外はしない: 別話題を連投しても過去の参加は残る (投稿単位所属)', () {
      final posts = [
        post('1', 'alice', 'ストラトローンチの打ち上げ配信見てる'),
        post('2', 'bob', 'ストラトローンチ配信、自分も見てる', at: const Duration(minutes: 1)),
        // alice が無関係の別話題を 4 連投(v0 ならイベントから除外されていた)。
        post('3', 'alice', '晩ごはんのカレーを仕込む', at: const Duration(minutes: 5)),
        post('4', 'alice', 'カレーのルーが足りない', at: const Duration(minutes: 6)),
        post('5', 'alice', 'カレーに福神漬けは必須', at: const Duration(minutes: 7)),
        post('6', 'alice', 'カレーができた', at: const Duration(minutes: 8)),
      ];
      // buildAll = 表示フィルタ前の全イベント(TTL で沈んでいても所属は残る)。
      final events = ConversationEngine().buildAll(followeePosts: posts, now: base.add(const Duration(minutes: 9)));
      final launch = events.firstWhere((e) => e.root.id == '1');
      // alice の投稿 1 はイベントに残ったまま。
      expect(launch.posts.map((p) => p.id), contains('1'));
      expect(launch.members.map((u) => u.displayName), contains('alice'));
    });

    test('単独投稿は仮 ROOT のまま表示されず、後続が来れば遡及して表示される', () {
      final engine = ConversationEngine();
      final solo = [post('1', 'a', 'ストラトローンチの機体が好き')];
      expect(engine.build(followeePosts: solo, now: base.add(const Duration(minutes: 1))), isEmpty);
      final followed = [...solo, post('2', 'b', 'ストラトローンチの機体、翼が長いよね', at: const Duration(minutes: 1))];
      final events = ConversationEngine().build(followeePosts: followed, now: base.add(const Duration(minutes: 2)));
      expect(events, hasLength(1));
      expect(events.single.root.id, '1');
    });
  });

  group('TTL とライフサイクル', () {
    ConversationEvent fastEvent() {
      final e = ConversationEvent.root(post('1', 'a', 'ストラトローンチ見てる'));
      e.add(post('2', 'b', 'ストラトローンチいいね', at: const Duration(seconds: 10)));
      e.add(post('3', 'a', 'ストラトローンチ最高', at: const Duration(seconds: 20)));
      return e;
    }

    test('テンポの速い会話は TTL 下限(5分)で沈む', () {
      const s = RelationalSettings();
      final e = fastEvent();
      expect(e.ttl(s), const Duration(minutes: 5));
      expect(e.stateAt(base.add(const Duration(minutes: 4)), s), ConversationState.active);
      expect(e.stateAt(base.add(const Duration(minutes: 6)), s), ConversationState.dormant);
      expect(e.stateAt(base.add(const Duration(minutes: 20)), s), ConversationState.closed);
    });

    test('ゆっくりした会話は間隔に応じて TTL が伸びる(上限 30 分)', () {
      const s = RelationalSettings();
      final e = ConversationEvent.root(post('1', 'a', 'ストラトローンチ見てる'));
      e.add(post('2', 'b', 'ストラトローンチいいね', at: const Duration(minutes: 20)));
      expect(e.ttl(s), const Duration(minutes: 30));
      expect(e.stateAt(base.add(const Duration(minutes: 45)), s), ConversationState.active);
    });

    test('ハードアンカー(URL)一致は候補ウィンドウ外でも再開できる', () {
      final posts = [
        post('1', 'a', '例の記事読んだ https://example.com/stratolaunch-report すごい'),
        post('2', 'b', 'その記事いいよね https://example.com/stratolaunch-report', at: const Duration(minutes: 2)),
        // 40 分後(ウィンドウ 30 分の外)に同じ URL を貼る。
        post('3', 'c', '出遅れたけど読んだ https://example.com/stratolaunch-report', at: const Duration(minutes: 42)),
      ];
      final events = ConversationEngine().buildAll(followeePosts: posts);
      final e = events.firstWhere((ev) => ev.root.id == '1');
      expect(e.posts.map((p) => p.id), ['1', '2', '3']);
    });

    test('lookback を渡すと TTL で沈んだ過去の会話も表示に含める (D-028)', () {
      final posts = [
        post('1', 'a', '同人誌の原稿、落とした……'),
        post('2', 'b', 'えっ、マジ', at: const Duration(seconds: 40)),
      ];
      // 3 時間後: 会話はとっくに CLOSED → 通常表示は空。
      final now = base.add(const Duration(hours: 3));
      expect(ConversationEngine().build(followeePosts: posts, now: now), isEmpty);
      // 遡り表示(4 時間)なら過去の空リプ会話が出る。
      final events = ConversationEngine().build(followeePosts: posts, now: now, lookback: const Duration(hours: 4));
      expect(events, hasLength(1));
      expect(events.single.posts.map((p) => p.id), ['1', '2']);
      // 遡り窓より古ければやはり出ない。
      expect(ConversationEngine().build(followeePosts: posts, now: now, lookback: const Duration(hours: 1)), isEmpty);
    });

    test('markAction で浮上する(自分の関連投稿へのアクション)', () {
      final e = fastEvent();
      final engine = ConversationEngine();
      final at = base.add(const Duration(minutes: 4));
      engine.markAction([e], postKey: e.posts.last.key, at: at);
      expect(e.lastActivityAt, at);
    });
  });

  group('遡り窓ストア (D-028)', () {
    test('引っ張るたびに +30 分、上限 12 時間、リセットで 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = container.read(relationalLookbackProvider.notifier);
      expect(container.read(relationalLookbackProvider), 0);
      expect(store.extend(), isTrue);
      expect(container.read(relationalLookbackProvider), 30);
      store.extend();
      expect(container.read(relationalLookbackProvider), 60);
      for (var i = 0; i < 100; i++) {
        store.extend();
      }
      expect(container.read(relationalLookbackProvider), RelationalLookbackStore.maxMinutes);
      expect(store.extend(), isFalse);
      store.reset();
      expect(container.read(relationalLookbackProvider), 0);
    });
  });

  group('設定の直列化 (D-028)', () {
    test('JSON 往復で重み・τ を含め復元できる', () {
      const s = RelationalSettings(linkBias: 80, tauSeconds: 900, maxTtlMinutes: 45, weights: LinkWeights(content: 0.6, reactiveBonus: 0.25));
      final restored = RelationalSettings.fromJson(s.toJson());
      expect(restored.linkBias, 80);
      expect(restored.tauSeconds, 900);
      expect(restored.maxTtlMinutes, 45);
      expect(restored.weights.content, 0.6);
      expect(restored.weights.reactiveBonus, 0.25);
      // 未指定フィールドは既定値。
      expect(restored.weights.entity, const LinkWeights().entity);
    });

    test('壊れた/欠けた JSON は既定値へフォールバック', () {
      final restored = RelationalSettings.fromJson({'linkBias': 60, 'weights': 'broken'});
      expect(restored.linkBias, 60);
      expect(restored.weights.content, const LinkWeights().content);
      expect(restored.tauSeconds, const RelationalSettings().tauSeconds);
    });
  });

  group('適応しきい値', () {
    test('標本が無い間は既定 0.5 + バイアス', () {
      expect(ConversationEngine().thresholdFor(null), closeTo(0.5, 1e-9));
      expect(ConversationEngine(settings: const RelationalSettings(linkBias: 100)).thresholdFor(null), closeTo(0.75, 1e-9));
      // 0.5 - 0.25 = 0.25 だが下限 0.3 でクランプされる。
      expect(ConversationEngine(settings: const RelationalSettings(linkBias: 50)).thresholdFor(null), closeTo(0.3, 1e-9));
    });

    test('無関係投稿のベストスコア分布からコミュニティ別に適応する', () {
      // 互いに無関係な投稿を大量に流す → ROOT 判定の標本が貯まる。
      final topics = ['カレーの仕込み', '飛行機の写真', '週末の登山計画', '新刊の告知', '水槽の掃除', '自転車の整備', '映画の感想', '編み物の進捗', '盆栽の手入れ', 'ラジオの収録'];
      final posts = [for (var i = 0; i < topics.length; i++) post('$i', 'u$i', '${topics[i]}をしている', at: Duration(minutes: i))];
      final engine = ConversationEngine();
      engine.buildAll(followeePosts: posts);
      final t = engine.thresholdFor(null);
      // 無関係スコアが低い環境ではしきい値が下がる(ただし下限 0.3)。
      expect(t, lessThan(0.5));
      expect(t, greaterThanOrEqualTo(0.3));
    });
  });
}
