import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/compose/mfm_picker_fow.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

void main() {
  late PluginRegistry registry;

  Widget app({List<Post> Function(AccountId viewer)? posts, Set<String>? localEmojis}) {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts ?? MockData.timeline, localEmojis: localEmojis));
    return ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    );
  }

  testWidgets('FOWヘッダーの投稿オプション (D-045): 公開範囲/連合/リアクション受け入れが NewPost に載る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsOneWidget); // ヘッダー中央タイトル (D-052)

    // 投稿オプションはツールバー(横スクロール)に移動 (D-052)。
    await tester.dragUntilVisible(find.byTooltip('公開範囲: パブリック'), find.byType(SingleChildScrollView).last, const Offset(-60, 0));
    await tester.pumpAndSettle();

    // 公開範囲 → ホーム
    await tester.tap(find.byTooltip('公開範囲: パブリック'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ホーム').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('公開範囲: ホーム'), findsOneWidget);

    // 連合オフ(このサーバーのみ)
    await tester.tap(find.byTooltip('連合あり(タップで連合なしに)'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('連合なし(このサーバーのみ)'), findsOneWidget);

    // リアクションの受け入れ → いいねのみ
    await tester.tap(find.byTooltip('リアクションの受け入れ: 全て'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いいねのみ').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'オプションのテスト');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();

    final session = registry.session(fakeSession()) as FakeSnsSession;
    final draft = session.lastDraft!;
    expect(draft.visibility, 'home');
    expect(draft.localOnly, isTrue);
    expect(draft.reactionAcceptance, 'likeOnly');
  });

  testWidgets('MFMピッカー (D-045): 一覧 → サブページでプロパティー入力 → 決定でカーソルが中身部分へ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('MFM')); // ツールバーは横スクロール(D-174 で「動画」が増えた)
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('MFM'));
    await tester.pumpAndSettle();

    // ホーム画面: 関数名 + 説明文の縦リスト(rotate まではスクロール)
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('2倍に拡大'), findsOneWidget);

    // 親子 FOW (D-067): 子ピッカーはコンポーザー(親)の下側に付き、親は
    // 子の高さぶん持ち上がる — 入力部がピッカーに被らない。
    expect(tester.getBottomLeft(find.byType(TextField).first).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MfmPickerPanel)).dy + 1));
    await tester.scrollUntilVisible(find.text('rotate'), 80, scrollable: find.descendant(of: find.byType(MfmPickerPanel), matching: find.byType(Scrollable)));
    await tester.ensureVisible(find.text('rotate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('rotate'));
    await tester.pumpAndSettle();

    // サブページ: プロパティー入力 → スニペットに反映
    final propField = find.descendant(of: find.byType(MfmPickerPanel), matching: find.byType(TextField));
    await tester.enterText(propField, '30');
    await tester.pumpAndSettle();
    expect(find.text(r'$[rotate.deg=30 …]'), findsOneWidget);

    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    // 本文に挿入され、カーソルは中身部分(] の手前)
    final body = tester.widget<TextField>(find.byType(TextField).last);
    expect(body.controller!.text, r'$[rotate.deg=30 ]');
    expect(body.controller!.selection.baseOffset, r'$[rotate.deg=30 '.length);
  });

  testWidgets('ダイレクト投稿への返信 (D-047): stick FOW + specified 固定・宛先/連合の継承', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Post direct(AccountId viewer) => Post(
          id: 'd1',
          account: viewer,
          author: UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス'),
          createdAt: DateTime(2026, 8, 28, 11),
          body: '秘密の相談です',
          visibility: 'specified',
          localOnly: true,
          directToIds: const ['peer1'],
        );
    await tester.pumpWidget(app(posts: (v) => [direct(v)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('秘密の相談です').first);
    await tester.pumpAndSettle();

    // 常駐 stick (D-050): ページを開いた時点で縮小状態のコンポーザーが居る。
    expect(find.text('キャンセル'), findsNothing);
    expect(find.byType(TextField), findsWidgets);

    // 入力(フォーカス)で割り込みヘッダーが展開: キャンセル とダイレクト表示。
    await tester.enterText(find.byType(TextField).last, '@alice 了解です');
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('ダイレクト投稿への返信(相手にだけ届きます)'), findsOneWidget);
    // 公開範囲などのオプションはダイレクトでは出さない。
    expect(find.byTooltip('公開範囲: パブリック'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '返信').last);
    await tester.pumpAndSettle();

    final session = registry.session(fakeSession()) as FakeSnsSession;
    final draft = session.lastDraft!;
    expect(draft.visibility, 'specified');
    expect(draft.directToIds, containsAll(['alice', 'peer1']));
    expect(draft.localOnly, isTrue); // 連合なしの親 → 返信も連合なし
    expect(draft.reactionAcceptance, isNull);
  });

  testWidgets('stick FOW (D-048): 枠は下側も角丸 + ページ遷移で自動消滅', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Post plain(AccountId viewer) => Post(
          id: 'p1',
          account: viewer,
          author: UserSummary(id: 'bob', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ'),
          createdAt: DateTime(2026, 8, 28, 12),
          body: '角丸の確認です',
        );
    await tester.pumpWidget(app(posts: (v) => [plain(v)]));
    await tester.pumpAndSettle();

    // 投稿 → スレッド: 常駐 stick コンポーザー (D-050) が縮小状態で置かれる。
    await tester.tap(find.text('角丸の確認です').first);
    await tester.pumpAndSettle();

    // FOW = 角丸四角形枠: stick はフッター上にドックするので下側も丸い。
    final panel = tester.widgetList<Material>(find.byType(Material)).firstWhere((w) => w.elevation == 8);
    expect((panel.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));

    // ドラッグハンドル (D-049): 上に引くと展開段階へスナップ、
    // 大きく下げると最下段(折りたたみフィット)へ戻って止まる。
    final handle = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'サイズ変更ハンドル');
    expect(handle, findsOneWidget);
    Material fowPanel() => tester.widgetList<Material>(find.byType(Material)).firstWhere((w) => w.elevation == 8);
    double panelHeight() => tester.getSize(find.byWidget(fowPanel())).height;
    final h0 = panelHeight(); // 折りたたみフィット
    await tester.drag(handle, const Offset(0, -160));
    await tester.pumpAndSettle();
    final h1 = panelHeight();
    expect(h1, greaterThan(h0 + 80)); // 展開段階(またはそれ以上)へ
    // ドラッグしても入力中のテキストは消えない (D-050 修正)。
    await tester.enterText(find.byType(TextField).last, '消えないでね');
    await tester.pumpAndSettle();
    await tester.drag(handle, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.text('消えないでね'), findsOneWidget);
    await tester.drag(handle, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(panelHeight(), lessThan(h1)); // 最下段方向へ戻る
    expect(find.text('消えないでね'), findsOneWidget);

    // 特定ページに張り付く stick はページ遷移で自動消滅する。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.widgetWithText(FilledButton, '返信'), findsNothing);
  });

  testWidgets('常駐 stick の ✕ (D-051): メンションだけなら閉じる / 入力があれば下書き確認 → 復元', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Post plain(AccountId viewer) => Post(
          id: 'p2',
          account: viewer,
          author: UserSummary(id: 'bob', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob'), displayName: 'ボブ'),
          createdAt: DateTime(2026, 8, 29, 9),
          body: '下書きの確認です',
        );
    await tester.pumpWidget(app(posts: (v) => [plain(v)]));
    await tester.pumpAndSettle();

    // スレッドへ → 常駐 stick(縮小)。タップでメンションが自動入力される。
    await tester.tap(find.text('下書きの確認です').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(find.text('@bob '), findsOneWidget);

    // メンションだけ → キャンセルでポップアップなしに閉じ、滞在中は再表示されない。
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('書きかけの投稿があります'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    // 入り直して本文を書いてから ✕ → 確認ポップアップ → 下書きに保存。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書きの確認です').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '@bob 書きかけの返信');
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    // ポップアップ「下書きに保存しますか」(保存 / キャンセル)。キャンセルは編集に戻る。
    expect(find.text('下書きに保存しますか'), findsOneWidget);
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();
    expect(find.text('下書きに保存しますか'), findsNothing);
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    // 保存 / 変更を破棄 / キャンセル (D-177)。
    expect(find.byKey(const ValueKey('composer.close.discard')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.close.saveNew')), findsNothing); // 新規保存は開いている下書きがあるときだけ
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    // ページを出て戻っても自動では入らない (D-177): 「下書き」FOW から選んで開く。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書きの確認です').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(find.text('@bob 書きかけの返信'), findsNothing);
    expect(find.text('@bob '), findsOneWidget);
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@bob 書きかけの返信'));
    await tester.pumpAndSettle();
    expect(find.text('@bob 書きかけの返信'), findsOneWidget);
    // 開いている下書きを直してから「変更を破棄」→ 保存済みの下書きは元のまま。
    await tester.enterText(find.byType(TextField).last, '@bob 書きかけの返信 2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    expect(find.text('下書きを上書きしますか'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('composer.close.discard')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書きの確認です').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    expect(find.text('@bob 書きかけの返信'), findsOneWidget);
    expect(find.text('@bob 書きかけの返信 2'), findsNothing);
  });

  testWidgets('通常コンポーザー (D-051): 余白クリックで自動的に下書きへ入って消失 → 再オープンで復元', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    // ヘッダー (D-052): キャンセル(左)/ 投稿(太字・中央)/ 下書き(右)。
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('投稿'), findsOneWidget);
    expect(find.text('下書き'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '書きかけのノート');
    await tester.pumpAndSettle();

    // 余白(スクリム)クリック → ポップアップなしで消失(自動下書き)。
    await tester.tapAt(const Offset(20, 80));
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsNothing);
    expect(find.text('書きかけの投稿があります'), findsNothing);

    // もう一度開いても自動では入らない (D-177)。「下書き」ボタン(青文字・右揃え)→ 下書き FOW (D-176)
    // → 行をタップで開く。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    expect(find.text('書きかけのノート'), findsNothing);
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('書きかけのノート'));
    await tester.pumpAndSettle();
    expect(find.text('書きかけのノート'), findsOneWidget);
    // 「今の内容を上書き保存して閉じる」→ 下書きは 1 つのまま。
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drafts.save')));
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsNothing);
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    expect(find.text('書きかけのノート'), findsOneWidget);
  });

  testWidgets('リアクションピッカー (D-055): ヘッダー行あり・投稿のバーの複製は置かない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // ピッカーを開くのは、絵文字でリアクションできる SNS だけ (D-321)。
    await tester.pumpWidget(app(localEmojis: const {}));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    // ヘッダー行系 (D-055): 閉じる/リアクションのヘッダーがあり、
    // 「謎のアクションバー」(呼び出し元投稿の複製)はパネル内に出さない。
    expect(find.text('リアクション'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
    final panel = find.byType(EmojiPanel);
    expect(find.descendant(of: panel, matching: find.byType(RasqActionBar)), findsNothing);
  });

  test('mfmSnippet: プロパティー/フラグ/固定スニペットの組み立て', () {
    final rotate = mfmFunctions.firstWhere((f) => f.name == 'rotate');
    expect(mfmSnippet(rotate, {'deg': '30'}), (r'$[rotate.deg=30 ', ']'));
    expect(mfmSnippet(rotate, {'deg': ''}), (r'$[rotate ', ']'));

    final flip = mfmFunctions.firstWhere((f) => f.name == 'flip');
    expect(mfmSnippet(flip, {'h': 'true', 'v': 'false'}), (r'$[flip.h ', ']'));
    expect(mfmSnippet(flip, {'h': 'true', 'v': 'true'}), (r'$[flip.h,v ', ']'));

    final x2 = mfmFunctions.firstWhere((f) => f.name == 'x2');
    expect(mfmSnippet(x2, {}), (r'$[x2 ', ']'));

    final bold = markdownFunctions.firstWhere((f) => f.name == '太字');
    expect(mfmSnippet(bold, {}), ('**', '**'));
  });
}
