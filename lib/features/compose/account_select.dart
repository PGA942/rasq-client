import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// アカウント選択ピル (D-170): FOW ヘッダー左に置く 200〜300px の角丸ピル。
/// アバター + SNS の色点 + `@handle@instance` + ▾。共有 FOW とコンポーザーで同じ見た目。
/// タップの中身は呼び出し側([onTap])— 共有 FOW はドロップダウン、コンポーザーは
/// アカウントバンドルタイルの開閉。
class AccountSelectPill extends StatelessWidget {
  const AccountSelectPill({super.key, required this.account, this.displayName, this.avatarUrl, this.onTap, this.open = false, this.tooltip, this.minWidth = 200, this.maxWidth = 300});
  final AccountId account;
  final String? displayName;
  final Uri? avatarUrl;
  final VoidCallback? onTap;

  /// 開いている(▴)か。
  final bool open;
  final String? tooltip;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth, minHeight: 32, maxHeight: 32),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              RasqAvatar(imageUrl: avatarUrl, size: 24, fallbackLabel: displayName ?? account.handle),
              const SizedBox(width: 6),
              RasqSnsPill(account: account, showLabel: false, dotSize: 10),
              const SizedBox(width: 6),
              // handle と instance は別の Text(バンドルタイルの `@handle@instance` 行と区別)。
              Flexible(child: Text('@${account.handle}', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1)),
              Flexible(child: Text('@${account.instance}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis, maxLines: 1)),
              const SizedBox(width: 2),
              Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: onTap == null ? scheme.onSurfaceVariant.withValues(alpha: 0.4) : scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// ピルの矩形を錨にアカウントのドロップダウンを出す(共有 FOW 用)。
Future<AccountSession?> pickAccountSession(OverlayManager manager, {required String id, required Rect anchor, required List<AccountSession> sessions, AccountSession? selected}) async {
  final key = await manager.showDropdown<String>(id: id, anchor: anchor, dense: true, items: [
    for (final s in sessions) RasqDropdownItem('${s.account}', s.account.key, checked: s.account.key == selected?.account.key),
  ]);
  if (key == null) return null;
  return sessions.where((s) => s.account.key == key).firstOrNull;
}
