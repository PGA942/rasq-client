// rasq-central のホームページ (S-095 / S-096 / S-098 / S-101 / S-103) の「実機っぽいプレビュー」に貼る、アプリの画面のスクリーンショット。
// ホームページには スマホ / タブレット の 2 つのプレビューがあり (S-098)、節ごとに両方の画面を持つ:
//
//   | 節 | スマホ(縦、390×844 論理 px の 2 倍 = 780×1688) | タブレット |
//   |---|---|---|
//   | はじめ | home_onboarding.png | 横向き(1280×800 の 1.5 倍 = 1920×1200): home_onboarding_wide.png(2 カラム、D-405) |
//   | RASQ Web クライアント | home_timeline.png(ホームのタイムライン) | 横向き: home_client.png(レール + 2 カラムのホーム) |
//   | RASQ アカウント・QuickView | home_account.png | 縦向き(800×1280 の 1.5 倍 = 1200×1920、1 カラム): home_account_tall.png |
//   | ASTell | home_astell_listen.png(ルームで聞いているところ) | 縦向き: home_astell_listen_tall.png |
//   | RAi (D-463 → D-464) | 下の見本のキーフレーム(静止版の rai.webp は homeshots.sh が案内の 2 コマ目から) | 縦向き: 同(_tall) |
//
// RAi の節 (Central S-103 / D-464) は、端末の画面で 2 つの見本を交互に流す。見本ごとにキーフレームを描く
// (homeshots.sh が 1 本の animated WebP にまとめる):
//   - 案内「TL にリストを設定」(インストラクション、RAi が部品を指差して順に進む): home_rai_guide_00.png …(8 コマ)
//   - アシスタントの RAi との会話(「ハロー、RAi さん」→ 返事が流れる): home_rai_chat_00.png …(6 コマ)
//   タブレットは末尾に _tall(縦、1 カラム)。静止版の rai(_tall).webp は案内の 2 コマ目(「タイムラインを追加」を指す)。
//   (前の RAi のホームだけの 1 枚 home_rai.png は撮らない。会話の見本の 1 コマ目がそれにあたる)
//
// タブレットの縦向きは幅 800 論理 px(< RasqSizes.tabletBreakpoint = 840)なので、アプリはスマホと同じ 1 カラムで描く。
// ホームページは画像の比率で端末(長辺 / 短辺 が 2 以上ならスマホ、それ未満ならタブレット)と向きを決める (S-096)。
// 実行(WebP への変換と置き場までまとめて)は tool/preview/homeshots.sh。手で回すなら:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/homeshots_test.dart --update-goldens
// → tool/preview/home_*.png(git には入れない。成果物は rasq-central の src/web/home/*.webp)。
// ほかのプレビュー (vc_preview_test.dart など) と同じく、フォント未指定ならスキップ。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart' show TimelineConfigScreen;
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart' show RaiReferenceIndex, raiSituationSystem;
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fake_rai_embedding_model.dart';
import '../../test/support/fake_rai_llm.dart';
import '../../test/support/fakes.dart';

/// 端末の画面の大きさ(物理 px と倍率)。ホームページの端末の画面に貼るテクスチャの大きさになる。
enum HomeView {
  /// スマホの縦: 390×844 論理 px(iPhone 14 相当)の 2 倍。
  phone(780, 1688, 2),

  /// タブレットの横向き: 1280×800 論理 px(16:10)の 1.5 倍。レール + 2 カラム。
  tabletWide(1920, 1200, 1.5),

  /// タブレットの縦向き: 800×1280 論理 px(10:16)の 1.5 倍。幅が 840 未満なので 1 カラム。
  tabletTall(1200, 1920, 1.5);

  const HomeView(this.width, this.height, this.dpr);
  final double width;
  final double height;
  final double dpr;

  void apply(WidgetTester tester) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }
}

/// 返事を 1 字ずつ時間をかけて流す偽の端末内 LLM(会話の見本で「流れている途中」のコマを撮るため)。
/// シチュエーションの一文と計画は短く即答、本文の返事は [firstDelay] 待ってから 1 字 [perChar] ずつ。
class _SlowRaiLlm extends FakeRaiLlm {
  _SlowRaiLlm({required String answer}) : super(phase: RaiLlmPhase.ready, reply: answer);
  static const firstDelay = Duration(milliseconds: 900);
  static const perChar = Duration(milliseconds: 40);

