import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_models/rasq_models.dart';

import '../features/catalog/catalog_screen.dart';
import '../features/dev/wasm_plugin_screen.dart';
import '../features/dm/dm_room_screen.dart';
import '../features/dm/dm_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/login/sns_login_screen.dart';
import '../features/nodeprog/composer_config_screen.dart';
import '../features/nodeprog/node_editor_screen.dart';
import '../features/nodeprog/timeline_config_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/post/post_detail_screen.dart';
import '../features/post/reactions_screen.dart';
import '../features/media/media_viewer_screen.dart';
import '../features/settings/composer_settings_screen.dart';
import '../features/settings/mute_block_screen.dart';
import '../features/settings/settings_dsl.dart';
import '../features/settings/settings_section_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/clips/clip_timeline_screen.dart';
import '../features/lists/lists_screens.dart';
import '../features/relational/relational_engine.dart';
import '../features/relational/relational_event_screen.dart';
import '../features/bookmarks/bookmarks_screen.dart';
import '../features/users/follow_requests_screen.dart';
import '../features/users/follows_screen.dart';
import '../features/users/user_page_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/backend_screen.dart';
import '../features/store/plugin_page_screen.dart';
import '../features/store/store_home_screen.dart';
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
  static const wasmDev = '/dev/wasm';
  static const login = '/login';
  static const viewer = '/viewer';
  static const lists = '/lists';
  static const bookmarks = '/bookmarks';
  static const profileEdit = '/profile/edit';
  static const loginMisskey = '/login/misskey';
  static const loginMastodon = '/login/mastodon';

  /// ノードプログラミング画面 (D-090)。`/nodes/<scope>`。TL スコープの
  /// キャンバスは一旦無効化 (D-121) — TL の歯車は [tlConfig] へ。
  static String nodes(String scope) => '/nodes/${Uri.encodeComponent(scope)}';

  /// タイムラインのカスタマイズ(簡略版, D-121)。`/tlconfig/<scope>`。
  static String tlConfig(String scope) => '/tlconfig/${Uri.encodeComponent(scope)}';

  /// 投稿先のカスタマイズ (D-126: 完全に別ページ)。
  static const composerConfig = '/composerconfig';

  /// プラグインストア (M4 / D-120)。
  static const store = '/store';
  static String storePlugin(String id) => '/store/plugin/${Uri.encodeComponent(id)}';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Navigator under [AppOverlayRoot]; full-screen pages push here.
final _appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app');

/// `post/:id` — thread screen, nested under each tab so the global nav stays.
GoRoute get _postRoute => GoRoute(
      path: 'post/:id',
      builder: (_, s) => PostDetailScreen(postId: s.pathParameters['id']!, initial: s.extra is Post ? s.extra as Post : null),
      routes: [
        GoRoute(path: 'reactions', builder: (_, s) => ReactionsScreen(postId: s.pathParameters['id']!, initial: s.extra is Post ? s.extra as Post : null)),
      ],
    );

