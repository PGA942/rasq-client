import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'avatar.dart';
import 'badge.dart';
import 'brand.dart';
import 'buttons.dart';
import 'sns_pill.dart';
import '../l10n/design_l10n.dart';

/// アイテム行コンポーネント (ユーザー版): アイコン + 名前 + @handle●SNS + 自己紹介 + フォローボタン + `…`.
/// Shared by フォロワー一覧 / ミュート一覧 / リアクション表示 / トレンドのユーザー欄.
class RasqUserRow extends StatelessWidget {
  const RasqUserRow({
    super.key,
    required this.user,
    this.following,
    this.followedBy = false,
    this.onFollowTap,
    this.onTap,
    this.onMore,
    this.leading,
    this.trailing,
    this.bio,
    this.subtitle,
  });

  final UserSummary user;

  /// null = no follow button (e.g. self).
  final bool? following;
  final bool followedBy;
  final VoidCallback? onFollowTap;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  /// Extra widget before the avatar (e.g. reaction emoji).
  final Widget? leading;

  /// Replaces the follow button when provided.
  final Widget? trailing;
  final String? bio;

  /// Small line under the handle (e.g. timestamp).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = bio ?? user.bio;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (leading != null) ...[leading!, const SizedBox(width: RasqSpacing.sm)],
          RasqAvatar(imageUrl: user.avatarUrl, size: RasqSizes.avatarLg, presence: user.presence, fallbackLabel: user.displayName),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(user.displayName, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      RasqVerifiedBadge(kind: user.verification),
                    ]),
                    Row(children: [
                      Flexible(child: Text('@${user.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 2),
                      Flexible(child: RasqSnsPill(account: user.account)),
                    ]),
                    if (followedBy) Padding(padding: const EdgeInsets.only(top: 2), child: RasqPill(label: context.designL10n.designFollowedBy)),
                    if (subtitle != null) Text(subtitle!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
                if (trailing != null)
                  trailing!
                else if (following != null)
                  RasqTogglePillButton(label: context.designL10n.designFollow, activeLabel: context.designL10n.designFollowing, active: following!, onPressed: onFollowTap),
                if (onMore != null) RasqIconButton(icon: Icons.more_horiz, size: 20, onPressed: onMore, tooltip: context.designL10n.designMenu),
              ]),
              if (text != null && text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ]),
      ),
    );
  }
}
