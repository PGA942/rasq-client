import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// オンボーディングの ① で、住んでいる地域を選ぶ (D-542)。[code] = 国のコード(`US-CA` なら国 → 州の順に選ぶ)。
Future<void> pickOnboardingRegion(WidgetTester tester, [String code = 'JP']) async {
  final country = code.split('-').first;
  await tester.ensureVisible(find.byKey(const ValueKey('onb.region')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onb.region')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('region.search')), country);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('region.country.$country')));
  await tester.pumpAndSettle();
  if (code.contains('-')) {
    await tester.enterText(find.byKey(const ValueKey('region.search')), code.split('-').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('region.state.$code')));
    await tester.pumpAndSettle();
  }
}
