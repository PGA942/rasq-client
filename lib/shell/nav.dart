import 'package:flutter/material.dart';

/// Global navigation destinations (ホーム / 検索・トレンド / AsTell / 通知 / DM).
/// Wireframe icons are custom glyphs; Material equivalents are used until the
/// icon font lands.
enum RasqNavTab {
  home('ホーム', Icons.home_outlined, Icons.home),
  search('検索', Icons.travel_explore_outlined, Icons.travel_explore),
  vc('ASTell', Icons.settings_input_antenna_outlined, Icons.settings_input_antenna),
  notifications('通知', Icons.notifications_none, Icons.notifications),
  dm('DM', Icons.mail_outline, Icons.mail);

  const RasqNavTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
