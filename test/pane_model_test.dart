import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/emoji_panel.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/features/post/reactions_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('ペインモデル (D-057): 第2から開くと第3へ(第2は狭く)、第3から開くと旧ページが第2へ移動', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600); // 1200x800 論理
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final author = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
    Post post(AccountId viewer) => Post(id: 'p1', account: viewer, author: author, createdAt: DateTime(2026, 8, 29, 10), body: 'ペインモデルの確認');

    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    double col3Width() => tester.getSize(find.byType(ThirdColumnView)).width;
    // 空のとき第3カラムは検索ホーム幅。
    expect(col3Width(), lessThanOrEqualTo(kSearchHomeColumnWidth + 1));

    // 第2カラム(ホームTL)から投稿を開く → 第3カラムに出て広がり、第2は狭く。
    await tester.tap(find.text('ペインモデルの確認').first);
    await tester.pumpAndSettle();
    final inCol3 = find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(PostDetailScreen));
    expect(inCol3, findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // router 側には居ない
    expect(col3Width(), greaterThan(600));

    // 第3カラムのページからユーザーページを開く → 旧ページ(投稿)が第2カラム
    // (router)へ移動し、ユーザーページが第3カラムに出る。
    tester.element(inCol3).pushUser(author);
    await tester.pumpAndSettle();
    final col3 = find.byType(ThirdColumnView);
    expect(find.descendant(of: col3, matching: find.byType(UserPageScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // 第2カラム(router)側
    expect(find.descendant(of: col3, matching: find.byType(PostDetailScreen)), findsNothing);

    // カラム専用ヘッダーは無く、戻りは**ページ自身のヘッダーの <** に統合
    // (D-059)。✕ は出ない。
    expect(find.descendant(of: col3, matching: find.byTooltip('閉じる')), findsNothing);
    final backInCol3 = find.descendant(of: col3, matching: find.byTooltip('戻る'));
    expect(backInCol3, findsOneWidget);

    // < 長押し → どこまで戻るかのドロップダウン(チェーン + 閉じる)。
    await tester.longPress(backInCol3);
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsWidgets); // チェーン先頭(移した投稿ページ)
    expect(find.text('閉じる'), findsOneWidget);
    await tester.tap(find.text('投稿').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: col3, matching: find.byType(PostDetailScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // router 側の複製は消えた
    expect(find.byType(UserPageScreen), findsNothing);

    // previous の無い entry の < は「閉じる」= 検索(狭)へ。✕ は出ない。
    expect(find.descendant(of: col3, matching: find.byTooltip('閉じる')), findsNothing);
    await tester.tap(find.descendant(of: col3, matching: find.byTooltip('戻る')));
    await tester.pumpAndSettle();
    expect(col3Width(), lessThanOrEqualTo(kSearchHomeColumnWidth + 1));
    expect(find.byType(PostDetailScreen), findsNothing); // 第2カラムはホームTLのまま

    // ---- FOW の横ドッキング (D-062) -----------------------------------
    // リアクションピッカーは開いた側(第2カラム)に揃い、カラム幅に収まる。
    await tester.longPress(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsOneWidget);
    Finder fowPanel() => find.byWidgetPredicate((w) => w is Material && w.elevation == 8);
    expect(tester.getTopLeft(fowPanel()).dx, closeTo(72, 1)); // 第2カラムの左端
    expect(tester.getSize(fowPanel()).width, closeTo(1200 - 72 - kSearchHomeColumnWidth, 1));

    // FOW 内ヘッダーを掴んで右へ → 第3カラムの中心へスナップ(幅も追従)。
    await tester.drag(find.text('リアクション'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(fowPanel()).dx, closeTo(1200 - kSearchHomeColumnWidth, 1));
    expect(tester.getSize(fowPanel()).width, closeTo(kSearchHomeColumnWidth, 1));

    // さらに右の壁へ 50px 以上めり込ませる → 最大化(全幅)。
    await tester.drag(find.text('リアクション'), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(fowPanel()).width, closeTo(1200, 1));

    // ピックでリアクション実行 → 閉じる(従来どおり)。
    await tester.tap(find.descendant(of: find.byType(EmojiPanel), matching: find.text('👍')).first);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPanel), findsNothing);

    // ---- 第3カラム内の「リアクションを表示」 (D-061) ------------------
    // matchedLocation(第2カラム)基準でリンクが切れていた回帰テスト。
    await tester.tap(find.text('ペインモデルの確認').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('リアクションを表示'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: col3, matching: find.byType(ReactionsScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // 投稿ページは第2カラムへ
    // < で投稿ページを取り戻せる。
    await tester.tap(find.descendant(of: col3, matching: find.byTooltip('戻る')).first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: col3, matching: find.byType(PostDetailScreen)), findsOneWidget);
  });
}
