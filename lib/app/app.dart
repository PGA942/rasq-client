import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:material_ui/material_ui.dart' as mui;

import '../backend/test_endpoints.dart';
import '../features/home/reaction_history.dart';
import '../features/plugins/slot_plugins.dart';
import '../features/media/video_player.dart' show VideoPrefs;
import '../features/settings/developer_mode.dart';
import '../features/settings/settings_dsl.dart';
import '../features/store/plugin_updates.dart' show pluginAutoUpdateProvider;
import '../features/theme/theme_packs.dart';
import '../notify/central_inbox.dart';
import 'providers.dart';
import 'router.dart';

class RasqApp extends ConsumerWidget {
  const RasqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Central の受信箱 (D-309): 起動 / アプリへ戻ったとき / ログインの変化で 1 回ずつ読み、`child_safe` などを受け手へ。
    ref.watch(centralInboxProvider);
    // プラグインのアップデート (D-356): 起動後に 1 回、設定どおりに。
    ref.watch(pluginAutoUpdateProvider);
    // テスト用の接続先 (D-360): 設定を SNS の接続先の差し替えに反映。
    ref.watch(testEndpointsSyncProvider);
    final developerMode = ref.watch(developerModeProvider);
    final mode = ref.watch(themeModeProvider);
    final skin = ref.watch(activeSkinProvider);
    // DSL 設定の実適用 (D-031): 表示サイズ / モーション抑制。
    // reduceMotion は MediaQuery.disableAnimations に流す — MFM の
    // spin/rainbow 等は既にこれを見て静止画に縮退する。
    final textScale = (settingValue(ref, 'appearance.display', 'textScale', 100) as num).toDouble() / 100.0;
    final reduceMotion = settingValue(ref, 'appearance.motion', 'reduceMotion', false) == true;
    // MFM の動き / 動画の既定 (D-238): 描画側の静的な設定へ流す。
    final mfm = (enabled: settingValue(ref, 'appearance.mfm', 'animations', true) != false, speed: ((settingValue(ref, 'appearance.mfm', 'speed', 100) as num).toDouble() / 100.0).clamp(0.25, 4.0));
    if (RasqMfmTransform.motion.value != mfm) WidgetsBinding.instance.addPostFrameCallback((_) => RasqMfmTransform.motion.value = mfm);
    ReactionPrefs.predictWhenEmpty = settingValue(ref, reactionSettingsArea, 'predictWhenEmpty', false) == true;
    VideoPrefs.autoplay = settingValue(ref, 'appearance.video', 'autoplay', true) != false;
    VideoPrefs.defaultSpeed = double.tryParse('${settingValue(ref, 'appearance.video', 'defaultSpeed', '1.0')}') ?? 1.0;
    VideoPrefs.pipKeepPosition = settingValue(ref, 'appearance.video', 'pipKeepPosition', true) != false;
    return MaterialApp.router(
      title: 'RASQ',
      // スロットプラグインのトースト出口 (D-167)。
      scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
      debugShowCheckedModeBanner: false,
      // pro_image_editor (D-173) は material_ui の AppBar/Scaffold を使うので、その MaterialLocalizations も要る。
      // iOS / macOS では閉じるときの確認が cupertino_ui のダイアログ(showAdaptiveDialog)になるので、その
      // CupertinoLocalizations も要る (D-253: 無いと × / 戻るで例外になり、閉じられなかった)。
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate, cui.DefaultCupertinoLocalizations.delegate],
      // 着せ替え (D-335): 色の上書き(効く明るさだけ)。面とアイコンは RasqSkinScope 経由で各部品が描く。
      theme: skin?.applyTo(RasqTheme.light()) ?? RasqTheme.light(),
      darkTheme: skin?.applyTo(RasqTheme.dark()) ?? RasqTheme.dark(),
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
          // 着せ替え (D-335): アプリの一番下に `app` の面(背景色 + 画像のレイヤー。Scaffold は透明になっている)。
          // 開発者モード (D-362): 部品が細かい説明を出すかを読む。
          child: RasqDeveloperMode(enabled: developerMode, child: RasqSkinScope(skin: skin, child: RasqSkinned(surface: RasqSkinSurfaceId.app, child: child!))),
        );
      },
      routerConfig: router,
    );
  }
}
