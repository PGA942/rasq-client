@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';

/// ブラウザで動かす確認 (D-303): `flutter test --platform chrome test/web`。
///
/// RAi の 3D (three_js / flutter_angle) は Web では最初のフレームを返さず、**アプリ全体が起動しなくなった**。
/// Web では 2D で描くこと、直に 3D を作っても落ちないことを、ブラウザの中で確かめる。
void main() {
  test('Web では 3D の RAi を使わない', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(raiMascot3dProvider), isFalse);
  });

  testWidgets('RAi のマスコットは 2D で描ける(three_js を作らない)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: Center(child: RaiMascot(size: 96))))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RaiMascot), findsOneWidget);
    expect(find.byType(RaiMascot3d), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RAi ホームの画面が、例外なく開ける', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RaiHomeScreen())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(find.byType(RaiMascot3d), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
