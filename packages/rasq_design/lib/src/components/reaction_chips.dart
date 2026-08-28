import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'custom_emoji.dart';

/// 投稿内のリアクション数表示 (D-040): アクションバーの上に並ぶ角丸ボタン
/// タイル(絵文字 + 数)。既定は最大 [maxChips] 個。自分がリアクションした
/// タイルはハイライト。ホバー/長押しで絵文字のチップ([RasqCustomEmoji])。
class RasqReactionChips extends StatelessWidget {
  const RasqReactionChips({
    super.key,
    required this.reactions,
    this.emojiUrls = const {},
    this.myReaction,
    this.maxChips = 10,
    this.onTap,
  });

  /// リアクション文字列(`👍` / `:name@.:`)→ 数。表示順は挿入順。
  final Map<String, int> reactions;

  /// カスタム絵文字リアクションの画像 URL。
  final Map<String, Uri> emojiUrls;
  final String? myReaction;
  final int maxChips;
  final ValueChanged<String>? onTap;

  String _nameOf(String r) => r.startsWith(':') ? r.replaceAll(RegExp(r'^:|@[^:]*:$|:$'), '') : r;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final entries = reactions.entries.take(maxChips).toList();
    final rest = reactions.length - entries.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final e in entries)
          _chip(context, scheme, e.key, e.value),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('+$rest', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }

  Widget _chip(BuildContext context, ColorScheme scheme, String reaction, int count) {
    final mine = reaction == myReaction;
    return Material(
      color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(RasqSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(RasqSpacing.sm),
        onTap: onTap == null ? null : () => onTap!(reaction),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 3),
          decoration: mine ? BoxDecoration(border: Border.all(color: scheme.primary, width: 1.2), borderRadius: BorderRadius.circular(RasqSpacing.sm)) : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            RasqCustomEmoji(url: emojiUrls[reaction], fallbackText: reaction.startsWith(':') ? _nameOf(reaction) : reaction, height: 18, name: _nameOf(reaction)),
            const SizedBox(width: 4),
            Text('$count', style: RasqTypography.count.copyWith(color: mine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
