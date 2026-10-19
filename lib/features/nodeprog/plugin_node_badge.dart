import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart' show UserSummary;
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../l10n/l10n.dart';

/// プラグインのノードの印 (D-355): このグラフの持ち主のアカウント(アイコン)と、そのアカウントで動くプラグインの版。
/// 「アカウントごとにバージョンを設定」で版を分けていると、同じプラグインでもアカウントで版が変わるので、ノードの上で見えるようにする。
/// [owner] null = 総合 / 関数の中身(既定の版)。[version] null = 登録されていない(動かない)。
class PluginNodeBadge extends StatelessWidget {
  const PluginNodeBadge({super.key, required this.owner, required this.version});
  final AccountSession? owner;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = owner;
    return Tooltip(
      message: [if (o != null) '${o.account}' else context.l10n.nodeprogEditorBadgeDefaultOwner, version == null ? context.l10n.nodeprogEditorBadgeNotRegistered : 'v$version'].join(context.l10n.nodeprogEditorBadgeSeparator),

      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 1, 6, 1),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (o != null) RasqAvatar(imageUrl: o.avatarUrl, size: 14, fallbackLabel: o.displayName ?? o.account.handle) else Icon(Icons.public, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(version == null ? '—' : 'v$version', style: RasqTypography.caption.copyWith(fontSize: 10, color: version == null ? scheme.error : scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// ヘッダーのアイコン用(グラフの持ち主のアカウント)。
UserSummary ownerSummaryOf(AccountSession s) => UserSummary(id: s.account.key, account: s.account, displayName: s.displayName ?? s.account.handle, avatarUrl: s.avatarUrl);
