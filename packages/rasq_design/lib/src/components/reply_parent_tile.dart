import 'package:flutter/material.dart';

import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'avatar.dart';
import '../l10n/design_l10n.dart';

/// リプライ元投稿の省略タイル (D-069、L2 composite `ReplyParentTile`)。
///
/// ワイヤーフレーム p.5 の DM ルーム/通知の形: 小アバター + 名前、右端に
/// 「N件の添付ファイル/リンク」のサマリー、下に本文 1 行。アバターの下から
/// **スレッド線(stem)**が伸びて、下の返信タイルへ繋がる。
/// TL に流れてきたリプライ・リプライ欄(スレッド展開)の 1 つ前の投稿で共用。
class RasqReplyParentTile extends StatelessWidget {
  const RasqReplyParentTile({super.key, required this.author, required this.content, this.attachmentSummary, this.onTap});

  final UserSummary author;

  /// 本文の抜粋(ホストが RSL を 1 行の RichText にして渡す)。
  final Widget content;

  /// 右端の添付サマリー(「1件の添付ファイル」「1件の添付リンク」等)。
  /// null = 非表示。
  final String? attachmentSummary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: context.designL10n.designReplyParentSemantics(author.displayName),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 左列: 小アバター + 下へ伸びるスレッド線(返信タイルへ接続)。
              SizedBox(
                width: RasqSizes.avatarMd,
                child: Column(children: [
                  RasqAvatar(imageUrl: author.avatarUrl, size: 22, fallbackLabel: author.displayName),
                  Expanded(
                    child: Center(child: Container(width: 2, margin: const EdgeInsets.only(top: 2), color: scheme.outlineVariant)),
                  ),
                ]),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: Text(author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (attachmentSummary != null)
                      Padding(
                        padding: const EdgeInsets.only(left: RasqSpacing.sm),
                        child: Text(attachmentSummary!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                  ]),
                  Padding(padding: const EdgeInsets.only(top: 1, bottom: 6), child: content),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
