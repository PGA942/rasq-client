import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rasq_client/features/search/search_filter.dart';
import 'package:rasq_client/features/search/search_ranker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

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

    test('computeSearchMlScores: GLiNER 抽出 → クエリ×2 / ジャンル×1 の加点', () async {
      final manifest = MlModelManifest.fromJson({
        'id': 'rasq.official.search/gliner-ner',
        'version': '0.1.0',
        'task': 'custom',
        'io': {'input': 'texts', 'output': 'tensors'},
        'runtimes': {
          'server': {'engine': 'triton', 'model': 'gliner'},
        },
      });
      final gateway = MlGateway(
        manifests: {manifest.id: manifest},
        triton: TritonExecutor(
          baseUrl: Uri.parse('https://ml.example'),
          post: (url, {headers, body}) async {
            final out = jsonEncode({
              'entities': [
                [
                  {'text': 'ストラトローンチ', 'label': 'ロケット', 'score': 0.9},
                  {'text': '打上会', 'label': '宇宙', 'score': 0.5},
                ],
                <Object>[],
              ],
            });
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'outputs': [
                  {'name': 'OUTPUT', 'datatype': 'BYTES', 'shape': [1], 'data': [out]},
                ],
              })),
              200,
            );
          },
        ),
      );
      final a = post('a', 'ストラトローンチの話');
      final b = post('b', '無関係');
      final scores = await computeSearchMlScores(gateway, [a, b], query: 'ロケット', genres: {'宇宙'});
      expect(scores[a.key], closeTo(0.9 * 2 + 0.5, 1e-9));
      expect(scores.containsKey(b.key), isFalse);
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

  group('RasqExpandableSearchBox (一体型展開タイル)', () {
    Widget wrap(Widget child) => MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: Padding(padding: const EdgeInsets.all(8), child: child)));

    List<RasqFilterChipItem> sortPeriod(SearchFilterState filter) => buildSortPeriodChips(filter: filter, onSortTap: (_) {}, onPeriodTap: (_) {});

    testWidgets('折りたたみ時はフィルタ非表示、展開でタイル内にチップとジャンルが入る', (tester) async {
      const filter = SearchFilterState(genres: {'宇宙'});
      final genres = buildGenreChips(filter: filter, genreCandidates: const ['映画化', 'サラダボール', 'ロケット発射'], onGenreToggle: (_) {});
      await tester.pumpWidget(wrap(RasqExpandableSearchBox(expanded: false, filterChips: sortPeriod(filter), genreChips: genres)));
      expect(find.text('関連順'), findsNothing);

      await tester.pumpWidget(wrap(RasqExpandableSearchBox(expanded: true, filterChips: sortPeriod(filter), genreChips: genres, onReset: () {})));
      await tester.pumpAndSettle();
      expect(find.text('関連順'), findsOneWidget);
      expect(find.text('期間'), findsOneWidget);
      // 選択済み『宇宙』優先で入れ子ジャンルボタン(上限 maxGenreChips)。
      expect(find.text('#宇宙'), findsOneWidget);
      expect(find.text('#映画化'), findsOneWidget);
      expect(find.text('リセット'), findsOneWidget);
    });

    testWidgets('ジャンルトグル・リセット・∨トグルが届く', (tester) async {
      String? toggled;
      var reset = 0;
      var chevron = 0;
      final genres = buildGenreChips(filter: SearchFilterState.initial, genreCandidates: const ['宇宙'], onGenreToggle: (g) => toggled = g);
      await tester.pumpWidget(wrap(RasqExpandableSearchBox(
        expanded: true,
        filterChips: sortPeriod(SearchFilterState.initial),
        genreChips: genres,
        onReset: () => reset++,
        onDropdownTap: () => chevron++,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#宇宙'));
      expect(toggled, '宇宙');
      await tester.tap(find.text('リセット'));
      expect(reset, 1);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
      expect(chevron, 1);
    });

    test('buildGenreChips は選択済み優先で maxGenreChips 個まで', () {
      final chips = buildGenreChips(
        filter: const SearchFilterState(genres: {'g9'}),
        genreCandidates: const ['g1', 'g2', 'g3', 'g4', 'g5', 'g6', 'g7'],
        onGenreToggle: (_) {},
      );
      expect(chips, hasLength(maxGenreChips));
      expect(chips.first.label, '#g9');
      expect(chips.first.selected, isTrue);
    });
  });
}
