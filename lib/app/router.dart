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
import '../features/login/bluesky_login_screen.dart';
import '../features/login/mixi2_login_screen.dart';
import '../features/plugins/media_editor_screen.dart';
import '../features/plugins/pro_media_editor_screen.dart';
import '../features/settings/composer_settings_screen.dart';
import '../features/settings/legal_screen.dart';
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
import '../features/users/profile_image_viewer.dart';
import '../features/search/search_screen.dart';
import '../features/settings/action_bar_plugins_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/backend_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/store/plugin_page_screen.dart';
import '../features/store/review_timeline_screen.dart';
import '../features/store/store_home_screen.dart';
import '../features/rai/rai_achievements_screen.dart';
import '../features/rai/rai_home_screen.dart';
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

  /// プラグインボタン (D-210): 宣言されたボタンの有効 / 無効と束ねる閾値。
  static const actionBarPlugins = '/settings/actionbar-plugins';
  static const catalog = '/catalog';
  static const wasmDev = '/dev/wasm';
  static const login = '/login';

  /// 初回オンボーディング (D-138): RASQ アカウント作成の案内。
  static const onboarding = '/onboarding';
  static const viewer = '/viewer';

  /// プロフィールのアイコン / バナーの全画面表示 (D-177)。
  static const imageViewer = '/viewer/image';

  static const mediaEditor = '/media-editor';
  static const mediaEditorPro = '/media-editor/pro';
  static const lists = '/lists';
  static const bookmarks = '/bookmarks';
  static const profileEdit = '/profile/edit';

  /// RAi ホーム (D-179)。
  static const rai = '/rai';

  /// RAi のアチーブメント (D-215)。
  static const raiAchievements = '/rai/achievements';
  static const loginMisskey = '/login/misskey';
  static const loginMastodon = '/login/mastodon';
  static const loginBluesky = '/login/bluesky';
  static const loginMixi2 = '/login/mixi2';

  /// ノードプログラミング画面 (D-090)。`/nodes/<scope>`。TL スコープの
  /// キャンバスは一旦無効化 (D-121) — TL の歯車は [tlConfig] へ。
  static String nodes(String scope) => '/nodes/${Uri.encodeComponent(scope)}';

  /// タイムラインのカスタマイズ(簡略版, D-121)。`/tlconfig/<scope>`。
  static String tlConfig(String scope) => '/tlconfig/${Uri.encodeComponent(scope)}';

  /// カスタムフィードの TL (D-195: Bluesky のフィードジェネレーター)。
  static String feed(String uri) => '/feeds/${Uri.encodeComponent(uri)}';

  /// 投稿先のカスタマイズ (D-126: 完全に別ページ)。
  static const composerConfig = '/composerconfig';

  /// ヘルプ、法的表示 (D-238)。
  static const settingsLegal = '/settings/legal';

  /// プラグインストア (M4 / D-120)。
  static const store = '/store';
  static String storePlugin(String id) => '/store/plugin/${Uri.encodeComponent(id)}';

  /// レビュー TL (D-137)。
  static String storePluginReviews(String id) => '/store/plugin/${Uri.encodeComponent(id)}/reviews';
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
  ref.listen(rasqAccountsProvider, (_, _) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final sessions = ref.read(sessionsProvider);
      final ledger = ref.read(rasqAccountsProvider);
      final loc = state.matchedLocation;
      final onLogin = loc.startsWith(Routes.login);
      if (sessions.isLoading || ledger.isLoading) return null; // keep splash until storage is read
      final loggedIn = sessions.value?.isLoggedIn ?? false;
      // 未ログインでも開ける画面: カタログ/開発用、オンボーディング、接続先設定
      // (オンボーディングから Central の接続先を入れるため)。
      const open = {Routes.catalog, Routes.wasmDev, Routes.onboarding, '${Routes.settings}/server'};
      // 初回オンボーディング (D-138): 台帳が空(= 新規端末)ならまず RASQ
      // アカウント作成の案内へ。SNS ログイン済みの端末は移行で済み扱い。
      final onboardingDone = ledger.value?.onboardingDone ?? false;
      if (!onboardingDone && !loggedIn && !open.contains(loc) && !onLogin) return Routes.onboarding;
      if (!loggedIn && !onLogin && !open.contains(loc)) return Routes.login;
      if (loggedIn && loc == Routes.onboarding) return Routes.home;
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
            GoRoute(path: 'legal', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const LegalScreen()),
            // プラグインボタン (D-210): 宣言されたボタン / 束ねる閾値。
            GoRoute(path: 'actionbar-plugins', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ActionBarPluginsScreen()),
          ]),
          GoRoute(path: Routes.profileEdit, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const ProfileEditScreen()),
          GoRoute(path: Routes.rai, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const RaiHomeScreen(), routes: [
            GoRoute(path: 'achievements', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const RaiAchievementsScreen()),
          ]),
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
          GoRoute(path: '/feeds/:uri', parentNavigatorKey: _appNavigatorKey, builder: (_, s) => FeedTimelineScreen(uri: Uri.decodeComponent(s.pathParameters['uri']!), info: s.extra is FeedInfo ? s.extra as FeedInfo : null)),
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
          GoRoute(
            path: Routes.imageViewer,
            parentNavigatorKey: _appNavigatorKey,
            pageBuilder: (_, s) {
              final x = s.extra as ({Uri url, String? title});
              return CustomTransitionPage(child: ProfileImageViewerScreen(url: x.url, title: x.title), transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child));
            },
          ),
          // メディアエディター (D-169): 添付をプラグインで加工する全画面。
          GoRoute(
            path: Routes.mediaEditor,
            parentNavigatorKey: _appNavigatorKey,
            pageBuilder: (_, s) => CustomTransitionPage(child: MediaEditorScreen(args: s.extra! as MediaEditorArgs), transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child)),
          ),
          // 添付の加工 (D-173): pro_image_editor(基本)→ プラグインへバイパス。
          GoRoute(
            path: Routes.mediaEditorPro,
            parentNavigatorKey: _appNavigatorKey,
            pageBuilder: (_, s) => CustomTransitionPage(child: ProMediaEditorScreen(args: s.extra! as ProMediaEditorArgs), transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child)),
          ),
          GoRoute(path: Routes.catalog, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const CatalogScreen()),
          // プラグインストア (M4 / D-120)。
          GoRoute(path: Routes.store, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const StoreHomeScreen()),
          GoRoute(
              path: '/store/plugin/:id',
              parentNavigatorKey: _appNavigatorKey,
              builder: (_, s) => PluginPageScreen(pluginId: Uri.decodeComponent(s.pathParameters['id']!))),
          GoRoute(
              path: '/store/plugin/:id/reviews',
              parentNavigatorKey: _appNavigatorKey,
              builder: (_, s) => ReviewTimelineScreen(pluginId: Uri.decodeComponent(s.pathParameters['id']!))),
          GoRoute(path: Routes.wasmDev, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const WasmPluginScreen()),
          GoRoute(path: Routes.onboarding, parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const OnboardingScreen()),
          GoRoute(
            path: Routes.login,
            parentNavigatorKey: _appNavigatorKey,
            builder: (_, _) => const LoginScreen(),
            routes: [
              GoRoute(path: 'misskey', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MisskeyLoginScreen()),
              GoRoute(path: 'mastodon', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const MastodonLoginScreen()),
              GoRoute(path: 'bluesky', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const BlueskyLoginScreen()),
              GoRoute(path: 'mixi2', parentNavigatorKey: _appNavigatorKey, builder: (_, _) => const Mixi2LoginScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
