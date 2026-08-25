import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

/// ヘッダー4種 (原典: UI_Elements「ヘッダー（4種）」). All expose the same
/// 56dp height so content offsets are stable across tabs.

/// ホームヘッダー: avatar (opens sidebar) + VC widget + trailing chevron.
class RasqHomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqHomeHeader({super.key, required this.me, this.onAvatarTap, this.vcWidget, this.onTrailingTap, this.trailingIcon = Icons.keyboard_arrow_down});

  final UserSummary me;
  final VoidCallback? onAvatarTap;

  /// VCウィジェット (参加中のVC表示) — host-only slot.
  final Widget? vcWidget;
  final VoidCallback? onTrailingTap;
  final IconData trailingIcon;

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.headerHeight);

  @override
  Widget build(BuildContext context) => _HeaderBar(
        leading: _AvatarButton(me: me, onTap: onAvatarTap),
        middle: vcWidget ?? const SizedBox.shrink(),
        middleAlignment: Alignment.centerLeft,
        trailing: RasqIconButton(icon: trailingIcon, onPressed: onTrailingTap, tooltip: 'タイムライン切り替え'),
      );
}

/// 通知ヘッダー: like home but no VC widget, explicit title.
class RasqNotificationHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqNotificationHeader({super.key, required this.me, this.onAvatarTap, this.onTrailingTap, this.title});

  final UserSummary me;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTrailingTap;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.headerHeight);

  @override
  Widget build(BuildContext context) => _HeaderBar(
        leading: _AvatarButton(me: me, onTap: onAvatarTap),
        middle: title == null ? const SizedBox.shrink() : Text(title!, style: RasqTypography.title),
        trailing: RasqIconButton(icon: Icons.keyboard_arrow_up, onPressed: onTrailingTap, tooltip: '先頭へ'),
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
        leading: _AvatarButton(me: me, onTap: onAvatarTap),
        middle: RasqSearchBar(controller: controller, focusNode: focusNode, hintText: hintText, onSubmitted: onSubmitted, onDropdownTap: onDropdownTap, onTap: onSearchTap, readOnly: readOnly),
        middlePadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        trailing: trailing ?? const SizedBox(width: RasqSpacing.sm),
      );
}

/// ページヘッダー: 戻る＋タイトル＋`…`. Used by every sub screen.
class RasqPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const RasqPageHeader({super.key, required this.title, this.onBack, this.onMore, this.actions = const [], this.leadingAvatar, this.bottom});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final List<Widget> actions;

  /// Optional avatar between back and title (スレッド展開画面 / リアクション).
  final UserSummary? leadingAvatar;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(RasqSizes.headerHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final bar = _HeaderBar(
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, onPressed: onBack ?? () => Navigator.of(context).maybePop(), tooltip: '戻る'),
        if (leadingAvatar != null) RasqAvatar(imageUrl: leadingAvatar!.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: leadingAvatar!.displayName),
      ]),
      middle: Text(title, style: RasqTypography.title, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        ...actions,
        RasqIconButton(icon: Icons.more_horiz, onPressed: onMore, tooltip: 'メニュー'),
      ]),
    );
    if (bottom == null) return bar;
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, bottom!]);
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.me, this.onTap});
  final UserSummary me;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'サイドバーを開く',
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
