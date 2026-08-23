import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'avatar.dart';
import 'badge.dart';
import 'brand.dart';
import 'buttons.dart';
import 'sns_pill.dart';

/// ユーザータイル（大）— ユーザーページ上部専用の独立コンポーネント
/// (原典: UI_Elements「アイコン位置ズレ時のダメージが大きいため独立」).
/// バナー・アイコン・名前・@handle●SNS・フォローされています・フォロー/編集ボタン・
/// 自己紹介・メタ情報(場所/登録日/誕生日/リンク)・フォロー中/フォロワー数.
class RasqUserTileLarge extends StatelessWidget {
  const RasqUserTileLarge({
    super.key,
    required this.profile,
    this.isSelf = false,
    this.following,
    this.followedBy = false,
    this.requested = false,
    this.onFollowTap,
    this.onEditTap,
    this.onNotifyTap,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onLinkTap,
    this.bio,
    this.restricted = false,
    this.onShowRestricted,
  });

  final UserProfile profile;
  final bool isSelf;
  final bool? following;
  final bool followedBy;
  final bool requested;
  final VoidCallback? onFollowTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onNotifyTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;
  final ValueChanged<Uri>? onLinkTap;

  /// Rich bio (RSL spans rendered by the host); falls back to plain description.
  final Widget? bio;

  /// 制限ユーザー: banner row 「⚠ このユーザーは制限されています 表示」.
  final bool restricted;
  final VoidCallback? onShowRestricted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final u = profile.summary;
    const bannerH = 120.0;
    const avatarSize = RasqSizes.avatarXl;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(
          height: bannerH,
          width: double.infinity,
          child: profile.bannerUrl == null
              ? ColoredBox(color: scheme.surfaceContainerHighest)
              : Image.network(profile.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
        ),
        Positioned(
          left: RasqSpacing.page,
          bottom: -avatarSize / 2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
            child: RasqAvatar(imageUrl: u.avatarUrl, size: avatarSize, presence: u.presence, fallbackLabel: u.displayName),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (isSelf)
            OutlinedButton(onPressed: onEditTap, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const Text('編集する'))
          else ...[
            if (onNotifyTap != null) RasqIconButton(icon: Icons.notifications_none, onPressed: onNotifyTap, tooltip: '通知'),
            if (following != null)
              RasqTogglePillButton(label: requested ? '申請中' : 'フォロー', activeLabel: 'フォロー中', active: following!, onPressed: onFollowTap, dense: false),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(u.displayName, style: RasqTypography.title, overflow: TextOverflow.ellipsis)),
            RasqVerifiedBadge(kind: u.verification, size: 18),
          ]),
          Row(children: [
            Flexible(child: Text('@${u.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 2),
            Flexible(child: RasqSnsPill(account: u.account)),
            if (followedBy) const Padding(padding: EdgeInsets.only(left: 8), child: RasqPill(label: 'フォローされています')),
          ]),
          if (restricted)
            Container(
              margin: const EdgeInsets.only(top: RasqSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
              decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: tokens.danger, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('このユーザーは制限されています。', style: RasqTypography.bodySmall)),
                TextButton(onPressed: onShowRestricted, child: const Text('表示')),
              ]),
            ),
          const SizedBox(height: RasqSpacing.sm),
          if (bio != null) bio! else if (profile.description != null && profile.description!.isNotEmpty) Text(profile.description!, style: RasqTypography.body),
          const SizedBox(height: RasqSpacing.sm),
          Wrap(spacing: 16, runSpacing: 4, children: [
            if (profile.location != null && profile.location!.isNotEmpty) _meta(Icons.place_outlined, profile.location!, scheme),
            if (profile.createdAt != null) _meta(Icons.calendar_today_outlined, '${profile.createdAt!.year}年${profile.createdAt!.month}月に登録', scheme),
            if (profile.birthday != null && profile.birthday!.isNotEmpty) _meta(Icons.cake_outlined, _birthday(profile.birthday!), scheme),
            for (final f in profile.fields)
              InkWell(
                onTap: onLinkTap == null ? null : () {
                  final uri = Uri.tryParse(f.value.trim());
                  if (uri != null && uri.hasScheme) onLinkTap!(uri);
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(f.name, style: RasqTypography.bodySmall),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_short(f.value), style: RasqTypography.bodySmall.copyWith(color: tokens.link), overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ]),
          const SizedBox(height: RasqSpacing.sm),
          Row(children: [
            if (profile.followingCount != null) _count('フォロー中', profile.followingCount!, onFollowingTap),
            const SizedBox(width: 16),
            if (profile.followersCount != null) _count('フォロワー', profile.followersCount!, onFollowersTap),
            const Spacer(),
            if (profile.postsCount != null) Text('${profile.postsCount} ノート', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: RasqSpacing.sm),
        ]),
      ),
    ]);
  }

  Widget _meta(IconData i, String t, ColorScheme s) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 16, color: s.onSurfaceVariant), const SizedBox(width: 4), Text(t, style: RasqTypography.bodySmall)]);
  Widget _count(String label, int n, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text('$n', style: RasqTypography.displayName), const SizedBox(width: 4), Text(label, style: RasqTypography.bodySmall)]),
      );

  static String _birthday(String ymd) {
    final p = ymd.split('-');
    return p.length == 3 ? '${p[0]}年${int.tryParse(p[1]) ?? p[1]}月${int.tryParse(p[2]) ?? p[2]}日' : ymd;
  }

  static String _short(String v) {
    var s = v.replaceFirst(RegExp(r'^https?://'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.length > 28 ? '${s.substring(0, 26)}…' : s;
  }
}
