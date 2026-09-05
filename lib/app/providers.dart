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

/// Theme mode (アプリの外観 → M2). Default follows the system.
final themeModeProvider = NotifierProvider<ThemeModeStore, ThemeModeSetting>(ThemeModeStore.new);

enum ThemeModeSetting { system, light, dark }

class ThemeModeStore extends Notifier<ThemeModeSetting> {
  @override
  ThemeModeSetting build() => ThemeModeSetting.system;
  void set(ThemeModeSetting v) => state = v;
}
