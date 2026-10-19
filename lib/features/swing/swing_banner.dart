import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../home/home_header.dart' show SwingAuthorBundle, swingBundleColor;
import 'swing_providers.dart';
import 'swing_viewer.dart' show openSwingViewer, swingRemainingLabel;
import '../../l10n/l10n.dart';

/// Swing の角丸バナー (D-386、検索の結果): リング付きのアイコン + 名前 + @ハンドル、右に件数 / 残り時間、下に文字。
/// 押すとその人の Swing のビューワー。
class SwingBanner extends StatelessWidget {
  const SwingBanner({super.key, required this.entry});
  final SwingAuthorEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = entry.first;
    final unseen = entry.unseen > 0;
    final text = s.text.trim().isNotEmpty ? s.text.trim() : context.l10n.swingKindSwing(s.kind.label);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('swing.banner.${s.authorAccountId}'),
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        onTap: () => openSwingViewer(context, author: s.authorAccountId),
        child: Ink(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
            gradient: LinearGradient(
              colors: [swingBundleColor.withValues(alpha: unseen ? 0.22 : 0.1), RasqColors.main.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: unseen ? swingBundleColor.withValues(alpha: 0.5) : scheme.outlineVariant),
          ),
          child: Row(children: [
            // アイコンは見た目だけ(押すのはバナー全体)。
            IgnorePointer(child: SwingAuthorBundle(swing: s, unseen: unseen, size: 40)),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(child: Text(s.author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: RasqSpacing.xs),
                  Flexible(child: Text('@${s.author.account.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text(text, style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: RasqSpacing.xs),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(unseen ? context.l10n.swingBannerNew(entry.unseen) : context.l10n.swingBannerTotal(entry.total), style: RasqTypography.caption.copyWith(color: unseen ? swingBundleColor : scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              Text(swingRemainingLabel(s.remaining(DateTime.now())), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}
