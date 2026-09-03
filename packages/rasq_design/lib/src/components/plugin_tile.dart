import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// プラグイン/ノード/サーバー表示の共用タイル (D-093)。
///
/// 「アクションバーをなくして `>` メニューがついた投稿タイルみたいなもの」—
/// 左にアイコン(投稿タイルのアバター位置)、名前 + 提供元の積みヘッダー
/// (displayName/handle と同じタイポグラフィ)、本文(説明)、任意の詳細行、
/// 右端に `>`。ノード検索・プラグインストア・サーバー一覧で使い回す。
class RasqPluginTile extends StatelessWidget {
  const RasqPluginTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.description,
    this.detail,
    this.detailColorDots = const [],
    this.onTap,
    this.chevron = true,
    this.padding,
  });

  /// 左上のアイコン(角丸タイル内)。[leading] があればそちらを優先。
  final IconData? icon;
  final Widget? leading;

  /// 名前(投稿タイルの displayName 相当)。
  final String title;

  /// 提供元/ジャンルなど(handle 相当のグレー行)。
  final String? subtitle;

  /// 説明本文(投稿本文相当)。
  final String? description;

  /// 追加の 1 行(ノードの入出力情報など、caption)。
  final String? detail;

  /// [detail] の先頭に付ける色ドット(データ形式の色など)。
  final List<Color> detailColorDots;

  final VoidCallback? onTap;

  /// 右端の `>`(メニューへの導線)。
  final bool chevron;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: leading ?? Icon(icon ?? Icons.extension_outlined, size: 22),
          ),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: RasqTypography.displayName, overflow: TextOverflow.ellipsis),
                    if (subtitle != null) Text(subtitle!, style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (chevron) Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
              ]),
              if (description != null) ...[
                const SizedBox(height: RasqSpacing.xs),
                Text(description!, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (detail != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  for (final c in detailColorDots) ...[
                    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                    const SizedBox(width: 3),
                  ],
                  if (detailColorDots.isNotEmpty) const SizedBox(width: 3),
                  Expanded(child: Text(detail!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
