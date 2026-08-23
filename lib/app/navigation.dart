import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_models/rasq_models.dart';

import 'router.dart';

/// Navigation helpers shared by rows/screens.
extension RasqNavigation on BuildContext {
  /// Opens the thread screen for [post] (nested in the current tab so the
  /// global nav stays visible).
  void pushPost(Post post) {
    final loc = GoRouterState.of(this).matchedLocation;
    final base = loc.startsWith(Routes.dm)
        ? Routes.dm
        : loc.startsWith(Routes.search)
            ? Routes.search
            : loc.startsWith(Routes.notifications)
                ? Routes.notifications
                : Routes.home;
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

  void pushUser(UserSummary user) => push('$_tabBase/user/${Uri.encodeComponent(user.id)}', extra: user);
  void pushFollows(UserSummary user, {required bool followers}) => push('$_tabBase/user/${Uri.encodeComponent(user.id)}/follows${followers ? '?tab=followers' : ''}', extra: user);
  void pushFollowRequests() => push('${Routes.notifications}/requests');
  void pushMuteBlock() => push('${Routes.settings}/mute-block');
  void openViewer(Post post, int index) => push(Routes.viewer, extra: (post: post, index: index));

  void pushTrend(String tag) => push('${Routes.search}/trend/${Uri.encodeComponent(tag)}');

  void pushDmRoom(DmRoom room) => push('${Routes.dm}/room/${Uri.encodeComponent(room.peer.id)}', extra: room);
}
