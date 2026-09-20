import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'avatar.dart';
import 'brand.dart';
import 'buttons.dart';
import 'rich_text.dart';
import 'sns_pill.dart';
import 'timestamp.dart';

/// The three post-card kinds (原典: UI_Elements「投稿カード系(3種)」).
enum RasqPostTileVariant {
  /// TL etc. Action bar, all slots, FOW may replace slots or the whole tile.
  normal,

  /// リアクション表示 / VC内 / タイマー通知 / 引用. No action bar, bordered.
  embedded,

  /// リレーショナルTL専用 — compact, no action bar, shows a thread footer.
  threadSummary,
}

/// 投稿カード (L2 composite `PostTile`, host-implemented per D-002).
///
/// Slot model (原典: 「PostCard スロット設計」, D-004 / D-005): the tile owns the
/// geometry — avatar column, header row, vertical rhythm, 44dp tap targets —
/// and exposes **slots** the host (and later the RRL renderer / validation
/// gate) fills:
///
/// | slot | prop | sideload | 審査済み |
/// |---|---|---|---|
/// | avatar | [avatar] (default: [RasqAvatar] of [author]) | ✗ | ✓ |
/// | content | [content] (本文: [RasqRichText] / [RasqCollapsedPost] / [RasqContentWarning]) | ✓ (GPU/net 不可) | ✓ |
/// | media | [media] ([RasqMediaGrid]) | tag only | ✓ |
/// | action | [actionBar] ([RasqActionBar]) | ✗ | ✓ |
/// | 完全置き換え | (replace the whole tile; must keep thread nav / tap size / media gap) | ✗ | ✓ |
///
/// [poll] / [quote] / [linkBanner] are content-slot children (RRL tags
/// `vote`, `quote`, `link`). Everything is props; the tile has no store access.
/// Strings inside slots are parsed by the host (RSL), so the tile takes
/// ready-made spans/widgets rather than raw text.
class RasqPostTile extends StatelessWidget {
  const RasqPostTile({
    super.key,
    this.variant = RasqPostTileVariant.normal,
    required this.author,
    required this.createdAt,
    required this.content,
    this.nameSpans,
    this.repostedBy,
    this.bannerIcon,
    this.bannerText,
    this.avatar,
    this.media,
    this.poll,
    this.quote,
    this.linkBanner,
    this.actionBar,
    this.onTap,
    this.onAuthorTap,
    this.onMore,
    this.headerAction,
    this.dense = false,
    this.threadReplyCount,
    this.padding,
  });

  final RasqPostTileVariant variant;
  final UserSummary author;
  final DateTime createdAt;

  /// Display name as RSL spans (custom emoji in names). Falls back to plain
  /// [UserSummary.displayName].
  final List<RasqSpan>? nameSpans;
  final UserSummary? repostedBy;

  /// 上付きバナー行 (D-085): RT 行と同スタイルの「アイコン + テキスト」。
  /// TL プラグイン(tl.customize の badges)や RRL の PostTile props から渡る。
  final IconData? bannerIcon;
  final String? bannerText;

  /// avatar slot override.
  final Widget? avatar;

  /// content slot: body text (already parsed into a widget by the host).
  final Widget content;

  /// media slot.
  final Widget? media;
  final Widget? poll;

  /// 引用: an embedded-size [RasqPostTile] built by the host.
  final Widget? quote;
  final Widget? linkBanner;

  /// action slot; ignored for [RasqPostTileVariant.embedded] / threadSummary.
  final Widget? actionBar;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  /// `…` context menu. Receives the button's global rect so the host can
  /// anchor an Overlay-Manager dropdown on it. Hidden when null.
  final ValueChanged<Rect>? onMore;

  /// ヘッダー右上、`…` の左に置く追加ボタン (D-111: アカウント選択 ↓ など)。
  final Widget? headerAction;

  /// Smaller avatar, no outer page padding (notification 投稿タイル系).
  final bool dense;

  /// Footer for [RasqPostTileVariant.threadSummary] (e.g. 3 → 「3件の返信」).
  final int? threadReplyCount;

  /// Override the outer padding (host layout rules otherwise apply).
  final EdgeInsets? padding;

  bool get _showsActions => variant == RasqPostTileVariant.normal && actionBar != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final embedded = variant == RasqPostTileVariant.embedded;
    final summary = variant == RasqPostTileVariant.threadSummary;
    final avatarSize = embedded ? RasqSizes.avatarSm : (dense || summary ? RasqSizes.avatarMd : RasqSizes.avatarLg);

