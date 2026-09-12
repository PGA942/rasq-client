import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/login/login_screen.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_spline.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RAi (D-179): バー(トグル / 質問する)、インストラクションの参照、部品へのスプライン移動、
/// アシスタントは中央固定、RAi ホーム。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  group('スプライン (RaiPath)', () {
    test('端点は from / to、途中は直線から膨らみ、長さは距離以上', () {
      final p = RaiPath(from: const Offset(0, 0), to: const Offset(100, 0), bulge: 0.25);
      expect(p.at(0), const Offset(0, 0));
      expect((p.at(1) - const Offset(100, 0)).distance, lessThan(0.001));
      expect(p.at(0.5).dy.abs(), greaterThan(5)); // 直線(y=0)から離れる
      expect(p.length, greaterThan(p.distance));
      // 膨らみ 0・行き過ぎ 0 なら直線。
      final line = RaiPath(from: const Offset(0, 0), to: const Offset(100, 0), bulge: 0, overshoot: 0);
      expect(line.at(0.5).dy.abs(), lessThan(0.001));
      expect(line.at(0.5).dx, inExclusiveRange(0, 100)); // 3 次ベジエは等速ではない
    });
    test('距離 0 なら動かない', () {
      final p = RaiPath(from: const Offset(3, 3), to: const Offset(3, 3));
      expect(p.at(0.5), const Offset(3, 3));
    });
  });

  group('参照 (matchInstruction)', () {
    test('キーワードで引ける / 知らない質問は null', () {
      expect(matchInstruction('Blueskyでログインしたい')?.instruction.id, 'login-bluesky');
      expect(matchInstruction('つぶやくには？')?.instruction.id, 'post');
      expect(matchInstruction('下書きはどこ')?.instruction.id, 'draft');
      expect(matchInstruction('zzzz qqqq'), isNull);
    });
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('サイドバー → RAi ホーム(バーはアシスタント)→ トグルでインストラクション → 質問 → 部品へ移動して指差す → 次へ / 閉じる', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(find.text('マクロとか、お任せください！'), findsOneWidget);
    // バー: アシスタントモードで開く(クラウドモデルのチップ)。
    expect(find.text('困ったとき、お手伝いします！'), findsOneWidget);
    expect(find.text(RaiMode.assistant.modelName), findsOneWidget);
    expect(c.read(raiProvider).mode, RaiMode.assistant);
    // 上段はそのまま入力欄(ヒント = 困ったとき…、D-180)。「質問する」で送信。
    // アシスタントの返事は中央固定(RAi が画面中央)。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '何かできる？');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('第二期'));
    final screen = tester.getSize(find.byType(RasqApp));
    final overlayMascot = find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot));
    expect(tester.getCenter(overlayMascot).dx, closeTo(screen.width / 2, 1));
    // トグル → インストラクション(端末内モデル)。返事は消える。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).mode, RaiMode.instruction);
    expect(find.text(RaiMode.instruction.modelName), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.bubble')), findsNothing);
    // 質問「投稿したい」→ ホームへ移動 → 「投稿」ボタンの脇に RAi + 吹き出し + ハイライト。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsNothing); // ディープリンクでホームへ
    expect(find.text('右下の「投稿」でコンポーザーが開きます'), findsOneWidget);
    final target = c.read(raiProvider).target!;
    final fab = tester.getRect(find.byTooltip('投稿'));
    expect(target.overlaps(fab), isTrue);
    final mascotRect = tester.getRect(overlayMascot);
    expect((mascotRect.center - fab.center).distance, lessThan(200)); // ボタンの脇(下の方の部品は上から)
    expect(tester.getRect(find.byKey(const ValueKey('rai.toggle'))).top, lessThan(screen.height / 2)); // バーはボタンを隠さないよう上へ
    expect(mascotRect.overlaps(fab), isFalse); // 被らない
    // 次へ → 2 手順目(部品が無ければ中央)、閉じる → RAi は消えるがバーは残る。
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本文を書いて'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.bubble')), findsNothing);
    expect(find.byKey(const ValueKey('rai.toggle')), findsOneWidget);
    // 履歴が RAi ホームに並ぶ。
    expect(c.read(raiProvider).history.first, '投稿したい');
    // 「Blueskyでログイン」→ ログイン画面へ遷移してラベルのボタンを指差す。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'Blueskyでログインしたい');
    await tester.testTextInput.receiveAction(TextInputAction.send); // キーボードの送信でも
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('「Blueskyでログイン」をクリックしてください'), findsOneWidget);
    expect(c.read(raiProvider).target!.overlaps(tester.getRect(find.text('Blueskyでログイン'))), isTrue);
    // バーの ✕ で全部消える。
    await tester.tap(find.byTooltip('RAi を閉じる'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.toggle')), findsNothing);
    expect(find.byType(RaiMascot), findsNothing);
  });

  testWidgets('ログイン画面の「Raiのインストラクチャ」→ 入力欄付きのバー(インストラクション)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({});
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    if (find.byType(LoginScreen).evaluate().isEmpty) {
      // オンボーディング等が先に出る構成なら、ログインへ。
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).go('/login');
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Raiのインストラクチャ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.input')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rai.input'))).focusNode?.hasFocus, isTrue); // 入力欄にフォーカス
    expect(find.text(RaiMode.instruction.modelName), findsOneWidget);
  });
}
