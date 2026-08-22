import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/catalog_screen.dart';
import '../features/dm/dm_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vc/vc_screen.dart';
import '../shell/rasq_shell.dart';

/// Route names (keep in sync with deep links: Push通知→投稿詳細, ブックマーク等).
abstract final class Routes {
  static const home = '/home';
  static const search = '/search';
  static const vc = '/vc';
  static const notifications = '/notifications';
  static const dm = '/dm';
  static const settings = '/settings';
  static const catalog = '/catalog';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RasqShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.vc, builder: (_, _) => const VcScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.dm, builder: (_, _) => const DmScreen())]),
        ],
      ),
      // Sub screens pushed above the shell (ページヘッダー: 戻る＋タイトル＋…).
      GoRoute(path: Routes.settings, parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.catalog, parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const CatalogScreen()),
    ],
  );
});
