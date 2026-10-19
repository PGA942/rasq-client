import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/onboarding_discover_api.dart';
import '../../l10n/l10n.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import 'onboarding_previews.dart' show showcasePlainText;
import 'showcase_genres.dart' show showcaseEligible;

/// オンボーディングの左カラム (D-414): **公開 RASQ リストの有力な投稿だけ**を縦に流す(Central §1 `GET /onboarding/feed`)。
///
/// D-412 のサーバー / リストのタイルは、まだその人のデータが無いので当たりにくかった(ユーザー判断 2026-10-03)。
/// 除外(返信 / CW / センシティブ / ボット / メンション …)と強さの順は Central。端末でも見守り (D-307) と同じ除外を重ねる。
/// 投稿にはリストの名前を付ける。押しても何も起きない(見本)。画像は読まない(枚数だけ)。
class OnboardingFeedColumn extends ConsumerWidget {
  const OnboardingFeedColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final feed = ref.watch(onboardingFeedProvider);
    final gate = ref.watch(childGateProvider);
    final items = [for (final i in feed.value?.items ?? const <OnboardingFeedItem>[]) if (showcaseEligible(i.post, gate: gate)) i];
    return Column(key: const ValueKey('onboarding.feed'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: context.l10n.onboardingFeedTitle),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
        child: Text(context.l10n.onboardingFeedCaption, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ),
      Expanded(
        child: feed.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(RasqSpacing.page),
                    child: Text(context.l10n.onboardingFeedEmpty, key: const ValueKey('onboarding.feed.empty'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xl),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: RasqSpacing.xs),
                    itemBuilder: (_, i) => OnboardingFeedCard(item: items[i]),
                  ),
      ),
    ]);
  }
}

/// 左カラムの投稿 1 件(アイコン・名前・本文 6 行まで・反応の数・リストの名前)。
class OnboardingFeedCard extends StatelessWidget {
  const OnboardingFeedCard({super.key, required this.item});
  final OnboardingFeedItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = item.post;
    final n = [...p.counts.values, ...p.reactions.values].fold<int>(0, (a, b) => a + b);
    return Container(
      key: ValueKey('onboarding.feed.${p.key}'),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          RasqAvatar(imageUrl: p.author.avatarUrl, size: 20, fallbackLabel: p.author.displayName),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(
            child: Text('${showcasePlainText(p.author.displayName)} @${p.author.account.handle}@${p.author.account.instance}',
                style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(showcasePlainText(p.body), style: RasqTypography.bodySmall, maxLines: 6, overflow: TextOverflow.ellipsis),
        const SizedBox(height: RasqSpacing.xs),
        Row(children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: RasqColors.sub.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(context.l10n.onboardingFeedListName(item.listName), style: RasqTypography.caption.copyWith(color: RasqColors.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: RasqSpacing.xs),
          if (n > 0) Text('♡ $n', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          if (p.media.isNotEmpty) Text('  ${context.l10n.onboardingShowcasePostImages(p.media.length)}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
