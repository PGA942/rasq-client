import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/compose_providers.dart';
import 'package:rasq_client/features/compose/drafts_fow.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 下書き FOW (D-176): 複数の下書き、ヘッダー「キャンセル / 下書き / 決定」、フッター「選択」→ 決定が削除に。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openComposer(WidgetTester tester) async {
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
  }

  String composerText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).last).controller!.text;

  testWidgets('保存 → 上書き / 新規 → 一覧から選んで決定で開く → 選択モードで削除', (tester) async {
    final c = await pump(tester);
    // 1 つめ: A を保存して閉じる。
    await openComposer(tester);
    await tester.enterText(find.byType(TextField).last, '下書き A');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    expect(find.byKey(draftsConfirmKey), findsNothing); // 通常モードのヘッダー右は空(選択モードで「削除」)
    expect(find.byKey(const ValueKey('drafts.save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drafts.save')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(c.read(composeDraftsProvider.notifier).list.length, 1);
    // 開き直しても自動では入らない (D-177)。B を書いて「保存して閉じる」→ 2 つになる。
    await openComposer(tester);
    expect(composerText(tester), '');
    await tester.enterText(find.byType(TextField).last, '下書き B');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drafts.saveNew')), findsNothing); // 開いている下書きが無いので 1 行
    await tester.tap(find.byKey(const ValueKey('drafts.save')));
    await tester.pumpAndSettle();
    final drafts = c.read(composeDraftsProvider.notifier).list;
    expect(drafts.length, 2);
    expect(drafts.map((d) => d.text).toSet(), {'下書き A', '下書き B'});
    // 一覧: A の行(右に >)をタップ → そのまま編集画面へ。
    await openComposer(tester);
    expect(composerText(tester), '');
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    final a = drafts.firstWhere((d) => d.text == '下書き A');
    expect(find.descendant(of: find.byKey(ValueKey('drafts.item.${a.id}')), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('drafts.item.${a.id}')));
    await tester.pumpAndSettle();
    expect(composerText(tester), '下書き A');
    expect(c.read(composeDraftsProvider.notifier).list.length, 2);
    // 選択モード: フッターの「選択」→ ヘッダーが「削除」に → B にチェック → 削除。
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(draftsSelectKey));
    await tester.pumpAndSettle();
    expect(find.text('削除'), findsOneWidget);
    final b = drafts.firstWhere((d) => d.text == '下書き B');
    await tester.tap(find.byKey(ValueKey('drafts.item.${b.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(draftsConfirmKey));
    await tester.pumpAndSettle();
    expect(c.read(composeDraftsProvider.notifier).list.map((d) => d.text), ['下書き A']);
    expect(find.byKey(draftsConfirmKey), findsNothing); // 削除後は通常モードに戻る
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();
    // キャンセル(コンポーザー)→ 開いている下書きなので「下書きを上書きしますか」
    // = 上書き / 新規保存 / 変更を破棄 / キャンセル (D-177)。
    await tester.enterText(find.byType(TextField).last, '下書き A (直した)');
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    expect(find.text('下書きを上書きしますか'), findsOneWidget);
    for (final t in ['上書き', '新規保存', '変更を破棄']) {
      expect(find.text(t), findsOneWidget);
    }
    // キャンセル = 編集に戻る。
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();
    expect(find.text('下書きを上書きしますか'), findsNothing);
    expect(composerText(tester), '下書き A (直した)');
    // 新規保存 → A は元のまま + 新しい下書き。
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新規保存'));
    await tester.pumpAndSettle();
    expect(c.read(composeDraftsProvider.notifier).list.map((d) => d.text).toSet(), {'下書き A', '下書き A (直した)'});
    // 直した方を開いて 上書き → 中身が変わる。
    await openComposer(tester);
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き A (直した)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '下書き A (さらに直した)');
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('上書き'));
    await tester.pumpAndSettle();
    expect(c.read(composeDraftsProvider.notifier).list.map((d) => d.text).toSet(), {'下書き A', '下書き A (さらに直した)'});
    // 送信すると開いている下書きだけ消える。
    await openComposer(tester);
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き A (さらに直した)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
    expect(c.read(composeDraftsProvider.notifier).list.map((d) => d.text), ['下書き A']);
  });
}
