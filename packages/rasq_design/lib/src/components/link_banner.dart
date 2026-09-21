import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// リンク先バナー (RRL tag `link`): OGP-style card under the post body.
/// VC links are *not* rendered here — the host swaps in the VC component
/// (原典: 「VCリンク時はVCコンポーネントに置き換え」).
class RasqLinkBanner extends StatelessWidget {
  const RasqLinkBanner({super.key, required this.url, this.title, this.description, this.imageUrl, this.onTap});

  final Uri url;
  final String? title;
  final String? description;
  final Uri? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      label: title ?? url.toString(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
            clipBehavior: Clip.antiAlias,
            child: Row(children: [
              if (imageUrl != null)
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, imageUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.link, color: scheme.onSurfaceVariant))),
                )
              else
                SizedBox(width: 56, height: 88, child: Icon(Icons.link, color: scheme.onSurfaceVariant)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (title != null) Text(title!, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (description != null) Text(description!, style: RasqTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(url.host, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
