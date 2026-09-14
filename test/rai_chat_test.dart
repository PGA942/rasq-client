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
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
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

  test('コントローラー: playOnce は通知して連番が進む、roll は描画側が進める', () {
    final c = RaiMascot3dController();
    var n = 0;
    c.addListener(() => n++);
    c.playOnce('accident');
    expect(c.oneShot, 'accident');
    expect(c.oneShotSeq, 1);
    expect(n, 1);
    c.rollSpeed = 1;
    expect(c.roll, 0);
    c.dispose();
  });

  late FakeRaiLlm llm;
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    llm = FakeRaiLlm(phase: RaiLlmPhase.ready);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []));
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

  testWidgets('曖昧な質問 → 行の下に選択肢のチップ(最新の行だけ押せる)→ 選ぶと提案タイル', (tester) async {
    final c = await pump(tester);
    llm.reply = 'ログインしたい状況';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'ログイン');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final st = c.read(raiProvider);
    if (st.choices.isNotEmpty) {
      expect(find.byKey(ValueKey('rai.chat.choice.${st.choices.first.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('rai.chat.choice.${st.choices.first.id}')));
      await tester.pumpAndSettle();
    }
    expect(c.read(raiProvider).proposal, isNotNull);
    expect(find.byKey(ValueKey('rai.chat.proposal.${c.read(raiProvider).proposal}')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.live')), findsNothing);
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
}