/// `user/:id` (+ `follows`) — nested under each tab.
GoRoute get _userRoute => GoRoute(
      path: 'user/:id',
      builder: (_, s) => UserPageScreen(userId: s.pathParameters['id']!, initial: s.extra is UserSummary ? s.extra as UserSummary : null),
      routes: [
        GoRoute(
          path: 'follows',
          builder: (_, s) => FollowsScreen(userId: s.pathParameters['id']!, initialFollowers: s.uri.queryParameters['tab'] == 'followers', user: s.extra is UserSummary ? s.extra as UserSummary : null),
        ),
      ],
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
      if (!loggedIn && !onLogin && loc != Routes.catalog && loc != Routes.wasmDev) return Routes.login;
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
              StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen(), routes: [_postRoute, _userRoute])]),
              StatefulShellBranch(routes: [
                GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen(), routes: [
                  GoRoute(path: 'trend/:tag', builder: (_, s) => TrendScreen(tag: s.pathParameters['tag']!)),
                  _postRoute,
                  _userRoute,
                ]),
              ]),
              StatefulShellBranch(routes: [GoRoute(path: Routes.vc, builder: (_, _) => const VcScreen(), routes: [_postRoute, _userRoute])]),
              StatefulShellBranch(routes: [GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen(), routes: [_postRoute, _userRoute, GoRoute(path: 'requests', builder: (_, _) => const FollowRequestsScreen())])]),
              StatefulShellBranch(routes: [
                GoRoute(path: Routes.dm, builder: (_, _) => const DmScreen(), routes: [
                  GoRoute(path: 'room/:peerId', builder: (_, s) => DmRoomScreen(peerId: s.pathParameters['peerId']!, room: s.extra is DmRoom ? s.extra as DmRoom : null)),
                  _postRoute,
                  _userRoute,
                ]),
              ]),
            ],
          ),
          // Full-screen pages above the tab shell (ページヘッダー: 戻る＋タイトル＋…),
          // still below the OverlayHost.
          GoRoute(path: Routes.settings, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const SettingsScreen(), routes: [
            GoRoute(path: 'mute-block', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MuteBlockScreen()),
            GoRoute(path: 'dsl/:area', parentNavigatorKey: _appNavigatorKey, builder: (_, state) => SettingsDslScreen(area: state.pathParameters['area']!)),
            GoRoute(path: 'section/:id', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => SettingsSectionScreen(sectionId: s.pathParameters['id']!)),
            // その他の設定 → 投稿コンポーザー (D-131)。
            GoRoute(path: 'composer', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ComposerSettingsScreen()),
            GoRoute(path: 'server', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const BackendSettingsScreen()),
          ]),
          GoRoute(path: Routes.profileEdit, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ProfileEditScreen()),
          GoRoute(path: Routes.bookmarks, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const BookmarksScreen()),
          // タブ外(リスト/クリップ/設定などアプリ直下のページ)から開く
          // 投稿/ユーザー/トレンドの複製ルート (D-038)。タブ配下の同ルートを
          // タブ外から push すると StatefulShellRoute のページキーが二重に
          // なって `!keyReservation.contains(key)` で落ちるため、こちらへ。
          GoRoute(path: '/post/:id', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => PostDetailScreen(postId: s.pathParameters['id']!, initial: s.extra is Post ? s.extra as Post : null), routes: [
            GoRoute(path: 'reactions', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => ReactionsScreen(postId: s.pathParameters['id']!, initial: s.extra is Post ? s.extra as Post : null)),
          ]),
          GoRoute(path: '/user/:id', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => UserPageScreen(userId: s.pathParameters['id']!, initial: s.extra is UserSummary ? s.extra as UserSummary : null), routes: [
            GoRoute(
              path: 'follows',
              parentNavigatorKey: _appNavigatorKey,
              builder: (_, s) => FollowsScreen(userId: s.pathParameters['id']!, initialFollowers: s.uri.queryParameters['tab'] == 'followers', user: s.extra is UserSummary ? s.extra as UserSummary : null),
            ),
          ]),
          GoRoute(path: '/trend/:tag', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => TrendScreen(tag: s.pathParameters['tag']!)),
          // ノードプログラミング (D-090): TL/トレンド/投稿先のカスタマイズ。
          GoRoute(path: '/nodes/:scope', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => NodeEditorScreen(scope: Uri.decodeComponent(s.pathParameters['scope']!))),
          // TL カスタマイズの簡略版 (D-121): コンポーネント積み → グラフに
          // コンパイル。TL の歯車はこちらへ(キャンバスは一旦無効化)。
          GoRoute(path: '/tlconfig/:scope', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => TimelineConfigScreen(scope: Uri.decodeComponent(s.pathParameters['scope']!))),
          // 投稿先のカスタマイズ (D-126): 完全に別ページ(戻るで 1 つ前へ)。
          GoRoute(path: Routes.composerConfig, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ComposerConfigScreen()),
          GoRoute(path: '/clips/detail', parentNavigatorKey: _appNavigatorKey, builder: (_, state) => ClipTimelineScreen(clip: state.extra! as ClipInfo)),
          GoRoute(path: '/relational/event', parentNavigatorKey: _appNavigatorKey, builder: (_, state) => RelationalEventScreen(event: state.extra! as ConversationEvent)),
          GoRoute(path: Routes.lists, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ListsScreen(), routes: [
            GoRoute(path: 'import', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ListImportScreen()),
            GoRoute(path: ':id', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => ListDetailScreen(listId: s.pathParameters['id']!, info: s.extra is UserListInfo ? s.extra as UserListInfo : null)),
          ]),
          GoRoute(
            path: Routes.viewer,
            parentNavigatorKey: _appNavigatorKey,
            pageBuilder: (_, s) {
              final x = s.extra as ({Post post, int index});
              return CustomTransitionPage(child: MediaViewerScreen(post: x.post, initialIndex: x.index), transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child));
            },
          ),
          GoRoute(path: Routes.catalog, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const CatalogScreen()),
          // プラグインストア (M4 / D-120)。
          GoRoute(path: Routes.store, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const StoreHomeScreen()),
          GoRoute(
              path: '/store/plugin/:id',
              parentNavigatorKey: _appNavigatorKey,
              builder: (_, s) => PluginPageScreen(pluginId: Uri.decodeComponent(s.pathParameters['id']!))),
          GoRoute(path: Routes.wasmDev, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const WasmPluginScreen()),
          GoRoute(
            path: Routes.login,
            parentNavigatorKey: _appNavigatorKey,
            builder: (_, _) => const LoginScreen(),
            routes: [
              GoRoute(path: 'misskey', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MisskeyLoginScreen()),
              GoRoute(path: 'mastodon', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MastodonLoginScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
