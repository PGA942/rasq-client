import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart' show composerFowId;
import 'package:rasq_client/features/nodeprog/node_canvas.dart';
import 'package:rasq_client/features/nodeprog/node_editor_screen.dart';
import 'package:rasq_client/features/rai/rai_automation.dart';
import 'package:rasq_client/features/rai/rai_chat.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_layout.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_motion.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/rai/rai_stats.dart';
import 'package:rasq_client/features/rai/rai_trace_graph.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/rai/rai_web_search.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_sections.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_rai_embedding_model.dart';
import 'support/fake_rai_llm.dart';
import 'support/fakes.dart';

/// RAi ホームのチャット (D-218): 行の下のリンクカード / 選択肢、背景の RAi(薄さ / 腕 / accident)、
/// 本文の URL 抽出、コントローラーのロール / 1 回だけのクリップ。
/// チャットの行の本文 (D-232: 返事は Text.rich のリッチテキストなので plain text で読む)。
String raiRowText(WidgetTester tester, int row) {
  final rich = find.descendant(of: find.byKey(ValueKey('rai.chat.rich.$row')), matching: find.byType(Text));
  if (rich.evaluate().isNotEmpty) return tester.widgetList<Text>(rich).map((t) => t.data ?? t.textSpan!.toPlainText()).join('\n');
  final t = tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('rai.chat.msg.$row')), matching: find.byType(Text)).first); // 失敗の行は赤の Text
  return t.data ?? t.textSpan!.toPlainText();
}

