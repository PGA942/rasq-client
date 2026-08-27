import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Standard error block used by TL / search / store screens.
///
/// Wireframe rules: a (replaceable) image, `Error:CODE Title`, a hint line;
/// 404/408 use the compact variant; TL errors recover via pull-to-refresh.
class RasqErrorView extends StatelessWidget {
  const RasqErrorView({super.key, required this.code, this.image, this.onRetry, this.retryLabel = '見てみる', this.compact});

  final ErrorCode code;
  final Widget? image;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Force compact rendering; defaults to [ErrorCode.isCompact].
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = compact ?? code.isCompact;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(RasqSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!isCompact)
            SizedBox(
              width: 120,
              height: 120,
              child: image ??
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: scheme.onSurface)),
                    child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
                  ),
            ),
          if (!isCompact) const SizedBox(height: RasqSpacing.md),
          Text(code.display, style: RasqTypography.title.copyWith(color: scheme.onSurface), textAlign: TextAlign.center),
          if (code.message != null) ...[
            const SizedBox(height: RasqSpacing.xs),
            Text(code.message!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: RasqSpacing.lg),
            FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ]),
      ),
    );
  }
}

/// Inner-frame error (inline, inside a tile): `Error:401 Unauthorized` + hint.
class RasqInlineErrorTile extends StatelessWidget {
  const RasqInlineErrorTile({super.key, required this.code, this.onTap});
  final ErrorCode code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RasqSpacing.md),
        decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(code.display, style: RasqTypography.listTile.copyWith(color: scheme.onSurface)),
          if (code.message != null) Text(code.message!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
