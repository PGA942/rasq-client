import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'store_models.dart';

/// リリースノートの FOW (D-137: 「アップデートとバージョン」のフレームを
/// タップすると、その版のリリースノートが Function Override Widget で開く)。
///
/// 中身 = 版 / チャンネル / 公開日 → リリースノート本文 → **この版で増えた
/// 権限**(種別ラベル付き、危険色)→ 「Ver.〇〇をインストール」ボタン。
/// インストールは呼び出し側([onInstall])が確認シート → 検証を通す。
const releaseFowId = 'fow.store.release';

Future<void> openReleaseFow(
  WidgetRef ref, {
  required StorePluginDetail detail,
  required ReleaseNote release,
  required InstalledPlugin? installed,
  required Future<void> Function(String version) onInstall,
  int column = 0,
}) async {
  final manager = ref.read(overlayManagerProvider);
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.5,
    minHeightFactor: 0.3,
    maxHeightFactor: 0.9,
    title: '${detail.name} ${release.version}',
    cancelText: '閉じる',
    dockAboveFooter: true,
    columnIndex: column,
  );
  await manager.showFow<void>(
    id: releaseFowId,
    spec: spec,
    semanticsLabel: 'リリースノート ${release.version}',
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => ReleaseNoteBody(
      detail: detail,
      release: release,
      installed: installed,
      onInstall: () async {
        handle.close();
        await onInstall(release.version);
      },
    ),
  );
}

/// FOW の中身(テストしやすいように分離)。
class ReleaseNoteBody extends StatelessWidget {
  const ReleaseNoteBody({super.key, required this.detail, required this.release, required this.installed, required this.onInstall});
  final StorePluginDetail detail;
  final ReleaseNote release;
  final InstalledPlugin? installed;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final isCurrent = installed?.version == release.version;
    // 停止/失効は新規インストール不可(警告はバナー明示の上で可, D-120 ③)。
    final blocked = detail.status.isCaution && detail.status != PluginStatus.warning;
    final date = release.publishedAt;
    final meta = [
      release.channel == 'beta' ? 'プレビュー版 (β)' : '安定版',
      '${date.year}/${date.month}/${date.day} 公開',
      if (detail.version == release.version) '現在の掲載版',
      if (isCurrent) 'インストール中',
    ].join(' ・ ');
    return ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.page), children: [
      Text(meta, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: RasqSpacing.sm),
      Text(release.notes.isEmpty ? 'この版のリリースノートはありません。' : release.notes, style: RasqTypography.body),
      if (release.permissionsAdded.isNotEmpty) ...[
        const SizedBox(height: RasqSpacing.md),
        Container(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.key_outlined, size: 16, color: tokens.danger),
              const SizedBox(width: 6),
              Text('この版で増えた権限', style: RasqTypography.bodySmall.copyWith(color: tokens.danger, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            for (final p in release.permissionsAdded)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${p.kind.label}: ${p.permission} — ${p.reason}', style: RasqTypography.bodySmall),
              ),
            const SizedBox(height: RasqSpacing.xs),
            Text('権限が増える更新は自動アップデートの対象外です。内容を確認してから入れてください。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ],
      const SizedBox(height: RasqSpacing.lg),
      FilledButton(
        onPressed: isCurrent || blocked ? null : onInstall,
        child: Text(
          isCurrent
              ? 'Ver.${release.version} はインストール済み'
              : blocked
                  ? '${detail.status.label}のためインストールできません'
                  : 'Ver.${release.version} をインストール',
        ),
      ),
      if (installed != null && !isCurrent)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: Text('現在 v${installed!.version} が入っています。この版に置き換わります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ),
    ]);
  }
}
