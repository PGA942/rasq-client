import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Global navigation destinations (ホーム / 検索・トレンド / AsTell / 通知 / DM).
/// Wireframe icons are custom glyphs; Material equivalents are used until the
/// icon font lands.
enum RasqNavTab {
  home(Icons.home_outlined, Icons.home),
  search(Icons.travel_explore_outlined, Icons.travel_explore),
  vc(Icons.settings_input_antenna_outlined, Icons.settings_input_antenna),
  notifications(Icons.notifications_none, Icons.notifications),
  dm(Icons.mail_outline, Icons.mail);

  const RasqNavTab(this.icon, this.selectedIcon);

  String get label => switch (this) {
        RasqNavTab.home => appL10n.shellNavHome,
        RasqNavTab.search => appL10n.shellNavSearch,
        RasqNavTab.vc => 'ASTell',
        RasqNavTab.notifications => appL10n.shellNavNotifications,
        RasqNavTab.dm => 'DM',
      };

  final IconData icon;
  final IconData selectedIcon;
}
