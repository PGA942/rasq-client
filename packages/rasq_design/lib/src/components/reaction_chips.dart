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

  static String _nameOf(String r) => r.startsWith(':') ? r.replaceAll(RegExp(r'^:|@[^:]*:$|:$'), '') : r;

  static bool _isLocal(String r) => !r.startsWith(':') || r.endsWith('@.:') || !r.contains('@');

  /// 絵文字名が同じ変種(`:cat@.:` と `:cat@remote.example:` 等)を 1 タイルに
  /// 合算する (D-041)。代表はローカルサーバーの絵文字を優先。ImageHash に
  /// よる同一判定は絵文字側の事前計算インデックス(絵文字予測.md)導入時に
  /// 追加する。
  @visibleForTesting
  static List<GroupedReaction> group(Map<String, int> reactions, String? myReaction) {
    final byName = <String, GroupedReaction>{};
    for (final e in reactions.entries) {
      final name = _nameOf(e.key);
      final cur = byName[name];
      final local = _isLocal(e.key);
      if (cur == null) {
        byName[name] = GroupedReaction(name: name, representative: e.key, count: e.value, hasLocal: local, mine: e.key == myReaction);
      } else {
        byName[name] = GroupedReaction(
          name: name,
          // ローカル変種があればそれを代表に(リアクション送信もローカルで)。
          representative: cur.hasLocal ? cur.representative : (local ? e.key : cur.representative),
          count: cur.count + e.value,
          hasLocal: cur.hasLocal || local,
          mine: cur.mine || e.key == myReaction,
        );
      }
    }
    return byName.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final grouped = group(reactions, myReaction);
    final entries = grouped.take(maxChips).toList();
    final rest = grouped.length - entries.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final g in entries) _chip(context, scheme, g),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('+$rest', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }

  Widget _chip(BuildContext context, ColorScheme scheme, GroupedReaction g) {
    final mine = g.mine;
    final url = emojiUrls[g.representative] ?? emojiUrls.entries.where((e) => _nameOf(e.key) == g.name).firstOrNull?.value;
    final emoji = RasqCustomEmoji(url: url, fallbackText: g.representative.startsWith(':') ? g.name : g.representative, height: 18, name: g.name);
    final count = Text('${g.count}', style: RasqTypography.count.copyWith(color: mine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant));

    // ローカルサーバーに無い絵文字はリアクションできない → **枠なし**の
    // 表示のみ(タップ不可、D-041)。
    if (!g.hasLocal) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [emoji, const SizedBox(width: 4), count]),
      );
    }
    return Material(
      color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(RasqSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(RasqSpacing.sm),
        onTap: onTap == null ? null : () => onTap!(g.representative),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 3),
          decoration: mine ? BoxDecoration(border: Border.all(color: scheme.primary, width: 1.2), borderRadius: BorderRadius.circular(RasqSpacing.sm)) : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [emoji, const SizedBox(width: 4), count]),
        ),
      ),
    );
  }
}

/// [RasqReactionChips.group] の 1 グループ。
@immutable
class GroupedReaction {
  const GroupedReaction({required this.name, required this.representative, required this.count, required this.hasLocal, required this.mine});
  final String name;

  /// タップ時に送るリアクション文字列(ローカル変種優先)。
  final String representative;
  final int count;
  final bool hasLocal;
  final bool mine;
}
