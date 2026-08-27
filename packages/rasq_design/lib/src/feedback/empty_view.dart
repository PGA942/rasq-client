import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Empty state (「投稿はありません」「なんにもないようです」).
class RasqEmptyView extends StatelessWidget {
  const RasqEmptyView({super.key, required this.title, this.hint, this.image, this.action});

  final String title;
  final String? hint;
  final Widget? image;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(RasqSpacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (image != null) ...[SizedBox(width: 120, height: 120, child: image), const SizedBox(height: RasqSpacing.md)],
        Text(title, style: RasqTypography.title.copyWith(color: scheme.onSurface), textAlign: TextAlign.center),
        if (hint != null) ...[const SizedBox(height: RasqSpacing.xs), Text(hint!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center)],
        if (action != null) ...[const SizedBox(height: RasqSpacing.lg), action!],
      ]),
    );
  }
}
