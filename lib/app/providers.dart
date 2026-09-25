import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

export '../session/rasq_accounts.dart';
export '../session/session_providers.dart';

/// The single Overlay Manager instance. Every overlay request (app or plugin)
/// goes through it — never call `showDialog` / `showModalBottomSheet` directly.
final overlayManagerProvider = Provider<OverlayManager>((ref) {
  final m = OverlayManager();
  ref.onDispose(m.dispose);
  return m;
});

/// 電話のアプリ(Android / iOS のネイティブ)として動いているか。Web 版(電話のブラウザでも)とデスクトップは false。
/// 既定を電話だけ変えたい設定(TL の上下の「投稿を読み込む」D-316 など)が見る。テストは差し替える
/// (flutter_test の既定の [defaultTargetPlatform] は Android)。
final mobileAppProvider = Provider<bool>((ref) => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS));

/// Theme mode (アプリの外観 → M2). Default follows the system.
final themeModeProvider = NotifierProvider<ThemeModeStore, ThemeModeSetting>(ThemeModeStore.new);

enum ThemeModeSetting { system, light, dark }

class ThemeModeStore extends Notifier<ThemeModeSetting> {
  @override
  ThemeModeSetting build() => ThemeModeSetting.system;
  void set(ThemeModeSetting v) => state = v;
}
