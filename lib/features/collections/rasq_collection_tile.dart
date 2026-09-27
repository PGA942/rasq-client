import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart' show Routes;
import '../../backend/rasq_collections_api.dart';
import 'rasq_collections.dart';

/// RASQ リスト / RASQ クリップのタイル (D-345)。AsTell のタイルと同じ角丸 + グラデーションの面に、
/// 種類のアイコン + 種類名 / 名前 / 作った人 / 説明(2 行)/ 人数(件数)・フォロワー / 入っているサーバー(3 つまで)/「見てみる」。
class RasqCollectionTile extends StatelessWidget {
  const RasqCollectionTile({super.key, required this.collection, this.onOpen});
  final RasqCollection collection;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = collection;
    final isList = c.kind == RasqCollectionKind.list;
    final caption = [
      isList ? '${c.itemCount}人' : '${c.itemCount}件',
      if (c.followerCount > 0) 'フォロワー ${c.followerCount}',
      if (!c.isPublic) '非公開',
    ].join(' ・ ');
    return Container(
      key: ValueKey('rasqCollection.tile.${c.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        gradient: LinearGradient(
          colors: [(isList ? RasqColors.lightBlue : RasqColors.yellow).withValues(alpha: 0.35), RasqColors.main.withValues(alpha: 0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(isList ? Icons.people_alt_outlined : Icons.workspaces_outlined, size: 16, color: RasqColors.sub),
          const SizedBox(width: RasqSpacing.xs),
          Text(isList ? 'RASQ リスト' : 'RASQ クリップ', style: RasqTypography.caption.copyWith(color: RasqColors.sub, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(c.name, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(children: [
          RasqAvatar(imageUrl: c.owner.avatarUrl, size: 18, fallbackLabel: c.owner.displayName),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(child: Text('${c.owner.displayName} @${c.owner.handle}', style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        if (c.description != null) ...[
          const SizedBox(height: RasqSpacing.xs),
          Text(c.description!, style: RasqTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: RasqSpacing.xs),
        Row(children: [
          Expanded(
            child: Text(
              [caption, if (c.instances.isNotEmpty) c.instances.take(3).join(' / ')].join(' ・ '),
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onOpen != null) TextButton(key: ValueKey('rasqCollection.tile.open.${c.id}'), onPressed: onOpen, child: const Text('見てみる')),
        ]),
      ]),
    );
  }
}

/// 投稿の本文に共有リンクがあるときのタイル(PostRow)。概要だけを引く(取り直さない)。見られない / 消えたものは出さない。
class RasqCollectionPostTile extends ConsumerWidget {
  const RasqCollectionPostTile({super.key, required this.idOrCode});
  final String idOrCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(rasqCollectionSummaryProvider(idOrCode)).value;
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: RasqSpacing.xs),
      child: RasqCollectionTile(collection: c, onOpen: () => context.push(Routes.rasqCollection(c.code ?? c.id))),
    );
  }
}

/// 一覧の行(リスト画面 / アカウントページのタブ)。
class RasqCollectionRow extends StatelessWidget {
  const RasqCollectionRow({super.key, required this.collection, this.showOwner = false});
  final RasqCollection collection;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final isList = c.kind == RasqCollectionKind.list;
    return RasqListTile(
      key: ValueKey('rasqCollection.row.${c.id}'),
      title: c.name,
      subtitle: [
        isList ? '${c.itemCount}人' : '${c.itemCount}件',
        if (showOwner) '@${c.owner.handle}',
        c.isPublic ? '公開' : '非公開',
      ].join(' ・ '),
      leading: Icon(isList ? Icons.people_alt_outlined : Icons.workspaces_outlined),
      onTap: () => context.push(Routes.rasqCollection(c.code ?? c.id)),
    );
  }
}
