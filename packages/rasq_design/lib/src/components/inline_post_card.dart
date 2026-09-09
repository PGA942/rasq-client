import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'avatar.dart';
import 'rich_text.dart';

/// インラインフレームの小表示 (D-156、ワイヤーフレーム p.1 右端 / p.5 右端):
/// 別の面の中に投稿を埋め込むときのコンパクトなカード。小アバター + 名前 +
/// @handle を 1 行、本文は数行、メディアがあれば**左にサムネイル(最大 4 枚、
/// 2×2)**。TL の引用表示(通常の埋め込みタイル)は対象外。
class RasqInlinePostCard extends StatelessWidget {
  const RasqInlinePostCard({super.key, required this.author, required this.content, this.nameSpans, this.thumbnails = const [], this.mediaCount = 0, this.onTap, this.badge});

  final UserSummary author;
  final List<RasqSpan>? nameSpans;

  /// 本文(ホストが数行に切った RichText)。
  final Widget content;

  /// 左のサムネイル(URL、最大 4 枚まで使う)。
  final List<Uri> thumbnails;

  /// 添付の総数(5 枚以上のとき「+N」を出す)。
  final int mediaCount;
  final VoidCallback? onTap;

  /// 右上の小さな印(「引用」「添付」等)。
  final Widget? badge;

  static const thumbBox = 64.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumbs = thumbnails.take(4).toList();
    return Semantics(
      container: true,
      label: '${author.displayName}の投稿(インラインフレーム)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
            padding: const EdgeInsets.all(RasqSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (thumbs.isNotEmpty) ...[
                _Thumbnails(urls: thumbs, extra: mediaCount > 4 ? mediaCount - 4 : 0),
                const SizedBox(width: RasqSpacing.sm),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    RasqAvatar(imageUrl: author.avatarUrl, size: 18, fallbackLabel: author.displayName),
                    const SizedBox(width: 6),
                    Flexible(
                      child: nameSpans != null
                          ? RasqRichText(nameSpans!, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)
                          : Text(author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    Flexible(child: Text('@${author.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (badge != null) ...[const SizedBox(width: 4), badge!],
                  ]),
                  const SizedBox(height: 2),
                  content,
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 64×64 の箱に 1 枚なら全面、2 枚なら左右、3〜4 枚なら 2×2。
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({required this.urls, required this.extra});
  final List<Uri> urls;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget img(Uri u) => Image.network(u.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.image_outlined, size: 14, color: scheme.onSurfaceVariant)));
    Widget cell(int i) => Expanded(
          child: Stack(fit: StackFit.expand, children: [
            img(urls[i]),
            if (extra > 0 && i == urls.length - 1) ColoredBox(color: Colors.black45, child: Center(child: Text('+$extra', style: RasqTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)))),
          ]),
        );
    final Widget body;
    if (urls.length == 1) {
      body = img(urls[0]);
    } else if (urls.length == 2) {
      body = Row(children: [cell(0), const SizedBox(width: 2), cell(1)]);
    } else {
      body = Column(children: [
        Expanded(child: Row(children: [cell(0), const SizedBox(width: 2), cell(1)])),
        const SizedBox(height: 2),
        Expanded(child: Row(children: [cell(2), const SizedBox(width: 2), if (urls.length > 3) cell(3) else const Expanded(child: SizedBox())])),
      ]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(key: Key('inline.thumbs.${urls.length}'), width: RasqInlinePostCard.thumbBox, height: RasqInlinePostCard.thumbBox, child: body),
    );
  }
}
