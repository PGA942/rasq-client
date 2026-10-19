import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../shell/headers.dart';
import 'rai_stats.dart';
import '../../l10n/l10n.dart';

/// RAi のアチーブメント (D-215): サイドバーの「アチーブメント」タイルから開くページ。
/// 上に達成数、下に実績ごとの進み具合(達成は金のトロフィー)。
class RaiAchievementsScreen extends ConsumerWidget {
  const RaiAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(raiStatsProvider);
    final progress = raiAchievementProgress(stats);
    final unlocked = progress.where((p) => p.unlocked).length;
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.raiAchievementsTitle, onBack: () => Navigator.of(context).maybePop()),
      body: ListView(key: const ValueKey('rai.achievements'), padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.xs),
          child: Row(children: [
            const Icon(Icons.emoji_events, size: 32, color: RasqColors.yellow),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.raiAchievementsProgress(unlocked, progress.length), key: const ValueKey('rai.achievements.summary'), style: RasqTypography.title),
                Text(context.l10n.raiAchievementsStats(stats.instructionsAsked, stats.assistantAsked, stats.assistantAppAsked, stats.instructionsCompleted, stats.repeatedAsks), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        for (final p in progress) RaiAchievementTile(progress: p),
      ]),
    );
  }
}

/// 実績 1 つ: トロフィー / 題名 / 説明 / 進み具合。
class RaiAchievementTile extends StatelessWidget {
  const RaiAchievementTile({super.key, required this.progress});
  final RaiAchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = progress;
    return Padding(
      key: ValueKey('rai.sidebar.ach.${p.achievement.id}'),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
      child: Row(children: [
        Icon(p.unlocked ? Icons.emoji_events : Icons.emoji_events_outlined, size: 24, color: p.unlocked ? RasqColors.yellow : scheme.onSurfaceVariant),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.achievement.title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: p.unlocked ? scheme.onSurface : scheme.onSurfaceVariant))),
              Text('${math.min(p.count, p.achievement.threshold)} / ${p.achievement.threshold}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
            Text(p.achievement.description, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: p.fraction, minHeight: 4, backgroundColor: scheme.surfaceContainerHighest, color: p.unlocked ? RasqColors.yellow : RasqColors.accent),
            ),
          ]),
        ),
      ]),
    );
  }
}
