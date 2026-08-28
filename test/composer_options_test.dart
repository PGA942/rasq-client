import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/mfm_picker_fow.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

void main() {
  late PluginRegistry registry;

  Widget app({List<Post> Function(AccountId viewer)? posts}) {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts ?? MockData.timeline));
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
    expect(find.text('ノートの作成'), findsOneWidget);

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
    await tester.tap(find.byTooltip('MFM'));
    await tester.pumpAndSettle();

    // ホーム画面: 関数名 + 説明文の縦リスト(rotate まではスクロール)
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('2倍に拡大'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('rotate'), 80, scrollable: find.descendant(of: find.byType(MfmPickerPanel), matching: find.byType(Scrollable)));
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
    await tester.tap(find.text('返信..'));
    await tester.pumpAndSettle();

    // stick FOW: ヘッダーレス(キャンセル無し)で、割り込みヘッダーに閉じる
    // ボタンとダイレクト表示が出る。
    expect(find.text('キャンセル'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('ダイレクト投稿への返信(相手にだけ届きます)'), findsOneWidget);
    // 公開範囲などのオプションはダイレクトでは出さない。
    expect(find.byTooltip('公開範囲: パブリック'), findsNothing);

    await tester.enterText(find.byType(TextField).last, '@alice 了解です');
    await tester.pumpAndSettle();
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

    // 投稿 → スレッド → 返信バーで stick コンポーザーを開く。
    await tester.tap(find.text('角丸の確認です').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('返信..'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);

    // FOW = 角丸四角形枠: stick はフッター上にドックするので下側も丸い。
    final panel = tester.widgetList<Material>(find.byType(Material)).firstWhere((w) => w.elevation == 8);
    expect((panel.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));

    // ドラッグハンドル (D-049): 上に引くと拡大(最上段より上はシームレス)、
    // 大きく下げると最下段(折りたたみフィット)へスナップして止まる。
    final handle = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'サイズ変更ハンドル');
    expect(handle, findsOneWidget);
    Material fowPanel() => tester.widgetList<Material>(find.byType(Material)).firstWhere((w) => w.elevation == 8);
    double panelHeight() => tester.getSize(find.byWidget(fowPanel())).height;
    final fitExpanded = panelHeight();
    await tester.drag(handle, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(panelHeight(), greaterThan(fitExpanded + 100));
    await tester.drag(handle, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(panelHeight(), lessThan(fitExpanded)); // 最下段(折りたたみ段階)で停止

    // 特定ページに張り付く stick はページ遷移で自動消滅する。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.widgetWithText(FilledButton, '返信'), findsNothing);
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
