import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/search/search_filter.dart';
import 'package:rasq_client/features/search/search_ranker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
final now = DateTime(2026, 8, 25, 12);

Post post(String id, String body, {int reactions = 0, Duration age = Duration.zero, String author = 'x'}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: now.subtract(age),
      body: body,
      reactions: {'👍': reactions},
    );

void main() {
  group('SearchRanker (関連順, ルールベース段)', () {
    const ranker = SearchRanker();

    test('hashtag > body > author match, reactions and recency break ties', () {
      final posts = [
        post('a', '関係ない話', age: const Duration(hours: 1)),
        post('b', 'ロケットの話', age: const Duration(hours: 1)),
        post('c', '#ロケット 打ち上げ', age: const Duration(hours: 1)),
        post('d', 'ロケットの話', reactions: 100, age: const Duration(hours: 1)),
      ];
      final ranked = ranker.rank(posts, query: 'ロケット', now: now);
      expect(ranked.map((p) => p.id).toList(), ['c', 'd', 'b', 'a']);
    });

    test('mlScore (GLiNER/SigLIP 接続点) が加点される', () {
      final a = post('a', '本文A', age: const Duration(hours: 1));
      final b = post('b', '本文B', age: const Duration(hours: 1));
      final ranked = SearchRanker(mlScore: {b.key: 5.0}).rank([a, b], query: 'ロケット', now: now);
      expect(ranked.first.id, 'b');
    });
  });

  group('applySearchFilter', () {
    final posts = [
      post('new', '#宇宙 きょうの話', age: const Duration(hours: 2), reactions: 1),
      post('old', '宇宙の古い話', age: const Duration(days: 10), reactions: 50),
      post('other', '無関係', age: const Duration(hours: 3), reactions: 9),
    ];

    test('期間フィルタ + 新しい順', () {
      final out = applySearchFilter(posts, const SearchFilterState(period: SearchPeriod.week, sort: SearchSort.newest), query: '宇宙', now: now);
      expect(out.map((p) => p.id).toList(), ['new', 'other']);
    });

    test('ジャンル絞り込み + リアクション多い順', () {
      final out = applySearchFilter(posts, const SearchFilterState(genres: {'宇宙'}, sort: SearchSort.reactions), query: '', now: now);
      expect(out.map((p) => p.id).toList(), ['old', 'new']);
    });

    test('dirty 判定', () {
      expect(SearchFilterState.initial.dirty, isFalse);
      expect(const SearchFilterState(sort: SearchSort.newest).dirty, isTrue);
      expect(SearchFilterState.initial.toggleGenre('a').dirty, isTrue);
    });
  });

  group('RasqSearchFilterBar', () {
    Widget wrap(Widget child) => MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: child));

    testWidgets('visible=false は畳まれ、true でチップが並ぶ(ジャンル直置きは3個まで)', (tester) async {
      final chips = buildSearchFilterChips(
        filter: const SearchFilterState(genres: {'宇宙'}),
        genreCandidates: const ['映画化', 'サラダボール', 'ロケット発射'],
        onSortTap: (_) {},
        onPeriodTap: (_) {},
        onGenreToggle: (_) {},
      );
      await tester.pumpWidget(wrap(RasqSearchFilterBar(visible: false, chips: chips)));
      expect(find.text('関連順'), findsNothing);

      await tester.pumpWidget(wrap(RasqSearchFilterBar(visible: true, chips: chips, onReset: () {})));
      await tester.pumpAndSettle();
      expect(find.text('関連順'), findsOneWidget);
      expect(find.text('期間'), findsOneWidget);
      // 選択済み『宇宙』優先 + 候補2つ = 直置き3個、4個目は出ない。
      expect(find.text('#宇宙'), findsOneWidget);
      expect(find.text('#映画化'), findsOneWidget);
      expect(find.text('#サラダボール'), findsOneWidget);
      expect(find.text('#ロケット発射'), findsNothing);
      expect(find.text('リセット'), findsOneWidget);
    });

    testWidgets('ジャンルボタンのトグルとリセットが届く', (tester) async {
      String? toggled;
      var reset = 0;
      final chips = buildSearchFilterChips(
        filter: SearchFilterState.initial,
        genreCandidates: const ['宇宙'],
        onSortTap: (_) {},
        onPeriodTap: (_) {},
        onGenreToggle: (g) => toggled = g,
      );
      await tester.pumpWidget(wrap(RasqSearchFilterBar(visible: true, chips: chips, onReset: () => reset++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#宇宙'));
      expect(toggled, '宇宙');
      await tester.tap(find.text('リセット'));
      expect(reset, 1);
    });
  });
}
