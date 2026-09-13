import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_models/rasq_models.dart';

import '../features/post/post_detail_screen.dart';
import '../features/post/reactions_screen.dart';
import '../features/trend/trend_screen.dart';
import '../features/users/follows_screen.dart';
import '../features/users/user_page_screen.dart';
import '../shell/third_column.dart';
import 'router.dart';
import '../features/plugins/media_editor_screen.dart';
import '../features/plugins/pro_media_editor_screen.dart';
import '../features/plugins/slot_plugins.dart';
import 'dart:typed_data';

/// Navigation helpers shared by rows/screens.
extension RasqNavigation on BuildContext {
  /// 現在地がタブ(StatefulShellRoute)配下か。
  ///
  /// **タブ外**(リスト/クリップ/設定などアプリ直下のページ)からタブ配下の
  /// ルートを push すると、base 側と push 側で StatefulShellRoute のページ
  /// (キー = `ValueKey(route.hashCode)`)が二重マッチして
  /// `!keyReservation.contains(key)` アサーションで落ちる(実機で再現)。
  /// タブ外からはアプリ直下の複製ルート(`/post` `/user` `/trend`)へ push する。
  bool get _inTab {
    final loc = GoRouterState.of(this).matchedLocation;
    // オーバーレイ(FOW)の context はタブの状態を返すが、見えているのがアプリ直下の画面(全画面ビューワーなど)なら
    // タブ外扱いにする (D-204: ビューワーの FOW から投稿へ遷移すると二重マッチで落ちていた)。
    final visible = visibleLocationOf(GoRouter.of(this).routerDelegate.currentConfiguration);
    return _isTabLocation(loc) && _isTabLocation(visible);
  }

  /// Opens the thread screen for [post] (nested in the current tab so the
  /// global nav stays visible; タブ外ではアプリ直下ルートへ).
  void pushPost(Post post) {
    final base = _inTab ? _tabBase : '';
    final loc = '$base/post/${Uri.encodeComponent(post.id)}';
    // ペインモデル (D-057): タブレット幅では第3カラム(current)に開く。
    if (_inTab && openPageInPanes(this, id: 'post:${post.key}', title: '投稿', location: loc, extra: post, builder: (_) => PostDetailScreen(postId: post.id, initial: post))) return;
    push(loc, extra: post);
  }

  void pushReactions(Post post) {
    // 第3カラム内 (D-061): matchedLocation は第2カラムのルートを指すため、
    // entry 自身の location を基準にする(そのままだとリンクが切れる)。
    final pane = PaneScope.maybeOf(this)?.entry;
    final base = pane?.location ?? GoRouterState.of(this).matchedLocation;
    final loc = '$base/reactions';
    if ((pane != null || _inTab) && openPageInPanes(this, id: 'reactions:${post.key}', title: 'リアクション', location: loc, extra: post, builder: (_) => ReactionsScreen(postId: post.id, initial: post))) return;
    push(loc, extra: post);
  }

  String get _tabBase {
    final loc = GoRouterState.of(this).matchedLocation;
    return loc.startsWith(Routes.dm)
        ? Routes.dm
        : loc.startsWith(Routes.search)
            ? Routes.search
            : loc.startsWith(Routes.notifications)
                ? Routes.notifications
                : loc.startsWith(Routes.vc)
                    ? Routes.vc
                    : Routes.home;
  }

  void pushClip(ClipInfo clip) => push('/clips/detail', extra: clip);
  void pushUser(UserSummary user) {
    final loc = '${_inTab ? _tabBase : ''}/user/${Uri.encodeComponent(user.id)}';
    if (_inTab && openPageInPanes(this, id: 'user:${user.key}', title: user.displayName, location: loc, extra: user, builder: (_) => UserPageScreen(userId: user.id, initial: user))) return;
    push(loc, extra: user);
  }
  void pushFollows(UserSummary user, {required bool followers}) {
    final loc = '${_inTab ? _tabBase : ''}/user/${Uri.encodeComponent(user.id)}/follows${followers ? '?tab=followers' : ''}';
    if (_inTab && openPageInPanes(this, id: 'follows:${user.key}:$followers', title: followers ? 'フォロワー' : 'フォロー中', location: loc, extra: user, builder: (_) => FollowsScreen(userId: user.id, initialFollowers: followers, user: user))) return;
    push(loc, extra: user);
  }
  void pushFollowRequests() => push('${Routes.notifications}/requests');
  void pushMuteBlock() => push('${Routes.settings}/mute-block');
  void openViewer(Post post, int index) => push(Routes.viewer, extra: (post: post, index: index));

