import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-087/D-088: サイドバーのアカウントバンドルタイル(RASQ アカウント)と
/// 総合表示 — バンドルタイル短押しで全アカウント合流の「総合」TL、個別
/// アカウント押下で現状どおりの単独表示に戻る。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);

  Post postOf(AccountId v) => Post(
      id: 'p-${v.handle}',
      account: v,
      author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle),
      createdAt: DateTime(2026, 8, 31, 10),
      body: '${v.handle} の投稿');

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('バンドルタイル短押し → 総合表示(両アカウントの投稿が合流)、個別選択で戻る', (tester) async {
    final container = await pump(tester);

    // 通常表示: 現在アカウントの投稿だけ。
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsNothing);

    // サイドバー: RASQ アカウント(素の @handle)+ アカウント行(handle@instance)。
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    Finder inSidebar(Finder f) => find.descendant(of: find.byType(RasqSidebar), matching: f);
    expect(inSidebar(find.text('@tester')), findsOneWidget); // バンドルタイル(インスタンスなし)
    expect(inSidebar(find.text('@tester@example.test')), findsOneWidget);
    expect(inSidebar(find.text('@second@example.test')), findsOneWidget);

    // ^ でアカウントリストを閉じる/開く (D-087)。
    await tester.tap(find.byTooltip('アカウントリストを隠す'));
    await tester.pumpAndSettle();
    expect(inSidebar(find.text('@second@example.test')), findsNothing);
    await tester.tap(find.byTooltip('アカウントリストを表示'));
    await tester.pumpAndSettle();

    // バンドルタイル短押し → 総合表示。タブは「総合」になり両方の投稿が流れる。
    await tester.tap(inSidebar(find.text('@tester')));
    await tester.pumpAndSettle();
    expect(container.read(bundleViewProvider), isTrue);
    expect(find.text('総合'), findsOneWidget);
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsOneWidget);

    // 個別アカウントを選ぶと総合表示を抜けてそのアカウント単独に戻る。
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(container.read(bundleViewProvider), isFalse);
    expect(container.read(currentAccountProvider), acc2);
    expect(find.text('second の投稿'), findsOneWidget);
    expect(find.text('tester の投稿'), findsNothing);
  });

  testWidgets('D-089: コンポーザーのバンドルタイルで投稿先を選ぶと、そのアカウントで送信される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = await pump(tester);
    final registry = container.read(pluginRegistryProvider);

    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();

    // バンドルタイル(RASQ アカウントの顔)をタップ → 投稿先リスト。
    await tester.tap(find.text('@tester').last);
    await tester.pumpAndSettle();
    expect(find.text('投稿先のカスタマイズ'), findsOneWidget);
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'バンドルからの投稿');
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    // second のセッションに届いている(現在アカウント tester ではなく)。
    final s2 = registry.session(session(acc2)) as FakeSnsSession;
    expect(s2.lastDraft?.text, 'バンドルからの投稿');
    final s1 = registry.session(session(acc1)) as FakeSnsSession;
    expect(s1.lastDraft, isNull);
  });

  testWidgets('アカウント行の … → ログアウトでそのアカウントが外れる', (tester) async {
    final container = await pump(tester);
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('アカウントの操作').last);
    await tester.pumpAndSettle();
    expect(find.text('このアカウントを表示'), findsOneWidget);
    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    final sessions = container.read(sessionsProvider).value!;
    expect([for (final s in sessions.sessions) s.account], [acc1]);
  });
}
