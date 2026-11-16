import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/login/terms_sheet.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

// SNS のプラグインの規約の FOW (D-557): 見出しは題だけ、ボタンは下(「同意してログイン」/「同意して新規登録」/「キャンセル」)。

const _manifest = PluginManifest(id: 'test.sns', name: 'テスト SNS', version: '1.0.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey], termsOfService: '## 規約\n- 守ること\n### 第 1 条\n本文');

Future<OverlayManager> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late OverlayManager manager;
  await tester.pumpWidget(ProviderScope(
    child: Consumer(builder: (context, ref, _) {
      manager = ref.watch(overlayManagerProvider);
      return MaterialApp(home: OverlayScope(manager: manager, child: OverlayHost(manager: manager, child: const Scaffold(body: SizedBox.expand()))));
    }),
  ));
  return manager;
}

void main() {
  testWidgets('ログイン: 下に「同意してログイン」と「キャンセル」。見出しには同意のボタンを置かない。同意で true', (tester) async {
    final manager = await _pump(tester);
    final result = showTermsSheet(manager, _manifest);
    await tester.pumpAndSettle();
    expect(find.text('プラグインの規約'), findsOneWidget);
    expect(find.text('テスト SNS'), findsOneWidget);
    expect(find.text('同意してログイン'), findsOneWidget);
    expect(find.text('同意'), findsNothing);
    // ボタンは本文より下(FOW の下側)。
    final body = tester.getRect(find.text('本文'));
    final agree = tester.getRect(find.byKey(termsAgreeKey));
    final cancel = tester.getRect(find.byKey(termsCancelKey));
    expect(agree.top, greaterThan(body.bottom));
    expect(cancel.top, greaterThan(agree.bottom - 1));
    expect(cancel.bottom, lessThanOrEqualTo(900));
    await tester.tap(find.byKey(termsAgreeKey));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.text('プラグインの規約'), findsNothing);
  });

  testWidgets('新規登録: 「同意して新規登録」。キャンセル(下のボタン)で false', (tester) async {
    final manager = await _pump(tester);
    final result = showTermsSheet(manager, _manifest, purpose: TermsPurpose.signup);
    await tester.pumpAndSettle();
    expect(find.text('同意して新規登録'), findsOneWidget);
    expect(find.text('同意してログイン'), findsNothing);
    await tester.tap(find.byKey(termsCancelKey));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('読むだけ(設定 → 法務): 「閉じる」だけ', (tester) async {
    final manager = await _pump(tester);
    final result = showTermsSheet(manager, _manifest, purpose: TermsPurpose.view);
    await tester.pumpAndSettle();
    expect(find.byKey(termsAgreeKey), findsNothing);
    expect(find.text('閉じる'), findsOneWidget);
    await tester.tap(find.byKey(termsCancelKey));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  test('規約の無いプラグインは出さずに同意したことにする(読むだけなら false)', () async {
    final manager = OverlayManager();
    const none = PluginManifest(id: 'x', name: 'x', version: '1', kind: PluginKind.sns, supportedSns: [SnsKind.misskey]);
    expect(await showTermsSheet(manager, none), isTrue);
    expect(await showTermsSheet(manager, none, purpose: TermsPurpose.signup), isTrue);
    expect(await showTermsSheet(manager, none, purpose: TermsPurpose.view), isFalse);
  });
}
