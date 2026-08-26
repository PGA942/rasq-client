import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';

void main() {
  Widget wrap(SessionStorage storage, Widget child) => ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(theme: RasqTheme.light(), home: child),
      );

  testWidgets('設定DSL画面: アセットを描画し、変更が KV `<area>.v1` へ永続化される (D-031/D-035)', (tester) async {
    final storage = MemorySessionStorage();
    await tester.pumpWidget(wrap(storage, const SettingsDslScreen(area: 'appearance.motion')));
    await tester.pumpAndSettle();

    expect(find.text('モーションの抑制'), findsOneWidget);
    expect(find.text('モーションを抑制する'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final saved = jsonDecode((await storage.read('appearance.motion.v1'))!) as Map;
    expect(saved['reduceMotion'], isTrue);
  });

  testWidgets('設定DSL画面: 保存値が既定値より優先されて復元される', (tester) async {
    final storage = MemorySessionStorage({'appearance.display.v1': jsonEncode({'textScale': 120})});
    await tester.pumpWidget(wrap(storage, const SettingsDslScreen(area: 'appearance.display')));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 120);
  });

  testWidgets('設定DSL画面: 不明な area は空表示に縮退する(クラッシュしない)', (tester) async {
    await tester.pumpWidget(wrap(MemorySessionStorage(), const SettingsDslScreen(area: 'no-such-area')));
    await tester.pumpAndSettle();
    expect(find.text('設定ページを読み込めません'), findsOneWidget);
  });
}
