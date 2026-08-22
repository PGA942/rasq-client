import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import 'providers.dart';
import 'router.dart';

class RasqApp extends ConsumerWidget {
  const RasqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'RASQ',
      debugShowCheckedModeBanner: false,
      theme: RasqTheme.light(),
      darkTheme: RasqTheme.dark(),
      themeMode: switch (mode) {
        ThemeModeSetting.system => ThemeMode.system,
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
