import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/features/login/mixi2_login_screen.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/search/search_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

Widget app({bool loggedIn = true, bool bookmark = false}) {
  final storage = MemorySessionStorage(loggedIn
      ? {
          SessionsNotifier.storageKey: jsonEncode({
            'sessions': [fakeSession().toJson()],
            'current': fakeSession().account.key,
          }),
        }
      : null);
  final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline, bookmark: bookmark));
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(registry),
    ],
    child: const RasqApp(),
  );
}

void main() {
  testWidgets('ログアウトしたあとは、SNS のログインより先に RASQ アカウントのログイン画面 (D-301)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // オンボーディングは済んでいて、RASQ アカウントは無く(ログアウト後)、SNS のログインも無い端末。
    final storage = MemorySessionStorage({
      RasqAccountsNotifier.storageKey: jsonEncode({
        'accounts': [
          {'id': 'local', 'kind': 'local', 'createdAt': DateTime.now().toIso8601String(), 'sessionKeys': <String>[]},
        ],
        'current': 'local',
        'onboardingDone': true,
      }),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    // 主なボタンは「ログイン」。SNS のログイン画面は、まだ出さない。
    expect(find.text('RASQ アカウントにログインしますか?'), findsOneWidget);
    expect(find.text('SNSにログイン'), findsNothing);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('onboarding.login'))), isA<FilledButton>());
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('onboarding.create'))), isA<OutlinedButton>());
    // 「SNS アカウントだけで使う」で、これまでどおり SNS のログインへ。
    await tester.tap(find.byKey(const ValueKey('onboarding.skip')));
    await tester.pumpAndSettle();
    expect(find.text('SNSにログイン'), findsOneWidget);
  });

  testWidgets('no session → onboarding (RASQ アカウント作成) → skip → login screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(loggedIn: false));
    await tester.pumpAndSettle();
    // 初回オンボーディング (D-138 → D-414): 新規端末はまず ① のページ(ユーザー名・パスワード・年齢)。
    // サーバー未設定なので「次へ」は無効、スキップで従来のシステムへ。
    expect(find.text('RASQ アカウントを作る'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('onb.next'))).onPressed, isNull);
    await tester.tap(find.text('スキップしてこの端末だけで使う'));
    await tester.pumpAndSettle();
    expect(find.text('SNSにログイン'), findsOneWidget);
    expect(find.text('Misskeyでログイン'), findsOneWidget);

    // mixi2 は D-206 でサンプルプラグイン(ダミーモード)のログイン画面が開く。
    expect(find.text('Blueskyでログイン'), findsOneWidget);
    await tester.tap(find.text('mixi2でログイン'));
    await tester.pumpAndSettle();
    expect(find.byType(Mixi2LoginScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(Mixi2LoginScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(Mixi2LoginScreen), findsNothing);

    // Misskey → server screen → terms sheet appears through the Overlay Manager.
    await tester.tap(find.text('Misskeyでログイン'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'ログイン'), findsOneWidget);
  });

  testWidgets('session → home timeline from plugin; action updates store; sidebar opens/closes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('フォロー中'), findsWidgets);
    expect(find.text('ダグラス'), findsOneWidget);

    // Tap "リアクション" on the first post → optimistic done state.
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsOneWidget);
    expect(find.text('@tester@example.test'), findsOneWidget);

    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsNothing);
  });

  testWidgets('post → thread screen, search → trend tag → trend TL, dm → room', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Thread: tap a post body.
    await tester.tap(find.textContaining('Take off'));
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsOneWidget); // page header
    expect(find.text('返信'), findsWidgets); // 返信 row + reply bar
    expect(find.text('リアクションを表示'), findsOneWidget);

    // リアクションを表示 → sections (emoji + count), expand → user rows.
    await tester.tap(find.text('リアクションを表示'));
    await tester.pumpAndSettle();
    // 「30」は投稿内リアクションタイル (D-040) とリアクション表示欄の 2 箇所。
    expect(find.text('30'), findsWidgets);
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    expect(find.text('フォロー'), findsWidgets); // follow pill in user row
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // 常駐 stick コンポーザー (D-050): ページに戻ると縮小状態で置き直される →
    // 入力 → send → thread refreshed(送信後も閉じない)。
    expect(find.text('返信'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, '@username テスト返信');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '返信').last);
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsNothing);
    expect(find.widgetWithText(FilledButton, '返信'), findsWidgets); // 常駐で残る
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // FAB → composer (normal) with CW + poll + emoji panel toggles.
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsOneWidget); // ヘッダー中央タイトル (D-052)
    expect(find.text('下書き'), findsOneWidget); // 右揃えの下書きボタン
    await tester.tap(find.byTooltip('隠す(注釈)'));
    await tester.pumpAndSettle();
    expect(find.text('注釈..'), findsOneWidget);
    await tester.tap(find.byTooltip('投票'));
    await tester.pumpAndSettle();
    expect(find.text('回答1'), findsOneWidget);
    await tester.tap(find.byTooltip('絵文字'));
    await tester.pumpAndSettle();
    expect(find.text('デフォルト'), findsOneWidget); // 旧「全てのemoji」(D-040)
    // D-052: パネル内ヘッダーの「キャンセル」(左揃え)で閉じる。投票が入っているので
    // 「下書きに保存しますか」(D-176 改)→ 保存 で閉じる。
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('下書きに保存しますか'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsNothing);

    // Search tab → trend words from plugin → trend TL.
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    expect(find.text('打上会'), findsOneWidget);
    expect(find.text('117 Users'), findsOneWidget);
    await tester.tap(find.text('打上会'));
    await tester.pumpAndSettle();
    expect(find.text('フォロー中の反応'), findsOneWidget);
    expect(find.text('トレンド'), findsWidgets);
    expect(find.text('ダグラス'), findsWidgets); // tag timeline row(フォロー中の反応のセクションにも出る、D-442)

    // DM tab → room list → room timeline.
    await tester.tap(find.byTooltip('DM'));
    await tester.pumpAndSettle();
    expect(find.text('事故アピール'), findsWidgets);
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('都市伝説'), findsOneWidget);
  });

  testWidgets('user page, follows, notification prefs, mute/block, media viewer', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // ブックマーク一覧は、ブックマークのある SNS だけ SNS から読む (D-369)。
    await tester.pumpWidget(app(bookmark: true));
    await tester.pumpAndSettle();

    // Author name → user page (UserTileLarge) → フォロー中 count → follows screen.
    await tester.tap(find.text('ダグラス').first);
    await tester.pumpAndSettle();
    expect(find.text('56 ノート'), findsOneWidget);
    expect(find.text('フォロー中'), findsWidgets);
    await tester.tap(find.text('34'));
    await tester.pumpAndSettle();
    expect(find.text('フォロワー'), findsWidgets);
    await tester.tap(find.byTooltip('戻る').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る').first);
    await tester.pumpAndSettle();

    // Media tile → full-screen viewer (black scaffold with action bar).
    await tester.dragUntilVisible(find.byType(RasqMediaGrid).first, find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表示する').first); // reveal sensitive tile
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RasqMediaGrid).first);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // Notifications → prefs sheet.
    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('通知プロファイル設定'));
    await tester.pumpAndSettle();
    expect(find.text('リアクションを通知する'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    // Sidebar → settings → ミュート/ブロック.
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全ての設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ミュート/ブロック'));
    await tester.pumpAndSettle();
    expect(find.text('ブロック中'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // 設定第一階層 → アプリの外観.
    await tester.tap(find.text('アプリの外観'));
    await tester.pumpAndSettle();
    expect(find.text('フォントやカラースキーム'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // Sidebar → リスト → リストの中身 (ユーザー欄).
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リスト'));
    await tester.pumpAndSettle();
    expect(find.text('Fediverse Banner'), findsOneWidget);
    await tester.tap(find.text('Fediverse Banner'));
    await tester.pumpAndSettle();
    expect(find.text('外す'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    // Sidebar → ブックマーク (お気に入り).
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ブックマーク'));
    await tester.pumpAndSettle();
    expect(find.text('ダグラス'), findsOneWidget);
  });

  testWidgets('tablet width switches to the 2-pane layout', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // 第3カラム (D-056): 空のときは検索が入る(プレースホルダーではなく)。
    expect(find.byType(ThirdColumnView), findsOneWidget);
    expect(find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(SearchScreen)), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // features が補助面を開ける → タイトル + ✕、閉じると検索へ戻る。
    final ctx = tester.element(find.byType(ThirdColumnView));
    final container = ProviderScope.containerOf(ctx, listen: false);
    container.read(thirdColumnProvider.notifier).open(ThirdColumnEntry(id: 'test', title: '補助面テスト', builder: (_) => const Text('第3カラムの中身')));
    await tester.pumpAndSettle();
    expect(find.text('補助面テスト'), findsOneWidget);
    expect(find.text('第3カラムの中身'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(SearchScreen)), findsOneWidget);

    // 空時コンテンツの設定(歯車 → 表示しない)。
    await tester.tap(find.byTooltip('第3カラムの設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('表示しない'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(SearchScreen)), findsNothing);
    expect(find.text('第3カラム'), findsOneWidget); // 空ビュー
  });
}
