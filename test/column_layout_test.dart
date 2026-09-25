import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/features/search/search_screen.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/column_layout.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

void main() {
  // ---- 幅の計算 (D-320): 5 種類 × 広い / 狭い画面 --------------------------
  // 広い = 1920px の画面(レール 72 を除いて 1848)、狭い = 840px ちょうど(768)。
  group('splitColumns', () {
    const wide = 1848.0, narrow = 768.0;
    void expectSplit(({double small, double large}) got, double small, double large) {
      expect(got.small, closeTo(small, 0.01));
      expect(got.large, closeTo(large, 0.01));
    }

    test('1:1', () {
      const l = ColumnLayout(split: ColumnSplit.even);
      expectSplit(splitColumns(wide, l), 924, 924);
      expectSplit(splitColumns(narrow, l), 384, 384);
    });

    test('2:3', () {
      const l = ColumnLayout(split: ColumnSplit.twoThree);
      expectSplit(splitColumns(wide, l), 739.2, 1108.8);
      expectSplit(splitColumns(narrow, l), 307.2, 460.8);
    });

    test('3:5', () {
      const l = ColumnLayout(split: ColumnSplit.threeFive);
      expectSplit(splitColumns(wide, l), 693, 1155);
      expectSplit(splitColumns(narrow, l), 288, 480);
    });

    test('小型カラムの幅を固定: 入らなければ半分まで(小型が大型より広くならない)', () {
      expectSplit(splitColumns(wide, const ColumnLayout(split: ColumnSplit.smallFixed, smallPx: 500)), 500, 1348);
      expectSplit(splitColumns(narrow, const ColumnLayout(split: ColumnSplit.smallFixed, smallPx: 500)), 384, 384);
      // 既定(320px)はこれまでの見た目と同じ。
      expectSplit(splitColumns(wide, ColumnLayout.standard), 320, 1528);
      expectSplit(splitColumns(narrow, ColumnLayout.standard), 320, 448);
    });

    test('大型カラムの幅を固定: 小型を最小幅だけ残す / 半分より細くはしない', () {
      expectSplit(splitColumns(wide, const ColumnLayout(split: ColumnSplit.largeFixed, largePx: 1200)), 648, 1200);
      expectSplit(splitColumns(narrow, const ColumnLayout(split: ColumnSplit.largeFixed, largePx: 1200)), kMinColumnWidth.toDouble(), narrow - kMinColumnWidth);
      // 半分より細い大型は半分に広げる。
      expectSplit(splitColumns(wide, const ColumnLayout(split: ColumnSplit.largeFixed, largePx: 400)), 924, 924);
    });

    test('最小幅 2 つ分に足りない幅では、どれも半分ずつ', () {
      for (final s in ColumnSplit.values) {
        final got = splitColumns(500, ColumnLayout(split: s, smallPx: 2000, largePx: 2000));
        expect(got.small, closeTo(250, 0.01), reason: s.name);
        expect(got.large, closeTo(250, 0.01), reason: s.name);
      }
    });

    test('比でも小型は最小幅を守る', () {
      // 3:5 で 700 → 小型 262.5 < 280 なので 280。
      expectSplit(splitColumns(700, const ColumnLayout(split: ColumnSplit.threeFive)), 280, 420);
    });
  });

  group('入力の検証', () {
    test('columnPxError', () {
      expect(columnPxError(''), isNotNull);
      expect(columnPxError('abc'), contains('数字'));
      expect(columnPxError('12.5'), contains('数字'));
      expect(columnPxError('${kMinColumnWidth - 1}'), contains('$kMinColumnWidth'));
      expect(columnPxError('${kMaxColumnWidth + 1}'), contains('$kMaxColumnWidth'));
      expect(columnPxError(' 400 '), isNull);
    });

    test('保存値の読み直し: 壊れた値は既定へ', () {
      expect(ColumnLayout.fromSettings(const {}), ColumnLayout.standard);
      final l = ColumnLayout.fromSettings(const {'split': 'largeFixed', 'smallPx': 10, 'largePx': 900});
      expect(l.split, ColumnSplit.largeFixed);
      expect(l.smallPx, kDefaultSmallColumnPx);
      expect(l.largePx, 900);
      expect(ColumnLayout.fromSettings(const {'split': 'nope'}).split, ColumnLayout.standard.split);
    });
  });

  // ---- シェル --------------------------------------------------------------
  final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  Post post(AccountId viewer) => Post(id: 'p1', account: viewer, author: author, createdAt: DateTime(2026, 9, 25, 10), body: 'カラムの確認');

  Future<ProviderContainer> pumpWide(WidgetTester tester, {Map<String, String> extra = const {}}) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
      ...extra,
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  final col3 = find.byType(ThirdColumnView);
  Finder inCol3(Finder f) => find.descendant(of: col3, matching: f);

  testWidgets('サイドの検索欄から開いた検索結果 (D-320): 第3カラムの < で閉じて検索(小型)へ戻れる', (tester) async {
    await pumpWide(tester);
    double col3Width() => tester.getSize(col3).width;
    expect(col3Width(), closeTo(kSearchHomeColumnWidth, 1));

    // サイドの検索欄(第3カラムの検索)で検索 → 結果が第3カラムに大型で出る。
    await tester.enterText(inCol3(find.byType(TextField)).first, '打上会');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(TrendScreen)), findsOneWidget);
    expect(col3Width(), greaterThan(600));

    // 以前は Navigator.maybePop で、何も起きず大型のまま抜け出せなかった。
    await tester.tap(inCol3(find.byTooltip('トレンドホームへ戻る')));
    await tester.pumpAndSettle();
    expect(find.byType(TrendScreen), findsNothing);
    expect(inCol3(find.byType(SearchScreen)), findsOneWidget);
    expect(col3Width(), closeTo(kSearchHomeColumnWidth, 1));
  });

  testWidgets('第3カラムのページから開いたトレンド (D-320): < で元のページへ戻る(第2カラムへ移した複製も片付く)', (tester) async {
    await pumpWide(tester);
    await tester.tap(find.text('カラムの確認').first);
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(PostDetailScreen)), findsOneWidget);

    tester.element(inCol3(find.byType(PostDetailScreen))).pushTrend('打上会');
    await tester.pumpAndSettle();
    expect(inCol3(find.byType(TrendScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // 投稿は第2カラム(router)へ

    await tester.tap(inCol3(find.byTooltip('トレンドホームへ戻る')));
    await tester.pumpAndSettle();
    expect(find.byType(TrendScreen), findsNothing);
    expect(inCol3(find.byType(PostDetailScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // router 側の複製は消えた
  });

  testWidgets('保存したカラムの比がシェルに出る (D-320)', (tester) async {
    await pumpWide(tester, extra: {'$columnLayoutArea.v1': jsonEncode({'split': 'even'})});
    // 1:1 = (1200 - 72) / 2。
    expect(tester.getSize(col3).width, closeTo(564, 1));
  });

  testWidgets('カラムの幅の画面 (D-320): 選ぶとすぐ反映し、固定幅は正しい値だけ保存する', (tester) async {
    final c = await pumpWide(tester);
    c.read(routerProvider).push(Routes.settingsColumns);
    await tester.pumpAndSettle();
    // 既定は「小型カラムの幅を固定」320px(これまでの見た目)。
    expect(find.textContaining('(既定)'), findsOneWidget);
    expect(find.text('小型 320 px / 大型 808 px'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('columns.split.twoThree')));
    await tester.pumpAndSettle();
    expect(c.read(columnLayoutProvider).split, ColumnSplit.twoThree);
    expect(find.byKey(const ValueKey('columns.px')), findsNothing); // 比のときは入力欄なし

    await tester.tap(find.byKey(const ValueKey('columns.split.largeFixed')));
    await tester.pumpAndSettle();
    final input = find.descendant(of: find.byKey(const ValueKey('columns.px')), matching: find.byType(TextField));
    expect(tester.widget<TextField>(input).controller!.text, '$kDefaultLargeColumnPx');

    await tester.enterText(input, '100');
    await tester.pump();
    expect(find.byKey(const ValueKey('columns.px.error')), findsOneWidget);
    expect(c.read(columnLayoutProvider).largePx, kDefaultLargeColumnPx); // 保存しない

    await tester.enterText(input, '600');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('columns.px.error')), findsNothing);
    expect(c.read(columnLayoutProvider).largePx, 600);
    expect(find.text('小型 528 px / 大型 600 px'), findsOneWidget);

    // 戻ると、シェルの第2カラム(空の第3カラムのとき = 大型)が 600px。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.getSize(col3).width, closeTo(528, 1));
  });
}
