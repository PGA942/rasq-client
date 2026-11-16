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
import 'rich_text.dart';
import 'sns_pill.dart';
import '../platform/media_policy.dart';
import '../platform/media_image.dart';
import '../l10n/design_l10n.dart';

/// プロフィールの項目の種類 (D-560): URL・@ハンドル(`@name` / `@name@host`)はリンク、それ以外は追加情報。
enum ProfileFieldKind { link, mention, info }

final _fieldMention = RegExp(r'^@([A-Za-z0-9_][A-Za-z0-9_.-]*)(?:@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+))?$');

/// 項目の値の文字(HTML のタグを外し、前後の空白を除く)。Mastodon の項目はリンクを `<a>` で包んで返す。
String profileFieldText(String value) => value.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').trim();

/// 項目の種類と、リンクなら行き先 / @ハンドルならその名前とホスト(ホストが無ければ null = そのサーバー)。
({ProfileFieldKind kind, Uri? url, String? handle, String? host}) classifyProfileField(String value) {
  final t = profileFieldText(value);
  final m = _fieldMention.firstMatch(t);
  if (m != null) return (kind: ProfileFieldKind.mention, url: null, handle: m.group(1), host: m.group(2)?.toLowerCase());
  final u = !t.contains(RegExp(r'\s')) ? Uri.tryParse(t) : null;
  if (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.')) return (kind: ProfileFieldKind.link, url: u, handle: null, host: null);
  return (kind: ProfileFieldKind.info, url: null, handle: null, host: null);
}

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
    this.onAvatarTap,
    this.onBannerTap,
    this.nameSpans,
    this.onMentionTap,
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

  /// 名前の絵文字を描いた名前 (D-560)。null なら名前の文字のまま。
  final List<RasqSpan>? nameSpans;

  /// 項目の @ハンドルのタップ (D-560)。[host] が null ならこの人のサーバーの人。
  final void Function(String handle, String? host)? onMentionTap;

  /// アイコン / バナー画像のタップ(全画面表示、D-177)。
  final VoidCallback? onAvatarTap;
  final VoidCallback? onBannerTap;

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
          child: profile.bannerUrl == null || !rasqMediaAllowed(context, profile.bannerUrl)
              ? ColoredBox(color: scheme.surfaceContainerHighest)
              : GestureDetector(
                  onTap: onBannerTap,
                  child: Semantics(
                    button: onBannerTap != null,
                    label: context.designL10n.designProfileBanner,
                    child: Image(image: rasqMediaImage(context, profile.bannerUrl!), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
                  ),
                ),
        ),
        Positioned(
          left: RasqSpacing.page,
          bottom: -avatarSize / 2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
            child: RasqAvatar(imageUrl: u.avatarUrl, size: avatarSize, presence: u.presence, fallbackLabel: u.displayName, onTap: onAvatarTap),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (isSelf)
            OutlinedButton(onPressed: onEditTap, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)), child: Text(context.designL10n.designProfileEdit))
          else ...[
            if (onNotifyTap != null) RasqIconButton(icon: Icons.notifications_none, onPressed: onNotifyTap, tooltip: context.designL10n.designProfileNotifications),
            if (following != null)
              RasqTogglePillButton(label: requested ? context.designL10n.designFollowRequested : context.designL10n.designFollow, activeLabel: context.designL10n.designFollowing, active: following!, onPressed: onFollowTap, dense: false),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: nameSpans == null
                  ? Text(u.displayName, style: RasqTypography.title, overflow: TextOverflow.ellipsis)
                  : RasqRichText(nameSpans!, key: const ValueKey('profile.name'), style: RasqTypography.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            RasqVerifiedBadge(kind: u.verification, size: 18),
          ]),
          Row(children: [
            Flexible(child: Text('@${u.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 2),
            Flexible(child: RasqSnsPill(account: u.account)),
            if (followedBy) Padding(padding: const EdgeInsets.only(left: 8), child: RasqPill(label: context.designL10n.designFollowedBy)),
          ]),
          if (restricted)
            Container(
              margin: const EdgeInsets.only(top: RasqSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
              decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: tokens.danger, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(context.designL10n.designProfileRestricted, style: RasqTypography.bodySmall)),
                TextButton(onPressed: onShowRestricted, child: Text(context.designL10n.designProfileRestrictedShow)),
              ]),
            ),
          const SizedBox(height: RasqSpacing.sm),
          if (bio != null) bio! else if (profile.description != null && profile.description!.isNotEmpty) Text(profile.description!, style: RasqTypography.body),
          const SizedBox(height: RasqSpacing.sm),
          Wrap(spacing: 16, runSpacing: 4, children: [
            if (profile.location != null && profile.location!.isNotEmpty) _meta(Icons.place_outlined, profile.location!, scheme),
            if (profile.createdAt != null) _meta(Icons.calendar_today_outlined, context.designL10n.designProfileJoined(RasqDateFormat.yearMonth(profile.createdAt!)), scheme),
            if (profile.birthday != null && profile.birthday!.isNotEmpty) _meta(Icons.cake_outlined, _birthday(profile.birthday!), scheme),
            // リンク (D-560): URL と @ハンドルだけ。@ハンドルはその人のページを開く(ホストが無ければこの人のサーバー)。
            for (final (i, f) in profile.fields.indexed)
              if (classifyProfileField(f.value) case final c when c.kind != ProfileFieldKind.info)
                InkWell(
                  key: ValueKey('profile.field.$i'),
                  onTap: c.kind == ProfileFieldKind.link
                      ? (onLinkTap == null ? null : () => onLinkTap!(c.url!))
                      : (onMentionTap == null ? null : () => onMentionTap!(c.handle!, c.host)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(c.kind == ProfileFieldKind.link ? Icons.link : Icons.alternate_email, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(f.name, style: RasqTypography.bodySmall),
                    const SizedBox(width: 6),
                    Flexible(child: Text(c.kind == ProfileFieldKind.link ? _short(profileFieldText(f.value)) : profileFieldText(f.value), style: RasqTypography.bodySmall.copyWith(color: tokens.link), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
          ]),
          // 追加情報 (D-560): リンクでない項目は、名前と値をそのまま(押せない、リンクの色にしない)。
          if (profile.fields.any((f) => classifyProfileField(f.value).kind == ProfileFieldKind.info))
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: Column(key: const ValueKey('profile.info'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (i, f) in profile.fields.indexed)
                  if (classifyProfileField(f.value).kind == ProfileFieldKind.info)
                    Padding(
                      key: ValueKey('profile.field.$i'),
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(f.name, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: RasqSpacing.sm),
                        Expanded(child: Text(profileFieldText(f.value), style: RasqTypography.bodySmall)),
                      ]),
                    ),
              ]),
            ),
          const SizedBox(height: RasqSpacing.sm),
          Row(children: [
            ?_countOrHidden(context, 'following', context.designL10n.designFollowing, profile.followingCount, profile.followingVisibility, onFollowingTap),
            const SizedBox(width: 16),
            ?_countOrHidden(context, 'followers', context.designL10n.designFollowers, profile.followersCount, profile.followersVisibility, onFollowersTap),
            const Spacer(),
            if (profile.postsCount != null) Text(context.designL10n.designProfileNotes('${profile.postsCount}'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: RasqSpacing.sm),
        ]),
      ),
    ]);
  }

  Widget _meta(IconData i, String t, ColorScheme s) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 16, color: s.onSurfaceVariant), const SizedBox(width: 4), Text(t, style: RasqTypography.bodySmall)]);
  /// 人数 (D-560)。人数が来ないとき: 本人だけに公開なら 🔒、フォロワーにだけ公開なら ?(押せない)。どちらでもなければ出さない。
  Widget? _countOrHidden(BuildContext context, String key, String label, int? n, FollowListVisibility? visibility, VoidCallback? onTap) {
    if (n != null) return _count(label, n, onTap);
    final hidden = switch (visibility) { FollowListVisibility.private => '🔒', FollowListVisibility.followers => '?', _ => null };
    if (hidden == null) return null;
    final reason = visibility == FollowListVisibility.private ? context.designL10n.designProfileCountPrivate : context.designL10n.designProfileCountFollowersOnly;
    return Tooltip(
      message: reason,
      child: Semantics(
        label: '$label $reason',
        child: Row(key: ValueKey('profile.count.$key.hidden'), mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Text(hidden, style: RasqTypography.displayName)),
          const SizedBox(width: 4),
          ExcludeSemantics(child: Text(label, style: RasqTypography.bodySmall)),
        ]),
      ),
    );
  }

  Widget _count(String label, int n, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text('$n', style: RasqTypography.displayName), const SizedBox(width: 4), Text(label, style: RasqTypography.bodySmall)]),
      );

  /// `YYYY-MM-DD` → 表示の言語の年月日(日本語は `2000年1月5日`)。読めなければそのまま。
  static String _birthday(String ymd) {
    final p = ymd.split('-');
    final y = p.length == 3 ? int.tryParse(p[0]) : null, m = p.length == 3 ? int.tryParse(p[1]) : null, d = p.length == 3 ? int.tryParse(p[2]) : null;
    return y == null || m == null || d == null ? ymd : RasqDateFormat.yearMonthDay(DateTime(y, m, d));
  }

  static String _short(String v) {
    var s = v.replaceFirst(RegExp(r'^https?://'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.length > 28 ? '${s.substring(0, 26)}…' : s;
  }
}
