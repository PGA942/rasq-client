import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../features/plugins/slot_plugins.dart';
import '../features/settings/settings_dsl.dart';
import 'providers.dart';
import 'router.dart';

class RasqApp extends ConsumerWidget {
  const RasqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    // DSL 設定の実適用 (D-031): 表示サイズ / モーション抑制。
    // reduceMotion は MediaQuery.disableAnimations に流す — MFM の
    // spin/rainbow 等は既にこれを見て静止画に縮退する。
    final textScale = (settingValue(ref, 'appearance.display', 'textScale', 100) as num).toDouble() / 100.0;
    final reduceMotion = settingValue(ref, 'appearance.motion', 'reduceMotion', false) == true;
    return MaterialApp.router(
      title: 'RASQ',
      // スロットプラグインのトースト出口 (D-167)。
      scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
      debugShowCheckedModeBanner: false,
      // pro_image_editor (D-173) は material_ui の AppBar/Scaffold を使うので、その MaterialLocalizations も要る。
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate],
      theme: RasqTheme.light(),
      darkTheme: RasqTheme.dark(),
      themeMode: switch (mode) {
        ThemeModeSetting.system => ThemeMode.system,
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * textScale),
            disableAnimations: mq.disableAnimations || reduceMotion,
          ),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}
