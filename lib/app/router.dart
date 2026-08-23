import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_models/rasq_models.dart';

import '../features/catalog/catalog_screen.dart';
import '../features/dm/dm_room_screen.dart';
import '../features/dm/dm_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/login/misskey_login_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/post/post_detail_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/trend/trend_screen.dart';
import '../features/vc/vc_screen.dart';
import '../shell/app_overlay_root.dart';
import '../shell/rasq_shell.dart';
import 'providers.dart';

/// Route names (keep in sync with deep links: Push通知→投稿詳細, ブックマーク等).
abstract final class Routes {
  static const home = '/home';
  static const search = '/search';
  static const vc = '/vc';
  static const notifications = '/notifications';
  static const dm = '/dm';
  static const settings = '/settings';
  static const catalog = '/catalog';
  static const login = '/login';
  static const loginMisskey = '/login/misskey';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Navigator under [AppOverlayRoot]; full-screen pages push here.
final _appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app');

/// `post/:id` — thread screen, nested under each tab so the global nav stays.
GoRoute get _postRoute => GoRoute(
      path: 'post/:id',
      builder: (_, s) => PostDetailScreen(postId: s.pathParameters['id']!, initial: s.extra is Post ? s.extra as Post : null),
    );

/// Bridges Riverpod state → GoRouter.refreshListenable.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionsProvider, (_, _) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final sessions = ref.read(sessionsProvider);
      final loc = state.matchedLocation;
      final onLogin = loc.startsWith(Routes.login);
      if (sessions.isLoading) return null; // keep splash until storage is read
      final loggedIn = sessions.value?.isLoggedIn ?? false;
      if (!loggedIn && !onLogin && loc != Routes.catalog) return Routes.login;
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _appNavigatorKey,
        builder: (context, state, child) => AppOverlayRoot(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => RasqShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen(), routes: [_postRoute])]),
              StatefulShellBranch(routes: [
                GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen(), routes: [
                  GoRoute(path: 'trend/:tag', builder: (_, s) => TrendScreen(tag: s.pathParameters['tag']!)),
                  _postRoute,
                ]),
              ]),
              StatefulShellBranch(routes: [GoRoute(path: Routes.vc, builder: (_, _) => const VcScreen())]),
              StatefulShellBranch(routes: [GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen(), routes: [_postRoute])]),
              StatefulShellBranch(routes: [
                GoRoute(path: Routes.dm, builder: (_, _) => const DmScreen(), routes: [
                  GoRoute(path: 'room/:peerId', builder: (_, s) => DmRoomScreen(peerId: s.pathParameters['peerId']!, room: s.extra is DmRoom ? s.extra as DmRoom : null)),
                  _postRoute,
                ]),
              ]),
            ],
          ),
          // Full-screen pages above the tab shell (ページヘッダー: 戻る＋タイトル＋…),
          // still below the OverlayHost.
          GoRoute(path: Routes.settings, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const SettingsScreen()),
          GoRoute(path: Routes.catalog, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const CatalogScreen()),
          GoRoute(
            path: Routes.login,
            parentNavigatorKey: _appNavigatorKey,
            builder: (_, _) => const LoginScreen(),
            routes: [GoRoute(path: 'misskey', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MisskeyLoginScreen())],
          ),
        ],
      ),
    ],
  );
});
