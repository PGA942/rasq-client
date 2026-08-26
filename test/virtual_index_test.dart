import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/clips/virtual_index.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
final base = DateTime(2026, 8, 27, 12);

Post post(String id, String author, String body, {Duration at = Duration.zero}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: base.add(at),
      body: body,
    );

void main() {
  group('クリップの仮想目次 (D-036)', () {
    test('共通ハッシュタグ > エンティティの優先でグループ化し、残りは「話題を特定できない投稿」', () {
      final posts = [
        post('1', 'a', '#京都旅行 の宿を探している'),
        post('2', 'b', '#京都旅行 町家の旅館いいな', at: const Duration(days: 1)),
        post('3', 'c', '#京都旅行 駅近ホテルも捨てがたい', at: const Duration(days: 2)),
        post('4', 'd', '猫カフェのラテアート可愛い', at: const Duration(days: 3)),
        post('5', 'e', '猫カフェ行きたい', at: const Duration(days: 4)),
        post('6', 'f', 'ぜんぜん関係ない独り言', at: const Duration(days: 5)),
      ];
      final index = buildClipIndex(posts);
      expect(index.map((e) => e.label), ['#京都旅行', '猫カフェ', fallbackIndexLabel]);
      expect(index[0].labelSource, 'hashtag');
      expect(index[0].count, 3);
      expect(index[1].count, 2);
      expect(index[2].count, 1);
      expect(index[2].confidence, lessThan(0.5));
      // 代表投稿(根拠)は開始候補を含む 2〜3 件。
      expect(index[0].representativeKeys, isNotEmpty);
      expect(index[0].representativeKeys.length, lessThanOrEqualTo(3));
      // 元の並びは変えない: postKeys は参照のみ。
      expect(index[0].postKeys, containsAll([posts[0].key, posts[1].key, posts[2].key]));
    });

    test('URL ドメインが強いアンカーとしてラベルになる', () {
      final posts = [
        post('1', 'a', 'この記事すごい https://stratolaunch.example/report'),
        post('2', 'b', '読んだ? https://stratolaunch.example/report のやつ', at: const Duration(hours: 1)),
      ];
      final index = buildClipIndex(posts);
      expect(index.single.label, 'stratolaunch.example');
      expect(index.single.labelSource, 'url');
    });

    test('大きい章は第 2 階層に分かれる(最大 2 階層)', () {
      final posts = [
        for (var i = 0; i < 3; i++) post('r$i', 'u$i', '#夏イベント ロケットの展示すごい', at: Duration(hours: i)),
        for (var i = 0; i < 3; i++) post('f$i', 'v$i', '#夏イベント 屋台のやきそば美味しい', at: Duration(hours: 10 + i)),
      ];
      final index = buildClipIndex(posts);
      final top = index.first;
      expect(top.label, '#夏イベント');
      expect(top.count, 6);
      expect(top.children, isNotEmpty);
      for (final c in top.children) {
        expect(c.children, isEmpty); // 3 階層は作らない
      }
    });

    test('共有語が無ければ無理に命名しない(全部 fallback)', () {
      final posts = [
        post('1', 'a', '眠い'),
        post('2', 'b', '腹へった', at: const Duration(hours: 1)),
      ];
      final index = buildClipIndex(posts);
      expect(index.single.label, fallbackIndexLabel);
    });
  });

  group('会話イベント → 目次 (リスト/TL 用)', () {
    test('共有エンティティがあれば命名、無ければ「関連投稿 N件」の仮ラベル', () {
      final named = ConversationEvent.root(post('1', 'a', 'ストラトローンチの配信見てる'));
      named.add(post('2', 'b', 'ストラトローンチ、翼が長い', at: const Duration(minutes: 1)));
      final unnamed = ConversationEvent.root(post('3', 'c', '原稿落とした……', at: const Duration(minutes: 2)));
      unnamed.add(post('4', 'd', 'えっ、マジ', at: const Duration(minutes: 3)));

      final index = indexFromConversationEvents([named, unnamed], now: base.add(const Duration(minutes: 4)));
      expect(index, hasLength(2));
      final labels = index.map((e) => e.label).toList();
      expect(labels, contains('ストラトローンチ'));
      expect(labels, contains('関連投稿 2件'));
      final fallback = index.firstWhere((e) => e.labelSource == 'fallback');
      expect(fallback.confidence, lessThan(0.5));
      // 進行中(ACTIVE)が先頭に来る。
      expect(index.first.state, IndexEntryState.active);
    });
  });
}