  @override
  Stream<String> chat(String prompt, {String? system, int? maxTokens}) async* {
    if (system == raiSituationSystem) {
      yield 'RAi にあいさつしている';
      return;
    }
    if (system == RaiController.raiPlanSystem) {
      yield '- あいさつを返す';
      return;
    }
    await Future<void>.delayed(firstDelay);
    await for (final ch in super.chat(prompt, system: system, maxTokens: maxTokens)) {
      await Future<void>.delayed(perChar);
      yield ch;
    }
  }
}

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    // FlutterTest = flutter_test の既定のフォント(テーマを通らない文字はここへ落ちる)。
    // fontFamily の無い文字は、ここで登録した名前では探されずエンジンのテストのフォントに落ちて □ になる(D-458 で
    // FilledButton / OutlinedButton の文言がそうだった → rasq_design のテーマ側で labelLarge と同じ名前を付けた)。
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display', 'FlutterTest']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    // アイコン: テストの既定ではアイコンのフォントが無く □ になるので、Flutter SDK の控え(bin/cache)から Material Icons を読む。
    // RASQ_PREVIEW_ICONS で別の .otf を指せる。見つからなければ □ のまま(失敗にはしない)。
    const inSdk = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var icons = Platform.environment['RASQ_PREVIEW_ICONS'] ?? '${Platform.environment['FLUTTER_ROOT'] ?? ''}/$inSdk';
    // テストは flutter_tester(bin/cache/artifacts/engine/…)で動くので、そこから上へ SDK の根を探す。
    for (var d = File(Platform.resolvedExecutable).parent; !File(icons).existsSync() && d.path != d.parent.path; d = d.parent) {
      icons = '${d.path}/$inSdk';
    }
    if (File(icons).existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File(icons).readAsBytesSync().buffer)));
      await loader.load();
    } else {
      // ignore: avoid_print
      print('homeshots: Material Icons のフォントが見つかりません ($icons)。アイコンは □ になります');
    }
  });

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  final loggedIn = MemorySessionStorage({
    SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
  });

  /// SNS のタイムラインの見本 (MockData) でログイン中。Central には繋がない(ASTell はモックのルーム)。
  Future<ProviderContainer> pumpApp(WidgetTester tester, HomeView view) async {
    view.apply(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  /// ASTell のルーム「打ち上げの打ち上げ」(モック、ダグラスが話していて TiVard が画面を共有中)に入って**聞いている**ところ:
  /// ルーム FOW(共有欄 / 参加メンバー / 字幕の文字起こし / 下段のマイク(オフ)・画面・字幕・共有)。ホームページの ASTell の節。
  Future<void> pumpListening(WidgetTester tester, HomeView view) async {
    final c = await pumpApp(tester, view);
    final room = (await c.read(astellClientProvider).room('r-launch'))!;
    await c.read(astellSessionProvider.notifier).join(room);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ASTell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
  }

  /// 時計を [ms] だけ進める(RAi の 3D / 浮遊の動きは止まらないので pumpAndSettle は使わない)。
  Future<void> run(WidgetTester tester, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// RAi の見本 (D-464) の土台: SNS の見本 (MockData) でログイン中、テストの偽物の LLM([llm])/ 埋め込み。
  /// 操作の索引(アセットの読み込み = 実 I/O)を FakeAsync の外で組んでから、RAi のホーム(アシスタント)を開く。
  /// [withIndex] = false なら操作の索引を読めないことにする(会話の見本: 「RAi」を含むあいさつが操作「RAi に操作を聞く」の
  /// 提案にならず、LLM の返事だけになる)。
  Future<ProviderContainer> pumpRaiHome(WidgetTester tester, HomeView view, RaiLlm llm, {bool withIndex = true}) async {
    view.apply(tester);
    // rootBundle は loadString の Future をプロセスで持つので、前のテストのゾーンのものを捨てる(rai_chat_test と同じ)。
    rootBundle.clear();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        raiLlmProvider.overrideWithValue(llm),
        raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()),
        deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)),
        if (!withIndex) raiReferenceProvider.overrideWith((ref) => Future<RaiReferenceIndex>.error(StateError('会話の見本では操作の索引を使わない'))),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    if (withIndex) await tester.runAsync(() => c.read(raiReferenceProvider.future));
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.rai);
    await run(tester, 2000);
    return c;
  }

  /// キーフレームを home_<name>_00.png から順に撮る口。
  Future<void> Function() frames(String name) {
    var i = 0;
    return () => expectLater(find.byType(RasqApp), matchesGoldenFile('home_${name}_${(i++).toString().padLeft(2, '0')}.png'));
  }

  /// 見本 (a): インストラクションの案内「TL にリストを設定」(rasq-client assets/rai/operations.jsonl の `tl-list`、
  /// base = `tl-temp` の 1 手順目から分岐)。アプリと同じく RAi が部品へ移動して指差し、指した部品を押すと次の手順へ進む。
  /// 8 コマ: 質問を入れる → ∨ を指す → 「タイムラインを追加」を指す → 追加の一覧(「リスト…」を選ぶ手順)→ リストを選ぶ →
  /// 戻るとリストが流れる → 「決定」を指す → 決定後のタイムライン。
  Future<void> raiGuide(WidgetTester tester, HomeView view, String name) async {
    // 手順ごとに待つ時間(RAi が次の部品へ走って止まるまで)。
    const step = 5000;
    final c = await pumpRaiHome(tester, view, FakeRaiLlm());
    final n = c.read(raiProvider.notifier);
    final shot = frames(name);
    // バーのトグルでインストラクションへ(RAi のページは閉じて、ホームのタイムラインに戻る)。
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await run(tester);
    expect(c.read(raiProvider).mode, RaiMode.instruction);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'TL にリストを設定');
    await run(tester, 600);
    await shot(); // 00: 質問を入れたところ
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await run(tester, step);
    if (c.read(raiProvider).lastOperation != 'tl-list') {
      // 索引の引き方が変わって別の操作に当たっても、見本は同じ案内にする(テストの偽物の埋め込みは n-gram)。
      n.dismissBubble();
      unawaited(n.runInstruction('tl-list'));
      await run(tester, step);
    }
    expect(c.read(raiProvider).lastOperation, 'tl-list');
    expect(c.read(raiProvider).stepIndex, 0);
    expect(c.read(raiProvider).target, isNotNull);
    await shot(); // 01: 選んでいるタブの ∨ を指す
    await tester.tapAt(c.read(raiProvider).target!.center);
    await run(tester, step);
    expect(c.read(raiProvider).stepIndex, 1);
    // 「タイムラインを追加」は一時変更の FOW の下のほう。見えるところまで送ってから RAi に取り直させる(人が送るのと同じ)。
    final config = find.descendant(of: find.byType(TimelineConfigScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.descendant(of: find.byType(TimelineConfigScreen), matching: find.text('タイムラインを追加')), 120, scrollable: config);
    await tester.drag(config, const Offset(0, -80)); // FOW の下端に寄りすぎないよう少し余分に送る
    await run(tester, 300);
    await run(tester, 500);
    unawaited(n.relocate());
    await run(tester, step);
    expect(c.read(raiProvider).target, isNotNull);
    await shot(); // 02: 「タイムラインを一時変更」の「タイムラインを追加」を指す(静止版の 1 枚)
    await tester.tapAt(c.read(raiProvider).target!.center);
    await run(tester, step);
    expect(c.read(raiProvider).stepIndex, 2);
    await shot(); // 03: 追加の一覧(「リストTL」)と、リストのタイルを選ぶ手順
    await tester.tap(find.text('リストTL').last);
    await run(tester);
    await tester.tap(find.text('リストTLを取得').last);
    await run(tester);
    await tester.tap(find.text('Fediverse Banner').last);
    await run(tester, 1000);
    await shot(); // 04: リストを選ぶ
    await tester.tap(find.text('決定').last);
    await run(tester);
    unawaited(n.next());
    await run(tester, step);
    expect(c.read(raiProvider).stepIndex, 3);
    await shot(); // 05: 戻るとそのタブにリストの投稿が流れる
    unawaited(n.next());
    await run(tester, step);
    expect(c.read(raiProvider).stepIndex, 4);
    expect(c.read(raiProvider).target, isNotNull);
    await shot(); // 06: 「決定」を指す
    await tester.tapAt(c.read(raiProvider).target!.center);
    await run(tester, step);
    expect(c.read(raiProvider).bubble, isNull, reason: '最後の手順の部品を押すと案内は閉じる');
    // stick に畳んだ一時変更を ✕ で閉じる(一時変更はそのタブに残る)。決定したタイムラインだけを見せる。
    await tester.tap(find.byKey(const ValueKey('tl.temp.close')));
    await run(tester, 3000);
    await shot(); // 07: 決定したタイムライン
  }

  /// 見本 (b) の返事。
  const raiChatAnswer = 'ハロー！RAi です。タイムラインの整え方や ASTell のルーム探し、投稿の下書きまで、RASQ のことなら何でも聞いてくださいね。';

  /// 見本 (b): アシスタントの RAi との会話。RAi のホームで「ハロー、RAi さん」と送り、返事が 1 字ずつ流れる。
  /// 6 コマ: 空のホーム → 入れたところ → 送った(考え中)→ 流れている途中 × 2 → 返事。
  Future<void> raiChat(WidgetTester tester, HomeView view, String name) async {
    final c = await pumpRaiHome(tester, view, _SlowRaiLlm(answer: raiChatAnswer), withIndex: false);
    final shot = frames(name);
    expect(c.read(raiProvider).mode, RaiMode.assistant);
    await shot(); // 00: RAi のホーム
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'ハロー、RAi さん');
    await run(tester, 600);
    await shot(); // 01: 入れたところ
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await run(tester, 500);
    expect(c.read(raiProvider).busy, isTrue);
    await shot(); // 02: 送った(考え中)
    Future<void> until(bool Function() ok) async {
      for (var k = 0; k < 200 && !ok(); k++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    String bubble() => c.read(raiProvider).bubble ?? '';
    await until(() => bubble().length >= raiChatAnswer.length ~/ 3);
    await shot(); // 03: 流れている途中
    await until(() => bubble().length >= raiChatAnswer.length * 2 ~/ 3);
    await shot(); // 04
    await until(() => !c.read(raiProvider).busy);
    await run(tester, 1000);
    expect(c.read(raiProvider).bubble, raiChatAnswer);
    expect(c.read(raiProvider).proposal, isNull, reason: 'あいさつは操作の提案にしない');
    await shot(); // 05: 返事
  }

  /// RASQ アカウントページ(はな @hana、Central の口をまねる)。ホームページの RASQ アカウント・QuickView の節。
  Future<void> pumpAccount(WidgetTester tester, HomeView view) async {
    view.apply(tester);
    const author = {'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな'};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /accounts/hana':
          return json({
            'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな', 'bio': '写真と宇宙の話をします。ASTell で夜の雑談もやっています。', 'location': '東京', 'birthday': '', 'createdAt': '2026-09-01T00:00:00Z',
            'links': [{'label': 'サイト', 'url': 'https://example.com/'}],
            'snsAccounts': [
              {'accountKey': 'misskey:misskey.io:hana', 'kind': 'misskey', 'instance': 'misskey.io', 'handle': 'hana', 'displayName': 'はな', 'serverName': 'Misskey.io', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
              {'accountKey': 'mastodon:mastodon.social:hana', 'kind': 'mastodon', 'instance': 'mastodon.social', 'handle': 'hana', 'displayName': 'hana', 'serverName': 'Mastodon', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
            ],
            'plugins': <Object>[],
            'reviews': <Object>[],
          });
        case 'GET /accounts/hana/posts':
          return json({
            'source': 'rasq', 'limit': 3,
            'posts': [
              {'id': 'p1', 'author': author, 'body': '今夜 21 時から ASTell で「夜の雑談」をやります。写真の話をゆるく。', 'images': <Object>[], 'createdAt': '2026-10-09T12:00:00Z', 'replyCount': 3, 'rebroadCount': 2, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p2', 'author': author, 'body': 'ロケットの打ち上げ、無事に成功しました。おめでとうございます！ #打上会', 'images': <Object>[], 'createdAt': '2026-10-08T09:30:00Z', 'replyCount': 1, 'rebroadCount': 5, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p3', 'author': author, 'body': 'RASQ アカウントを作りました。SNS のアカウントを束ねて使っています。', 'images': <Object>[], 'createdAt': '2026-09-01T00:00:00Z', 'replyCount': 0, 'rebroadCount': 0, 'rebroaded': false, 'queues': <Object>[]},
            ],
          });
        case 'GET /accounts/hana/rasq-collections':
          return json(<Object>[]);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.rasqAccount('hana'));
    await tester.pumpAndSettle();
  }

  /// 最初のオンボーディング(登録)。サーバーのタイル (D-412) の情報だけ Central の口をまねる
  /// (plugin_preview_test の onboarding_wide と同じ)。ホームページの はじめ の節。
  Future<void> pumpOnboarding(WidgetTester tester, HomeView view) async {
    view.apply(tester);
    final central = MockClient((req) async => switch (req.url.path) {
          '/api/v1/servers/misskey.io/info' => json({'host': 'misskey.io', 'software': 'misskey', 'version': '2025.4.1', 'name': 'Misskey.io', 'description': 'Misskey.io は、地球で生まれた分散マイクロブログ SNS です。', 'themeColor': '#86b300', 'users': 520000, 'posts': 210000000, 'registrationOpen': true}),
          '/api/v1/servers/mastodon.social/info' => json({'host': 'mastodon.social', 'software': 'mastodon', 'version': '4.8.0', 'name': 'Mastodon', 'description': 'The original server of Mastodon.', 'themeColor': '#6364ff', 'users': 3100000, 'registrationOpen': true}),
          _ => json({'error': {'code': '404', 'message': 'not found'}}, 404),
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
  }

  // ── はじめ ──
  testWidgets('onboarding (phone)', (tester) async {
    await pumpOnboarding(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_onboarding.png'));
  });

  testWidgets('onboarding (tablet, landscape)', (tester) async {
    await pumpOnboarding(tester, HomeView.tabletWide);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_onboarding_wide.png'));
  });

  // ── RASQ Web クライアント ──
  testWidgets('home timeline (phone)', (tester) async {
    await pumpApp(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_timeline.png'));
  });

  testWidgets('web client (tablet, landscape)', (tester) async {
    await pumpApp(tester, HomeView.tabletWide);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_client.png'));
  });

  // ── RASQ アカウント・QuickView ──
  testWidgets('rasq account page (phone)', (tester) async {
    await pumpAccount(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_account.png'));
  });

  testWidgets('rasq account page (tablet, portrait)', (tester) async {
    await pumpAccount(tester, HomeView.tabletTall);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_account_tall.png'));
  });

  // ── ASTell ──
  testWidgets('astell listening in a room (phone)', (tester) async {
    await pumpListening(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_astell_listen.png'));
  });

  testWidgets('astell listening in a room (tablet, portrait)', (tester) async {
    await pumpListening(tester, HomeView.tabletTall);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_astell_listen_tall.png'));
  });

  // ── RAi (D-463 → D-464): 2 つの見本のキーフレーム ──
  testWidgets('rai guide "TL にリストを設定" (phone)', (tester) async {
    await raiGuide(tester, HomeView.phone, 'rai_guide');
  });

  testWidgets('rai guide "TL にリストを設定" (tablet, portrait)', (tester) async {
    await raiGuide(tester, HomeView.tabletTall, 'rai_guide_tall');
  });

  testWidgets('rai chat "ハロー、RAi さん" (phone)', (tester) async {
    await raiChat(tester, HomeView.phone, 'rai_chat');
  });

  testWidgets('rai chat "ハロー、RAi さん" (tablet, portrait)', (tester) async {
    await raiChat(tester, HomeView.tabletTall, 'rai_chat_tall');
  });
}
