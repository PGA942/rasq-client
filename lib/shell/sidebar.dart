import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';

/// Sidebar content (原典: UI_status「サイドバー」: マルチアカウント・ブックマーク・
/// リスト・プラグイン・設定・ヘルプ・Webコンソール). Shown through the
/// Overlay Manager on the `sidebar` layer (closes on barrier tap).
class RasqSidebar extends ConsumerWidget {
  const RasqSidebar({super.key, required this.handle});

  final OverlayHandle handle;

  static const String overlayId = 'app.sidebar';

  static Future<void> open(OverlayManager manager) => manager.show(RasqOverlayEntry(
        id: overlayId,
        layer: OverlayLayer.sidebar,
        alignment: Alignment.centerLeft,
        semanticsLabel: 'サイドバー',
        builder: (context, handle) => RasqSidebar(handle: handle),
      ));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserProvider);
    final sessions = ref.watch(sessionsProvider).value ?? const SessionsState();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.sm, 0),
              child: Row(children: [
                const RasqLogo(height: 22),
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
                    Text(me.displayName, style: RasqTypography.title, overflow: TextOverflow.ellipsis),
                    Text('@${me.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const Icon(Icons.keyboard_arrow_up),
              ]),
            ),
            const SizedBox(height: RasqSpacing.sm),
            // 低いウィンドウ(macOS 等)でも溢れないよう、中央部はスクロール領域。
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
            // Multi-account switcher: tap to switch (drop-down animation is 未定).
            for (final s in sessions.sessions)
              InkWell(
                onTap: () async {
                  await ref.read(sessionsProvider.notifier).setCurrent(s.account);
                  handle.close();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 6),
                  child: Row(children: [
                    RasqSnsPill(account: s.account, showLabel: false, dotSize: 16),
                    const SizedBox(width: RasqSpacing.sm),
                    Expanded(child: Text('${s.account}', style: RasqTypography.bodySmall.copyWith(fontWeight: s.account.key == sessions.current?.account.key ? FontWeight.w700 : null), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.more_horiz, size: 18),
                  ]),
                ),
              ),
            TextButton.icon(onPressed: () => go(Routes.login), icon: const Icon(Icons.add, size: 18), label: const Text('アカウントを追加')),
            const Divider(),
            RasqListTile(title: 'ブックマーク', leading: const Icon(Icons.bookmark_border), chevron: false, onTap: () => go(Routes.bookmarks)),
            RasqListTile(title: 'リスト', leading: const Icon(Icons.list_alt_outlined), chevron: false, onTap: () => go(Routes.lists)),
            RasqListTile(title: 'プラグイン', leading: const Icon(Icons.extension_outlined), chevron: false, onTap: () {}),
            RasqListTile(title: '全ての設定', leading: const Icon(Icons.settings_outlined), chevron: false, onTap: () => go(Routes.settings)),
            RasqListTile(title: 'ヘルプ', leading: const Icon(Icons.help_outline), chevron: false, onTap: () {}),
              ]),
            ),
            RasqListTile(title: 'コンポーネントカタログ (dev)', leading: const Icon(Icons.widgets_outlined), chevron: false, divider: false, onTap: () => go(Routes.catalog)),
            RasqListTile(title: 'WASMプラグイン試験 (dev)', leading: const Icon(Icons.extension_outlined), chevron: false, divider: false, onTap: () => go(Routes.wasmDev)),
            RasqListTile(title: 'Webコンソール', leading: const Icon(Icons.language), chevron: false, divider: false, onTap: () {}),
          ]),
        ),
      ),
    );
  }
}
