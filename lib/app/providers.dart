import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../mock/mock_data.dart';

/// The single Overlay Manager instance. Every overlay request (app or plugin)
/// goes through it — never call `showDialog` / `showModalBottomSheet` directly.
final overlayManagerProvider = Provider<OverlayManager>((ref) {
  final m = OverlayManager();
  ref.onDispose(m.dispose);
  return m;
});

/// Currently selected (primary) account. M1 replaces this with the real
/// multi-account session store; M0 serves mock data.
final currentAccountProvider = Provider<AccountId>((ref) => MockData.accountBluesky);

/// Viewer profile for headers / sidebar.
final currentUserProvider = Provider<UserSummary>((ref) => MockData.me);

/// Theme mode (アプリの外観 → M2). Default follows the system.
final themeModeProvider = NotifierProvider<ThemeModeStore, ThemeModeSetting>(ThemeModeStore.new);

enum ThemeModeSetting { system, light, dark }

class ThemeModeStore extends Notifier<ThemeModeSetting> {
  @override
  ThemeModeSetting build() => ThemeModeSetting.system;
  void set(ThemeModeSetting v) => state = v;
}
