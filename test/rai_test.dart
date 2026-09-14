import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/login/login_screen.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/profile/profile_edit_screen.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_llm_device.dart';
import 'package:rasq_client/features/rai/rai_models_fow.dart';
import 'package:rasq_client/features/rai/rai_motion.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/rai/rai_spline.dart';
import 'package:rasq_client/features/rai/rai_stats.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_rai_embedding_model.dart';
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
    test('リボン (D-193): 前半と後半で反対側へ膨らむ S 字、端点は同じ', () {
      final r = RaiPath(from: const Offset(0, 0), to: const Offset(400, 0), bulge: 0.25, ribbon: true);
      expect(r.at(0), const Offset(0, 0));
      expect((r.at(1) - const Offset(400, 0)).distance, lessThan(0.001));
      expect(r.at(0.25).dy.sign, isNot(r.at(0.75).dy.sign)); // 反対側
      expect(r.at(0.5).dy.abs(), lessThan(1)); // 中央で直線を横切る
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

  test('コードネーム (D-198): モデルコード + サイズ', () {
    expect(raiModelSpecById('qwen3-1.7b-q4km').codename, 'QA Mini');
    expect(raiModelSpecById('qwen3-0.6b-q4km').codename, 'QA Nano');
    expect(raiModelSpecById('qwen3-4b-q4km').codename, 'QA Lite+');
    expect(raiModelSpecById('agents-a1-4b-q4km').codename, 'Agent Lite+');
    expect(raiModelSpecById('lfm2.5-2.6b').codename, 'Liquid Lite');
    expect(raiCloudModelSpecs.firstWhere((m) => m.id == 'cloud-qwen3.9-33b-a3b').codename, 'QA Max');
    expect(raiCloudModelSpecs.firstWhere((m) => m.id == 'cloud-cyllm-jp-150b').codename, 'CyLLM Extreme');
    expect(raiSizeClass(10), 'Core');
    expect(raiSizeClass(20), 'Core+');
    expect(raiSizeClass(100), 'Max+');
    expect(RaiMode.assistant.modelName, 'QA Mini');
  });

  test('メモリの判定 (raiMemoryVerdict)', () {
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 8192), RaiRamVerdict.ok); // 3.3 GB 必要 / 4.9 GB まで余裕
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 5000), RaiRamVerdict.tight);
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: 3000), RaiRamVerdict.no);
    expect(raiMemoryVerdict(modelMb: 2885, totalRamMb: null), RaiRamVerdict.unknown);
  });

  group('参照 (D-189: rai_reference_test も参照)', () {
    test('キーワードで引ける / 知らない質問は null', () async {
      final index = await RaiReferenceIndex.fromJsonl(
        functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
        operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
        embedder: const NgramRaiEmbedder(),
      );
      expect(index.matchInstruction('Blueskyでログインしたい')?.instruction.id, 'login-bluesky');
      expect(index.matchInstruction('つぶやくには？')?.instruction.id, 'post');
      expect(index.matchInstruction('下書きはどこ')?.instruction.id, 'draft');
      expect(index.matchInstruction('zzzz qqqq'), isNull);
    });
  });

  late FakeRaiLlm llm;
  late FakeRaiEmbeddingModel embedding;
  setUp(() {
    llm = FakeRaiLlm();
    embedding = FakeRaiEmbeddingModel();
  });
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
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), raiLlmProvider.overrideWithValue(llm), raiEmbeddingModelProvider.overrideWithValue(embedding), deviceRamReaderProvider.overrideWithValue(() async => ram)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    // リファレンス索引 (D-189) はアセット読み込み(実 I/O)なので FakeAsync の外で先に組む。
    await tester.runAsync(() => c.read(raiReferenceProvider.future));
    await tester.pumpAndSettle();
    return c;
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
    // 静止位置は右下 (D-192: 右下 / 左下、直前に指した部品が右半分なら左下)。
    expect(tester.getCenter(overlayMascot).dx, closeTo(screen.width - raiPointSize / 2 - RasqSpacing.md, 1));
    expect(tester.getRect(overlayMascot).bottom, lessThan(tester.getRect(find.byType(RaiBar)).top + 1));
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
    expect((mascotRect.center - fab.center).distance, lessThan(raiPointSize * 1.6)); // ボタンの脇(大きさ 180 なので中心はその分離れる)
    expect(tester.getRect(find.byKey(const ValueKey('rai.toggle'))).top, lessThan(screen.height / 2)); // バーはボタンを隠さないよう上へ
    expect(mascotRect.deflate(raiPointSize * raiBodyInset).overlaps(fab), isFalse); // 体は被らない(箱の余白ぶんは部品の端に付く、D-196)
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
    // モデルは FOW で (D-183): バーのモデルチップ → タイル(ローカル / クラウド、完遂率 -%、メモリ判定)。FOW は入力ウィジェットの上に付く (D-192)。
    await tester.tap(find.byKey(const ValueKey('rai.model')));
    await tester.pumpAndSettle();
    expect(find.text('モデル'), findsOneWidget); // FOW タイトル
    expect(tester.getRect(find.byWidgetPredicate((w) => w is Material && w.elevation == 8)).bottom, lessThanOrEqualTo(tester.getRect(find.byType(RaiBar)).top + 1)); // バーの上に付く
    expect(tester.getSize(find.byWidgetPredicate((w) => w is Material && w.elevation == 8)).width, closeTo(tester.getSize(find.byType(RasqApp)).width - 16, 1)); // 幅は入力ウィジェットに揃う (D-185)
    expect(find.text('ローカル'), findsWidgets);
    expect(find.text('完遂率 -%'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.model.name.qwen3-1.7b-q4km'))).data, 'QA Mini'); // コードネーム (D-198)
    expect(find.textContaining('Qwen3 1.7B (Q4_K_M)'), findsWidgets); // gguf 名は元のまま
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
    expect(find.text('QA Nano'), findsOneWidget); // バーのチップ
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
    await tester.tap(find.byKey(const ValueKey('rai.model')));
    await tester.pumpAndSettle();
    // 選択中(0.6B)が先頭に来るので削除はすぐ見える。
    expect(tester.getRect(find.byKey(const ValueKey('rai.model.tile.qwen3-0.6b-q4km'))).top, lessThan(tester.getRect(find.byKey(const ValueKey('rai.model.tile.qwen3-1.7b-q4km'))).top));
    await tester.tap(find.byKey(const ValueKey('rai.model.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.model.download')), findsOneWidget);
  });

  testWidgets('アシスタント (D-189): LLM がシチュエーションを作ってから操作リファレンスを引き、関数の検索手順を提案(中央固定)', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    llm.set(RaiLlmStatus(RaiLlmPhase.ready, modelId: llm.spec.id));
    llm.reply = '画像を付けて投稿したい状況';
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '撮った写真をみんなに見せたい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    // LLM にはシチュエーションの一文だけ作らせる(返事の生成はしない)。
    expect(llm.systems.single, raiSituationSystem);
    final st = c.read(raiProvider);
    expect(st.situation, '画像を付けて投稿したい状況');
    expect(st.proposal, 'attach');
    expect(st.hits.first.id, 'attach');
    expect(st.target, isNull); // 中央固定
    expect(find.byType(RaiHomeScreen), findsOneWidget); // 画面は動かない
    // 1 行目 = 見出し、▶ で関数〔id〕と 入力 / 固定 が並ぶ。
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '「画像を付けて投稿」なら、この順で進めます(3 手順)');
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, '1. 右下の「投稿」でコンポーザーが開きます〔composer.open〕');
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('〔post.attach〕 入力: ファイル 固定: 閲覧注意=false'));
    await tester.tap(find.byKey(const ValueKey('rai.next')));
    await tester.pumpAndSettle();
    final last = tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data!;
    expect(last, contains('〔post.create〕 入力: 本文 固定: 公開範囲=public CW=false 返信制限=0 作成時刻='));
    // 提案は履歴(ログ)に全文で残る。
    expect(c.read(raiProvider).log.first.text, contains('3 手順'));
    // リファレンスに無い発言(シチュエーションでも引けない)→ LLM の返事。
    llm.reply = 'はい、RASQ の RAi です。';
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'zzzz qqqq');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).proposal, isNull);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, 'はい、RASQ の RAi です。');
    expect(llm.systems.last, contains('アシスタント'));
  });

  testWidgets('モデル FOW の「検索(リファレンスの埋め込み)」 (D-190): SigLIP2 をダウンロード → 索引が SigLIP2 で組み直る → 削除で n-gram に戻る', (tester) async {
    final c = await pump(tester);
    expect((await tester.runAsync(() => c.read(raiEmbedderProvider.future)))!.name, 'ngram-256');
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.model')));
    await tester.pumpAndSettle();
    final fowList = find.descendant(of: find.byType(RaiModelsBody), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rai.embed.tile')), 120, scrollable: fowList);
    await tester.pumpAndSettle();
    expect(find.text('MiniLM-L12 多言語(paraphrase, int8)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.embed.phase'))).data, '未ダウンロード');
    expect(find.textContaining('n-gram 代替'), findsOneWidget);
    await clearOfBar(tester, fowList, find.byKey(const ValueKey('rai.embed.download')));
    await tester.tap(find.byKey(const ValueKey('rai.embed.download')));
    await tester.pumpAndSettle();
    expect(embedding.installs, 1);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.embed.phase'))).data, '準備完了');
    expect(find.textContaining('検索: MiniLM-L12'), findsOneWidget);
    // 索引は新しい埋め込み器で組み直される。
    await tester.runAsync(() => c.read(raiReferenceProvider.future));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => c.read(raiEmbedderProvider.future)))!.name, 'fake-siglip');
    expect(c.read(raiReferenceProvider).value!.embedder.name, 'fake-siglip');
    await tester.tap(find.byKey(const ValueKey('rai.embed.delete')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.embed.phase'))).data, '未ダウンロード');
    await tester.runAsync(() => c.read(raiReferenceProvider.future));
    expect((await tester.runAsync(() => c.read(raiEmbedderProvider.future)))!.name, 'ngram-256');
  });

  testWidgets('指差した部品が押されたら自動で次へ (D-193)、タブ外の画面は push なので戻る / 決定が効く', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    // 「投稿したい」→ ホームの「投稿」を指差す。そのボタンを押すと(コンポーザーが開き)次の手順へ。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).stepIndex, 0);
    expect(find.text('右下の「投稿」でコンポーザーが開きます'), findsOneWidget);
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).stepIndex, 1);
    expect(find.textContaining('本文を書いて'), findsOneWidget);
    expect(c.read(raiProvider).target, isNotNull); // コンポーザーの「画像」を指す
    await tester.tap(find.byKey(const ValueKey('rai.speech.close')));
    await tester.pumpAndSettle();
    // タブ外の画面(プロフィール編集)へは push: ヘッダーの戻るで元の画面へ戻れる。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '自己紹介を変えたい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    expect(c.read(routerProvider).canPop(), isTrue);
    await tester.tap(find.byKey(const ValueKey('rai.speech.close')));
    await tester.pumpAndSettle();
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsNothing);
  });

  testWidgets('曖昧な質問は吹き出しの上に選択肢 (D-194)、入力欄は薄い補完(スペースで確定)と通常フォント', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    // 入力欄は通常の太さ。
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rai.input'))).style?.fontWeight, isNot(FontWeight.w700));
    // 「アカウント」だけでは複数の操作が同点 → 選択肢。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'アカウント');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    final st = c.read(raiProvider);
    expect(st.choices.length, greaterThanOrEqualTo(2));
    expect(st.steps, isEmpty);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rai.bubble'))).data, contains('どれのことですか'));
    final first = st.choices.first;
    expect(find.byKey(ValueKey('rai.choice.${first.id}')), findsOneWidget);
    expect(tester.getRect(find.byKey(ValueKey('rai.choice.${first.id}'))).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('rai.speech'))).top + 1)); // 吹き出しの上
    await tester.tap(find.byKey(ValueKey('rai.choice.${first.id}')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).choices, isEmpty);
    expect(c.read(raiProvider).lastOperation, first.id);
    expect(c.read(raiProvider).steps, isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('rai.speech.close')));
    await tester.pumpAndSettle();
    // 薄い補完: 「投稿」と打つと見出しの候補が薄く出て、スペースで確定。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿');
    await tester.pump();
    expect(find.byKey(const ValueKey('rai.ghost')), findsOneWidget);
    final ghost = tester.widget<Text>(find.byKey(const ValueKey('rai.ghost'))).data!;
    expect(ghost.startsWith('投稿'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿 ');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rai.input'))).controller!.text, ghost);
    expect(find.byKey(const ValueKey('rai.ghost')), findsNothing);
    // 直前の操作から分岐する見出しを優先する: 「投稿する」(post)のあとは post から分岐する操作。
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    if (c.read(raiProvider).choices.isNotEmpty) {
      await tester.tap(find.byKey(ValueKey('rai.choice.${c.read(raiProvider).choices.first.id}')));
      await tester.pumpAndSettle();
    }
    final last = c.read(raiProvider).lastOperation;
    expect(last, isNotNull);
    final branches = c.read(raiReferenceProvider).value!.operations.where((o) => o.base == last).toList();
    if (branches.isNotEmpty) {
      final head = branches.first.index.substring(0, 1);
      expect(c.read(raiProvider.notifier).suggest(head), branches.firstWhere((o) => o.index.startsWith(head), orElse: () => branches.first).index);
    }
  });

  testWidgets('モード切り替えで RAi ページが自動で開閉する (D-200)', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    // インストラクションへ → RAi ページは閉じる。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).mode, RaiMode.instruction);
    expect(find.byType(RaiHomeScreen), findsNothing);
    expect(find.byKey(const ValueKey('rai.toggle')), findsOneWidget); // バーは残る
    // アシスタントへ → RAi ページが開く。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).mode, RaiMode.assistant);
    expect(find.byType(RaiHomeScreen), findsOneWidget);
  });

  testWidgets('ログイン画面の「Raiのインストラクチャ」→ 入力欄付きのバー(インストラクション)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({});
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    await tester.runAsync(() => ProviderScope.containerOf(tester.element(find.byType(RasqApp))).read(raiReferenceProvider.future));
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

  testWidgets('RAi サイドバー (D-214): ← の右のアイコン → 入力タイルが消えてサイドバー(新しい会話 / 会話の履歴 / アチーブメント / マクロ)、実績は質問で進む、会話は区切って保存 / 開き直せる', (tester) async {
    final c = await pump(tester);
    RasqSidebar.open(c.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar.rai')));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.input')), findsOneWidget);
    // 中央のスタンバイ枠(2D では薄い RAi)は報告されている。
    expect(c.read(raiStandbySlotProvider), isNotNull);
    // アイコン → サイドバー。バーは消える。
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.toggle')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).sidebarOpen, isTrue);
    expect(find.byKey(const ValueKey('rai.input')), findsNothing);
    expect(find.byKey(const ValueKey('rai.sidebar.new')), findsOneWidget);
    expect(find.text('会話の履歴'), findsOneWidget);
    expect(find.text('アチーブメント'), findsOneWidget);
    expect(find.text('マクロ'), findsOneWidget);
    expect(find.textContaining('まだありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.sidebar.ach.ask1')), findsOneWidget);
    expect(find.text('0 / 1'), findsWidgets); // まだ 0
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rai.sidebar.macro.new')), 200, scrollable: find.descendant(of: find.byKey(const ValueKey('rai.sidebar')), matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.sidebar.macro.0')), findsOneWidget); // ダミー(無効)
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('rai.sidebar.macro.new'))).onPressed, isNull);
    // 外側のタップで閉じる → バーが戻る。
    await tester.tapAt(Offset(tester.getSize(find.byType(RasqApp)).width - 10, 400));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).sidebarOpen, isFalse);
    expect(find.byKey(const ValueKey('rai.input')), findsOneWidget);
    // インストラクションを聞く → 実績「はじめての質問」が進む(端末内に保存)。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiStatsProvider).instructionsAsked, 1);
    expect(c.read(raiStatsProvider).repeatedAsks, 0);
    expect(await c.read(sessionStorageProvider).read(RaiStatsStore.storageKey), contains('"instructionsAsked":1'));
    expect(c.read(raiProvider).log, isNotEmpty);
    // 同じ質問をもう一度 → 「何度も聞いた」。
    await tester.enterText(find.byKey(const ValueKey('rai.input')), '投稿したい');
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await tester.pumpAndSettle();
    expect(c.read(raiStatsProvider).instructionsAsked, 2);
    expect(c.read(raiStatsProvider).repeatedAsks, 1);
    // アシスタントへ戻す → RAi ホームが開く (D-200)。サイドバーに「いまの会話」、実績は 1 / 1 で達成。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.sidebar.conv.current')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('rai.sidebar.ach.ask1')), matching: find.text('1 / 1')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('rai.sidebar.ach.ask1')), matching: find.byIcon(Icons.emoji_events)), findsOneWidget); // 達成
    // 新しい会話 → いまの履歴が保存され、履歴は空、サイドバーは閉じる。
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.new')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).sidebarOpen, isFalse);
    expect(c.read(raiProvider).log, isEmpty);
    final saved = c.read(raiConversationsProvider);
    expect(saved.length, 1);
    expect(saved.single.title, '投稿したい');
    expect(await c.read(sessionStorageProvider).read(RaiConversationsStore.storageKey), contains('投稿したい'));
    // 保存した会話を開く → 発言の履歴として戻り、履歴が開く。
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.sidebar.conv.current')), findsNothing);
    await tester.tap(find.byKey(ValueKey('rai.sidebar.conv.${saved.single.id}')));
    await tester.pumpAndSettle();
    expect(c.read(raiProvider).sidebarOpen, isFalse);
    expect(c.read(raiProvider).log.length, saved.single.log.length);
    expect(c.read(raiProvider).conversationId, saved.single.id);
    expect(find.byKey(const ValueKey('rai.history.list')), findsOneWidget);
    // 削除。
    await tester.tap(find.byKey(const ValueKey('rai.history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.sidebar.conv.current')), findsOneWidget); // 開いた会話 = いまの会話
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('rai.sidebar.conv.delete.${saved.single.id}')));
    await tester.pumpAndSettle();
    expect(c.read(raiConversationsProvider), isEmpty);
    // 画面を離れるとサイドバーは閉じた扱い(バーが隠れたままにならない)。
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(RaiHomeScreen), findsNothing);
    expect(c.read(raiStandbySlotProvider), isNull);
    expect(find.byKey(const ValueKey('rai.input')), findsOneWidget);
  });

}