void main() {
  test('本文の URL を拾う(末尾の句読点 / 括弧は落とす)', () {
    final links = raiLinksIn('詳しくは https://example.com/docs/a を見てください。ほかに https://x.test/p?q=1)、もあります');
    expect(links.map((u) => u.toString()), ['https://example.com/docs/a', 'https://x.test/p?q=1']);
    expect(raiLinksIn('URL なし'), isEmpty);
  });

  test('案内の呼び出しタグ (D-219): [[instruction:<id>|<n>]] を拾い、本文から外す', () {
    final calls = raiToolCallsIn('設定はここです [[instruction:post|2]] ほかに [[ instruction : login-bluesky ]]');
    expect(calls.map((c) => (c.op, c.stopAt)), [('post', 2), ('login-bluesky', null)]);
    expect(raiStripToolCalls('設定はここです [[instruction:post|2]] \nほかに'), '設定はここです\nほかに');
    expect(raiToolCallsIn('タグ無し'), isEmpty);
  });

  test('コントローラー: playOnce は通知して連番が進む、spin(ヨー)は描画側が進める', () {
    final c = RaiMascot3dController();
    var n = 0;
    c.addListener(() => n++);
    c.playOnce('accident');
    expect(c.oneShot, 'accident');
    expect(c.oneShotSeq, 1);
    expect(n, 1);
    c.spinSpeed = 1;
    expect(c.spin, 0);
    c.dispose();
  });

  late FakeRaiLlm llm;
  /// [extraPosts] (D-223): 既定の 1 投稿(p1)に足す分。user.search など複数ユーザーが要る関数のテスト用
  /// (既存テストは渡さないので p1 だけの挙動は変わらない)。
  Future<ProviderContainer> pump(WidgetTester tester, {List<Post> Function(AccountId)? extraPosts, SnsKind kind = SnsKind.misskey, List<String> settingsPages = const [], List<FeedInfo> feeds = const [], RaiWebSearch? webSearch}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    llm = FakeRaiLlm(phase: RaiLlmPhase.ready);
    // rootBundle は loadString の Future をプロセス全体でキャッシュする。前のテストの fake async ゾーンで完了した
    // Future を別のテストから await すると、伝播のマイクロタスクが死んだゾーンに積まれて永遠に返らない
    // (settings.get → settings.set の順で踏んだ)。テストごとに空にする。
    rootBundle.clear();
    // Bluesky 役 (D-227): アカウントの kind も bluesky にする(関数の Bluesky 判定は AccountId.kind)。
    final session = kind == SnsKind.bluesky
        ? AccountSession(account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'tester.bsky.social'), pluginId: fakeSession().pluginId, token: 't', createdAt: DateTime(2026, 8, 22), displayName: 'テスター')
        : fakeSession();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [session.toJson()], 'current': session.account.key}),
    });
    // 投稿を 1 つ(関数 posts.fetch の取得先)。
    final acc = session.account;
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(
        kind: kind,
        settingsPages: settingsPages,
        feeds: feeds,
        posts: (_) => [
          Post(id: 'p1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 14), body: '今日は打ち上げ'),
          ...?extraPosts?.call(acc),
        ],
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), raiLlmProvider.overrideWithValue(llm), raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()), deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)), if (webSearch != null) raiWebSearchProvider.overrideWithValue(webSearch)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.runAsync(() => c.read(raiReferenceProvider.future));
    await tester.pumpAndSettle();
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('空のチャット → 質問 → 行の下にリンクカード、背景の RAi は薄く(0.35)、リンクの行が最新なら腕を上げる', (tester) async {
    final c = await pump(tester);
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.empty')), findsOneWidget);
    expect(c.read(raiChatActiveProvider), isTrue);
    // 背景の RAi(2D 代替)は枠の中心、薄い。
    final layerMascot = find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot));
    expect(layerMascot, findsOneWidget);
    final slot = tester.getRect(find.byKey(const ValueKey('rai.home.mascot')));
    expect(tester.getCenter(layerMascot).dx, closeTo(slot.center.dx, 1));
    expect(tester.widget<Opacity>(find.ancestor(of: layerMascot, matching: find.byType(Opacity)).first).opacity, closeTo(0.28, 0.01));
    // 返事に URL → 行の下にリンクカード。
    llm.reply = 'ヘルプはこちら https://help.example.test/rai を見てください。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'ヘルプはどこ？ zzzz');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.chat.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.user.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.msg.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.link.0.0')), findsOneWidget);
    expect(find.text('help.example.test'), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.speech')), findsNothing); // バーの上には出ない
    // リンクの行が最新 → 腕を上げる(コントローラーの腕)。
    final layerState = tester.state(find.byType(RaiMascotLayer)) as dynamic;
    expect((layerState.controller3d as RaiMascot3dController).arm, RaiArm.right); // ignore: avoid_dynamic_calls, State は private
    // 次の質問(考え中)で腕は下がり、RAi はさらに薄い(0.15)。返事は文字なしにして失敗 → フォールアップも無し → 失敗表示。
    llm.reply = '';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).error, isTrue);
    final msg1 = raiRowText(tester, 1);
    expect(msg1, contains('返事がありませんでした'));
    expect((layerState.controller3d as RaiMascot3dController).arm, RaiArm.none); // ignore: avoid_dynamic_calls, State は private
    expect(tester.widget<Opacity>(find.ancestor(of: layerMascot, matching: find.byType(Opacity)).first).opacity, closeTo(0.28, 0.01));
  });

  test('複合の質問の判定 (D-222)', () {
    expect(RaiController.isCompound('投稿したい'), isFalse);
    expect(RaiController.isCompound('Bluesky でログインして、投稿もしたい'), isTrue);
    expect(RaiController.isCompound('Xepos名義の投稿を取得して、そこからトレンドの刺激性をセットアップしてみてください'), isTrue);
    expect(RaiController.isCompound('通知を切って、DM も止めたい'), isTrue);
    expect(RaiController.isCompound('ログイン'), isFalse);
  });

  testWidgets('曖昧 / 複合な質問 (D-222): 止めずに LLM の返事 + 候補タイル、× で候補を外して記録し答え直す、候補の「この手順で案内」で案内へ', (tester) async {
    final c = await pump(tester);
    // 曖昧な短い質問 → 「どれのことですか」で止めない。
    llm.reply = 'アカウントの操作はいくつかあります。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'アカウント');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    var st = c.read(raiProvider);
    expect(st.choices, isEmpty);
    expect(st.proposal, isNull);
    expect(st.log.first.candidates.length, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('rai.chat.candidates.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.reject.0')), findsOneWidget);
    expect(find.text('どれのことですか？ 上の選択肢から選んでください'), findsNothing);
    final rejected = st.log.first.candidates;
    // × → 除外して記録、答え直し(新しい行の候補には入らない)。
    final before = llm.systems.length;
    await tester.tap(find.byKey(const ValueKey('rai.chat.reject.0')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(llm.systems.length, greaterThan(before));
    expect(c.read(raiMissesProvider).single.query, 'アカウント');
    expect(c.read(raiMissesProvider).single.rejected, rejected);
    expect(await c.read(sessionStorageProvider).read(RaiMissLog.storageKey), contains('アカウント'));
    expect(st.hits.map((h) => h.id).toSet().intersection(rejected.toSet()), isEmpty);
    expect(st.log.first.candidates.toSet().intersection(rejected.toSet()), isEmpty);
    expect(llm.systems.last, contains('違うと言われた操作'));
    expect(find.byKey(const ValueKey('rai.chat.reject.0')), findsNothing); // 古い行の × は消える
    // 複合の質問 → 候補タイル(login-bluesky / post のどちらか)+ 返事。候補の「この手順で案内」で案内へ。
    llm.reply = '順にやりましょう。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'Bluesky でログインして、投稿もしたい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(st.proposal, isNull);
    expect(st.log.first.candidates, isNotEmpty);
    final first = st.log.first.candidates.first;
    expect(find.byKey(ValueKey('rai.chat.candidate.$first')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(ValueKey('rai.chat.candidate.$first')), matching: find.byKey(ValueKey('rai.chat.guide.$first'))));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).mode, RaiMode.instruction);
    expect(c.read(raiProvider).lastOperation, first);
  });

  testWidgets('スキップ → 自動化 (D-226 → D-229): 承認タイル → 関数で進め、足りない本文は選択肢タイル(FOW)で聞き、答えでコンポーザーに下書きが入る', (tester) async {
    final c = await pump(tester);
    llm.reply = '順にやりましょう。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'Bluesky でログインして、投稿もしたい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final first = c.read(raiProvider).log.first.candidates.first;
    expect(find.byKey(ValueKey('rai.chat.skip.$first')), findsOneWidget); // 候補タイルに「スキップ」
    // 「投稿する」: 1 手順目(コンポーザーを開く)は畳まれ、2 手順目 post.create → post.compose(本文は途中で聞く)。
    await c.read(raiProvider.notifier).skip('post');
    await tester.pumpAndSettle();
    var st = c.read(raiProvider);
    expect(st.log.first.approval, 'post');
    expect(st.log.first.text, contains('「投稿する」は案内を出さずに私が関数でやります'));
    expect(st.log.first.text, contains('(関数で代替)'));
    expect(st.log.first.text, contains('→ post.compose'));
    expect(st.log.first.text, contains('本文 は実行の途中で選んでもらいます'));
    expect(find.byKey(const ValueKey('rai.chat.approval.post')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rai.chat.approve.post'))).onPressed, isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('rai.chat.approve.post')));
    await tester.tap(find.byKey(const ValueKey('rai.chat.approve.post')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(st.mode, RaiMode.instruction);
    expect(find.byType(RaiHomeScreen), findsNothing);
    // 本文が質問に無い → 選択肢タイル(入力タイルの上の FOW)で聞く。
    expect(find.byKey(const ValueKey('rai.ask.fow')), findsOneWidget);
    expect(st.bubble, contains('本文 はどれにしますか'));
    expect(c.read(raiProvider.notifier).autoPlan, isNotNull);
    await tester.enterText(find.byKey(const ValueKey('rai.ask.text')), 'いいことがありますように！');
    await tester.tap(find.byKey(const ValueKey('rai.ask.ok')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(find.byKey(const ValueKey('rai.ask.fow')), findsNothing);
    expect(c.read(overlayManagerProvider).contains(composerFowId), isTrue); // コンポーザーが本文つきで開いた(送信はしない)
    expect(find.text('いいことがありますように！'), findsWidgets);
    expect((c.read(currentSnsSessionProvider) as FakeSnsSession).lastDraft, isNull);
    expect(st.busy, isFalse);
    expect(st.bubble, contains('「投稿する」を関数で進めました'));
    final trace = st.log.first.trace;
    expect(trace.length, 2);
    expect(trace.first.status, RaiAutoStatus.skipped);
    expect(trace.last.status, RaiAutoStatus.done);
    expect(find.byKey(const ValueKey('rai.chat.trace.0')), findsNothing); // 工程タイルは RAi ページ(閉じている)で出る
    expect(c.read(raiStatsProvider).automations, 1);
    expect(c.read(raiStatsProvider).instructionsCompleted, 1);
    expect(raiAchievements.firstWhere((a) => a.id == 'auto1').count(c.read(raiStatsProvider)), 1);
    c.read(overlayManagerProvider).close(composerFowId, reason: OverlayCloseReason.discard);
    await tester.pumpAndSettle();
  });

  testWidgets('案内の画面移動 (D-230): 別のタブから始めても手順の画面(タブの根)へ go する(pop で手前に戻るだけだったバグ)', (tester) async {
    final c = await pump(tester);
    final router = c.read(routerProvider);
    c.read(raiProvider.notifier).setMode(RaiMode.instruction); // RAi ページを閉じる
    await tester.pumpAndSettle();
    router.go(Routes.search);
    await tester.pumpAndSettle();
    router.push(Routes.lists); // 検索タブの上にリストページ
    await tester.pumpAndSettle();
    expect(visibleLocationOf(router.routerDelegate.currentConfiguration), startsWith(Routes.lists));
    // endOfFrame を待つのでフレームを回しながら(await すると進まない)。
    unawaited(c.read(raiProvider.notifier).runInstruction('post')); // 1 手順目の画面は /home(タブの根)
    await tester.pumpAndSettle();
    expect(visibleLocationOf(router.routerDelegate.currentConfiguration), Routes.home);
    expect(c.read(raiProvider).stepIndex, 0);
    expect(c.read(raiProvider).bubble, contains('右下の「投稿」'));
  });

  testWidgets('入力タイルの移動 (D-233 → D-236): タイル全体を掴んで上へ → ヘッダーの下に付く、下へ → フッターの上、広い画面ではカラムの幅に合わせてスナップ', (tester) async {
    final c = await pump(tester);
    expect(c.read(raiBarPlacementProvider), const RaiBarPlacement());
    expect(find.byKey(const ValueKey('rai.grip')), findsNothing); // 掴み手は無い
    final before = tester.getRect(find.byType(RaiBar));
    // タイルの右下の余白(入力欄やボタンの外)を掴んで段階的に動かす。
    Future<void> dragBar(Offset by) async {
      final r = tester.getRect(find.byKey(const ValueKey('rai.bar')));
      final gesture = await tester.startGesture(Offset(r.right - 4, r.bottom - 3));
      await gesture.moveBy(by / 4);
      await tester.pump();
      await gesture.moveBy(by * 3 / 4);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }
    await dragBar(const Offset(0, -500));
    var p = c.read(raiBarPlacementProvider);
    expect(p.y, 0);
    final after = tester.getRect(find.byType(RaiBar));
    expect(after.top, lessThan(before.top - 200));
    expect((await c.read(sessionStorageProvider).read('rai.v1'))!, contains('"barY":0'));
    // 半分より下へ → フッターの上に戻る(間には止まらない)。
    await dragBar(Offset(0, (before.top - after.top) * 0.75));
    p = c.read(raiBarPlacementProvider);
    expect(p.y, 1);
    // 広い画面(2 カラム): 右へ動かすと第 3 カラムのスロットへ、幅はカラムに合わせて広がる。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    final col0W = tester.getRect(find.byType(RaiBar)).width;
    expect(col0W, greaterThan(520)); // 第 2 カラムの幅に合わせて広がる
    await dragBar(const Offset(600, 0));
    p = c.read(raiBarPlacementProvider);
    expect(p.column, 1);
    final wide = tester.getRect(find.byType(RaiBar));
    expect(wide.center.dx, greaterThan(700));
    expect(wide.width, lessThanOrEqualTo(col0W)); // 第 3 カラム(狭い)に合わせる
  });

  testWidgets('設定画面の RAi ページ (D-237): 工程グラフの自動表示を切れる', (tester) async {
    final c = await pump(tester);
    rootBundle.clear();
    c.read(routerProvider).push('/settings/dsl/rai');
    await tester.pumpAndSettle();
    expect(find.text('工程グラフを自動で表示'), findsOneWidget);
    await tester.tap(find.text('工程グラフを自動で表示'));
    await tester.pumpAndSettle();
    expect((await c.read(sessionStorageProvider).read('rai.v1'))!, contains('"traceGraphAuto":false'));
    expect(settingsSections['rai']!.rows.first.route, '/settings/dsl/rai');
  });

  testWidgets('入力タイルの幅 (D-237): カラム幅 600px 未満は最大幅、以上は増えた分の 1/2 まで', (tester) async {
    await pump(tester); // 360 幅 → 全幅(左右 8px)
    expect(tester.getRect(find.byType(RaiBar)).width, closeTo(360 - 16, 1));
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    // 840px 未満なので列スロットは無く、画面幅 800 → 600 + 100 = 700 − 16。
    expect(tester.getRect(find.byType(RaiBar)).width, closeTo(700 - 16, 1));
    // 展開行の「質問する」は右端に付く。
    final bar = tester.getRect(find.byType(RaiBar));
    final ask = tester.getRect(find.byKey(const ValueKey('rai.ask')));
    expect(bar.right - ask.right, lessThan(12));
  });

  testWidgets('承認タイルの「やめる」(D-226): 何もせず断りの行だけ、古い行の承認タイルは押せない', (tester) async {
    final c = await pump(tester);
    await c.read(raiProvider.notifier).skip('post');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.chat.decline.post')));
    await tester.pumpAndSettle();
    final st = c.read(raiProvider);
    expect(st.mode, RaiMode.assistant);
    expect(st.log.first.text, contains('「投稿する」は案内で進めるときに'));
    expect(st.log.first.approval, isNull);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rai.chat.approve.post'))).onPressed, isNull);
    expect(c.read(raiStatsProvider).automations, 0);
  });

  testWidgets('自動化の分岐 (D-229、Bluesky): 検索で見つからなければ別の語を聞き、取り込み先は質問から読んでホームの TL に取り込む(しおりも)', (tester) async {
    const feeds = [FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/cats', name: 'Cats', description: 'ねこ')];
    final c = await pump(tester, kind: SnsKind.bluesky, feeds: feeds);
    final session = c.read(currentSnsSessionProvider) as FakeSnsSession;
    session.saved = []; // 保存済みは空から
    llm.reply = '順にやりましょう。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '鳥のカスタムフィードをホームのタイムラインに取り込みたい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    await c.read(raiProvider.notifier).skip('feed-import');
    await tester.pumpAndSettle();
    var st = c.read(raiProvider);
    expect(st.log.first.text, contains('質問から: フィード=鳥、取り込み先=ホームのタイムライン'));
    await tester.tap(find.byKey(const ValueKey('rai.chat.approve.feed-import')));
    await tester.pumpAndSettle();
    // 「鳥」のフィードは無い → 別の語を聞く(止まる / 聞く)。
    expect(find.byKey(const ValueKey('rai.ask.fow')), findsOneWidget);
    expect(c.read(raiProvider).bubble, contains('フィード が見つかりません'));
    await tester.enterText(find.byKey(const ValueKey('rai.ask.text')), 'Cats');
    await tester.tap(find.byKey(const ValueKey('rai.ask.ok')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(find.byKey(const ValueKey('rai.ask.fow')), findsNothing);
    expect(st.bubble, contains('「カスタムフィードを保存してホームのタイムラインに取り込む」を関数で進めました'));
    expect(st.bubble, contains('「Cats」を保存しました'));
    expect(st.bubble, contains('をホームのタイムラインに取り込みました'));
    expect((await session.savedFeeds()).map((f) => f.uri), contains('at://did:plc:x/app.bsky.feed.generator/cats'));
    final acc = c.read(currentAccountSessionProvider)!.account;
    final area = await c.read(settingsAreaProvider('nodeprog.${acc.key}.tl.home').future);
    final cfg = TlConfig.fromJson((jsonDecode(area['tlcfg'] as String) as Map).cast<String, Object?>());
    expect(cfg.sources.map((s) => s.tl), contains('feed:at://did:plc:x/app.bsky.feed.generator/cats'));
    final trace = st.log.first.trace;
    final done = trace.where((s) => s.status == RaiAutoStatus.done).map((s) => s.binding!.call).toList();
    expect(done, contains('feeds.list'));
    expect(done.sublist(done.length - 2), ['feed.save', 'timeline.addFeed']);
    expect(trace.firstWhere((s) => s.fn == 'feeds.search').status, RaiAutoStatus.done); // 聞き直した検索も済
    expect(trace.where((s) => s.status == RaiAutoStatus.skipped), isNotEmpty);
    expect(trace.where((s) => s.status == RaiAutoStatus.asking), isEmpty);
    // インラインのノード表示 (D-234): TL カスタマイズを書いたので、RAi ページの行の下にホームのグラフが 80% で出る。
    expect(RaiController.raiGraphScopeOf(trace), 'tl.home');
    expect(st.log.first.graphScope, 'tl.home');
    c.read(raiProvider.notifier).setMode(RaiMode.assistant);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inline.nodes')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('inline.nodes')), matching: find.byType(NodeCard)), findsWidgets);
    expect(find.text('tl.home · 80%'), findsOneWidget);
    // 工程グラフ (D-236): 3 手順以上なので自動表示。設定を off にすると「グラフビューで表示」ボタンになり、押すと出る。
    expect(find.byKey(const ValueKey('rai.chat.tracegraph')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('rai.chat.tracegraph')), matching: find.byType(NodeCard)).evaluate().length, greaterThanOrEqualTo(3));
    expect(find.textContaining('工程 '), findsWidgets);
    await c.read(settingsAreaProvider(raiSettingsArea).notifier).set('traceGraphAuto', false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.chat.tracegraph')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('rai.chat.tracegraph.show')));
    await tester.tap(find.byKey(const ValueKey('rai.chat.tracegraph.show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.chat.tracegraph')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('inline.nodes.expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inline.nodes.expand')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(NodeEditorScreen), findsOneWidget); // 拡大 → 全画面のエディタ
  });

  test('工程グラフ (D-236): 手順がノードに、順に「工程」の辺で繋がり、左から右に並ぶ', () {
    final trace = [
      const RaiAutoStep(index: 0, text: '歯車を押す', status: RaiAutoStatus.skipped, detail: '関数で代替'),
      RaiAutoStep(index: 1, text: 'フィードを足す', fn: 'timeline.addFeed', binding: raiAutoBindings['timeline.addFeed'], status: RaiAutoStatus.done, detail: '取り込みました'),
      const RaiAutoStep(index: 2, text: '決定を押す', status: RaiAutoStatus.guide, detail: '押す部品は案内で'),
    ];
    final g = raiTraceToGraph(trace);
    expect(g.nodes.length, 3);
    expect(g.edges.length, 2);
    expect(g.nodes.map((n) => n.type).toSet(), {'rai.step'});
    expect(g.nodes[1].title, startsWith('✓ 2.'));
    expect(g.nodes[1].inputs.map((p) => p.value), containsAll(['関数で済', 'timeline.addFeed']));
    expect(g.nodes[0].x, lessThan(g.nodes[1].x));
    expect(g.nodes[1].x, lessThan(g.nodes[2].x));
    expect(g.edges.first.from, 's0');
    expect(g.edges.first.to, 's1');
    expect(raiTraceIcon(g.nodes[2]), Icons.touch_app_outlined);
  });

  testWidgets('自動化の取り込み先 (D-229): 任されていなければ選択肢タイルで聞き、「トレンドの指向性」なら tendency.seed で好きなジャンルに足す', (tester) async {
    const feeds = [FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/birds', name: '鳥', description: 'とり')];
    final c = await pump(tester, kind: SnsKind.bluesky, feeds: feeds, extraPosts: (acc) => [
      for (var i = 0; i < 5; i++) Post(id: 'b$i', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 10 + i), body: '#野鳥 の観察会、カワセミとシジュウカラを見た $i'),
    ]);
    llm.reply = 'やりましょう。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '鳥のフィードを取り込める?');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    await c.read(raiProvider.notifier).skip('feed-import');
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).log.first.text, contains('取り込み先 は実行の途中で選んでもらいます'));
    await tester.tap(find.byKey(const ValueKey('rai.chat.approve.feed-import')));
    await tester.pumpAndSettle();
    // 取り込み先を聞く FOW(自由入力なし、3 択)。
    expect(find.byKey(const ValueKey('rai.ask.fow')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.ask.text')), findsNothing);
    expect(find.text('トレンドの指向性'), findsOneWidget);
    await tester.tap(find.text('トレンドの指向性'));
    await tester.pumpAndSettle();
    final st = c.read(raiProvider);
    expect(st.bubble, contains('をトレンドの指向性(好きなジャンル)に足しました'));
    expect((await c.read(tendencyProfileProvider.future)).genres, isNotEmpty);
    final trace = st.log.first.trace;
    expect(trace.firstWhere((s) => s.fn == 'timeline.importFeed').status, RaiAutoStatus.done);
    expect(trace.firstWhere((s) => s.fn == 'timeline.importFeed').detail, contains('指向性'));
    expect(st.bubble, isNot(contains('ホームのタイムラインに取り込みました'))); // 取り込み先は指向性だけ
  });

  test('計画 (D-229): fn の対応で bound / 手前の UI は畳む / 後ろの部品つきは案内へ、質問からの抽出と「任せる」', () {
    const op = RaiOperation(id: 'x', index: 'テスト');
    final plan = RaiAutoPlan.build(op, const [RaiStep('歯車を押す', tooltip: '設定'), RaiStep('フィードを足す', fn: 'timeline.addFeed', inputs: ['フィード']), RaiStep('決定を押す', label: '決定'), RaiStep('説明だけ')], '「鳥」のフィードをホームの TL へ');
    expect(plan.steps.map((s) => s.status).toList(), [RaiAutoStatus.skipped, RaiAutoStatus.pending, RaiAutoStatus.guide, RaiAutoStatus.skipped]);
    expect(plan.hasBound, isTrue);
    expect(plan.guideFrom, 2);
    expect(plan.inputsNeeded, ['フィード', '取り込み先']);
    expect(plan.entrusted, isFalse);
    expect(raiExtractInput('フィード', '「鳥」のフィードをホームの TL へ'), '鳥');
    expect(raiExtractInput('フィード', '猫のカスタムフィードを取り込む'), '猫');
    expect(raiExtractInput('ワード', 'ネタバレを除外したい'), 'ネタバレ');
    expect(raiExtractInput('本文', '「おはよう」と投稿して'), 'おはよう');
    expect(raiExtractInput('取り込み先', 'フィードをトレンドの指向性へ'), 'トレンドの指向性');
    expect(raiExtractInput('取り込み先', 'タイムラインと指向性の両方'), '両方');
    expect(raiExtractInput('本文', 'よろしく'), isNull);
    expect(raiEntrusted('あとは任せる'), isTrue);
    expect(raiEntrusted('自動でやって'), isTrue);
    expect(raiEntrusted('フィードを取り込む'), isFalse);
    final none = RaiAutoPlan.build(op, const [RaiStep('a', tooltip: 'x')], 'q');
    expect(none.hasBound, isFalse);
    expect(none.describe(), contains('案内(指差し)で進めます'));
  });

  testWidgets('RaiLinkCard はタップで開く(差し替え可)', (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RaiLinkCard(url: Uri.parse('https://example.com/a/b'), onOpen: (u) async => opened = u))));
    await tester.tap(find.byType(RaiLinkCard));
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://example.com/a/b');
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('/a/b'), findsOneWidget);
  });

  testWidgets('LLM の返事の [[instruction:post|1]] は勝手に始めず提案タイルに (D-237)、「この手順で案内」で 1 手順目まで進めて止まる', (tester) async {
    final c = await pump(tester);
    llm.reply = '投稿画面まで案内しますね。 [[instruction:post|1]]';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    var st = c.read(raiProvider);
    expect(st.mode, RaiMode.assistant); // 勝手にインストラクションへ移らない
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(st.steps, isEmpty);
    final answer = st.log.firstWhere((u) => u.text.contains('投稿画面まで案内しますね。'));
    expect(answer.text, contains('案内「投稿する」を 1 手順目まで進める用意をしました'));
    expect(answer.proposal, 'post');
    expect(st.log.any((u) => u.text.contains('[[')), isFalse);
    expect(find.byKey(const ValueKey('rai.chat.guide.post')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.skip.post')), findsOneWidget);
    // タイルから始めると LLM の指定どおり 1 手順目で止まる。
    await tester.tap(find.byKey(const ValueKey('rai.chat.guide.post')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(st.mode, RaiMode.instruction);
    expect(find.byType(RaiHomeScreen), findsNothing);
    expect(st.stopAt, 1);
    expect(st.steps.length, greaterThan(1));
    expect(st.stepIndex, 0);
    expect(st.hasNext, isFalse); // 1 手順目で打ち切り
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('右下の「投稿」'));
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).steps, isEmpty);
    expect(c.read(raiProvider).stopAt, isNull);
  });

  testWidgets('「さらに尋ねる」(D-219 → D-220): 案内を一時停止してアシスタント(RAi ページ)へ、戻ると続きから', (tester) async {
    final c = await pump(tester);
    expect(find.byKey(const ValueKey('rai.askMore')), findsNothing); // 案内していないときは無い
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final steps = c.read(raiProvider).steps;
    expect(steps, isNotEmpty);
    expect(find.byType(RaiHomeScreen), findsNothing);
    expect(find.byKey(const ValueKey('rai.askMore')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.askMore')));
    await tester.pumpAndSettle();
    var st = c.read(raiProvider);
    expect(st.mode, RaiMode.assistant); // モードを切り替えて RAi ページ(チャット)へ
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(st.steps, isEmpty);
    expect(st.target, isNull);
    expect(st.suspended, isNotNull);
    expect(st.suspended!.steps.length, steps.length);
    expect(st.suspended!.stepIndex, 0); // asking は RAi ページを開くときに戻る(バーはチャットの入力欄)
    expect(find.byKey(const ValueKey('rai.chat.suspended')), findsOneWidget);
    expect(find.textContaining('案内を一時停止中(1 / ${steps.length} 手順目)'), findsOneWidget);
    // 「続きへ」(= 前の画面に戻る)→ インストラクションに戻って同じ手順を指す。
    await tester.tap(find.byKey(const ValueKey('rai.chat.resume')));
    await tester.pumpAndSettle();
    st = c.read(raiProvider);
    expect(find.byType(RaiHomeScreen), findsNothing);
    expect(st.mode, RaiMode.instruction);
    expect(st.suspended, isNull);
    expect(st.steps.length, steps.length);
    expect(st.stepIndex, 0);
    expect(st.target, isNotNull);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('右下の「投稿」'));
  });

  test('箇条書きの計画 (D-220): 「- 」「・」「1.」を拾い、最大 4 個 / 40 文字で打ち切る', () {
    expect(RaiController.parsePlan('- 投稿する\n・画像を付ける\n1. 公開範囲を選ぶ\n説明の行\n2) 送信\n- 5 つ目'), ['投稿する', '画像を付ける', '公開範囲を選ぶ', '送信']);
    expect(RaiController.parsePlan('箇条書きなし'), isEmpty);
    expect(RaiController.parsePlan('- ${'あ' * 60}').single.length, 40);
  });

  testWidgets('二段の回答 (D-220): 計画(短い生成)→ 各項目でリファレンスを絞る → 計画と候補を添えて答える', (tester) async {
    final c = await pump(tester);
    llm.replies.addAll(['zzzz の状況', '- 投稿する\n- 画像を付ける\n- a\n- b\n- c', 'できますよ。']);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(llm.systems.length, 3);
    expect(llm.systems[1], RaiController.raiPlanSystem);
    expect(llm.maxTokensLog[1], 96);
    final finalSystem = llm.systems[2]!;
    expect(finalSystem, contains('やること: 投稿する / 画像を付ける / a / b')); // 4 個で打ち切り
    expect(finalSystem, isNot(contains('/ c')));
    expect(finalSystem, contains('post: 投稿する')); // 計画の項目で引いたリファレンス
    expect(finalSystem, contains('[[instruction:'));
    expect(c.read(raiProvider).hits.map((h) => h.id), contains('post'));
    expect(find.descendant(of: find.byKey(const ValueKey('rai.chat.msg.0')), matching: find.text('できますよ。')), findsOneWidget);
  });

  testWidgets('関数呼び出しと再始動予約 (D-221): [[call:posts.fetch]] → 取得 → モデル解放 → 計画 / ダイジェスト / 取得情報を注入して答え直す', (tester) async {
    final c = await pump(tester);
    llm.replies.addAll(['zzzz の状況', '- 打ち上げの投稿を探す', '探してみます。 [[call:posts.fetch|keyword=打ち上げ|limit=1]]', 'ありました: 今日は打ち上げ です。']);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(llm.released, 1); // 再始動予約: 取得が終わってからモデルを解放
    expect(llm.systems.length, 4);
    final restarted = llm.systems.last!;
    expect(restarted, contains('計画: 1. 打ち上げの投稿を探す'));
    expect(restarted, contains('ここまでのダイジェスト: 探してみます。'));
    expect(restarted, contains('取得した情報'));
    expect(restarted, contains('[posts.fetch#1]'));
    expect(restarted, contains('今日は打ち上げ'));
    expect(restarted.length, lessThan(2500));
    final st = c.read(raiProvider);
    expect(st.bubble, 'ありました: 今日は打ち上げ です。');
    expect(st.log.any((u) => u.text.contains('注入してモデルを再始動します')), isTrue);
    expect(st.log.any((u) => u.text.contains('[[call:')), isFalse);
    expect(c.read(raiProvider.notifier).scratch.keys, ['posts.fetch#1']);
  });

  testWidgets('関数: post.create は投稿し、自動化が許可されないアクションは断る、reference.get は詳細を返す', (tester) async {
    final c = await pump(tester);
    llm.replies.addAll(['zzzz の状況', '', '投稿します [[call:post.create|text=RAi から投稿]] [[call:post.action|action=nope|post=p1]]']);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final text = c.read(raiProvider).bubble!;
    expect(text, contains('投稿します'));
    // 送信は自動化不可 (D-237): 投稿せず、代わりにコンポーザーへ下書き。
    expect(text, contains('post.create は自動化不可です'));
    expect(text, contains('代わりに post.compose: ノートの作成の下書きをコンポーザーに入れました'));
    expect((c.read(currentSnsSessionProvider) as FakeSnsSession).lastDraft, isNull);
    expect(c.read(overlayManagerProvider).contains(composerFowId), isTrue);
    expect(find.text('RAi から投稿'), findsWidgets);
    expect(text, contains('アクション nope はありません'));
    expect(llm.released, 0); // 取得系が無いので再始動しない
    c.read(overlayManagerProvider).close(composerFowId, reason: OverlayCloseReason.discard);
    await tester.pumpAndSettle();
    llm.replies.addAll(['zzzz の状況', '', '調べます [[call:reference.get|id=post]]', '投稿するには「投稿」を押します']);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq 2');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(llm.released, 1);
    expect(llm.systems.last, contains('操作「投稿する」(post)'));
    expect(c.read(raiProvider).bubble, '投稿するには「投稿」を押します');
  });

  group('関数の拡充 (D-223): 既存 SNS プラグイン関数のラップ', () {
    testWidgets('timeline.list: TL を取って注入 → 答え直す', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', 'TL を見ます [[call:timeline.list|kind=home|limit=5]]', 'TL はこちらです。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[timeline.list#1]'));
      expect(restarted, contains('TL(home)'));
      expect(restarted, contains('今日は打ち上げ'));
      expect(c.read(raiProvider).bubble, 'TL はこちらです。');
    });

    testWidgets('post.thread: 投稿とその返信を取る', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', 'スレッドを見ます [[call:post.thread|post=p1]]', 'これですね。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[post.thread#1]'));
      expect(restarted, contains('スレッド'));
      expect(restarted, contains('今日は打ち上げ'));
      expect(c.read(raiProvider).bubble, 'これですね。');
    });

    testWidgets('user.search: keyword でユーザーを検索する', (tester) async {
      final c = await pump(tester,
          extraPosts: (acc) => [
                Post(id: 'p2', account: acc, author: UserSummary(id: 'u2', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'yamada'), displayName: '山田'), createdAt: DateTime(2026, 9, 14), body: '別の投稿'),
              ]);
      llm.replies.addAll(['zzzz の状況', '', '探します [[call:user.search|keyword=山田|limit=5]]', '山田さんが見つかりました。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[user.search#1]'));
      expect(restarted, contains('@yamada'));
      expect(restarted, contains('山田'));
      expect(c.read(raiProvider).bubble, '山田さんが見つかりました。');
    });

    testWidgets('notifications.list: 未読件数つきで通知を取る', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', '通知を見ます [[call:notifications.list|kind=all|limit=5]]', '未読が 1 件あります。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[notifications.list#1]'));
      expect(restarted, contains('通知(未読 1 件)'));
      expect(restarted, contains('リアクション'));
      expect(c.read(raiProvider).bubble, '未読が 1 件あります。');
    });

    testWidgets('trends.tags: トレンドのタグを取る', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', 'トレンドを見ます [[call:trends.tags|limit=5]]', '「打上会」が人気です。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[trends.tags#1]'));
      expect(restarted, contains('#打上会(117 人)'));
      expect(c.read(raiProvider).bubble, '「打上会」が人気です。');
    });

    testWidgets('follow.set: フォローする(実行系、取得系ではないので再始動しない)', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', 'フォローします [[call:follow.set|user=u1|on=true]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 0);
      expect(c.read(raiProvider).bubble, contains('follow.set: フォローしました'));
    });

    testWidgets('notifications.read: 通知を既読にする(実行系)', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', '既読にします [[call:notifications.read]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 0);
      expect(c.read(raiProvider).bubble, contains('notifications.read: 通知を既読にしました'));
    });

    testWidgets('settings.get: 設定ページにあるキーの値を読む(ホストの静的ページ)', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', '設定を見ます [[call:settings.get|area=appearance.display|key=textScale]]', '既定の 100% のままです。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[settings.get#1]'));
      expect(restarted, contains('appearance.display.textScale = 100'));
      expect(c.read(raiProvider).bubble, '既定の 100% のままです。');
    });

    testWidgets('settings.set (D-225): 既定設定のパスワード不要なキーを書く、範囲外は断る', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', '大きくします [[call:settings.set|area=appearance.display|key=textScale|value=110]] [[call:settings.set|area=appearance.display|key=textScale|value=200]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 0);
      final bubble = c.read(raiProvider).bubble!;
      expect(bubble, contains('appearance.display.textScale を 110 にしました'));
      expect(bubble, contains('「textScale」に「200」は入れられません'));
      expect(c.read(settingsAreaProvider('appearance.display')).value?['textScale'], 110);
    });

    testWidgets('settings.set (D-225): プラグイン設定は操作禁止タグの無いキーだけ書く', (tester) async {
      final page = jsonEncode({
        'schema': 'rasq.settings-page/1',
        'area': 'timeline',
        'title': 'タイムライン',
        'defaults': {'withRenotes': true, 'purge': false},
        'root': {
          't': 'Column',
          'c': [
            {'t': 'SwitchListTile', 'k': 'withRenotes', 'p': {'title': 'リノートを表示', 'value': r'$.settings.withRenotes'}, 'on': {'change': 'settings.set'}},
            {'t': 'SwitchListTile', 'k': 'purge', 'p': {'title': '全部消す', 'value': r'$.settings.purge', 'tags': ['操作禁止']}, 'on': {'change': 'settings.set'}},
          ],
        },
      });
      final c = await pump(tester, settingsPages: [page]);
      llm.replies.addAll(['zzzz の状況', '', '変えます [[call:settings.set|area=sns.timeline|key=withRenotes|value=off]] [[call:settings.set|area=sns.timeline|key=purge|value=on]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      final bubble = c.read(raiProvider).bubble!;
      expect(bubble, contains('sns.timeline.withRenotes を false にしました'));
      expect(bubble, contains('「purge」は操作禁止タグが付いているので RAi からは書きません'));
      expect(c.read(settingsAreaProvider('sns.timeline')).value, {'withRenotes': false});
    });

    testWidgets('post.reply (D-225): 送らずにコンポーザーへ下書きを入れる(送信はユーザー)', (tester) async {
      final c = await pump(tester);
      final session = c.read(currentSnsSessionProvider) as FakeSnsSession;
      llm.replies.addAll(['zzzz の状況', '', '返信の下書きです [[call:post.reply|post=p1|text=おつかれさまでした！]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(c.read(raiProvider).bubble, contains('post.reply: 返信の下書きをコンポーザーに入れました(送信はしていません)'));
      // コンポーザー(返信 stick)が開き、本文が入っている。投稿はされていない。
      expect(find.text('おつかれさまでした！'), findsOneWidget);
      expect(session.lastDraft, isNull);
      c.read(overlayManagerProvider).close(composerFowId, reason: OverlayCloseReason.discard);
      await tester.pumpAndSettle();
    });

    testWidgets('timeline.addFeed / timeline.excludeWord / feed.save (D-227): ホームの TL にフィードを取り込み、ワードを除外し、フィードを保存から外す', (tester) async {
      const feeds = [FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/sakamoto', name: 'サカモトデイズ', description: '作品のフィード')];
      final c = await pump(tester, kind: SnsKind.bluesky, feeds: feeds);
      llm.replies.addAll(['zzzz の状況', '', 'やります [[call:timeline.addFeed|feed=サカモト]] [[call:timeline.excludeWord|word=ネタバレ]] [[call:feed.save|feed=at://did:plc:x/app.bsky.feed.generator/sakamoto|on=false]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 0);
      final bubble = c.read(raiProvider).bubble!;
      final acc = c.read(currentAccountSessionProvider)!.account;
      expect(acc.kind, SnsKind.bluesky);
      expect(bubble, contains('「サカモトデイズ」($acc)をホームのタイムラインに取り込みました'));
      expect(bubble, contains('「ネタバレ」を含む投稿を home のタイムラインから除外するようにしました'));
      expect(bubble, contains('「サカモトデイズ」を保存から外しました(保存済み 0 件)'));
      final area = await c.read(settingsAreaProvider('nodeprog.${acc.key}.tl.home').future);
      final cfg = TlConfig.fromJson((jsonDecode(area['tlcfg'] as String) as Map).cast<String, Object?>());
      expect(cfg.sources.map((s) => s.tl), contains('feed:at://did:plc:x/app.bsky.feed.generator/sakamoto'));
      expect(cfg.algorithms.where((a) => a.isQueryFilter && a.exclude && a.query == 'ネタバレ').length, 1);
      // Bluesky ではないアカウントでは取り込めない。
      llm.replies.addAll(['zzzz の状況', '', 'もう一度 [[call:timeline.addFeed|feed=サカモト|account=@nobody@x.test]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz rrrr');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(c.read(raiProvider).bubble, contains('Bluesky のアカウントがありません'));
    });

    testWidgets('web.search (D-228): 既定(第一期)では無効で一覧にも出ない', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', '調べます [[call:web.search|q=サカモトデイズ]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.systems.last, isNot(contains('web.search(')));
      expect(llm.released, 0);
      expect(c.read(raiProvider).bubble, contains('web 検索は第一期では無効です'));
    });

    testWidgets('web.search (D-228): 有効(鍵つき)なら一覧に出て、検索して注入 → 答え直す', (tester) async {
      final client = MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode({'web': {'results': [{'title': 'SAKAMOTO DAYS', 'url': 'https://example.test/sd', 'description': '漫画'}]}})), 200));
      final c = await pump(tester, webSearch: RaiWebSearch(token: 'k', enabled: true, client: client, mode: RaiWebMode.web));
      llm.replies.addAll(['zzzz の状況', '', '調べます [[call:web.search|q=サカモトデイズ|count=1]]', '漫画です。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      expect(raiWebSearchUsage, contains('web.search(')); // 有効なら関数一覧に足される行(一覧は候補があるときだけ system に入る)
      expect(llm.systems.last, contains('[web.search#1]'));
      expect(llm.systems.last, contains('SAKAMOTO DAYS — 漫画 [https://example.test/sd]'));
      expect(c.read(raiProvider).bubble, '漫画です。');
    });

    testWidgets('app.actions: 自動化できる投稿アクション一覧を取る(reply は自動化不可)', (tester) async {
      final c = await pump(tester);
      llm.replies.addAll(['zzzz の状況', '', 'アクションを見ます [[call:app.actions]]', 'リノートとリアクションができます。']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 1);
      final restarted = llm.systems.last!;
      expect(restarted, contains('[app.actions#1]'));
      expect(restarted, contains('renote: リノート'));
      expect(restarted, contains('reply: 返信(自動化不可)'));
      expect(c.read(raiProvider).bubble, 'リノートとリアクションができます。');
    });

    testWidgets('非対応の関数呼び出し: UnsupportedError は「この SNS では使えません(関数名)」に日本語化される', (tester) async {
      final c = await pump(tester); // 既定 kind=misskey → savedFeeds は非対応(Bluesky 役のみ実装)
      llm.replies.addAll(['zzzz の状況', '', 'フィードを見ます [[call:feeds.list]]']);
      await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
      await tester.tap(find.byKey(const ValueKey('rai.ask')));
      await tester.pumpAndSettle();
      expect(llm.released, 0); // 非対応(fetched=false)なので再始動しない
      expect(c.read(raiProvider).bubble, contains('この SNS では使えません(feeds.list)'));
    });
  });
}
