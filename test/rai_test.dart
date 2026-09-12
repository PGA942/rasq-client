import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/login/login_screen.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_llm_device.dart';
import 'package:rasq_client/features/rai/rai_models_fow.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_spline.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_rai_llm.dart';
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

  test('発言の行割り (splitSpeechLines)', () {
    expect(splitSpeechLines('右下の「投稿」で開きます。本文を書いて送ります！\n添付は下から'), ['右下の「投稿」で開きます。', '本文を書いて送ります！', '添付は下から']);
    expect(splitSpeechLines(''), isEmpty);
  });

  test('<think> のフィルター (ThinkFilter): トークンをまたぐタグも落とす', () {
    final f = ThinkFilter();
    final out = StringBuffer();
    for (final t in ['<thi', 'nk>', 'ぐるぐる', '考える', '</thi', 'nk>\n\n', 'こんにちは', '！']) {
      out.write(f.push(t));
    }
    expect(out.toString(), 'こんにちは！');
    final g = ThinkFilter();
    expect(g.push('思考なし。') + g.push('<') + g.push('b>太字'), '思考なし。<b>太字');
  });

  test('メモリの判定 (raiMemoryVerdict)', () {
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 8192), RaiRamVerdict.ok); // 3.3 GB 必要 / 4.9 GB まで余裕
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 5000), RaiRamVerdict.tight);
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 3000), RaiRamVerdict.no);
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: null), RaiRamVerdict.unknown);
  });

  group('参照 (matchInstruction)', () {
    test('キーワードで引ける / 知らない質問は null', () {
      expect(matchInstruction('Blueskyでログインしたい')?.instruction.id, 'login-bluesky');
      expect(matchInstruction('つぶやくには？')?.instruction.id, 'post');
      expect(matchInstruction('下書きはどこ')?.instruction.id, 'draft');
      expect(matchInstruction('zzzz qqqq'), isNull);
    });
  });

  late FakeRaiLlm llm;
  setUp(() => llm = FakeRaiLlm());
  ({int? totalMb, int? availableMb}) ram = (totalMb: 8192, availableMb: 4096);

  /// FOW の下端は RAi バーに隠れるので、対象がその上に来るまで少しだけ送る。
  Future<void> clearOfBar(WidgetTester tester, Finder scrollable, Finder target) async {
    final limit = tester.getSize(find.byType(RasqApp)).height - 170;
    final bottom = tester.getRect(target).bottom;
    if (bottom > limit) {
      await tester.drag(scrollable, Offset(0, -(bottom - limit) - 8));
      await tester.pumpAndSettle();
    }
  }

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), raiLlmProvider.overrideWithValue(llm), deviceRamReaderProvider.overrideWithValue(() async => ram)], child: const RasqApp()));
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
    // アシスタント (D-181): 端末内モデルが未ダウンロード → フォールアップ(サーバー無し)も失敗 → 失敗表示、
    // 端末内モデルのメモリは解放。返事は中央固定(RAi が画面中央)。
    expect(find.text('未DL'), findsOneWidget); // チップの注記
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '何かできる？');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    // 発言は入力ウィジェットの上に 1 行ずつ (D-182): 1 行目 = 端末内モデルの理由、▶ で 2 行目 = フォールアップの理由。
    final failed = c.read(raiProvider).bubble!;
    expect(failed, contains('まだダウンロードされていません'));
    expect(failed, contains('フォールアップ先(サーバー側)が未接続です'));
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('まだダウンロードされていません'));
    expect(tester.getRect(find.byKey(const ValueKey('rai.speech'))).bottom, lessThan(tester.getRect(find.byKey(const ValueKey('rai.input'))).top)); // バーの上
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('フォールアップ先'));
    expect(find.byKey(const ValueKey('rai.ring.error')), findsOneWidget);
    expect(llm.released, 1);
    // 履歴ボタン (D-187): 入力ウィジェットが上に広がって発言の履歴(全文 + コピー)が出る。
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    final barTopBefore = tester.getRect(find.byType(RaiBar)).top;
    await tester.tap(find.byKey(const ValueKey('rai.history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.history.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.history.0')), findsOneWidget);
    expect(tester.getRect(find.byType(RaiBar)).top, lessThan(barTopBefore)); // 上方向に拡張
    expect(tester.getRect(find.byType(RaiBar)).bottom, closeTo(tester.getRect(find.byType(RaiBar)).bottom, 0.1));
    await tester.tap(find.byKey(const ValueKey('rai.history.copy.0')));
    await tester.pumpAndSettle();
    expect(copied, contains('フォールアップ先(サーバー側)が未接続です'));
    await tester.tap(find.byKey(const ValueKey('rai.history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.history.list')), findsNothing);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    final screen = tester.getSize(find.byType(RasqApp));
    final overlayMascot = find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot));
    expect(tester.getCenter(overlayMascot).dx, closeTo(screen.width / 2, 1));
    // モデルが準備できていれば端末内モデルの返事がトークンで流れる。
    llm.set(RaiLlmStatus(RaiLlmPhase.ready, modelId: llm.spec.id));
    await tester.pumpAndSettle();
    expect(find.text('未DL'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'こんにちは');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, 'はい、RASQ の RAi です。');
    expect(llm.systems.last, contains('アシスタント'));
    expect(find.byKey(const ValueKey('rai.ring.idle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.speech.close')));
    await tester.pumpAndSettle();
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
    // ▶ → 2 手順目(部品が無ければ中央)、✕ → RAi は消えるがバーは残る。
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本文を書いて'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.speech.close')));
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

  testWidgets('インストラクションで参照に無い質問は端末内モデルへバイパス、RAi ホームのモデル節でダウンロード / 削除 / 切り替え', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    // モデルは FOW で (D-183): ホームの状態行(未ダウンロード)→「モデルを選ぶ」→ タイル(ローカル / クラウド、完遂率 -%、メモリ判定)。
    expect(find.textContaining('未ダウンロード'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.models.open')));
    await tester.pumpAndSettle();
    expect(find.text('モデル'), findsOneWidget); // FOW タイトル
    expect(tester.getSize(find.byWidgetPredicate((w) => w is Material && w.elevation == 8)).width, closeTo(tester.getSize(find.byType(RasqApp)).width - 16, 1)); // 幅は入力ウィジェットに揃う (D-185)
    expect(find.text('ローカル'), findsWidgets);
    expect(find.text('完遂率 -%'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.model.ram.qwen3-1.7b-q4km'))).data, 'メモリ: 動作可'); // 8 GB の端末
    final fowList = find.descendant(of: find.byType(RaiModelsBody), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rai.model.tile.cloud-cyllm-jp-150b')), 120, scrollable: fowList);
    await tester.pumpAndSettle();
    expect(find.text('クラウド'), findsWidgets);
    expect(find.text('完遂率 集計外'), findsOneWidget); // 150B は集計外
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.model.phase.cloud-qwen3.9-33b-a3b'))).data, '未接続');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rai.model.download')), -120, scrollable: fowList);
    await tester.pumpAndSettle();
    // 既定は Qwen3 1.7B Q4_K_M の GGUF (D-188)。ダウンロード → 準備完了(解放 / 削除が出る)。
    expect(llm.spec.id, 'qwen3-1.7b-q4km');
    expect(llm.spec.engine, RaiEngine.gguf);
    await tester.tap(find.byKey(const ValueKey('rai.model.download')));
    await tester.pumpAndSettle();
    expect(llm.installs, 1);
    expect(find.byKey(const ValueKey('rai.model.release')), findsOneWidget);
    // 切り替え → Qwen3 0.6B の GGUF(「使う」)。RAi バーの下に隠れないよう少し余分に送る。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rai.model.use.qwen3-0.6b-q4km')), 80, scrollable: fowList);
    await clearOfBar(tester, fowList, find.byKey(const ValueKey('rai.model.use.qwen3-0.6b-q4km')));
    await tester.tap(find.byKey(const ValueKey('rai.model.use.qwen3-0.6b-q4km')));
    await tester.pumpAndSettle();
    expect(llm.spec.id, 'qwen3-0.6b-q4km');
    await tester.tap(find.text('閉じる').last); // FOW を閉じる
    await tester.pumpAndSettle();
    expect(find.textContaining('Qwen3 0.6B (Q4_K_M)'), findsWidgets);
    // インストラクションで参照に無い質問 → 端末内モデルが答える(操作のシステム指示)。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    llm.reply = '設定の「テーマ」から変えられます。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '設定の「テーマ」から変えられます。');
    expect(llm.systems.last, contains('操作'));
    // 複数文の返事は 1 行ずつ: ▶ で進む。
    llm.reply = '一つ目です。二つ目です！\n三つ目';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '一つ目です。');
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '二つ目です！');
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '三つ目');
    await tester.tap(find.byKey(const ValueKey('rai.next'))); // 最後の行で ▶ → 閉じる
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.speech')), findsNothing);
    // 削除(FOW)→ 確認 → 未ダウンロードに戻る。
    await tester.tap(find.byKey(const ValueKey('rai.model.tile')));
    await tester.pumpAndSettle();
    // 選択中(0.6B)が先頭に来るので削除はすぐ見える。
    expect(tester.getRect(find.byKey(const ValueKey('rai.model.tile.qwen3-0.6b-q4km'))).top, lessThan(tester.getRect(find.byKey(const ValueKey('rai.model.tile.qwen3-1.7b-q4km'))).top));
    await tester.tap(find.byKey(const ValueKey('rai.model.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.model.download')), findsOneWidget);
    expect(find.textContaining('未ダウンロード'), findsWidgets);
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
