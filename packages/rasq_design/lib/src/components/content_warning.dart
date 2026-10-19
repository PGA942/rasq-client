import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import '../l10n/design_l10n.dart';

/// 注釈 (CW) wrapper (RRL tag `cw`): shows the warning text and a
/// 「もっと見る / 隠す」 toggle; [child] (本文・メディア) is revealed below it.
/// Open/closed is ephemeral UI state kept here (not business state); the host
/// can force the initial state with [initiallyOpen].
class RasqContentWarning extends StatefulWidget {
  const RasqContentWarning({super.key, required this.cw, required this.child, this.initiallyOpen = false});
  final String cw;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<RasqContentWarning> createState() => _RasqContentWarningState();
}

class _RasqContentWarningState extends State<RasqContentWarning> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.cw, style: RasqTypography.body),
      const SizedBox(height: 4),
      OutlinedButton(
        onPressed: () => setState(() => _open = !_open),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12), side: BorderSide(color: scheme.outline), foregroundColor: scheme.onSurface),
        child: Text(_open ? context.designL10n.designContentWarningHide : context.designL10n.designContentWarningShow),
      ),
      if (_open) ...[const SizedBox(height: RasqSpacing.sm), widget.child],
    ]);
  }
}
