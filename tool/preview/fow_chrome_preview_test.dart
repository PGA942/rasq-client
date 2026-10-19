// 描画確認ハーネス (D-479): FOW の外側のふち(見出し / ハンドルのある FOW・RAi のウィジェット)を明 / 暗のテーマで PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/fow_chrome_preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  for (final (name, theme) in [('light', RasqTheme.light()), ('dark', RasqTheme.dark())]) {
    testWidgets('見出し / ハンドルのある FOW: $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 1500);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final m = OverlayManager();
      m.showFow<void>(
        id: 'fow',
        spec: FowSpec(title: '見出しのある FOW', cancelText: 'キャンセル', confirmText: '決定', initialHeightFactor: 0.5),
        builder: (context, handle) => ListView(children: const [
          ListTile(title: Text('一行目')),
          ListTile(title: Text('二行目')),
          ListTile(title: Text('三行目')),
        ]),
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: OverlayScope(
          manager: m,
          child: OverlayHost(
            manager: m,
            child: Scaffold(body: ListView(children: [for (var i = 0; i < 12; i++) ListTile(title: Text('投稿 $i'))])),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('fow_chrome_header_$name.png'));
    });

    testWidgets('RAi のウィジェット: $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(children: [
              ListView(children: [for (var i = 0; i < 8; i++) ListTile(title: Text('投稿 $i'))]),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(RasqSpacing.sm),
                  child: RaiBar(state: const RaiState(open: true), onToggleExpanded: () {}, onMode: (_) {}, onSubmit: (_) {}, onClose: () {}, modelLabel: 'Gemma'),
                ),
              ),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('fow_chrome_rai_$name.png'));
    });
  }
}