  /// プロフィールのアイコン / バナーを全画面で (D-177)。
  void openImage(Uri url, {String? title}) => push(Routes.imageViewer, extra: (url: url, title: title));

  /// メディアエディター (D-169): 全画面で加工して結果を返す(キャンセルは null)。
  Future<MediaEditResult?> pushMediaEditor({required SlotPlugin plugin, required Uint8List bytes, required String name, required String mimeType}) =>
      push<MediaEditResult>(Routes.mediaEditor, extra: MediaEditorArgs(plugin: plugin, bytes: bytes, name: name, mimeType: mimeType));

  /// 添付の加工 (D-173): 基本 = pro_image_editor、プラグインはそこからバイパス。
  Future<MediaEditResult?> pushProMediaEditor({required Uint8List bytes, required String name, required String mimeType}) =>
      push<MediaEditResult>(Routes.mediaEditorPro, extra: ProMediaEditorArgs(bytes: bytes, name: name, mimeType: mimeType));

  void pushTrend(String tag) {
    final loc = '${_inTab ? '${Routes.search}/trend' : '/trend'}/${Uri.encodeComponent(tag)}';
    if (_inTab && openPageInPanes(this, id: 'trend:$tag', title: '#$tag', location: loc, builder: (_) => TrendScreen(tag: tag))) return;
    push(loc);
  }

  /// トレンドTL上で検索を続ける(現在の結果画面を置き換える)。
  void replaceTrend(String tag) {
    // 第3カラム内 (D-061): entry を差し替える(第2カラムへは移さない)。
    if (replacePageInPane(this, id: 'trend:$tag', title: '#$tag', location: '${Routes.search}/trend/${Uri.encodeComponent(tag)}', builder: (_) => TrendScreen(tag: tag))) return;
    final loc = GoRouterState.of(this).matchedLocation;
    final base = loc.startsWith('/trend') ? '/trend' : '${Routes.search}/trend';
    pushReplacement('$base/${Uri.encodeComponent(tag)}');
  }

  void pushDmRoom(DmRoom room) => push('${Routes.dm}/room/${Uri.encodeComponent(room.peer.id)}', extra: room);
}

bool _isTabLocation(String loc) => loc.startsWith(Routes.home) || loc.startsWith(Routes.search) || loc.startsWith(Routes.vc) || loc.startsWith(Routes.notifications) || loc.startsWith(Routes.dm);

/// いま見えている画面の場所 (D-179): `RouteMatchList.uri` は push で積んだ画面を含まないので、
/// 一番上の一致(シェルの中 / 積んだ画面)まで辿る。
String visibleLocationOf(RouteMatchList config) {
  if (config.isEmpty) return '/';
  RouteMatchBase m = config.matches.last;
  while (m is ShellRouteMatch) {
    m = m.matches.last;
  }
  if (m is ImperativeRouteMatch) return visibleLocationOf(m.matches);
  return m.matchedLocation;
}

/// 履歴(積まれている画面)に [route] で始まる場所があるか (D-204: あればそこまで戻る)。
bool routeInHistory(RouteMatchList config, String route) {
  bool walk(RouteMatchBase m) {
    if (m is ImperativeRouteMatch) return m.matches.matches.any(walk);
    if (m is ShellRouteMatch) return m.matches.any(walk);
    return m.matchedLocation.startsWith(route);
  }
  return config.matches.any(walk);
}
