import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_models/rasq_models.dart';

import 'router.dart';

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
    return loc.startsWith(Routes.home) || loc.startsWith(Routes.search) || loc.startsWith(Routes.vc) || loc.startsWith(Routes.notifications) || loc.startsWith(Routes.dm);
  }

  /// Opens the thread screen for [post] (nested in the current tab so the
  /// global nav stays visible; タブ外ではアプリ直下ルートへ).
  void pushPost(Post post) {
    final base = _inTab ? _tabBase : '';
    push('$base/post/${Uri.encodeComponent(post.id)}', extra: post);
  }

  void pushReactions(Post post) {
    final loc = GoRouterState.of(this).matchedLocation;
    push('$loc/reactions', extra: post);
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
  void pushUser(UserSummary user) => push('${_inTab ? _tabBase : ''}/user/${Uri.encodeComponent(user.id)}', extra: user);
  void pushFollows(UserSummary user, {required bool followers}) => push('${_inTab ? _tabBase : ''}/user/${Uri.encodeComponent(user.id)}/follows${followers ? '?tab=followers' : ''}', extra: user);
  void pushFollowRequests() => push('${Routes.notifications}/requests');
  void pushMuteBlock() => push('${Routes.settings}/mute-block');
  void openViewer(Post post, int index) => push(Routes.viewer, extra: (post: post, index: index));

  void pushTrend(String tag) => push('${_inTab ? '${Routes.search}/trend' : '/trend'}/${Uri.encodeComponent(tag)}');

  /// トレンドTL上で検索を続ける(現在の結果画面を置き換える)。
  void replaceTrend(String tag) {
    final loc = GoRouterState.of(this).matchedLocation;
    final base = loc.startsWith('/trend') ? '/trend' : '${Routes.search}/trend';
    pushReplacement('$base/${Uri.encodeComponent(tag)}');
  }

  void pushDmRoom(DmRoom room) => push('${Routes.dm}/room/${Uri.encodeComponent(room.peer.id)}', extra: room);
}
