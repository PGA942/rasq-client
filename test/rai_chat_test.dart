import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/rai/rai_chat.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_motion.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/rai/rai_stats.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_rai_embedding_model.dart';
import 'support/fake_rai_llm.dart';
import 'support/fakes.dart';

/// RAi ホームのチャット (D-218): 行の下のリンクカード / 選択肢、背景の RAi(薄さ / 腕 / accident)、
/// 本文の URL 抽出、コントローラーのロール / 1 回だけのクリップ。
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
  Future<ProviderContainer> pump(WidgetTester tester, {List<Post> Function(AccountId)? extraPosts, SnsKind kind = SnsKind.misskey}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    llm = FakeRaiLlm(phase: RaiLlmPhase.ready);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    // 投稿を 1 つ(関数 posts.fetch の取得先)。
    final acc = fakeSession().account;
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(
        kind: kind,
        posts: (_) => [
          Post(id: 'p1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 14), body: '今日は打ち上げ'),
          ...?extraPosts?.call(acc),
        ],
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), raiLlmProvider.overrideWithValue(llm), raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()), deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096))],
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
    expect((layerState.controller3d as RaiMascot3dController).arm, RaiArm.right);
    // 次の質問(考え中)で腕は下がり、RAi はさらに薄い(0.15)。返事は文字なしにして失敗 → フォールアップも無し → 失敗表示。
    llm.reply = '';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).error, isTrue);
    final msg1 = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('rai.chat.msg.1')), matching: find.byType(Text)).first).data!;
    expect(msg1, contains('返事がありませんでした'));
    expect((layerState.controller3d as RaiMascot3dController).arm, RaiArm.none);
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

  testWidgets('RaiLinkCard はタップで開く(差し替え可)', (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RaiLinkCard(url: Uri.parse('https://example.com/a/b'), onOpen: (u) async => opened = u))));
    await tester.tap(find.byType(RaiLinkCard));
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://example.com/a/b');
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('/a/b'), findsOneWidget);
  });

  testWidgets('LLM の返事の [[instruction:post|1]] で案内が始まり 1 手順目で止まる(階層への到達)、チャットの行にはタグの代わりに注記', (tester) async {
    final c = await pump(tester);
    llm.reply = '投稿画面まで案内しますね。 [[instruction:post|1]]';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final st = c.read(raiProvider);
    expect(st.mode, RaiMode.instruction);
    expect(find.byType(RaiHomeScreen), findsNothing); // 案内はインストラクションで(RAi ページは閉じる)
    expect(st.stopAt, 1);
    expect(st.steps.length, greaterThan(1));
    expect(st.stepIndex, 0);
    expect(st.hasNext, isFalse); // 1 手順目で打ち切り
    // 返事の行(案内の手順の発言がその後に積まれる)にはタグの代わりに注記。
    final answer = st.log.firstWhere((u) => u.text.contains('投稿画面まで案内しますね。'));
    expect(answer.text, contains('案内「投稿する」を 1 手順目まで進めます'));
    expect(st.log.any((u) => u.text.contains('[[')), isFalse);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('右下の「投稿」'));
    // ▶ → 続きには進まず終わる(手順は捨てられる)。
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
    expect(text, contains('post.create: 投稿しました'));
    expect(text, contains('アクション nope はありません'));
    expect(llm.released, 0); // 取得系が無いので再始動しない
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
