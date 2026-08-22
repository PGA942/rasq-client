import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';

void main() {
  testWidgets('app boots into home timeline and opens the sidebar via header avatar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: RasqApp()));
    await tester.pumpAndSettle();

    // Home tabs and a mock post from the timeline.
    expect(find.text('フォロー中'), findsWidgets);
    expect(find.text('ダグラス'), findsOneWidget);

    // Header avatar → sidebar (Overlay Manager, sidebar layer).
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsOneWidget);

    // Barrier tap closes the sidebar (クローズ挙動: 背面タップで閉じる).
    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    expect(find.text('全ての設定'), findsNothing);
  });

  testWidgets('tablet width switches to the 2-pane layout', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: RasqApp()));
    await tester.pumpAndSettle();
    expect(find.text('第3カラム'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
