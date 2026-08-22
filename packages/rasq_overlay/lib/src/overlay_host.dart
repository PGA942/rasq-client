import 'package:flutter/material.dart';

import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';

/// Renders the content plus every open overlay, honouring layer z-order,
/// scrims and barrier behaviour. Place it once at the root of the app shell.
class OverlayHost extends StatelessWidget {
  const OverlayHost({super.key, required this.manager, required this.child, this.scrimColor});

  final OverlayManager manager;
  final Widget child;
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final entries = manager.entries;
        return PopScope(
          canPop: !entries.any((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) manager.handleBack();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              for (final e in entries) ..._buildEntry(context, e),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildEntry(BuildContext context, RasqOverlayEntry e) {
    final widgets = <Widget>[];
    final behavior = e.effectiveBarrierBehavior;
    if (behavior != OverlayBarrierBehavior.none) {
      widgets.add(Positioned.fill(
        child: Semantics(
          label: behavior == OverlayBarrierBehavior.ignore ? null : '閉じる',
          button: behavior != OverlayBarrierBehavior.ignore,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(e.id),
            child: e.layer.hasScrim
                ? ColoredBox(color: scrimColor ?? Colors.black.withValues(alpha: 0.35))
                : const SizedBox.expand(),
          ),
        ),
      ));
    }

    final handle = manager.handleFor(e);
    Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
    if (e.semanticsLabel != null) {
      content = Semantics(label: e.semanticsLabel, container: true, child: content);
    }

    if (e.layer == OverlayLayer.dropdown && e.anchor != null) {
      widgets.add(_AnchoredDropdown(anchor: e.anchor!, child: content));
    } else {
      widgets.add(Positioned.fill(child: Align(alignment: e.alignment, child: content)));
    }
    return widgets;
  }
}

/// Positions a dropdown next to its anchor, flipping horizontally/vertically
/// when it would overflow (「スクリーン端で位置反転」).
class _AnchoredDropdown extends StatelessWidget {
  const _AnchoredDropdown({required this.anchor, required this.child});
  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final openDown = anchor.bottom + 200 <= size.height || anchor.top < size.height / 2;
      final openRight = anchor.left + 220 <= size.width;
      return Positioned(
        top: openDown ? anchor.bottom : null,
        bottom: openDown ? null : size.height - anchor.top,
        left: openRight ? anchor.left : null,
        right: openRight ? null : size.width - anchor.right,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.width * 0.8, maxHeight: size.height * 0.6),
          child: child,
        ),
      );
    });
  }
}
