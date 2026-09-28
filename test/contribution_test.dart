import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/learning_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/learning/contribution.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_providers.dart';
import 'package:rasq_models/rasq_models.dart';

import 'support/fake_rai_llm.dart';

/// アルゴリズムとコミュニティへの貢献 (D-363): 端末の下見(規則 / 2B モデル)、束の組み立て(公開だけ・許可の書き手だけ・伏せ字)、
/// 判定 → 送信の流れ(Central は MockClient)。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'me');
  UserSummary user(String id, {String? bio}) => UserSummary(id: id, account: AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: id), displayName: id, bio: bio);
  final t0 = DateTime.utc(2026, 9, 28, 12);
  Post post(String id, UserSummary author, int minute, String body, {String? visibility, String? replyToId}) =>
      Post(id: id, account: viewer, author: author, createdAt: t0.add(Duration(minutes: minute)), body: body, visibility: visibility, replyToId: replyToId);

  group('端末の下見', () {
    test('自己紹介の明示の拒否は規則で deny(全角・空白入りも)。何も無ければ規則では決めない', () {
      ContributionAuthor a(String bio) => ContributionAuthor(host: 'h', id: 'x', bio: bio);
      expect(LearnabilityPrescreen.rule(a('写真を撮ります。AI学習禁止'))?.verdict, 'deny');
      expect(LearnabilityPrescreen.rule(a('illustrator ＃ＮｏＡＩ'))?.verdict, 'deny');
      expect(LearnabilityPrescreen.rule(a('Do not train on my posts'))?.verdict, 'deny');
      expect(LearnabilityPrescreen.rule(a('ＡＩ 学習 禁止'))?.verdict, 'deny');
      expect(LearnabilityPrescreen.rule(a('ロケットと星空が好き')), isNull);
    });

    test('2B モデルの答え: JSON を読む(think の前置きも)。読めなければ unsure', () {
      expect(LearnabilityPrescreen.parseHint('<think>..</think>{"verdict":"allow","reason":"拒否なし"}', 'm').verdict, 'allow');
      expect(LearnabilityPrescreen.parseHint('答え: {"verdict":"deny","reason":"断っている"}', 'm').reason, '断っている');
      expect(LearnabilityPrescreen.parseHint('たぶん大丈夫', 'm').verdict, 'unsure');
      expect(LearnabilityPrescreen.parseHint('{"verdict":"maybe"}', 'm').verdict, 'unsure');
    });

    test('端末のモデルが準備できていなければ unsure、準備できていればモデルに聞く', () async {
      final llm = FakeRaiLlm(phase: RaiLlmPhase.notInstalled);
      const a = ContributionAuthor(host: 'h', id: 'x', bio: '星が好き');
      expect((await LearnabilityPrescreen(llm).judge(a)).verdict, 'unsure');
      llm.set(RaiLlmStatus(RaiLlmPhase.ready, modelId: llm.spec.id));
      llm.reply = '{"verdict":"allow","reason":"拒否なし"}';
      final hint = await LearnabilityPrescreen(llm).judge(a);
      expect(hint.verdict, 'allow');
      expect(llm.prompts.single, contains('星が好き'));
    });
  });

  group('束の組み立て', () {
    final alice = user('alice');
    final bob = user('bob');
    final me = UserSummary(id: 'me-id', account: viewer, displayName: 'me');
    ConversationEvent event(List<Post> posts) {
      final e = ConversationEvent.root(posts.first);
      for (final p in posts.skip(1)) {
        e.posts.add(p);
      }
      return e;
    }

    test('公開の投稿だけ、@メンションと URL は伏せ、返信の関係は束の中の番号で', () {
      final c = relationalContributionOf(event([
        post('a1', alice, 0, 'ロケット見てる https://live.example/x @bob@misskey.rasq.test'),
        post('b1', bob, 1, 'すごい!', replyToId: 'a1'),
        post('b2', bob, 2, 'DM です', visibility: 'specified'),
        post('m1', me, 3, '自分の感想'),
      ]))!;
      final posts = (c.data['posts']! as List).cast<Map<String, Object?>>();
      expect(posts.length, 3);
      expect(posts[0]['t'], 'ロケット見てる <url> @user');
      expect(posts[1]['reply'], 0);
      expect(posts[2]['a'], -1, reason: '自分の投稿は書き手の一覧に入れない');
      expect([for (final a in c.authors) a.id], ['alice', 'bob']);
      expect(c.posts, 3);
    });

    test('許可の書き手だけに絞る。自分以外が残らず 2 件未満なら送らない', () {
      final e = event([post('a1', alice, 0, 'ロケット'), post('b1', bob, 1, 'すごい'), post('m1', me, 2, 'いいね')]);
      final only = relationalContributionOf(e, allowed: {'misskey.rasq.test|alice'})!;
      expect([for (final a in only.authors) a.id], ['alice']);
      expect(only.posts, 2);
      expect(relationalContributionOf(event([post('a1', alice, 0, 'ロケット'), post('b1', bob, 1, 'すごい')]), allowed: const {}), isNull);
    });
  });

  test('判定 → 許可の書き手の投稿だけを送る。RAi のやりとりも送る。同意していなければ集めない', () async {
    final calls = <String, Object?>{};
    var granted = true;
    http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 't', 'displayName': 't', 'createdAt': '2026-09-01T00:00:00Z'});
        case 'GET /me/learning':
          return json({'open': true, 'granted': granted, 'eligible': true, 'posts': 0, 'labels': 0});
        case 'POST /me/learning/judge':
          final authors = ((jsonDecode(req.body) as Map)['authors'] as List).cast<Map<String, Object?>>();
          calls['judge'] = authors;
          return json({
            'verdicts': [
              for (final a in authors) {'host': a['host'], 'id': a['id'], 'verdict': a['id'] == 'carol' ? 'deny' : 'allow', 'reason': 'r', 'judgedBy': 'llm'},
            ],
          });
        case 'POST /me/learning/contributions':
          final body = jsonDecode(req.body) as Map;
          calls['contributions:${body['kind']}'] = body['items'];
          return json({'accepted': (body['items'] as List).length, 'duplicate': 0, 'rejected': []});
      }
      return json(<String, Object?>{});
    });
    final alice = user('alice');
    final carol = user('carol', bio: 'AI学習禁止です');
    final bob = user('bob', bio: '宇宙が好き');
    final e = ConversationEvent.root(post('a1', alice, 0, 'ロケット'))
      ..posts.add(post('c1', carol, 1, 'すごい'))
      ..posts.add(post('b1', bob, 2, '見た!'));
    final llm = FakeRaiLlm(phase: RaiLlmPhase.notInstalled);
    final container = ProviderContainer(overrides: [
      centralClientProvider.overrideWithValue(OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => 't')),
      learningProvider.overrideWith(() => _FixedLearning(() => granted)),
      conversationEventsProvider.overrideWithValue(AsyncData([e])),
      raiLlmProvider.overrideWithValue(llm),
    ]);
    addTearDown(container.dispose);
    ContributionController.debounce = const Duration(days: 1);
    container.listen(contributionProvider, (_, _) {});
    await container.read(learningProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(contributionProvider).active, isTrue);
    expect(container.read(contributionProvider).pendingRelational, 1);
    container.read(contributionProvider.notifier).offerRai(query: '下書きはどこ? @x', answer: '投稿フォームの右上です', mode: 'assistant');
    await container.read(contributionProvider.notifier).flush();

    final judged = (calls['judge']! as List).cast<Map<String, Object?>>();
    expect([for (final a in judged) a['id']], ['alice', 'carol', 'bob']);
    // carol は端末の規則で deny の下見が付く。alice / bob はモデル未準備で unsure。
    expect((judged[1]['device']! as Map)['verdict'], 'deny');
    expect((judged[0]['device']! as Map)['verdict'], 'unsure');
    final items = (calls['contributions:relational']! as List).cast<Map<String, Object?>>();
    expect(items.single['authors'], [
      {'host': 'misskey.rasq.test', 'id': 'alice'},
      {'host': 'misskey.rasq.test', 'id': 'bob'},
    ]);
    expect(((items.single['data']! as Map)['posts'] as List).length, 2, reason: 'carol の投稿は抜く');
    final rai = (calls['contributions:rai']! as List).cast<Map<String, Object?>>();
    expect((rai.single['data']! as Map)['q'], '下書きはどこ? @user');
    final s = container.read(contributionProvider);
    expect(s.sentRelational, 1);
    expect(s.sentRai, 1);
    expect(s.verdicts['misskey.rasq.test|carol']?.verdict, 'deny');
    expect(s.pendingRelational, 0);

    // 撤回したら集めない。
    granted = false;
    container.invalidate(learningProvider);
    await container.read(learningProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(contributionProvider).active, isFalse);
    container.read(contributionProvider.notifier).offerRai(query: 'q', answer: 'a', mode: 'assistant');
    expect(container.read(contributionProvider).pendingRai, 0);
  });
}

class _FixedLearning extends LearningNotifier {
  _FixedLearning(this.granted);
  final bool Function() granted;

  @override
  Future<LearningStatus?> build() async => LearningStatus(open: true, granted: granted(), eligible: true);
}
