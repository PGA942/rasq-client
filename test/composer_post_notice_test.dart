import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 投稿の知らせ (D-500、SDK 契約 v0.25): SNS プラグインが `sns.createPost` の答えに添えた `notice` を、
/// 送った後にスナックバーで出す。複数のアカウントへ送ったときはアカウント名を添える。知らせが無ければ何も出さない。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);
  const fallback = SnsNotice(code: 'quote.fallbackUrl', message: '引用に対応していないサーバーなので、引用元の URL を付けて投稿しました');

  Post postOf(AccountId v) =>
      Post(id: 'p-${v.handle}', account: v, author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle), createdAt: DateTime(2026, 8, 31, 10), body: '${v.handle} の投稿');

  Future<PluginRegistry> pumpApp(WidgetTester tester, List<AccountId> accounts) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final a in accounts) session(a).toJson()], 'current': accounts.first.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return registry;
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
  }

  test('文: 1 アカウントなら知らせの文だけ、複数ならアカウント名を添えて行に分ける。無ければ null', () {
    expect(composePostNoticeText(const [], multi: true), isNull);
    expect(composePostNoticeText(const [('@tester@example.test', fallback)], multi: false), fallback.message);
    expect(
      composePostNoticeText(const [('@tester@example.test', fallback), ('@second@example.test', SnsNotice(code: 'x', message: '別の知らせ'))], multi: true),
      '@tester@example.test: ${fallback.message}\n@second@example.test: 別の知らせ',
    );
  });

  testWidgets('送った後に、プラグインの知らせをスナックバーで出す', (tester) async {
    final registry = await pumpApp(tester, [acc1]);
    (registry.session(session(acc1)) as FakeSnsSession).postNotice = fallback;
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    await send(tester, 'これ見て');
    expect((registry.session(session(acc1)) as FakeSnsSession).lastDraft?.text, 'これ見て');
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text(fallback.message)), findsOneWidget);
  });

  testWidgets('知らせの無いプラグイン(v0.24 以前)では何も出さない', (tester) async {
    final registry = await pumpApp(tester, [acc1]);
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    await send(tester, 'ふつうの投稿');
    expect((registry.session(session(acc1)) as FakeSnsSession).lastDraft?.text, 'ふつうの投稿');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('複数のアカウントへ送ったときは、アカウントごとにアカウント名を添える', (tester) async {
    final registry = await pumpApp(tester, [acc1, acc2]);
    (registry.session(session(acc1)) as FakeSnsSession).postNotice = fallback;
    (registry.session(session(acc2)) as FakeSnsSession).postNotice = const SnsNotice(code: 'x.y', message: '別の知らせ');
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    // 主投稿先を tester に固定 → 複数選択モードで second を「通常投稿」に。
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@tester@example.test'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('複数選択モード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('通常投稿'), findsOneWidget);
    await send(tester, '両方へ');
    expect((registry.session(session(acc2)) as FakeSnsSession).lastDraft?.text, '両方へ');
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text('@tester@example.test: ${fallback.message}\n@second@example.test: 別の知らせ')),
      findsOneWidget,
    );
  });
}