    final header = Row(children: [
      Expanded(
        child: InkWell(
          onTap: onAuthorTap,
          child: embedded ? _InlineName(author: author, nameSpans: nameSpans) : _StackedName(author: author, nameSpans: nameSpans),
        ),
      ),
      RasqTimestamp(createdAt),
      // ヘッダー右上の追加ボタン (D-111): … の左に置く(アカウント選択 ↓ 等)。
      if (headerAction != null && !embedded) headerAction!,
      if (onMore != null && !embedded)
        Builder(
          builder: (ctx) => RasqIconButton(
            icon: Icons.more_horiz,
            size: 20,
            tooltip: 'メニュー',
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox;
              onMore!(box.localToGlobal(Offset.zero) & box.size);
            },
          ),
        ),
    ]);

    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      SizedBox(height: embedded ? 2 : RasqSpacing.xs),
      content,
      if (media != null) ...[const SizedBox(height: RasqSpacing.sm), media!],
      if (poll != null) ...[const SizedBox(height: RasqSpacing.sm), poll!],
      if (quote != null) ...[const SizedBox(height: RasqSpacing.sm), quote!],
      if (linkBanner != null) ...[const SizedBox(height: RasqSpacing.sm), linkBanner!],
      if (_showsActions) ...[const SizedBox(height: RasqSpacing.xs), actionBar!],
      if (summary && threadReplyCount != null)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: Row(children: [
            Icon(Icons.forum_outlined, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('$threadReplyCount件の返信', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
    ]);

    final avatarWidget = avatar ?? RasqAvatar(imageUrl: author.avatarUrl, size: avatarSize, presence: author.presence, fallbackLabel: author.displayName, onTap: onAuthorTap);

    // 上付きバナー行(RT の「♻︎ 〇〇がリノートしました」と同スタイル)。
    // D-085: TL プラグインもアイコン名 + 表示テキストで同じ行を出せる。
    Widget bannerRow(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(left: avatarSize + RasqSpacing.md, bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
      ]),
    );

    Widget tile = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (bannerText != null && !embedded) bannerRow(bannerIcon ?? Icons.label_outline, bannerText!),
      if (repostedBy != null && !embedded) bannerRow(Icons.repeat, '${repostedBy!.displayName}がリノートしました'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        avatarWidget,
        SizedBox(width: embedded ? RasqSpacing.sm : RasqSpacing.md),
        Expanded(child: body),
      ]),
    ]);

    final pad = padding ??
        (embedded
            ? const EdgeInsets.all(RasqSpacing.sm)
            : dense
                ? const EdgeInsets.symmetric(vertical: RasqSpacing.xs)
                : const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.xs));

    if (embedded) {
      tile = Container(
        decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
        padding: pad,
        child: tile,
      );
    } else {
      tile = Padding(padding: pad, child: tile);
    }

    return Semantics(
      container: true,
      label: '${author.displayName}の投稿',
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: embedded ? BorderRadius.circular(RasqSizes.radiusMd) : null, child: tile),
      ),
    );
  }
}

/// 通常: 名前 / @handle ● SNS on two lines.
class _StackedName extends StatelessWidget {
  const _StackedName({required this.author, required this.nameSpans});
  final UserSummary author;
  final List<RasqSpan>? nameSpans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: _Name(author: author, nameSpans: nameSpans, style: RasqTypography.displayName)),
        RasqVerifiedBadge(kind: author.verification),
      ]),
      Row(children: [
        Flexible(child: Text('@${author.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 2),
        Flexible(child: RasqSnsPill(account: author.account)),
      ]),
    ]);
  }
}

/// 埋め込み: 名前 @handle on one line.
class _InlineName extends StatelessWidget {
  const _InlineName({required this.author, required this.nameSpans});
  final UserSummary author;
  final List<RasqSpan>? nameSpans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Flexible(child: _Name(author: author, nameSpans: nameSpans, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
      RasqVerifiedBadge(kind: author.verification, size: 14),
      const SizedBox(width: 6),
      Flexible(child: Text('@${author.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.author, required this.nameSpans, required this.style});
  final UserSummary author;
  final List<RasqSpan>? nameSpans;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = nameSpans;
    if (spans != null) return RasqRichText(spans, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Text(author.displayName, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
