import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
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
    expect(find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(UserPageScreen)), findsOneWidget);
    expect(find.byType(PostDetailScreen), findsOneWidget); // 第2カラム(router)側
    expect(find.descendant(of: find.byType(ThirdColumnView), matching: find.byType(PostDetailScreen)), findsNothing);

    // 第3カラムを閉じると検索(狭)に戻り、第2カラムの投稿ページは残る。
    await tester.tap(find.byTooltip('閉じる').last);
    await tester.pumpAndSettle();
    expect(col3Width(), lessThanOrEqualTo(kSearchHomeColumnWidth + 1));
    expect(find.byType(PostDetailScreen), findsOneWidget);
  });
}
