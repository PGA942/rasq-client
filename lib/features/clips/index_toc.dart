import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'virtual_index.dart';
import '../../l10n/l10n.dart';

/// 仮想目次の表示部品 (D-036)。クリップTL(「目次」)とリストTL
/// (「いま話されていること」)で共用。章タップで絞り込みトグル。
/// 状態アイコン: ● 進行中 / ○ 休眠 / … 未分類・単発。
class VirtualIndexToc extends StatefulWidget {
  const VirtualIndexToc({super.key, required this.entries, required this.selectedId, required this.onSelect, this.title, this.showState = false});

  final List<IndexEntry> entries;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  /// null = 「目次」。
  final String? title;

  /// true = 会話イベント由来(進行中/休眠のアイコンを出す)。
  final bool showState;

  @override
  State<VirtualIndexToc> createState() => _VirtualIndexTocState();
}

class _VirtualIndexTocState extends State<VirtualIndexToc> {
  bool _open = true;

  IconData _icon(IndexEntry e, {required bool child}) {
    if (child) return Icons.subdirectory_arrow_right;
    if (e.labelSource == 'fallback') return Icons.more_horiz;
    if (!widget.showState) return Icons.tag;
    return switch (e.state) {
      IndexEntryState.active => Icons.circle,
      IndexEntryState.dormant => Icons.circle_outlined,
      IndexEntryState.tentative => Icons.pending_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    Widget row(IndexEntry e, {bool child = false}) {
      final active = widget.selectedId == e.id;
      return InkWell(
        onTap: () => widget.onSelect(active ? null : e.id),
        child: Container(
          padding: EdgeInsets.fromLTRB(RasqSpacing.page + (child ? RasqSpacing.lg : 0), 6, RasqSpacing.page, 6),
          color: active ? scheme.primary.withValues(alpha: 0.08) : null,
          child: Row(children: [
            Icon(_icon(e, child: child), size: widget.showState && !child ? 10 : 16, color: e.state == IndexEntryState.active && widget.showState ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(child: Text(e.label, style: RasqTypography.bodySmall.copyWith(fontWeight: active ? FontWeight.w700 : null, color: e.labelSource == 'fallback' ? scheme.onSurfaceVariant : null))),
            if (widget.showState && e.participantKeys.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: Text(context.l10n.clipsTocPeople(e.participantKeys.length), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            Text(context.l10n.clipsPostCount(e.count), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 4),
          child: Row(children: [
            Icon(Icons.toc, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.sm),
            Text(widget.title ?? context.l10n.clipsTocTitle, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            if (widget.selectedId != null) ...[
              const SizedBox(width: RasqSpacing.sm),
              Text(context.l10n.clipsTocFiltering, style: RasqTypography.caption.copyWith(color: scheme.primary)),
            ],
            const Spacer(),
            AnimatedRotation(turns: _open ? 0 : -0.25, duration: const Duration(milliseconds: 150), child: Icon(Icons.keyboard_arrow_down, size: 18, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
      if (_open)
        for (final e in widget.entries) ...[
          row(e),
          for (final c in e.children) row(c, child: true),
        ],
      const Divider(),
    ]);
  }
}

/// entries(2 階層)から id で探す。
IndexEntry? findIndexEntry(List<IndexEntry> entries, String? id) {
  if (id == null) return null;
  for (final e in entries) {
    if (e.id == id) return e;
    for (final c in e.children) {
      if (c.id == id) return c;
    }
  }
  return null;
}
