import 'dart:convert';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/timeline_temp_fow.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/nodeprog/tl_config_store.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-338: タブの `↓{タイムライン名}` → タイムライン一時変更 FOW(探す + 一時的な構成)。
/// D-339: 「タイムラインをカスタマイズ」のタブを並べ替える(ホームのタブにも効く)。
void main() {
  test('D-339: 並びに載ったタブは、それらが占めていた位置に並びの順で入る(載っていないものは動かない)', () {
    const items = ['tl.social', 'tl.home', 'tl.relational', 'tl.custom:x', 'tl.node:1'];
    expect(applyTlTabOrder(items, (s) => s, const []), items);
    expect(applyTlTabOrder(items, (s) => s, const ['tl.node:1', 'tl.home', 'tl.social']), ['tl.node:1', 'tl.home', 'tl.relational', 'tl.custom:x', 'tl.social']);
    // 並びにあって、ここに無いスコープは無視する。
    expect(applyTlTabOrder(items, (s) => s, const ['tl.bundle', 'tl.home', 'tl.social']), ['tl.home', 'tl.social', 'tl.relational', 'tl.custom:x', 'tl.node:1']);
  });

  test('D-338: 探す語は本文・注意書き・名前・ハンドル・引用で、空白区切りは全部を含むもの', () {
    const acct = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'neko');
    final author = UserSummary(id: 'u1', account: acct, displayName: 'ねこ');
    final p = Post(id: 'p1', account: acct, author: author, createdAt: DateTime(2026), body: '今日は Flutter を書いた', contentWarning: 'ネタバレ');
    expect(timelinePostMatches(p, 'flutter'), isTrue); // 大文字小文字は区別しない
    expect(timelinePostMatches(p, 'ネタバレ'), isTrue);
    expect(timelinePostMatches(p, 'ねこ flutter'), isTrue);
    expect(timelinePostMatches(p, '@neko'.substring(1)), isTrue);
    expect(timelinePostMatches(p, 'flutter いぬ'), isFalse);
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
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

  Finder tab(String label) => find.descendant(of: find.byType(RasqTabs), matching: find.text(label));

  testWidgets('D-338: 選んでいるタブをもう一度押すと一時変更 FOW。探すと TL が絞られ、構成の変更は保存せずに効く', (tester) async {
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
    Finder inFow(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    // 中身は「タイムラインをカスタマイズ」の使い回し + いちばん上に TL 本体から探す欄。
    expect(inFow(find.byKey(const ValueKey('tl.temp.search'))), findsOneWidget);
    expect(inFow(find.text('アルゴリズム')), findsOneWidget);
    expect(inFow(find.text('SNSタイムライン')), findsOneWidget);
    expect(inFow(find.text('タブを追加')), findsNothing); // タブの追加は保存する画面で
    // 関連(ルールベースの別画面)は FOW のタブに無く、ホームでも ↓ が付かない。
    expect(inFow(find.text('関連')), findsNothing);

    // 探す: 読み込んだ投稿を絞る(見出しに件数)。タブには探している印。
    expect(find.text('犬派？猫派？'), findsOneWidget);
    await tester.enterText(inFow(find.byKey(const ValueKey('tl.temp.search'))), '猫派');
    await tester.pumpAndSettle();
    expect(container.read(timelineSearchProvider)['home'], '猫派');
    expect(find.byKey(const ValueKey('tl.search.banner')), findsOneWidget);
    expect(find.textContaining('「猫派」 1 件'), findsOneWidget);
    expect(find.textContaining('Take off'), findsNothing);
    expect(find.descendant(of: find.byType(RasqTabs), matching: find.byKey(const ValueKey('tab.dot'))), findsOneWidget); // 探している印

    // 構成を変える(時系列順を一時的に無効化)→ 一時変更に入り、保存した構成には書かない。
    await tester.tap(inFow(find.byTooltip('アルゴリズムの操作')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
    await tester.pumpAndSettle();
    expect(container.read(tlTemporaryConfigsProvider)['tl.home']?.algorithms.first.enabled, isFalse);
    expect((await container.read(settingsAreaProvider(homeArea).future))['tlcfg'], isNull);
    expect(inFow(find.byKey(const ValueKey('tl.temp.revert'))), findsOneWidget);
    expect(find.descendant(of: find.byType(RasqTabs), matching: find.byKey(const ValueKey('tab.dot'))), findsOneWidget); // 一時変更中の印

    // 元に戻す → 一時変更が外れる。もう一度変えて「この内容で保存」→ 保存した構成になる。
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.revert'))));
    await tester.pumpAndSettle();
    expect(container.read(tlTemporaryConfigsProvider), isEmpty);
    await tester.tap(inFow(find.byTooltip('アルゴリズムの操作')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
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

    // 閉じると探す語は消える(TL は元どおり)。
    await tester.tap(inFow(find.byKey(const ValueKey('tl.temp.close'))));
    await tester.pumpAndSettle();
    expect(manager.contains(timelineTempFowId), isFalse);
    expect(container.read(timelineSearchProvider), isEmpty);
    expect(homeTimelineFowScope.value, isNull);
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
