import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../app/navigation.dart';
import '../app/providers.dart';
import '../app/router.dart';
import '../backend/rasq_account.dart';
import '../features/child_safe/child_safe_providers.dart' show childGateProvider;
import '../features/child_safe/child_safe_screens.dart' show ChildSafeBadge;
import '../l10n/l10n.dart';
import 'rasq_account_fow.dart';
import 'rasq_terms_gate.dart';

/// アカウントリストの開閉 (D-087: バンドルタイルの ^ ボタン)。アプリ起動中は
/// サイドバーを閉じても保持する。
class _AccountsExpanded extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final sidebarAccountsExpandedProvider = NotifierProvider<_AccountsExpanded, bool>(_AccountsExpanded.new);

/// Sidebar content (原典: UI_status「サイドバー」+ マルチアカウント化による
/// UI変更点一覧: アカウントバンドルタイル(RASQ アカウント)・^ でアカウント
/// リスト開閉・行ごとの … 操作・総合/個別の切り替え)。Shown through the
/// Overlay Manager on the `sidebar` layer (closes on barrier tap).
class RasqSidebar extends ConsumerWidget {
  const RasqSidebar({super.key, required this.handle});

  final OverlayHandle handle;

  static const String overlayId = 'app.sidebar';

  static Future<void> open(OverlayManager manager) => manager.show(RasqOverlayEntry(
        id: overlayId,
        layer: OverlayLayer.sidebar,
        alignment: Alignment.centerLeft,
        semanticsLabel: appL10n.shellSidebarSemantics,
        builder: (context, handle) => RasqSidebar(handle: handle),
      ));

  Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final manager = ref.watch(overlayManagerProvider);
    final rasq = ref.watch(rasqAccountProvider);
    final sessions = ref.watch(sessionsProvider).value ?? const SessionsState();
    final bundle = sessions.bundleView;
    final expanded = ref.watch(sidebarAccountsExpandedProvider);
    final ledger = ref.watch(rasqAccountsProvider).value ?? const RasqAccountsState();
    final others = [for (final r in ledger.accounts) if (r.id != ledger.current?.id) r];
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
                // … の左横 (D-272 → D-291): **いま使っていない RASQ アカウント**(ゲスト = 「この端末のみ」のバンドルも含む)を、2 つまで。
                // 押すと、そのアカウントに切り替える(開いたアカウントページの履歴を出すのは、やめた)。
                for (final r in others.take(2))
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Builder(builder: (context) {
                      final u = summaryOfRecord(ref, r, isCurrent: false);
                      return Tooltip(
                        message: context.l10n.shellSidebarSwitchToAccountTooltip(u.displayName),
                        child: InkWell(
                          key: ValueKey('sidebar.otherAccount.${r.id}'),
                          customBorder: const CircleBorder(),
                          onTap: () => ref.read(rasqAccountsProvider.notifier).select(r.id),
                          child: RasqAvatar(imageUrl: u.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: u.displayName),
                        ),
                      );
                    }),
                  ),
                // … = RASQ アカウントの選択/編集 FOW (D-138。D-087 のドロップ
                // ダウンは FOW 内の「SNS アカウントを追加」「アカウント設定」へ)。
                RasqIconButton(
                  icon: Icons.more_horiz,
                  tooltip: context.l10n.shellSidebarRasqAccountTooltip,
                  // サイドバーは閉じない (D-272 → D-274): FOW は、後ろを暗くしてサイドバーの上に被さって出る
                  // (1 カラム = 全幅 / 2 カラム = 左カラム、入りきらなければ 2 カラムにまたがる)。別の画面へ移るときは、サイドバーも閉じる。
                  onPressed: () => openRasqAccountFow(ref, onNavigate: handle.close, overSidebar: true),
                ),
              ]),
            ),
            // アカウントバンドルタイル (D-087): RASQ アカウント。短押しで
            // 総合表示(全アカウントの TL が「総合」に合流)、^ でリスト開閉。
            InkWell(
              onTap: () async {
                // もう総合表示なら、もう一度押すと RASQ アカウントページへ (D-272)。
                // 行き先は、いまの RASQ アカウントのページ(切り替えの直後でも、前のアカウントのページを開かない。D-316)。
                final page = ref.read(currentCentralHandleProvider);
                // 幅の広い画面では第3カラムに開く (D-425)。
                if (bundle && page != null && page.isNotEmpty) {
                  context.pushRasqAccount(page);
                  handle.close();
                  return;
                }
                await ref.read(sessionsProvider.notifier).setBundleView(true);
                handle.close();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 4),
                child: Row(children: [
                  RasqAvatar(imageUrl: rasq.avatarUrl, size: RasqSizes.avatarLg, fallbackLabel: rasq.displayName),
                  const SizedBox(width: RasqSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rasq.displayName, style: RasqTypography.title.copyWith(color: bundle ? tokens.link : null), overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Flexible(child: Text('@${rasq.account.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                        // チャイルドセーフ (D-307): 見守られているアカウント。
                        if (ref.watch(childGateProvider).supervised) ...[const SizedBox(width: 4), const ChildSafeBadge()],
                      ]),
                    ]),
                  ),
                  RasqIconButton(
                    icon: expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    tooltip: expanded ? context.l10n.shellSidebarHideAccountsTooltip : context.l10n.shellSidebarShowAccountsTooltip,
                    onPressed: () => ref.read(sidebarAccountsExpandedProvider.notifier).toggle(),
                  ),
                ]),
              ),
            ),
            // 同意待ちの RASQ アカウント (D-371)。
            const RasqTermsBanner(),
            const SizedBox(height: RasqSpacing.sm),
            // 低いウィンドウ(macOS 等)でも溢れないよう、中央部はスクロール領域。
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                // Multi-account list: 短押しで個別表示へ切り替え、… で操作。
                if (expanded) ...[
                  for (final s in sessions.sessions) _accountRow(context, ref, manager, sessions, s, bundle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
                    child: TextButton.icon(
                      onPressed: () => go(Routes.settings),
                      icon: Icon(Icons.settings, size: 18, color: tokens.link),
                      label: Text(context.l10n.shellSidebarAccountSettingsButton, style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
                    ),
                  ),
                ],
                const Divider(),
                RasqListTile(title: context.l10n.shellSidebarBookmarks, leading: const Icon(Icons.bookmark_border), chevron: false, onTap: () => go(Routes.bookmarks)),
                RasqListTile(title: context.l10n.shellSidebarLists, leading: const Icon(Icons.list_alt_outlined), chevron: false, onTap: () => go(Routes.lists)),
                // プラグインストア (M4 / D-120)。
                RasqListTile(title: context.l10n.shellSidebarPlugins, leading: const Icon(Icons.extension_outlined), chevron: false, onTap: () => go(Routes.store)),
                // カスタムプラグイン (D-357): インストール済みのページ型を開く / 招待コードで参加。
                RasqListTile(key: const ValueKey('sidebar.custom'), title: context.l10n.shellSidebarCustomPlugins, leading: const Icon(Icons.dashboard_customize_outlined), chevron: false, onTap: () => go(Routes.customPlugins)),
                RasqListTile(title: context.l10n.shellSidebarAllSettings, leading: const Icon(Icons.settings_outlined), chevron: false, onTap: () => go(Routes.settings)),
                RasqListTile(title: context.l10n.shellSidebarHelp, leading: const Icon(Icons.help_outline), chevron: false, onTap: () {}),
                // RAi ホーム (D-179): サイドメニューの下部。
                RasqListTile(key: const ValueKey('sidebar.rai'), title: 'RAi', leading: Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  // 白い頭が明るい面で消えないよう薄い下地を敷く。
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                  child: Image.asset('assets/images/rai_icon.png', semanticLabel: 'RAi'),
                ), chevron: false, onTap: () => go(Routes.rai)),
              ]),
            ),
            // 開発者向けの画面は開発者モードのときだけ (D-362)。
            if (RasqDeveloperMode.of(context)) ...[
              RasqListTile(title: context.l10n.shellSidebarDevCatalog, leading: const Icon(Icons.widgets_outlined), chevron: false, divider: false, onTap: () => go(Routes.catalog)),
              RasqListTile(title: context.l10n.shellSidebarDevWasmPlugin, leading: const Icon(Icons.extension_outlined), chevron: false, divider: false, onTap: () => go(Routes.wasmDev)),
            ],
            RasqListTile(title: context.l10n.shellSidebarWebConsole, leading: const Icon(Icons.language), chevron: false, divider: false, onTap: () {}),
          ]),
        ),
      ),
    );
  }

  Widget _accountRow(BuildContext context, WidgetRef ref, OverlayManager manager, SessionsState sessions, AccountSession s, bool bundle) {
    final selected = !bundle && s.account.key == sessions.current?.account.key;
    return InkWell(
      onTap: () async {
        // 表示中のアカウントをもう一度押すと、そのアカウントのプロフィールページへ (D-272)。
        if (selected) {
          final me = ref.read(currentUserProvider);
          handle.close();
          return context.pushUser(me);
        }
        await ref.read(sessionsProvider.notifier).setCurrent(s.account);
        handle.close();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 6),
        child: Row(children: [
          RasqSnsPill(account: s.account, showLabel: false, dotSize: 16),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text('${s.account}', style: RasqTypography.bodySmall.copyWith(fontWeight: selected ? FontWeight.w700 : null), overflow: TextOverflow.ellipsis)),
          Builder(builder: (buttonContext) {
            return RasqIconButton(
              icon: Icons.more_horiz,
              size: 18,
              tooltip: context.l10n.shellSidebarAccountActionsTooltip,
              onPressed: () async {
                final pick = await manager.showDropdown<String>(id: 'sidebar.account.${s.account.key}', anchor: _rectOf(buttonContext), dense: true, items: [
                  RasqDropdownItem(context.l10n.shellSidebarShowAccountMenu, 'show'),
                  RasqDropdownItem(context.l10n.shellSidebarLogoutMenu, 'logout', destructive: true),
                ]);
                if (pick == 'show') {
                  await ref.read(sessionsProvider.notifier).setCurrent(s.account);
                  handle.close();
                } else if (pick == 'logout') {
                  await ref.read(sessionsProvider.notifier).remove(s.account);
                }
              },
            );
          }),
        ]),
      ),
    );
  }
}
