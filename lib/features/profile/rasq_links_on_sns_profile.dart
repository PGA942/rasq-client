import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/navigation.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../l10n/l10n.dart';
import 'rasq_account_page_screen.dart' show RasqSnsTileChip, openRasqSnsTile;

/// SNS のプロフィールに出す「RASQ アカウント」欄 (D-312)。
///
/// 見ている SNS アカウントを、公開ページに出している RASQ アカウントがあれば(本人が「SNS のプロフィールにも、
/// つないだアカウントを出す」を切っていなければ)、その RASQ アカウント(タップでアカウントページ)と、ほかにつないでいる
/// アカウントを小さく並べる。見ているアカウント自身と、自己紹介に書いてあるアカウントは重ねて出さない。
/// Central が無い / つながっていない / 読めないときは、何も出さない(欄ごと無い)。
class RasqLinksOnSnsProfile extends ConsumerWidget {
  const RasqLinksOnSnsProfile({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(rasqSnsOwnerProvider(profile.summary.account.key)).value;
    if (owner == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final muted = RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant);
    final others = snsProfileOtherAccounts(
      owner,
      viewing: profile.summary.account,
      bio: profile.description,
      extraTexts: [for (final f in profile.fields) '${f.name} ${f.value}', if (profile.url != null) profile.url.toString()],
    );
    final a = owner.account;
    // 見ている SNS アカウントを、この RASQ アカウントが持ち主として確かめているか (D-313)。
    final viewingKey = profile.summary.account.key.toLowerCase();
    final viewing = owner.snsAccounts.where((t) => t.key.toLowerCase() == viewingKey).firstOrNull;
    return Padding(
      key: const ValueKey('snsProfile.rasq'),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(context.l10n.profilePageRasqAccount, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: RasqSpacing.xs),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('snsProfile.rasq.open'),
            onTap: () => context.pushRasqAccount(a.handle),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                RasqAvatar(imageUrl: a.avatarUrl, size: 28, fallbackLabel: a.label),
                const SizedBox(width: RasqSpacing.sm),
                Flexible(child: Text(a.label, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Flexible(child: Text('@${a.handle}', style: muted, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const RasqBrandIcon(size: 14),
                if (viewing != null && viewing.verified) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.l10n.profilePageViewingVerified(viewing.verifiedLabel),
                    child: Icon(Icons.verified, key: const ValueKey('snsProfile.rasq.verified'), size: 16, color: scheme.primary, semanticLabel: context.l10n.profilePageVerifiedSemantics),
                  ),
                ],
                const Spacer(),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
        if (others.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              key: const ValueKey('snsProfile.rasq.tiles'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: RasqSpacing.sm),
              itemCount: others.length,
              separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
              itemBuilder: (_, i) => RasqSnsTileChip(tile: others[i], onTap: () => openRasqSnsTile(context, ref, others[i])),
            ),
          ),
      ]),
    );
  }
}
