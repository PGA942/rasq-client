import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'timestamp.dart';
import '../l10n/design_l10n.dart';

/// 投票コンポーネント (L2 composite `PollWidget`, RRL tag `vote` / `vote_option`).
///
/// State machine is derived from the [Poll] props (原典: UI_Elements「投票コンポー
/// ネント(状態切り替え)」):
///
/// | state | display |
/// |---|---|
/// | 未投票 | option buttons; multiple-choice shows checkboxes + 「投票する」 |
/// | 投票済み | result bars + percent + votes, own choice highlighted |
/// | 期限切れ | results even if not voted |
///
/// The only local state is the pending multi-select (ephemeral UI state, like
/// an `emit`); the vote itself goes out through [onVote] and comes back as a
/// new [Poll] from the Store.
class RasqPollWidget extends StatefulWidget {
  const RasqPollWidget({super.key, required this.poll, this.onVote, this.now});

  final Poll poll;

  /// Called with the chosen option indices. `null` → read-only (options are
  /// shown but disabled).
  final ValueChanged<Set<int>>? onVote;

  /// Injected clock for tests; defaults to `DateTime.now()`.
  final DateTime? now;

  @override
  State<RasqPollWidget> createState() => _RasqPollWidgetState();
}

class _RasqPollWidgetState extends State<RasqPollWidget> {
  final Set<int> _pending = {};

  @override
  void didUpdateWidget(covariant RasqPollWidget old) {
    super.didUpdateWidget(old);
    if (old.poll != widget.poll) _pending.clear();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final now = widget.now ?? DateTime.now();
    final results = poll.showsResults(now);
    final expired = poll.isExpired(now);
    return Semantics(
      container: true,
      label: context.designL10n.designPollVote,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < poll.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: results ? _ResultRow(option: poll.options[i], total: poll.totalVotes, chosen: poll.votedIndices.contains(i)) : _OptionRow(option: poll.options[i], index: i, poll: poll, pending: _pending, onToggle: _toggle, onVote: widget.onVote),
          ),
        if (!results && poll.multiple)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: widget.onVote == null || _pending.isEmpty ? null : () => widget.onVote!(Set.of(_pending)),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 36)),
              child: Text(context.designL10n.designPollSubmit),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            Text(context.designL10n.designPollVotes(poll.totalVotes), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (poll.expiresAt != null) ...[
              Text(' · ', style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (expired) Text(context.designL10n.designPollEnded, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)) else RasqTimestamp(poll.expiresAt!, mode: RasqTimestampMode.remaining, now: () => now),
            ],
          ]),
        ),
      ]),
    );
  }

  void _toggle(int i) => setState(() => _pending.contains(i) ? _pending.remove(i) : _pending.add(i));
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.index, required this.poll, required this.pending, required this.onToggle, required this.onVote});
  final PollOption option;
  final int index;
  final Poll poll;
  final Set<int> pending;
  final ValueChanged<int> onToggle;
  final ValueChanged<Set<int>>? onVote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onVote != null;
    final selected = pending.contains(index);
    final onTap = !enabled
        ? null
        : poll.multiple
            ? () => onToggle(index)
            : () => onVote!({index});
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: option.text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? scheme.primary : (enabled ? scheme.onSurface : scheme.outline), width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
            ),
            child: Row(children: [
              if (poll.multiple) ...[
                Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: RasqSpacing.sm),
              ],
              Expanded(child: Text(option.text, style: RasqTypography.listTile.copyWith(color: enabled ? scheme.onSurface : scheme.onSurfaceVariant), textAlign: poll.multiple ? TextAlign.start : TextAlign.center)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.option, required this.total, required this.chosen});
  final PollOption option;
  final int total;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : option.votes / total;
    final percent = (ratio * 100).round();
    return Semantics(
      label: '${option.text} $percent% ${context.designL10n.designPollVotes(option.votes)}${chosen ? context.designL10n.designPollVoted : ''}',
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: chosen ? scheme.primary : scheme.outline, width: chosen ? 2 : 1),
          borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0), child: ColoredBox(color: chosen ? scheme.primaryContainer : scheme.surfaceContainerHighest))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
            child: Row(children: [
              if (chosen) ...[Icon(Icons.check, size: 16, color: scheme.primary), const SizedBox(width: 4)],
              Expanded(child: Text(option.text, style: RasqTypography.listTile, overflow: TextOverflow.ellipsis)),
              Text('$percent%', style: RasqTypography.listTile),
              const SizedBox(width: RasqSpacing.sm),
              Text(context.designL10n.designPollVotes(option.votes), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}
