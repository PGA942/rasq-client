import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'thread_section.dart';

/// 返信欄の上の帯 (D-070 → D-292): ∨ + 欄の名前 + 並び順。短押し = 並び順、長押し = 欄の切り替え。
/// SNS の投稿の詳細と、RASQ の投稿の詳細で共通。
class ThreadSectionBar extends StatelessWidget {
  const ThreadSectionBar({super.key, required this.label, required this.order, this.onSortTap, this.onModeTap, this.trailing});
  final String label;
  final ThreadSortOrder order;
  final ValueChanged<Rect>? onSortTap;
  final ValueChanged<Rect>? onModeTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: scheme.onSurface, width: 1))),
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
      height: RasqSizes.minTap,
      child: Row(children: [
        Builder(
          builder: (ctx) {
            Rect anchor() {
              final box = ctx.findRenderObject() as RenderBox;
              return box.localToGlobal(Offset.zero) & box.size;
            }

            return InkWell(
              key: const ValueKey('thread.section.bar'),
              onTap: onSortTap == null ? null : () => onSortTap!(anchor()),
              onLongPress: onModeTap == null ? null : () => onModeTap!(anchor()),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.keyboard_arrow_down, size: 18),
                const SizedBox(width: 4),
                Text(label, style: RasqTypography.tab),
                if (order != ThreadSortOrder.none) Padding(padding: const EdgeInsets.only(left: 6), child: Text(order.label, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
              ]),
            );
          },
        ),
        const Spacer(),
        ?trailing,
      ]),
    );
  }
}
