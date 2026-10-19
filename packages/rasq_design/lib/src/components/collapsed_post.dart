import 'package:flutter/material.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/typography.dart';
import 'rich_text.dart';
import '../l10n/design_l10n.dart';

/// 省略表示コンポーネント (L2 composite `CollapsedPost`).
///
/// 既読投稿を折りたたみ表示: 先頭数行 + 「展開する」青文字。タップ領域はエリア全体
/// (テキストボタンではない)。TL・通知で共用。Whether a post *is* collapsed is
/// Store state (既読 + 長文) fed in by the host; this widget only renders the
/// collapsed form and reports the expand tap through [onExpand].
class RasqCollapsedPost extends StatelessWidget {
  const RasqCollapsedPost({super.key, required this.spans, this.maxLines = 3, this.onExpand, this.style, this.expandLabel});

  final List<RasqSpan> spans;
  final int maxLines;
  final VoidCallback? onExpand;
  final TextStyle? style;
  /// 省略すると「展開する」(表示の言語で、D-484)。
  final String? expandLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final expandLabel = this.expandLabel ?? context.designL10n.designExpandPost;
    return Semantics(
      button: true,
      label: expandLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onExpand,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RasqRichText(spans, style: style ?? RasqTypography.body, maxLines: maxLines, overflow: TextOverflow.ellipsis),
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(expandLabel, style: RasqTypography.bodySmall.copyWith(color: tokens.link))),
        ]),
      ),
    );
  }
}
