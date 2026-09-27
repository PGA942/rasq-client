import 'dart:convert';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/home/timeline_search.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/timeline_temp_fow.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/nodeprog/tl_config_store.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart' show FowSpec, OverlayManager;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-338: タブの `↓{タイムライン名}` → タイムライン一時変更 FOW(探す + 一時的な構成)。
/// D-339: 「タイムラインをカスタマイズ」のタブを並べ替える(ホームのタブにも効く)。
/// D-341: 外側タップで stick(検索欄と ✕ だけ)、展開はキャンセル / 決定 + 近似検索チップ、探すは絞らず ↑↓ で飛ぶ。
void main() {
  test('D-339: 並びに載ったタブは、それらが占めていた位置に並びの順で入る(載っていないものは動かない)', () {
    const items = ['tl.social', 'tl.home', 'tl.relational', 'tl.custom:x', 'tl.node:1'];
    expect(applyTlTabOrder(items, (s) => s, const []), items);
    expect(applyTlTabOrder(items, (s) => s, const ['tl.node:1', 'tl.home', 'tl.social']), ['tl.node:1', 'tl.home', 'tl.relational', 'tl.custom:x', 'tl.social']);
    // 並びにあって、ここに無いスコープは無視する。
    expect(applyTlTabOrder(items, (s) => s, const ['tl.bundle', 'tl.home', 'tl.social']), ['tl.home', 'tl.social', 'tl.relational', 'tl.custom:x', 'tl.node:1']);
  });

  test('D-338/D-341: 探す語は本文・注意書き・名前・ハンドル・引用で、空白区切りは全部を含むもの。近似検索はかな / 全角 / 打ち間違い', () {
    const acct = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'neko');
    final author = UserSummary(id: 'u1', account: acct, displayName: 'ねこ');
    final p = Post(id: 'p1', account: acct, author: author, createdAt: DateTime(2026), body: '今日は Flutter を書いた。ネコの写真も', contentWarning: 'ネタバレ');
    expect(timelinePostMatches(p, 'flutter'), isTrue); // 大文字小文字は区別しない
    expect(timelinePostMatches(p, 'ネタバレ'), isTrue);
    expect(timelinePostMatches(p, 'ねこ flutter'), isTrue);
    expect(timelinePostMatches(p, 'neko'), isTrue);
    expect(timelinePostMatches(p, 'flutter いぬ'), isFalse);
    // 近似検索: カタカナ ⇄ ひらがな、全角英字、1 文字の打ち間違い。
    expect(timelinePostMatches(p, 'ねこの写真'), isFalse);
    expect(timelinePostMatches(p, 'ねこの写真', fuzzy: true), isTrue);
    expect(timelinePostMatches(p, 'ＦＬＵＴＴＥＲ', fuzzy: true), isTrue);
    expect(timelinePostMatches(p, 'fluttr', fuzzy: true), isTrue);
    expect(timelinePostMatches(p, 'kotlin', fuzzy: true), isFalse);
    expect(approxContains('abcdef', 'bxd', 1), isTrue);
    expect(approxContains('abcdef', 'xyz', 1), isFalse);
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester, {List<Post> Function(AccountId viewer)? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts ?? MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  /// 40 件の TL。3 件(上から 3 / 21 / 36 番目)にカタカナの「ネコ」。
  List<Post> many(AccountId viewer) {
    final now = DateTime.now();
    final author = UserSummary(id: 'a', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'writer'), displayName: '書く人');
    return [
      for (var i = 0; i < 40; i++)
        Post(id: 'm$i', account: viewer, author: author, createdAt: now.subtract(Duration(minutes: i)), body: {2, 20, 35}.contains(i) ? 'ネコの写真 $i' : 'ふつうの投稿 $i\n二行目\n三行目'),
    ];
  }

  Finder searchField() => find.descendant(of: find.byKey(const ValueKey('tl.temp.search')), matching: find.byType(TextField));
  FowSpec fowSpec(OverlayManager m) => m.entries.firstWhere((e) => e.id == timelineTempFowId).fow!;

  Finder tab(String label) => find.descendant(of: find.byType(RasqTabs), matching: find.text(label));

  testWidgets('D-338/D-341: 選んでいるタブをもう一度押すと一時変更 FOW。展開はキャンセル / 決定、外側タップで stick、✕ で閉じる', (tester) async {
    final container = await pumpHome(tester);
    final manager = container.read(overlayManagerProvider);
    final homeArea = 'nodeprog.${fakeSession().account.key}.tl.home';

    // 別のタブへ移った直後に、同じタブを押し直しても開く(以前は previousIndex が古いままで開かなかった)。
    await tester.tap(tab('フォロー中'));
    await tester.pumpAndSettle();
    expect(manager.contains(timelineTempFowId), isFalse); // 移っただけでは開かない
    expect(find.descendant(of: find.byType(RasqTabs), matching: find.byIcon(Icons.keyboard_arrow_down)), findsOneWidget); // ↓フォロー中
    await tester.tap(tab('フォロー中'));
    await tester.pumpAndSettle();
    expect(manager.contains(timelineTempFowId), isTrue);
    final spec = fowSpec(manager);
    Finder inFow(Finder f) => find.descendant(of: find.byType(TimelineTempFowBody), matching: f);
    // 展開: ヘッダー(キャンセル / 決定)+ 検索欄 + 「タイムラインをカスタマイズ」の使い回し。
    expect(inFow(find.byKey(timelineTempHeaderKey)), findsOneWidget);
    expect(inFow(find.text('キャンセル')), findsOneWidget);
    expect(inFow(find.text('決定')), findsOneWidget);
    expect(inFow(find.text('アルゴリズム')), findsOneWidget);
    expect(inFow(find.text('タブを追加')), findsNothing); // タブの追加は保存する画面で
    expect(inFow(find.text('関連')), findsNothing); // 関連(ルールベースの別画面)は FOW のタブに無い
    // 検索欄は検索画面と同じ作り: ∨ でチップの列、「近似検索」がある。
    expect(inFow(find.text('近似検索')), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('tl.temp.search')), matching: find.byIcon(Icons.keyboard_arrow_down)).first);
    await tester.pumpAndSettle();
    expect(inFow(find.text('近似検索')), findsOneWidget);

    // 探しても TL は絞らない(件数だけ出る)。タブには探している印。
    await tester.enterText(searchField(), '猫派');
    await tester.pumpAndSettle();
    expect(container.read(timelineSearchProvider)['home']?.query, '猫派');
    expect(find.text('1 件'), findsOneWidget);
    expect(find.textContaining('Take off'), findsOneWidget);
    expect(find.descendant(of: find.byType(RasqTabs), matching: find.byKey(const ValueKey('tab.dot'))), findsOneWidget);

    // 構成を変える(時系列順を一時的に無効化)→ キャンセルで巻き戻して stick へ。
    await tester.tap(inFow(find.byTooltip('アルゴリズムの操作')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
    await tester.pumpAndSettle();
    expect(container.read(tlTemporaryConfigsProvider)['tl.home']?.algorithms.first.enabled, isFalse);
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.cancel'))));
    await tester.pumpAndSettle();
    expect(container.read(tlTemporaryConfigsProvider), isEmpty);
    expect(spec.isStick, isTrue);
    // stick = 検索欄と ✕ だけ(探す語は残る)。
    expect(inFow(find.byKey(timelineTempStickKey)), findsOneWidget);
    expect(inFow(find.byKey(timelineTempHeaderKey)), findsNothing);
    expect(inFow(find.text('アルゴリズム')), findsNothing);
    expect(tester.widget<TextField>(searchField()).controller!.text, '猫派');

    // ハンドルのタップで展開 → 変えて決定 → stick(一時変更は残る、保存はしない)。
    await tester.tap(find.bySemanticsLabel('サイズ変更ハンドル').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(spec.isStick, isFalse);
    await tester.tap(inFow(find.byTooltip('アルゴリズムの操作')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
    await tester.pumpAndSettle();
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.confirm'))));
    await tester.pumpAndSettle();
    expect(spec.isStick, isTrue);
    expect(container.read(tlTemporaryConfigsProvider)['tl.home']?.algorithms.first.enabled, isFalse);
    expect((await container.read(settingsAreaProvider(homeArea).future))['tlcfg'], isNull);

    // 空いたところのタップでも展開。「この内容で保存」で保存した構成になる。
    spec.expandStick();
    await tester.pumpAndSettle();
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.save'))));
    await tester.pumpAndSettle();
    expect(container.read(tlTemporaryConfigsProvider), isEmpty);
    final saved = TlConfig.fromJson((jsonDecode((await container.read(settingsAreaProvider(homeArea).future))['tlcfg'] as String) as Map).cast<String, Object?>());
    expect(saved.algorithms.first.enabled, isFalse);

    // FOW のタブを押すと、ホームのタブも付いていく。
    await tester.tap(inFow(find.text('おすすめ')));
    await tester.pumpAndSettle();
    expect(homeTimelineFowScope.value, 'tl.social');
    expect(DefaultTabController.of(tester.element(tab('おすすめ'))).index, 0);

    // 外側(TL)のタップは閉じずに stick へ。stick の間は後ろの TL を触れる。
    await tester.tapAt(const Offset(200, 140));
    await tester.pumpAndSettle();
    expect(manager.contains(timelineTempFowId), isTrue);
    expect(spec.isStick, isTrue);

    // ✕ で閉じると探す語は消える。
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.close'))));
    await tester.pumpAndSettle();
    expect(manager.contains(timelineTempFowId), isFalse);
    expect(container.read(timelineSearchProvider), isEmpty);
    expect(homeTimelineFowScope.value, isNull);
  });

  testWidgets('D-341: ↑↓ で上下の合う投稿へ飛ぶ(まだ作られていない行へも)。飛んだ先は一瞬ホバーの見た目。近似検索でかなの違いも拾う', (tester) async {
    final container = await pumpHome(tester, posts: many);
    final manager = container.read(overlayManagerProvider);
    await tester.tap(tab('フォロー中'));
    await tester.pumpAndSettle();
    await tester.tap(tab('フォロー中'));
    await tester.pumpAndSettle();
    collapseTimelineTempFow(fowSpec(manager)); // stick のまま探す
    await tester.pumpAndSettle();

    await tester.enterText(searchField(), 'ねこの写真');
    await tester.pumpAndSettle();
    expect(find.text('0 件'), findsOneWidget); // かなの違いは近似検索で
    container.read(timelineSearchProvider.notifier).setFuzzy('home', true);
    await tester.pumpAndSettle();
    expect(find.text('3 件'), findsOneWidget);

    Finder row(int i) => find.byKey(ValueKey('tl.row.${many(fakeSession().account)[i].key}'));
    // ↓: 上から順に。36 番目(最初は作られていない行)まで飛べる。TL の中身はそのまま(40 件)。
    for (final (i, label) in [(2, '1 / 3'), (20, '2 / 3'), (35, '3 / 3')]) {
      await tester.tap(find.byKey(const ValueKey('tl.search.next')));
      // まだ作られていない行へは、見当を付けて近づくのに数フレームかかる。
      for (var k = 0; k < 40 && find.descendant(of: row(i), matching: find.byKey(const ValueKey('tl.search.flash'))).evaluate().isEmpty; k++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(row(i), findsOneWidget);
      expect(find.descendant(of: row(i), matching: find.byKey(const ValueKey('tl.search.flash'))), findsOneWidget); // 一瞬ホバーの見た目
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text(label), findsOneWidget);
      final top = tester.getTopLeft(row(i)).dy;
      expect(top, inInclusiveRange(0, tester.view.physicalSize.height / tester.view.devicePixelRatio)); // 見えている
    }
    expect(tester.widget<RasqIconButton>(find.byKey(const ValueKey('tl.search.next'))).onPressed, isNull); // 最後で止まる
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('tl.search.flash')), findsNothing); // 一瞬だけ

    // ↑ で戻る。
    await tester.tap(find.byKey(const ValueKey('tl.search.prev')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(row(20), findsOneWidget);
    expect(container.read(timelineProvider(TimelineKind.home)).value!.posts, hasLength(40));
  });

  testWidgets('D-339: 「タイムラインをカスタマイズ」のタブは並べ替えられ、ホームのタブも同じ順になる', (tester) async {
    final container = await pumpHome(tester);
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);

    // 並べ替えシート: 「おすすめ」を先頭(総合の前)へ。
    await tester.tap(inScreen(find.byTooltip('タブの並べ替え')));
    await tester.pumpAndSettle();
    final sheetRow = find.byKey(const ValueKey('tlconfig.tabs.row.tl.social'));
    expect(sheetRow, findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(sheetRow));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var k = 0; k < 12; k++) {
      await g.moveBy(Offset(0, -tester.getSize(sheetRow).height * 0.15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pumpAndSettle();
    expect(container.read(tlTabOrderProvider).take(2), ['tl.social', 'tl.bundle']);

    // タブ行でも長押しでつかんで動かせる: 「フォロー中」を「おすすめ」の前へ。
    container.read(overlayManagerProvider).close('tlconfig.tabs.reorder');
    await tester.pumpAndSettle();
    final home = inScreen(find.byKey(const ValueKey('tlconfig.tab.tl.home')));
    final social = inScreen(find.byKey(const ValueKey('tlconfig.tab.tl.social')));
    final dx = (tester.getTopLeft(social).dx - 8 - tester.getCenter(home).dx) / 12; // つかむと元の場所から外れるので先に測る
    final g2 = await tester.startGesture(tester.getCenter(home));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var k = 0; k < 12; k++) {
      await g2.moveBy(Offset(dx, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g2.up();
    await tester.pumpAndSettle();
    final order = container.read(tlTabOrderProvider);
    expect(order.indexOf('tl.home'), lessThan(order.indexOf('tl.social')));

    // ホームのタブ: フォロー中 → おすすめ の順(関連は元の位置のまま)。
    Navigator.of(tester.element(find.byType(TimelineConfigScreen))).pop();
    await tester.pumpAndSettle();
    final labels = [for (final e in find.descendant(of: find.byType(RasqTabs), matching: find.byType(Text)).evaluate()) (e.widget as Text).data];
    expect(labels.indexOf('フォロー中'), lessThan(labels.indexOf('おすすめ')));
    expect(labels.last, '関連');
  });
}
