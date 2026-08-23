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

  void pushTrend(String tag) => push('${Routes.search}/trend/${Uri.encodeComponent(tag)}');

  void pushDmRoom(DmRoom room) => push('${Routes.dm}/room/${Uri.encodeComponent(room.peer.id)}', extra: room);
}
