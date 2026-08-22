import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/router.dart';

/// Sidebar content (原典: UI_status「サイドバー」: マルチアカウント・ブックマーク・
/// リスト・プラグイン・設定・ヘルプ・Webコンソール). Shown through the
/// Overlay Manager on the `sidebar` layer (closes on barrier tap).
class RasqSidebar extends StatelessWidget {
  const RasqSidebar({super.key, required this.me, required this.accounts, required this.handle, this.onAccountSettings});

  final UserSummary me;
  final List<AccountId> accounts;
  final OverlayHandle handle;
  final VoidCallback? onAccountSettings;

  static const String overlayId = 'app.sidebar';

  static Future<void> open(OverlayManager manager, {required UserSummary me, required List<AccountId> accounts}) => manager.show(RasqOverlayEntry(
        id: overlayId,
        layer: OverlayLayer.sidebar,
        alignment: Alignment.centerLeft,
        semanticsLabel: 'サイドバー',
        builder: (context, handle) => RasqSidebar(me: me, accounts: accounts, handle: handle),
      ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = (MediaQuery.sizeOf(context).width * 0.78).clamp(240.0, 340.0);
    void go(String route) {
      handle.close();
      context.push(route);
    }

    return Material(
      color: scheme.surface,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Account header: avatar + name + chevron, sub-accounts, account settings.
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.sm, 0),
              child: Row(children: [
                const Spacer(),
                RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: me.displayName),
                RasqIconButton(icon: Icons.more_horiz, onPressed: () {}, tooltip: 'その他'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Row(children: [
                RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarLg, fallbackLabel: me.displayName),
                const SizedBox(width: RasqSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.displayName, style: RasqTypography.title),
                    Text('@${me.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
                const Icon(Icons.keyboard_arrow_up),
              ]),
            ),
            const SizedBox(height: RasqSpacing.sm),
            for (final a in accounts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 2),
                child: Row(children: [
                  RasqSnsPill(account: a, showLabel: false, dotSize: 16),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text('$a', style: RasqTypography.bodySmall, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.more_horiz, size: 18),
                ]),
              ),
            TextButton.icon(onPressed: onAccountSettings, icon: const Icon(Icons.settings, size: 18), label: const Text('アカウントの設定')),
            const Divider(),
            RasqListTile(title: 'ブックマーク', leading: const Icon(Icons.bookmark_border), chevron: false, onTap: () {}),
            RasqListTile(title: 'リスト', leading: const Icon(Icons.list_alt_outlined), chevron: false, onTap: () {}),
            RasqListTile(title: 'プラグイン', leading: const Icon(Icons.extension_outlined), chevron: false, onTap: () {}),
            RasqListTile(title: '全ての設定', leading: const Icon(Icons.settings_outlined), chevron: false, onTap: () => go(Routes.settings)),
            RasqListTile(title: 'ヘルプ', leading: const Icon(Icons.help_outline), chevron: false, onTap: () {}),
            const Spacer(),
            RasqListTile(title: 'コンポーネントカタログ (dev)', leading: const Icon(Icons.widgets_outlined), chevron: false, divider: false, onTap: () => go(Routes.catalog)),
            RasqListTile(title: 'Webコンソール', leading: const Icon(Icons.language), chevron: false, divider: false, onTap: () {}),
          ]),
        ),
      ),
    );
  }
}
