import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/server_info_api.dart';

/// 「{サーバーのアイコン} サーバー名」(D-388、検索のトレンドの行)。アイコンと名前は Central のサーバー情報(D-345)。
/// 取れなければ SNS の色の印 + ホスト名。ほかのサーバーでもトレンドなら「+N」。
class ServerBadge extends ConsumerWidget {
  const ServerBadge({super.key, required this.account, this.more = 0, this.iconSize = 16});
  final AccountId account;
  final int more;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = ref.watch(serverInfoProvider(account.instance)).value;
    final icon = info?.iconUrl;
    final style = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Row(key: ValueKey('server.badge.${account.instance}'), mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(iconSize * 0.25),
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: icon == null
              ? Center(child: RasqSnsPill(account: account, showLabel: false, dotSize: iconSize * 0.7))
              : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '$icon', fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: RasqSnsPill(account: account, showLabel: false, dotSize: iconSize * 0.7))),
        ),
      ),
      const SizedBox(width: 4),
      Flexible(child: Text(info?.displayName ?? account.instance, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (more > 0) Text(' +$more', style: style.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}
