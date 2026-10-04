import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import 'third_column.dart';

/// ヘッダー4種 (原典: UI_Elements「ヘッダー（4種）」). All expose the same
/// 56dp height so content offsets are stable across tabs.

/// 幅の広い画面(左にナビゲーションのレールがある)か (D-429)。レールがあれば、ホーム / 通知(DM)/ 検索のヘッダーの左のアイコン
/// (アカウント、押すとサイドバー)はレールの下端へ移る(スマホのフッターメニューに当たる所)。
class RasqRailScope extends InheritedWidget {
  const RasqRailScope({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RasqRailScope>() != null;

  @override
  bool updateShouldNotify(RasqRailScope oldWidget) => false;
}

/// ヘッダーの左のアイコン。レールの中では [RasqHeaderAvatarButton] をそのまま使う。
Widget _leadingAvatar(BuildContext context, UserSummary me, VoidCallback? onTap) =>
    RasqRailScope.of(context) ? const SizedBox(width: RasqSpacing.xs) : RasqHeaderAvatarButton(me: me, onTap: onTap);

/// ホームヘッダー: avatar (opens sidebar) + VC widget + trailing chevron.
class RasqHomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqHomeHeader({super.key, required this.me, this.onAvatarTap, this.vcWidget, this.onTrailingTap, this.trailingIcon = Icons.keyboard_arrow_down, this.trailingTooltip = 'タイムライン切り替え', this.trailingKey});

  final UserSummary me;
  final VoidCallback? onAvatarTap;

  /// VCウィジェット (参加中のVC表示) — host-only slot.
  final Widget? vcWidget;
  final VoidCallback? onTrailingTap;
  final IconData trailingIcon;
  final String trailingTooltip;
  final Key? trailingKey;

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.headerHeight);

  @override
  Widget build(BuildContext context) => _HeaderBar(
        leading: _leadingAvatar(context, me, onAvatarTap),
        middle: vcWidget ?? const SizedBox.shrink(),
        middleAlignment: Alignment.centerLeft,
        trailing: RasqIconButton(key: trailingKey, icon: trailingIcon, onPressed: onTrailingTap, tooltip: trailingTooltip),
      );
}

/// しまったホームヘッダー (D-377): バーもタブ行も無く、TL の上に**浮かべて**左のアイコンと新着(AsTell / Swing、1 分だけ)だけ。
/// D-410: 右端の ↓ は無くし、**浮かべたアイコンを押すとヘッダーを戻す**(しまっている間、アイコンはサイドバーを開かない)。
class RasqFloatingHomeHeader extends StatelessWidget {
  const RasqFloatingHomeHeader({super.key, required this.me, this.arrivals, required this.onExpand});
  final UserSummary me;
  final Widget? arrivals;

  /// アイコンを押したとき(ヘッダーを戻す)。
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget float(Widget child) => Material(color: scheme.surface, elevation: 3, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: child);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: RasqSizes.headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
          child: Row(children: [
            float(Tooltip(message: 'ヘッダーを戻す', child: RasqHeaderAvatarButton(key: const ValueKey('home.header.expand'), me: me, onTap: onExpand, semanticsLabel: 'ヘッダーを戻す'))),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: arrivals ?? const SizedBox.shrink())),
          ]),
        ),
      ),
    );
  }
}

/// 通知ヘッダー: like home but no VC widget, explicit title.
class RasqNotificationHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqNotificationHeader({super.key, required this.me, this.onAvatarTap, this.onTrailingTap, this.title, this.trailing});

  final UserSummary me;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTrailingTap;
  final String? title;

  /// 右端の ↑ の代わりに置く部品(第3カラムの通知では第3カラムの設定ボタン、D-397)。
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.headerHeight);

  @override
  Widget build(BuildContext context) => _HeaderBar(
        leading: _leadingAvatar(context, me, onAvatarTap),
        middle: title == null ? const SizedBox.shrink() : Text(title!, style: RasqTypography.title),
        trailing: trailing ?? RasqIconButton(icon: Icons.keyboard_arrow_up, onPressed: onTrailingTap, tooltip: '先頭へ'),
      );
}

