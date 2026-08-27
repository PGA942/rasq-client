import 'package:flutter/material.dart';

import 'fow.dart';
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
              for (final e in entries)
                if (e.layer == OverlayLayer.fow) ...[
                  // FOW group is rendered once, at the position of the first FOW entry.
                  if (entries.firstWhere((x) => x.layer == OverlayLayer.fow) == e) ..._buildFowGroup(context, entries.where((x) => x.layer == OverlayLayer.fow).toList()),
                ] else
                  ..._buildEntry(context, e),
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

  /// FOWs dock to the bottom as a bottom-up column: newest at the bottom.
  /// A scrim is painted once, behind the topmost interstitial (if any).
  List<Widget> _buildFowGroup(BuildContext context, List<RasqOverlayEntry> fows) {
    final widgets = <Widget>[];
    final blocking = fows.lastWhere((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none, orElse: () => fows.first);
    if (blocking.effectiveBarrierBehavior != OverlayBarrierBehavior.none) {
      widgets.add(Positioned.fill(
        child: Semantics(
          label: '閉じる',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(blocking.id),
            child: ColoredBox(color: scrimColor ?? Colors.black.withValues(alpha: 0.35)),
          ),
        ),
      ));
    }
    widgets.add(Positioned.fill(
      child: _FowColumn(
        entries: fows,
        buildContent: (e) {
          final handle = manager.handleFor(e);
          Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
          if (e.semanticsLabel != null) content = Semantics(label: e.semanticsLabel, container: true, child: content);
          return content;
        },
        onCancel: (e) => manager.close(e.id, reason: OverlayCloseReason.discard),
        onConfirm: (e) => manager.close(e.id, result: true),
      ),
    ));
    return widgets;
  }
}

/// Lays FOW panels out bottom-up. Heights come from each spec's heightFactor
/// and are scaled down proportionally when they would not fit.
class _FowColumn extends StatelessWidget {
  const _FowColumn({required this.entries, required this.buildContent, required this.onCancel, required this.onConfirm});
  final List<RasqOverlayEntry> entries;
  final Widget Function(RasqOverlayEntry) buildContent;
  final void Function(RasqOverlayEntry) onCancel;
  final void Function(RasqOverlayEntry) onConfirm;

  @override
  Widget build(BuildContext context) {
    final ordered = entries.reversed.toList(); // newest first → placed at bottom
    return LayoutBuilder(builder: (context, constraints) {
      final insets = MediaQuery.viewInsetsOf(context).bottom;
      final avail = constraints.maxHeight - insets;
      return AnimatedBuilder(
        animation: Listenable.merge([for (final e in ordered) e.fow?.heightFactor].whereType<Listenable>().toList()),
        builder: (context, _) {
          final factors = [for (final e in ordered) (e.fow?.heightFactor.value ?? 0.45)];
          final total = factors.fold(0.0, (a, b) => a + b);
          final scale = total > 1 ? 1 / total : 1.0;
          final heights = [for (final f in factors) f * scale * avail];
          // Older entries are above; the newest sits at the very bottom.
          return Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (var i = ordered.length - 1; i >= 0; i--)
                _FowPanel(entry: ordered[i], height: heights[i], child: buildContent(ordered[i]), onCancel: () => onCancel(ordered[i]), onConfirm: () => onConfirm(ordered[i])),
            ]),
          );
        },
      );
    });
  }
}

class _FowPanel extends StatelessWidget {
  const _FowPanel({required this.entry, required this.height, required this.child, required this.onCancel, required this.onConfirm});
  final RasqOverlayEntry entry;
  final double height;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final spec = entry.fow ?? FowSpec();
    final scheme = Theme.of(context).colorScheme;
    final hostHeight = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height,
      child: Material(
        color: scheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          if (spec.showHandle)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: spec.resizable ? (d) => spec.resizeBy(d.delta.dy / hostHeight) : null,
              child: Semantics(
                label: 'サイズ変更ハンドル',
                child: SizedBox(
                  height: 18,
                  width: double.infinity,
                  child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2)))),
                ),
              ),
            ),
          if (spec.hasHeader)
            SizedBox(
              height: 40,
              child: Row(children: [
                if (spec.cancelText != null) TextButton(onPressed: onCancel, child: Text(spec.cancelText!, style: TextStyle(color: scheme.onSurfaceVariant))) else const SizedBox(width: 80),
                Expanded(child: Center(child: Text(spec.title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
                if (spec.confirmText != null) TextButton(onPressed: onConfirm, child: Text(spec.confirmText!, style: TextStyle(color: scheme.primary))) else const SizedBox(width: 80),
              ]),
            ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

/// Positions a dropdown next to its anchor, flipping horizontally/vertically
/// when it would overflow (「スクリーン端で位置反転」).
///
/// `LayoutBuilder → Positioned` の形は ParentDataWidget 違反(Positioned は
/// Stack の直下限定)で、開くたびに debug 例外が出ていた —
/// [CustomSingleChildLayout] のデリゲートで座標計算する形に修正 (D-039)。
class _AnchoredDropdown extends StatelessWidget {
  const _AnchoredDropdown({required this.anchor, required this.child});
  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: CustomSingleChildLayout(delegate: _DropdownLayout(anchor), child: child),
      );
}

class _DropdownLayout extends SingleChildLayoutDelegate {
  const _DropdownLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        maxWidth: constraints.maxWidth * 0.8,
        maxHeight: constraints.maxHeight * 0.6,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final openDown = anchor.bottom + 200 <= size.height || anchor.top < size.height / 2;
    final openRight = anchor.left + 220 <= size.width;
    final top = openDown ? anchor.bottom : anchor.top - childSize.height;
    final left = openRight ? anchor.left : anchor.right - childSize.width;
    return Offset(
      left.clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity)),
      top.clamp(0.0, (size.height - childSize.height).clamp(0.0, double.infinity)),
    );
  }

  @override
  bool shouldRelayout(_DropdownLayout oldDelegate) => oldDelegate.anchor != anchor;
}
