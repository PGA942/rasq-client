// 描画確認ハーネス (D-482): 設定の「SNSプラグイン」の節と、Misskey の「アカウント」ページ(プロフィールの文字の欄・公開範囲)を PNG に。
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/sns_settings_preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/settings/settings_section_screen.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';

/// サーバーの代わりに値を持つ Misskey のセッション(読み書きは MisskeyAccountSettings の形)。
class _MisskeySettings extends SnsSessionBase {
  Map<String, Object?> values = {
    ...MisskeyAccountSettings.defaults,
    'name': 'ゼポス',
    'description': 'RASQ で Misskey を見ています。\nよろしくお願いします。',
    'location': '東京',
    'birthday': '2000-01-31',
    'isCat': true,
    'followersVisibility': 'followers',
  };
  @override
  AccountId get account => const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'Xepos');
  @override
  String get pluginId => MisskeyPlugin.pluginId;
  @override
  Future<Map<String, Object?>> settingsRead(String area) async => values;
  @override
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) async => values = {...values, key: value};
}

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(MisskeyPlugin())),
        currentSnsSessionProvider.overrideWithValue(_MisskeySettings()),
      ],
      child: MaterialApp(theme: RasqTheme.light(), debugShowCheckedModeBanner: false, home: child),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('SNSプラグインの節', (tester) async {
    await pump(tester, const SettingsSectionScreen(sectionId: 'sns'));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('sns_settings_section.png'));
  });

  testWidgets('Misskey のアカウント: 上(プロフィール)と下(公開範囲)', (tester) async {
    await pump(tester, const SettingsDslScreen(area: 'sns.account'));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('sns_settings_misskey_account_top.png'));
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('sns_settings_misskey_account_bottom.png'));
  });
}