/// 検索ヘッダー: search bar is the main actor. Shared by 検索 and DM tabs.
class RasqSearchHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqSearchHeader({super.key, required this.me, this.onAvatarTap, this.hintText = '検索', this.controller, this.onSubmitted, this.onDropdownTap, this.onSearchTap, this.readOnly = false, this.trailing, this.focusNode});

  final UserSummary me;
  final VoidCallback? onAvatarTap;
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onDropdownTap;
  final VoidCallback? onSearchTap;
  final bool readOnly;
  final Widget? trailing;
  final FocusNode? focusNode;

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.headerHeight);

  @override
  Widget build(BuildContext context) => _HeaderBar(
        leading: _leadingAvatar(context, me, onAvatarTap),
        middle: RasqSearchBar(controller: controller, focusNode: focusNode, hintText: hintText, onSubmitted: onSubmitted, onDropdownTap: onDropdownTap, onTap: onSearchTap, readOnly: readOnly),
        middlePadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        trailing: trailing ?? const SizedBox(width: RasqSpacing.sm),
      );
}

/// ページヘッダー: 戻る＋タイトル＋`…`. Used by every sub screen.
class RasqPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqPageHeader({super.key, required this.title, this.onBack, this.onMore, this.actions = const [], this.leadingAvatar, this.leading, this.bottom, this.showMore = true});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final List<Widget> actions;

  /// 右端の … を出すか(ストアホームは … の代わりに歯車、D-353)。
  final bool showMore;

  /// Optional avatar between back and title (スレッド展開画面 / リアクション).
  final UserSummary? leadingAvatar;

  /// 戻るの右に置く任意の部品(RAi ホームのサイドバーのボタンなど、D-214)。
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(RasqSizes.headerHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    // 第3カラム内のページ (D-059): 戻りはこの < に統合される(カラム専用の
    // ヘッダー行は出さない)。長押しで「どこまで戻るか」のドロップダウン
    // (この長押し履歴は将来他の画面の < にも広げる予定)。
    final paneEntry = PaneScope.maybeOf(context)?.entry;
    final inPane = paneEntry != null && paneEntry.location != null;
    final bar = _HeaderBar(
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        // 既定の戻るは GoRouter を優先する — go_router 管理下のネスト
        // ナビゲータを直接 pop すると `!_debugLocked` アサーションで落ちる
        // ことがある(リストページ等の戻るボタン)。
        Builder(builder: (ctx) {
          return RasqActionButton.icon(
            icon: Icons.arrow_back_ios_new,
            tooltip: '戻る',
            onTap: onBack ??
                () {
                  if (inPane) return paneBackTo(ctx, paneEntry, target: paneEntry.previous);
                  final router = GoRouter.maybeOf(context);
                  if (router?.canPop() ?? false) {
                    router!.pop();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
            onLongPress: !inPane
                ? null
                : () async {
                    final box = ctx.findRenderObject() as RenderBox;
                    final anchor = box.localToGlobal(Offset.zero) & box.size;
                    final manager = ProviderScope.containerOf(ctx, listen: false).read(overlayManagerProvider);
                    final picked = await manager.showDropdown<(ThirdColumnEntry?,)>(id: 'thirdColumn.back', anchor: anchor, dense: true, items: [
                      for (final p in paneBackChain(paneEntry)) RasqDropdownItem(p.title, (p,)),
                      const RasqDropdownItem('閉じる', (null,)),
                    ]);
                    if (picked != null && ctx.mounted) paneBackTo(ctx, paneEntry, target: picked.$1);
                  },
          );
        }),
        if (leadingAvatar != null) RasqAvatar(imageUrl: leadingAvatar!.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: leadingAvatar!.displayName),
        ?leading,
      ]),
      middle: Text(title, style: RasqTypography.title, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        ...actions,
        if (showMore) RasqIconButton(icon: Icons.more_horiz, onPressed: onMore, tooltip: 'メニュー'),
      ]),
    );
    if (bottom == null) return bar;
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, bottom!]);
  }
}

/// ヘッダーの左のアカウントのアイコン(押すとサイドバー)。幅の広い画面ではナビゲーションのレールの下端にも (D-429)。
class RasqHeaderAvatarButton extends StatelessWidget {
  const RasqHeaderAvatarButton({super.key, required this.me, this.onTap, this.semanticsLabel = 'サイドバーを開く'});
  final UserSummary me;
  final VoidCallback? onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticsLabel,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: RasqSizes.minTap,
            height: RasqSizes.minTap,
            child: Center(child: RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarMd - 4, fallbackLabel: me.displayName)),
          ),
        ),
      );
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.leading, required this.middle, required this.trailing, this.middleAlignment = Alignment.center, this.middlePadding = EdgeInsets.zero});
  final Widget leading;
  final Widget middle;
  final Widget trailing;
  final Alignment middleAlignment;
  final EdgeInsets middlePadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: RasqSizes.headerHeight,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1.2))),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
          child: Row(children: [
            leading,
            Expanded(child: Padding(padding: middlePadding, child: Align(alignment: middleAlignment, child: middle))),
            trailing,
          ]),
        ),
      ),
    );
  }
}
